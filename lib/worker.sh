#!/usr/bin/env bash
# worker.sh — LARC queue-worker: polls local queue and executes actionable items
# T-102: 実行デーモン

set -uo pipefail

_WORKER_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_WORKER_SH_DIR}/runtime-common.sh"

larc_init_fallback_logs

# ── helpers ──────────────────────────────────────────────────────────────────

_worker_poll_once() {
  local agent_id="$1"

  # Peek at the next item — raw JSON output for programmatic parsing
  local next_json
  next_json=$(larc ingress next --agent "$agent_id" --raw-json 2>/dev/null || true)
  [[ -z "$next_json" ]] && return 0

  local gate status queue_id
  gate=$(echo "$next_json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('gate','none'))" 2>/dev/null || echo "none")
  status=$(echo "$next_json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('status',''))" 2>/dev/null || echo "")
  queue_id=$(echo "$next_json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('queue_id',''))" 2>/dev/null || echo "")

  [[ -z "$queue_id" ]] && return 0

  case "${gate}:${status}" in
    none:pending|preview:pending_preview|none:delegated|preview:delegated)
      # Check quota — exit code 1 = exceeded, 0 = ok, other = billing unavailable (allow)
      local billing_rc=0
      larc billing check "$agent_id" 2>/dev/null; billing_rc=$?
      if [[ "$billing_rc" -eq 1 ]]; then
        log_warn "Quota exceeded — skipping execution of $queue_id"
        return 0
      fi
      # Route to openclaw if available, otherwise fall back to run-once (supervised mode)
      local run_out="" run_rc=0
      if [[ -n "${LARC_OPENCLAW_CMD:-}" ]]; then
        log_info "Dispatching $queue_id via openclaw (gate=$gate)"
        run_out=$(larc ingress openclaw --queue-id "$queue_id" --agent "$agent_id" --days 14 --execute 2>&1)
        run_rc=$?
      else
        log_info "Rendering bundle for $queue_id (supervised mode — openclaw not installed)"
        run_out=$(larc ingress run-once --queue-id "$queue_id" --agent "$agent_id" --days 14 2>&1)
        run_rc=$?
      fi
      echo "$run_out"
      if [[ "$run_rc" -eq 0 ]]; then
        log_ok "Completed: $queue_id"
        larc billing record "$agent_id" "$queue_id" "done" 2>/dev/null || true
      else
        log_warn "Execution failed for $queue_id (rc=$run_rc)"
        larc billing record "$agent_id" "$queue_id" "failed" 2>/dev/null || true
      fi
      ;;

    approval:pending|approval:pending_approval|approval:in_progress|*:blocked_approval)
      # Waiting for human approval — skip, webhook will resume
      log_info "Skipping (awaiting approval): $queue_id"
      ;;

    *:done|*:failed)
      # Terminal state — nothing to do
      ;;

    *)
      log_warn "Unknown gate:status '$gate:$status' for $queue_id — skipping"
      ;;
  esac
}

# ── main loop ─────────────────────────────────────────────────────────────────

cmd_worker() {
  local agent_id="main"
  local interval=30

  # Load config in subprocess context
  larc_load_runtime_config

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent)    agent_id="$2"; shift 2 ;;
      --interval) interval="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  # Detect openclaw once at startup — avoid PATH search on every 30s poll cycle
  local _openclaw_cmd=""
  _openclaw_cmd="$(larc_detect_openclaw_cmd)"
  export LARC_OPENCLAW_CMD="$_openclaw_cmd"

  log_head "LARC worker starting (agent=$agent_id, interval=${interval}s, openclaw=${_openclaw_cmd:-none})"

  # Recover any items left in_progress from a previous crashed worker
  larc ingress recover --agent "$agent_id" --timeout 60 2>/dev/null || true

  while true; do
    _worker_poll_once "$agent_id" || true
    sleep "$interval"
  done
}
