#!/usr/bin/env bash
# webhook.sh — LARC Approval Webhook handler
# T-103: Lark Approval 承認完了 → queue resume

set -uo pipefail

# Self-contained log functions (webhook runs in subprocesses without bin/larc's env)
_RED='\033[0;31m'; _GREEN='\033[0;32m'; _YELLOW='\033[1;33m'
_BLUE='\033[0;34m'; _CYAN='\033[0;36m'; _BOLD='\033[1m'; _RESET='\033[0m'
type log_head  &>/dev/null || { log_head()  { echo -e "\n${_BOLD}${_CYAN}▶ $*${_RESET}"; }; }
type log_info  &>/dev/null || { log_info()  { echo -e "${_BLUE}[larc]${_RESET} $*"; }; }
type log_ok    &>/dev/null || { log_ok()    { echo -e "${_GREEN}[larc]${_RESET} $*"; }; }
type log_warn  &>/dev/null || { log_warn()  { echo -e "${_YELLOW}[larc]${_RESET} $*"; }; }

WEBHOOK_PID_FILE="${LARC_HOME:-$HOME/.larc}/run/webhook.pid"
WEBHOOK_LOG="${LARC_HOME:-$HOME/.larc}/logs/webhook.log"
WEBHOOK_PORT="${LARC_WEBHOOK_PORT:-14848}"

# ── Approval event handler ────────────────────────────────────────────────────

_webhook_handle_approval() {
  local payload="$1"

  python3 - "$payload" <<'PY'
import json, sys, subprocess, os, glob

payload_str = sys.argv[1]
try:
    payload = json.loads(payload_str)
except Exception as e:
    print(f"[webhook] Invalid JSON payload: {e}", file=sys.stderr)
    sys.exit(0)

# Support both Lark event envelope formats
event = payload.get("event", payload)
event_type = event.get("type", "") or payload.get("type", "") or payload.get("event_type", "")

if "approval" not in event_type.lower():
    sys.exit(0)

# Extract approval outcome
approval_code = event.get("approval_code", "") or event.get("instance_code", "")
status = event.get("status", "") or event.get("approval_status", "")

if not approval_code:
    print("[webhook] No approval_code in payload", file=sys.stderr)
    sys.exit(0)

print(f"[webhook] Approval event: code={approval_code} status={status}")

larc_home = os.environ.get("LARC_HOME", os.path.expanduser("~/.larc"))
queue_dir  = os.path.join(larc_home, "cache", "queue")

# Find queue item linked to this approval_code
target_queue_id = None
for jsonl_file in glob.glob(os.path.join(queue_dir, "*.jsonl")):
    with open(jsonl_file, "r") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                item = json.loads(line)
                # Match by approval_code stored as a dedicated field
                if (item.get("approval_code") == approval_code or
                        item.get("instance_code") == approval_code or
                        item.get("metadata", {}).get("approval_code") == approval_code):
                    item_status = item.get("status", "")
                    if item_status in ("blocked_approval", "in_progress", "pending"):
                        target_queue_id = item.get("queue_id", "")
                        break
            except Exception as e:
                print(f"[webhook] Skipping malformed line in {jsonl_file}: {e}", file=sys.stderr, flush=True)
                continue
    if target_queue_id:
        break

if not target_queue_id:
    print(f"[webhook] No matching queue item for approval_code={approval_code}")
    sys.exit(0)

print(f"[webhook] Matched queue_id={target_queue_id}")

# Route based on approval outcome
status_lower = status.lower()
if status_lower in ("approved", "pass", "agree", "done"):
    result = subprocess.run(
        ["larc", "ingress", "resume", "--queue-id", target_queue_id],
        capture_output=True, text=True
    )
    if result.returncode == 0:
        print(f"[webhook] Resumed queue item {target_queue_id}")
    else:
        print(f"[webhook] Resume failed: {result.stderr.strip()}", file=sys.stderr)

elif status_lower in ("rejected", "deny", "refuse", "cancel"):
    result = subprocess.run(
        ["larc", "ingress", "fail", "--queue-id", target_queue_id,
         "--note", f"Rejected via Lark Approval ({approval_code})"],
        capture_output=True, text=True
    )
    if result.returncode == 0:
        print(f"[webhook] Marked failed: {target_queue_id}")
    else:
        print(f"[webhook] Fail mark failed: {result.stderr.strip()}", file=sys.stderr)

else:
    print(f"[webhook] Unhandled approval status '{status}' — no action taken")
PY
}

