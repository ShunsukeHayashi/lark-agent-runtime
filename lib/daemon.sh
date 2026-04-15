#!/usr/bin/env bash
# daemon.sh — LARC Daemon: IM polling → auto-enqueue + worker loop
# T-101: Lark IM event → auto enqueue
# T-104: larc daemon start/stop/status/logs

set -uo pipefail

# Resolve LIB_DIR relative to this file if not exported by parent
_DAEMON_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${LIB_DIR:-$_DAEMON_SH_DIR}"
source "${LIB_DIR}/runtime-common.sh"

# Self-contained log functions (daemon runs in subprocesses without bin/larc's env)
_RED='\033[0;31m'; _GREEN='\033[0;32m'; _YELLOW='\033[1;33m'
_BLUE='\033[0;34m'; _CYAN='\033[0;36m'; _BOLD='\033[1m'; _RESET='\033[0m'
_log_info()  { echo -e "${_BLUE}[larc]${_RESET} $*"; }
_log_ok()    { echo -e "${_GREEN}[larc]${_RESET} $*"; }
_log_warn()  { echo -e "${_YELLOW}[larc]${_RESET} $*"; }
_log_head()  { echo -e "\n${_BOLD}${_CYAN}▶ $*${_RESET}"; }

# Use parent's log functions if available, else fall back to own
type log_head  &>/dev/null || { log_head()  { _log_head  "$@"; }; }
type log_info  &>/dev/null || { log_info()  { _log_info  "$@"; }; }
type log_ok    &>/dev/null || { log_ok()    { _log_ok    "$@"; }; }
type log_warn  &>/dev/null || { log_warn()  { _log_warn  "$@"; }; }

DAEMON_PID_DIR="${LARC_HOME:-$HOME/.larc}/run"
DAEMON_LOG_DIR="${LARC_HOME:-$HOME/.larc}/logs"
DAEMON_SEEN_DIR="${LARC_HOME:-$HOME/.larc}/cache/daemon"
IM_PID_FILE="$DAEMON_PID_DIR/im-poller.pid"
WORKER_PID_FILE="$DAEMON_PID_DIR/worker.pid"
IM_LOG="$DAEMON_LOG_DIR/im-poller.log"
WORKER_LOG="$DAEMON_LOG_DIR/worker.log"

# ── helpers ──────────────────────────────────────────────────────────────────

_daemon_ensure_dirs() {
  mkdir -p "$DAEMON_PID_DIR" "$DAEMON_LOG_DIR" "$DAEMON_SEEN_DIR"
}

_daemon_is_running() {
  local pid_file="$1"
  [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null
}

_daemon_stop_one() {
  local pid_file="$1" name="$2"
  if _daemon_is_running "$pid_file"; then
    local pid
    pid=$(cat "$pid_file")
    kill "$pid" 2>/dev/null && log_ok "Stopped $name (PID $pid)"
    rm -f "$pid_file"
  else
    log_info "$name is not running"
    rm -f "$pid_file"
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

  log_head "LARC IM poller starting (agent=$agent_id, interval=${interval}s)"

  touch "$seen_file"

  while true; do
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

seen_file  = "$seen_file"
agent_id   = "$agent_id"
allow_from_raw = "$allow_from"
msgs_file  = "$tmp_msgs"
allow_set  = set(x.strip() for x in allow_from_raw.split(",") if x.strip())

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
        deleted = msg.get("deleted", False)

        if not msg_id or msg_id in seen or deleted:
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
        if not text:
            new_ids.append(msg_id)
            continue

        cmd = ["larc", "ingress", "enqueue",
               "--text", text, "--sender", sender,
               "--source", "im", "--agent", agent_id]
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
  # Source worker.sh if not already loaded
  [[ "$(type -t _worker_poll_once)" == "function" ]] || \
    source "${LIB_DIR}/worker.sh"
  cmd_worker --agent "$agent_id" --interval "$interval"
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
          --agent)   agent_id="$2"; shift 2 ;;
          --interval) interval="$2"; shift 2 ;;
          *) shift ;;
        esac
      done

      log_head "Starting LARC daemon (agent=$agent_id)"
      _start_im_poller "$agent_id" "$interval"
      _start_worker    "$agent_id" "$interval"
      log_ok "LARC daemon started"
      ;;

    stop)
      log_head "Stopping LARC daemon"
      _daemon_stop_one "$IM_PID_FILE"    "IM poller"
      _daemon_stop_one "$WORKER_PID_FILE" "Worker"
      log_ok "LARC daemon stopped"
      ;;

    restart)
      cmd_daemon stop
      sleep 1
      cmd_daemon start "$@"
      ;;

    status)
      echo ""
      echo -e "${_BOLD}LARC Daemon Status${_RESET}"
      echo "────────────────────────────────────"

      if _daemon_is_running "$IM_PID_FILE"; then
        echo -e "  IM poller:  ${_GREEN}running${_RESET} (PID $(cat "$IM_PID_FILE"))"
      else
        echo -e "  IM poller:  ${_RED}stopped${_RESET}"
      fi

      if _daemon_is_running "$WORKER_PID_FILE"; then
        echo -e "  Worker:     ${_GREEN}running${_RESET} (PID $(cat "$WORKER_PID_FILE"))"
      else
        echo -e "  Worker:     ${_RED}stopped${_RESET}"
      fi

      # Show queue stats
      local queue_file="${LARC_HOME:-$HOME/.larc}/cache/queue/main.jsonl"
      if [[ -f "$queue_file" ]]; then
        local total pending done_count failed
        total=$(wc -l < "$queue_file" | tr -d ' ')
        pending=$(python3 -c "
import json, sys
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

    logs)
      local target="${1:-all}"
      case "$target" in
        im)     tail -f "$IM_LOG" ;;
        worker) tail -f "$WORKER_LOG" ;;
        *)
          echo "=== IM Poller (last 20) ==="
          tail -20 "$IM_LOG" 2>/dev/null || echo "(no log)"
          echo ""
          echo "=== Worker (last 20) ==="
          tail -20 "$WORKER_LOG" 2>/dev/null || echo "(no log)"
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
      echo "  larc daemon logs    [im|worker]"
      echo ""
      ;;
  esac
}
