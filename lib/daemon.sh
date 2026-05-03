#!/usr/bin/env bash
# daemon.sh — LARC Daemon: IM polling → auto-enqueue + worker loop
# T-101: Lark IM event → auto enqueue
# T-104: larc daemon start/stop/status/logs
# T-015: stable PID management + watchdog auto-restart + health check

set -uo pipefail

# Resolve LIB_DIR relative to this file if not exported by parent
_DAEMON_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${LIB_DIR:-$_DAEMON_SH_DIR}"
source "${LIB_DIR}/runtime-common.sh"

larc_init_fallback_logs

DAEMON_PID_DIR="${LARC_HOME:-$HOME/.larc}/run"
DAEMON_LOG_DIR="${LARC_HOME:-$HOME/.larc}/logs"
DAEMON_SEEN_DIR="${LARC_HOME:-$HOME/.larc}/cache/daemon"
IM_PID_FILE="$DAEMON_PID_DIR/im-poller.pid"
WORKER_PID_FILE="$DAEMON_PID_DIR/worker.pid"
WATCHDOG_PID_FILE="$DAEMON_PID_DIR/watchdog.pid"
IM_LOG="$DAEMON_LOG_DIR/im-poller.log"
WORKER_LOG="$DAEMON_LOG_DIR/worker.log"
WATCHDOG_LOG="$DAEMON_LOG_DIR/watchdog.log"
IM_HEARTBEAT_FILE="$DAEMON_PID_DIR/im-poller.heartbeat"
WORKER_HEARTBEAT_FILE="$DAEMON_PID_DIR/worker.heartbeat"
# How long (seconds) before a process is considered stale even if PID exists
DAEMON_HEARTBEAT_TIMEOUT="${LARC_DAEMON_HEARTBEAT_TIMEOUT:-120}"
# How often (seconds) the watchdog checks + restarts
WATCHDOG_INTERVAL="${LARC_WATCHDOG_INTERVAL:-60}"
# Max lines to keep in seen file before pruning
SEEN_FILE_MAX_LINES="${LARC_SEEN_FILE_MAX_LINES:-2000}"

# ── helpers ──────────────────────────────────────────────────────────────────

_daemon_ensure_dirs() {
  mkdir -p "$DAEMON_PID_DIR" "$DAEMON_LOG_DIR" "$DAEMON_SEEN_DIR"
}