# ── HTTP server (python3 socketserver) ───────────────────────────────────────

_webhook_server_loop() {
  local port="$1"
  log_head "LARC webhook server starting on port $port"

  python3 - "$port" <<'PY'
import sys, json, subprocess, os
from http.server import BaseHTTPRequestHandler, HTTPServer

port = int(sys.argv[1])
larc_home = os.environ.get("LARC_HOME", os.path.expanduser("~/.larc"))

class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print(f"[webhook] {fmt % args}", flush=True)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length).decode("utf-8", errors="replace") if length else ""

        # Respond immediately so Lark doesn't retry
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", "2")
        self.end_headers()
        self.wfile.write(b"{}")

        if not body:
            return

        print(f"[webhook] Received: {body[:200]}", flush=True)

        # Delegate to larc webhook handle
        result = subprocess.run(
            ["larc", "webhook", "handle", body],
            capture_output=True, text=True
        )
        if result.stdout:
            print(result.stdout.strip(), flush=True)
        if result.stderr:
            print(result.stderr.strip(), flush=True, file=sys.stderr)

    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"LARC webhook server OK")

httpd = HTTPServer(("", port), Handler)
print(f"[webhook] Listening on port {port}", flush=True)
httpd.serve_forever()
PY
}

# ── Public interface ──────────────────────────────────────────────────────────

cmd_webhook() {
  local subcmd="${1:-help}"
  shift || true

  mkdir -p "$(dirname "$WEBHOOK_PID_FILE")" "$(dirname "$WEBHOOK_LOG")"

  case "$subcmd" in
    start)
      local port="$WEBHOOK_PORT"
      [[ "${1:-}" =~ ^[0-9]+$ ]] && { port="$1"; shift; }

      if [[ -f "$WEBHOOK_PID_FILE" ]] && kill -0 "$(cat "$WEBHOOK_PID_FILE")" 2>/dev/null; then
        log_warn "Webhook server already running (PID $(cat "$WEBHOOK_PID_FILE"))"
        return 0
      fi

      _webhook_server_loop "$port" >> "$WEBHOOK_LOG" 2>&1 &
      local pid=$!
      echo "$pid" > "$WEBHOOK_PID_FILE"
      log_ok "Webhook server started on port $port (PID $pid) — log: $WEBHOOK_LOG"
      ;;

    stop)
      if [[ -f "$WEBHOOK_PID_FILE" ]] && kill -0 "$(cat "$WEBHOOK_PID_FILE")" 2>/dev/null; then
        kill "$(cat "$WEBHOOK_PID_FILE")" && log_ok "Webhook server stopped"
        rm -f "$WEBHOOK_PID_FILE"
      else
        log_info "Webhook server not running"
        rm -f "$WEBHOOK_PID_FILE"
      fi
      ;;

    handle)
      # Direct invocation: larc webhook handle '{"event":...}'
      local payload="${1:-}"
      if [[ -z "$payload" ]]; then
        payload=$(cat)  # read from stdin
      fi
      _webhook_handle_approval "$payload"
      ;;

    status)
      if [[ -f "$WEBHOOK_PID_FILE" ]] && kill -0 "$(cat "$WEBHOOK_PID_FILE")" 2>/dev/null; then
        echo -e "  Webhook server: ${_GREEN}running${_RESET} (PID $(cat "$WEBHOOK_PID_FILE"), port $WEBHOOK_PORT)"
      else
        echo -e "  Webhook server: ${_RED}stopped${_RESET}"
      fi
      ;;

    help|*)
      echo ""
      echo -e "${_BOLD}larc webhook${_RESET} — Approval webhook server"
      echo ""
      echo "  larc webhook start  [port]   Start HTTP server (default: $WEBHOOK_PORT)"
      echo "  larc webhook stop            Stop server"
      echo "  larc webhook handle [json]   Process a single event payload (or stdin)"
      echo "  larc webhook status          Show server status"
      echo ""
      echo "  To register with OpenClaw gateway, add a hook:"
      echo "    POST http://localhost:18789/hooks  {\"url\": \"http://localhost:$WEBHOOK_PORT\"}"
      echo ""
      ;;
  esac
}