_daemon_is_running() {
  local pid_file="$1"
  [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null
}

# Check process is alive AND has written a heartbeat within DAEMON_HEARTBEAT_TIMEOUT seconds
_daemon_is_healthy() {
  local pid_file="$1" heartbeat_file="$2"
  _daemon_is_running "$pid_file" || return 1
  [[ -f "$heartbeat_file" ]] || return 1
  local last_beat now age
  last_beat=$(cat "$heartbeat_file" 2>/dev/null || echo 0)
  now=$(date +%s)
  age=$(( now - last_beat ))
  [[ "$age" -le "$DAEMON_HEARTBEAT_TIMEOUT" ]]
}

_daemon_write_heartbeat() {
  local heartbeat_file="$1"
  date +%s > "$heartbeat_file" 2>/dev/null || true
}

_daemon_stop_one() {
  local pid_file="$1" name="$2"
  local heartbeat_file="${3:-}"
  if _daemon_is_running "$pid_file"; then
    local pid
    pid=$(cat "$pid_file")
    kill "$pid" 2>/dev/null && log_ok "Stopped $name (PID $pid)"
    sleep 0.5
    # Force kill if still alive
    kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null || true
  else
    log_info "$name is not running"
  fi
  rm -f "$pid_file"
  [[ -n "$heartbeat_file" ]] && rm -f "$heartbeat_file" || true
}

# Prune seen file: keep only the last SEEN_FILE_MAX_LINES entries
_seen_file_prune() {
  local seen_file="$1"
  [[ -f "$seen_file" ]] || return 0
  local line_count
  line_count=$(wc -l < "$seen_file" | tr -d ' ')
  if [[ "$line_count" -gt "$SEEN_FILE_MAX_LINES" ]]; then
    local tmp
    tmp=$(mktemp -t larc_seen)
    tail -n "$SEEN_FILE_MAX_LINES" "$seen_file" > "$tmp" && mv "$tmp" "$seen_file"
    log_info "[daemon] Pruned seen file: $line_count → $SEEN_FILE_MAX_LINES lines"
  fi
}

# ── IM poller (T-101) ────────────────────────────────────────────────────────

_im_poller_loop() {
  local agent_id="${1:-main}"
  local interval="${2:-30}"

  # Load config in the background subprocess context
  larc_load_runtime_config

  local chat_id="${LARC_IM_CHAT_ID:-}"
  local allow_from="${LARC_ALLOW_FROM:-}"
  local seen_file="$DAEMON_SEEN_DIR/seen-${agent_id}.txt"

  # Get bot's own open_id once at startup to filter outbound echo messages
  local bot_open_id=""
  bot_open_id=$(lark-cli api GET /open-apis/bot/v3/info --as bot 2>/dev/null \
    | python3 -c "import json,sys; print(json.load(sys.stdin).get('bot',{}).get('open_id',''))" 2>/dev/null || echo "")

  log_head "LARC IM poller starting (agent=$agent_id, interval=${interval}s, bot=$bot_open_id)"

  touch "$seen_file"
  _daemon_write_heartbeat "$IM_HEARTBEAT_FILE"

  local _cycle=0
  while true; do
    _cycle=$(( _cycle + 1 ))
    # Prune seen file every 100 cycles
    [[ $(( _cycle % 100 )) -eq 0 ]] && _seen_file_prune "$seen_file"
    # Fetch recent messages from the configured chat
    local raw_msgs fetch_ok
    raw_msgs=$(lark-cli im +chat-messages-list \
      --chat-id "${chat_id}" \
      --page-size "20" \
      2>/dev/null) && fetch_ok=1 || fetch_ok=0

    if [[ "$fetch_ok" -eq 0 ]] || [[ -z "$raw_msgs" ]]; then
      log_warn "IM message fetch failed, retrying in ${interval}s"
      sleep "$interval"
      continue
    fi

    # Parse message list and process new ones (use temp file to avoid pipe+heredoc conflict)
    local tmp_msgs
    tmp_msgs=$(mktemp -t larc_msgs)
    echo "$raw_msgs" > "$tmp_msgs"

    python3 <<PY || true
import json, sys, subprocess, os

seen_file      = "$seen_file"
agent_id       = "$agent_id"
allow_from_raw = "$allow_from"
bot_open_id    = "$bot_open_id"
msgs_file      = "$tmp_msgs"
allow_set      = set(x.strip() for x in allow_from_raw.split(",") if x.strip())

try:
    try:
        with open(msgs_file) as f:
            data = json.load(f)
    except Exception as e:
        print(f"[im-poller] JSON parse error: {e}", flush=True)
        sys.exit(0)

    data  = data.get("data", data)
    items = data.get("messages") or data.get("items") or []

    try:
        with open(seen_file) as f:
            seen = set(line.strip() for line in f)
    except Exception:
        seen = set()

    new_ids = []
    for msg in items:
        msg_id  = msg.get("message_id", "")
        sender  = msg.get("sender", {}).get("id", "") or \
                  msg.get("sender", {}).get("sender_id", {}).get("open_id", "")
        sender_type = msg.get("sender", {}).get("sender_type", "") or \
                      msg.get("sender", {}).get("type", "")
        deleted = msg.get("deleted", False)

        if not msg_id or msg_id in seen or deleted:
            continue

        # Skip the bot's own outbound messages to prevent echo loop
        if bot_open_id and sender == bot_open_id:
            new_ids.append(msg_id)
            continue
        if sender_type in ("app", "bot"):
            new_ids.append(msg_id)
            continue

        if allow_set and sender not in allow_set:
            new_ids.append(msg_id)
            continue

        content_raw = msg.get("content", "") or msg.get("body", {}).get("content", "")
        try:
            parsed = json.loads(content_raw)
            text = parsed.get("text", "") or parsed.get("content", "") or content_raw
        except Exception:
            text = content_raw
        if isinstance(text, list):
            text = " ".join(str(x) for x in text)
        text = text.strip()

        # Skip larc outbound notification messages (fallback for user-token sends)
        if text.startswith("[larc →") or text.startswith("[larc→"):
            new_ids.append(msg_id)
            continue
        if not text:
            new_ids.append(msg_id)
            continue

        # Issue #42: subdivide source=im. Bot/echo senders are filtered above,
        # so anything reaching this point is a real user request from IM.
        cmd = ["larc", "ingress", "enqueue",
               "--text", text, "--sender", sender,
               "--source", "im_user_request", "--agent", agent_id]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode == 0:
            print(f"[im-poller] Enqueued: {msg_id[:16]}... from {sender[:20]}", flush=True)
        else:
            print(f"[im-poller] Enqueue failed: {result.stderr.strip()}", file=sys.stderr, flush=True)
        new_ids.append(msg_id)

    if new_ids:
        with open(seen_file, "a") as f:
            f.write("\n".join(new_ids) + "\n")
finally:
    try:
        os.unlink(msgs_file)
    except Exception:
        pass
PY

    _daemon_write_heartbeat "$IM_HEARTBEAT_FILE"
    sleep "$interval"
  done
}

_start_im_poller() {
  local agent_id="${1:-main}"
  local interval="${2:-30}"

  if _daemon_is_running "$IM_PID_FILE"; then
    log_warn "IM poller already running (PID $(cat "$IM_PID_FILE"))"
    return 0
  fi

  if [[ -z "${LARC_IM_CHAT_ID:-}" ]]; then
    log_warn "LARC_IM_CHAT_ID not set — IM poller disabled"
    return 0
  fi

  _im_poller_loop "$agent_id" "$interval" >> "$IM_LOG" 2>&1 &
  local pid=$!
  echo "$pid" > "$IM_PID_FILE"
  log_ok "IM poller started (PID $pid) — log: $IM_LOG"
}

# ── Worker loop (T-102 integration) ─────────────────────────────────────────

_worker_loop() {
  local agent_id="${1:-main}"
  local interval="${2:-30}"
  [[ "$(type -t _worker_poll_once)" == "function" ]] || \
    source "${LIB_DIR}/worker.sh"
  # worker.sh's cmd_worker runs its own loop; wrap it to emit heartbeats
  _daemon_write_heartbeat "$WORKER_HEARTBEAT_FILE"
  cmd_worker --agent "$agent_id" --interval "$interval" &
  local worker_inner_pid=$!
  while kill -0 "$worker_inner_pid" 2>/dev/null; do
    _daemon_write_heartbeat "$WORKER_HEARTBEAT_FILE"
    sleep "$interval"
  done
}

_start_worker() {
  local agent_id="${1:-main}"
  local interval="${2:-30}"

  if _daemon_is_running "$WORKER_PID_FILE"; then
    log_warn "Worker already running (PID $(cat "$WORKER_PID_FILE"))"
    return 0
  fi

  _worker_loop "$agent_id" "$interval" >> "$WORKER_LOG" 2>&1 &
  local pid=$!
  echo "$pid" > "$WORKER_PID_FILE"
  log_ok "Worker started (PID $pid) — log: $WORKER_LOG"
}

# ── Watchdog (T-015) ─────────────────────────────────────────────────────────
# Monitors IM poller + worker; restarts either if it dies or stops heartbeating.

_watchdog_loop() {
  local agent_id="${1:-main}"
  local interval="${2:-30}"

  larc_load_runtime_config
  log_head "LARC watchdog starting (agent=$agent_id, check_interval=${WATCHDOG_INTERVAL}s)"

  while true; do
    sleep "$WATCHDOG_INTERVAL"

    # Restart IM poller if dead or heartbeat stale
    if ! _daemon_is_healthy "$IM_PID_FILE" "$IM_HEARTBEAT_FILE"; then
      if [[ -n "${LARC_IM_CHAT_ID:-}" ]]; then
        log_warn "[watchdog] IM poller down — restarting"
        rm -f "$IM_PID_FILE"
        _im_poller_loop "$agent_id" "$interval" >> "$IM_LOG" 2>&1 &
        echo "$!" > "$IM_PID_FILE"
        log_ok "[watchdog] IM poller restarted (PID $(cat "$IM_PID_FILE"))"
      fi
    fi

    # Restart worker if dead or heartbeat stale
    if ! _daemon_is_healthy "$WORKER_PID_FILE" "$WORKER_HEARTBEAT_FILE"; then
      log_warn "[watchdog] Worker down — restarting"
      rm -f "$WORKER_PID_FILE"
      _worker_loop "$agent_id" "$interval" >> "$WORKER_LOG" 2>&1 &
      echo "$!" > "$WORKER_PID_FILE"
      log_ok "[watchdog] Worker restarted (PID $(cat "$WORKER_PID_FILE"))"
    fi
  done
}

_start_watchdog() {
  local agent_id="${1:-main}"
  local interval="${2:-30}"

  if _daemon_is_running "$WATCHDOG_PID_FILE"; then
    log_warn "Watchdog already running (PID $(cat "$WATCHDOG_PID_FILE"))"
    return 0
  fi

  _watchdog_loop "$agent_id" "$interval" >> "$WATCHDOG_LOG" 2>&1 &
  local pid=$!
  echo "$pid" > "$WATCHDOG_PID_FILE"
  log_ok "Watchdog started (PID $pid) — log: $WATCHDOG_LOG"
}

# ── Public interface ─────────────────────────────────────────────────────────

cmd_daemon() {
  local subcmd="${1:-help}"
  shift || true

  _daemon_ensure_dirs

  case "$subcmd" in
    start)
      local agent_id="main" interval=30
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --agent)    agent_id="$2"; shift 2 ;;
          --interval) interval="$2"; shift 2 ;;
          *) shift ;;
        esac
      done

      log_head "Starting LARC daemon (agent=$agent_id, interval=${interval}s)"
      _start_im_poller "$agent_id" "$interval"
      _start_worker    "$agent_id" "$interval"
      _start_watchdog  "$agent_id" "$interval"
      log_ok "LARC daemon started (watchdog active — auto-restart enabled)"
      ;;

    stop)
      log_head "Stopping LARC daemon"
      # Stop watchdog first so it doesn't restart the others during shutdown
      _daemon_stop_one "$WATCHDOG_PID_FILE" "Watchdog"
      _daemon_stop_one "$IM_PID_FILE"       "IM poller" "$IM_HEARTBEAT_FILE"
      _daemon_stop_one "$WORKER_PID_FILE"   "Worker"    "$WORKER_HEARTBEAT_FILE"
      log_ok "LARC daemon stopped"
      ;;

    restart)
      cmd_daemon stop
      sleep 1
      cmd_daemon start "$@"
      ;;

    status)
      echo ""
      echo -e "${_LARC_LOG_BOLD}LARC Daemon Status${_LARC_LOG_RESET}"
      echo "────────────────────────────────────"

      # IM poller
      if _daemon_is_running "$IM_PID_FILE"; then
        local im_age=""
        if [[ -f "$IM_HEARTBEAT_FILE" ]]; then
          im_age=$(( $(date +%s) - $(cat "$IM_HEARTBEAT_FILE") ))
          if [[ "$im_age" -le "$DAEMON_HEARTBEAT_TIMEOUT" ]]; then
            echo -e "  IM poller:  ${_LARC_LOG_GREEN}running${_LARC_LOG_RESET} (PID $(cat "$IM_PID_FILE"), heartbeat ${im_age}s ago)"
          else
            echo -e "  IM poller:  ${_LARC_LOG_YELLOW}stale${_LARC_LOG_RESET} (PID $(cat "$IM_PID_FILE"), heartbeat ${im_age}s ago — watchdog will restart)"
          fi
        else
          echo -e "  IM poller:  ${_LARC_LOG_GREEN}running${_LARC_LOG_RESET} (PID $(cat "$IM_PID_FILE"), no heartbeat yet)"
        fi
      else
        echo -e "  IM poller:  ${_LARC_LOG_RED}stopped${_LARC_LOG_RESET}"
      fi

      # Worker
      if _daemon_is_running "$WORKER_PID_FILE"; then
        local wk_age=""
        if [[ -f "$WORKER_HEARTBEAT_FILE" ]]; then
          wk_age=$(( $(date +%s) - $(cat "$WORKER_HEARTBEAT_FILE") ))
          if [[ "$wk_age" -le "$DAEMON_HEARTBEAT_TIMEOUT" ]]; then
            echo -e "  Worker:     ${_LARC_LOG_GREEN}running${_LARC_LOG_RESET} (PID $(cat "$WORKER_PID_FILE"), heartbeat ${wk_age}s ago)"
          else
            echo -e "  Worker:     ${_LARC_LOG_YELLOW}stale${_LARC_LOG_RESET} (PID $(cat "$WORKER_PID_FILE"), heartbeat ${wk_age}s ago — watchdog will restart)"
          fi
        else
          echo -e "  Worker:     ${_LARC_LOG_GREEN}running${_LARC_LOG_RESET} (PID $(cat "$WORKER_PID_FILE"), no heartbeat yet)"
        fi
      else
        echo -e "  Worker:     ${_LARC_LOG_RED}stopped${_LARC_LOG_RESET}"
      fi

      # Watchdog
      if _daemon_is_running "$WATCHDOG_PID_FILE"; then
        echo -e "  Watchdog:   ${_LARC_LOG_GREEN}running${_LARC_LOG_RESET} (PID $(cat "$WATCHDOG_PID_FILE"))"
      else
        echo -e "  Watchdog:   ${_LARC_LOG_RED}stopped${_LARC_LOG_RESET} — auto-restart disabled"
      fi

      # Queue stats
      local queue_file="${LARC_HOME:-$HOME/.larc}/cache/queue/main.jsonl"
      if [[ -f "$queue_file" ]]; then
        local total pending done_count failed
        total=$(wc -l < "$queue_file" | tr -d ' ')
        pending=$(python3 -c "
import json
lines = open('$queue_file').readlines()
print(sum(1 for l in lines if l.strip() and json.loads(l).get('status','') in {'pending','pending_preview'}))
" 2>/dev/null || echo 0)
        done_count=$(python3 -c "
import json
lines = open('$queue_file').readlines()
print(sum(1 for l in lines if l.strip() and json.loads(l).get('status','') == 'done'))
" 2>/dev/null || echo 0)
        failed=$(python3 -c "
import json
lines = open('$queue_file').readlines()
print(sum(1 for l in lines if l.strip() and json.loads(l).get('status','') == 'failed'))
" 2>/dev/null || echo 0)
        echo ""
        echo -e "  Queue (main): total=$total  pending=$pending  done=$done_count  failed=$failed"
      fi
      echo ""
      ;;

    health)
      # Machine-readable health check: exits 0 if all healthy, 1 if any component stale/dead
      local ok=0
      if ! _daemon_is_healthy "$IM_PID_FILE" "$IM_HEARTBEAT_FILE"; then
        log_warn "IM poller: unhealthy"
        ok=1
      else
        log_ok "IM poller: healthy"
      fi
      if ! _daemon_is_healthy "$WORKER_PID_FILE" "$WORKER_HEARTBEAT_FILE"; then
        log_warn "Worker: unhealthy"
        ok=1
      else
        log_ok "Worker: healthy"
      fi
      if ! _daemon_is_running "$WATCHDOG_PID_FILE"; then
        log_warn "Watchdog: not running — auto-restart disabled"
        ok=1
      else
        log_ok "Watchdog: running"
      fi
      return "$ok"
      ;;

    logs)
      local target="${1:-all}"
      case "$target" in
        im)       tail -f "$IM_LOG" ;;
        worker)   tail -f "$WORKER_LOG" ;;
        watchdog) tail -f "$WATCHDOG_LOG" ;;
        *)
          echo "=== IM Poller (last 20) ==="
          tail -20 "$IM_LOG" 2>/dev/null || echo "(no log)"
          echo ""
          echo "=== Worker (last 20) ==="
          tail -20 "$WORKER_LOG" 2>/dev/null || echo "(no log)"
          echo ""
          echo "=== Watchdog (last 20) ==="
          tail -20 "$WATCHDOG_LOG" 2>/dev/null || echo "(no log)"
          ;;
      esac
      ;;

    help|*)
      echo ""
      echo -e "${BOLD}larc daemon${RESET} — LARC background daemon management"
      echo ""
      echo -e "${BOLD}Usage:${RESET}"
      echo "  larc daemon start   [--agent main] [--interval 30]"
      echo "  larc daemon stop"
      echo "  larc daemon restart [--agent main] [--interval 30]"
      echo "  larc daemon status"
      echo "  larc daemon health           # exits 0 if all components healthy"
      echo "  larc daemon logs    [im|worker|watchdog]"
      echo ""
      echo -e "${BOLD}Environment:${RESET}"
      echo "  LARC_DAEMON_HEARTBEAT_TIMEOUT  seconds before process considered stale (default: 120)"
      echo "  LARC_WATCHDOG_INTERVAL         watchdog check frequency in seconds (default: 60)"
      echo "  LARC_SEEN_FILE_MAX_LINES       max seen-message IDs to keep (default: 2000)"
      echo ""
      ;;
  esac
}
