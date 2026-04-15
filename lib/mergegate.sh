#!/usr/bin/env bash
# lib/mergegate.sh — LARC ↔ MergeGate integration
#
# Bridges LARC queue items to the MergeGate execution gate lifecycle:
#
#   LARC queue item (in_progress)
#       ↓  larc mergegate sync --queue-id <id>
#   mergegate gate register → mergegate gate assign
#       ↓  larc mergegate approve <task-id>  [if gate=approval]
#   Lark Approval instance → human review
#       ↓  on approval
#   mergegate gate validate → merge/complete
#
# MergeGate binary: https://github.com/ShunsukeHayashi/mergegate
# Install: cargo install --git https://github.com/ShunsukeHayashi/mergegate

set -uo pipefail

# ── helpers ──────────────────────────────────────────────────────────────────

_mg_require_binary() {
  if ! command -v mergegate &>/dev/null; then
    log_error "mergegate binary not found."
    log_info "Install: cargo install --git https://github.com/ShunsukeHayashi/mergegate"
    return 1
  fi
}

_mg_detect_issue_number() {
  local queue_json="$1"
  # Prefer explicit event_id; fall back to deriving a numeric ID from queue_id prefix
  python3 - "$queue_json" <<'PY'
import json, re, sys
d = json.loads(sys.argv[1])
event_id = d.get("event_id") or ""
m = re.search(r"(\d+)", event_id)
if m:
    print(m.group(1))
else:
    # Use first 6 hex digits of queue_id as a stable pseudo-number
    qid = (d.get("queue_id") or "")
    digits = re.sub(r"[^0-9]", "", qid)
    print(digits[:6] if digits else "0")
PY
}

_mg_task_id_from_issue() {
  local issue_number="$1"
  echo "issue-${issue_number}"
}

_mg_infer_risk() {
  local gate="$1"
  case "$gate" in
    approval) echo "high" ;;
    preview)  echo "medium" ;;
    *)        echo "low" ;;
  esac
}

_mg_symbol_count() {
  local task_types_json="$1"
  python3 -c "import json,sys; print(len(json.loads(sys.argv[1])))" "$task_types_json" 2>/dev/null || echo "1"
}

# ── public commands ───────────────────────────────────────────────────────────

cmd_mergegate() {
  local subcmd="${1:-help}"; shift || true
  case "$subcmd" in
    status)   _mg_status "$@" ;;
    init)     _mg_init "$@" ;;
    register) _mg_register "$@" ;;
    assign)   _mg_assign "$@" ;;
    impact)   _mg_impact "$@" ;;
    pr)       _mg_pr "$@" ;;
    merge)    _mg_merge "$@" ;;
    approve)  _mg_approve "$@" ;;
    sync)     _mg_sync "$@" ;;
    validate) _mg_validate "$@" ;;
    export)   _mg_export "$@" ;;
    help|--help|-h) _mg_help ;;
    *)
      log_error "Unknown mergegate subcommand: $subcmd"
      _mg_help
      return 1
      ;;
  esac
}

_mg_help() {
  cat <<EOF

${BOLD}larc mergegate${RESET} — LARC ↔ MergeGate integration

${BOLD}Workflow commands:${RESET}
  ${CYAN}sync${RESET} --queue-id <id> [--agent <name>] [--files <f1,f2>]
                        Register a LARC queue item in MergeGate and optionally
                        trigger Lark Approval if gate=approval.
  ${CYAN}approve${RESET} <task-id>   Create Lark Approval instance for a registered task.
                        Validates in MergeGate on successful human approval.

${BOLD}Gate commands (thin wrappers):${RESET}
  ${CYAN}status${RESET}              mergegate gate status
  ${CYAN}init${RESET}                mergegate gate init
  ${CYAN}register${RESET} --issue <n> --title "..." [--risk low|medium|high]
  ${CYAN}assign${RESET} <task-id> [--agent <name>] [--files <f1,f2>]
  ${CYAN}impact${RESET} <task-id> [--risk <level>] [--symbols <n>]
  ${CYAN}pr${RESET} <task-id> <pr-number>
  ${CYAN}merge${RESET} <task-id> <sha>
  ${CYAN}validate${RESET}            mergegate gate validate

${BOLD}Export:${RESET}
  ${CYAN}export${RESET} [--format json|md] [--state <state>] [--risk <level>] [--since <date>]

${BOLD}Examples:${RESET}
  larc mergegate status
  larc mergegate sync --queue-id abc123 --files "lib/ingress.sh,lib/worker.sh"
  larc mergegate approve issue-456
  larc mergegate pr issue-456 789
  larc mergegate merge issue-456 a1b2c3d
  larc mergegate export --format md --since 2026-04-14

EOF
}

# ── gate wrappers ─────────────────────────────────────────────────────────────

_mg_status() {
  _mg_require_binary || return 1
  mergegate gate status "$@"
}

_mg_init() {
  _mg_require_binary || return 1
  mergegate gate init "$@"
  log_ok "MergeGate ledger initialized"
}

_mg_register() {
  _mg_require_binary || return 1
  local issue="" title="" risk="medium"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --issue)  issue="$2";  shift 2 ;;
      --title)  title="$2";  shift 2 ;;
      --risk)   risk="$2";   shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$issue" || -z "$title" ]] && { log_error "Usage: larc mergegate register --issue <n> --title \"...\""; return 1; }
  mergegate gate register --issue "$issue" --title "$title"
  local task_id
  task_id=$(_mg_task_id_from_issue "$issue")
  mergegate gate impact "$task_id" --risk "$risk" --symbols 1
  log_ok "Registered MergeGate task: $task_id (risk=$risk)"
}

_mg_assign() {
  _mg_require_binary || return 1
  local task_id="${1:-}"; shift || true
  local agent="${LARC_OPENCLAW_CMD:-openclaw}" files=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent) agent="$2"; shift 2 ;;
      --files) files="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$task_id" ]] && { log_error "Usage: larc mergegate assign <task-id> [--agent <name>] [--files <f1,f2>]"; return 1; }
  local node
  node=$(hostname 2>/dev/null || echo "local")
  local cmd=(mergegate gate assign "$task_id" --agent "$agent" --node "$node")
  [[ -n "$files" ]] && cmd+=(--files "$files")
  "${cmd[@]}"
  log_ok "Assigned $task_id → agent=$agent"
}

_mg_impact() {
  _mg_require_binary || return 1
  local task_id="${1:-}"; shift || true
  local risk="medium" symbols=1
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --risk)    risk="$2";    shift 2 ;;
      --symbols) symbols="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$task_id" ]] && { log_error "Usage: larc mergegate impact <task-id> [--risk <level>] [--symbols <n>]"; return 1; }
  mergegate gate impact "$task_id" --risk "$risk" --symbols "$symbols"
}

_mg_pr() {
  _mg_require_binary || return 1
  local task_id="${1:-}" pr_number="${2:-}"
  [[ -z "$task_id" || -z "$pr_number" ]] && { log_error "Usage: larc mergegate pr <task-id> <pr-number>"; return 1; }
  mergegate gate pr "$task_id" "$pr_number"
  log_ok "Linked PR #$pr_number to $task_id"
}

_mg_merge() {
  _mg_require_binary || return 1
  local task_id="${1:-}" sha="${2:-}"
  [[ -z "$task_id" || -z "$sha" ]] && { log_error "Usage: larc mergegate merge <task-id> <sha>"; return 1; }
  mergegate gate merge "$task_id" "$sha"
  log_ok "MergeGate merge recorded: $task_id @ $sha"
}

_mg_validate() {
  _mg_require_binary || return 1
  mergegate gate validate "$@"
}

_mg_export() {
  _mg_require_binary || return 1
  local format="md" state="" risk="" since=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --format) format="$2"; shift 2 ;;
      --state)  state="$2";  shift 2 ;;
      --risk)   risk="$2";   shift 2 ;;
      --since)  since="$2";  shift 2 ;;
      *) shift ;;
    esac
  done
  local cmd=(mergegate gate "export-${format}")
  [[ -n "$state" ]] && cmd+=(--state "$state")
  [[ -n "$risk"  ]] && cmd+=(--risk "$risk")
  [[ -n "$since" ]] && cmd+=(--since "$since")
  "${cmd[@]}"
}

# ── sync: LARC queue item → MergeGate ────────────────────────────────────────

_mg_sync() {
  _mg_require_binary || return 1

  local queue_id="" agent="" files=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --queue-id) queue_id="$2"; shift 2 ;;
      --agent)    agent="$2";    shift 2 ;;
      --files)    files="$2";    shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$queue_id" ]] && { log_error "Usage: larc mergegate sync --queue-id <id> [--agent <name>] [--files <f1,f2>]"; return 1; }

  # Load queue item
  local queue_json
  queue_json=$(_ingress_get_local_queue_item "$queue_id" 2>/dev/null || echo "")
  [[ -z "$queue_json" ]] && { log_error "Queue item not found locally: $queue_id"; return 1; }

  # Extract fields from queue item
  local gate message task_types_json
  IFS=$'\t' read -r gate message task_types_json < <(python3 - "$queue_json" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
print(d.get("gate","none") + "\t" +
      d.get("message_text","") + "\t" +
      json.dumps(d.get("task_types",[])))
PY
  ) || { gate="none"; message=""; task_types_json="[]"; }

  local issue_number
  issue_number=$(_mg_detect_issue_number "$queue_json")
  local task_id
  task_id=$(_mg_task_id_from_issue "$issue_number")
  local risk
  risk=$(_mg_infer_risk "$gate")
  local symbol_count
  symbol_count=$(_mg_symbol_count "$task_types_json")
  local title="${message:0:80}"
  [[ -z "$title" ]] && title="LARC task $queue_id"

  log_head "MergeGate sync: $task_id (risk=$risk)"

  # Register in MergeGate
  mergegate gate register --issue "$issue_number" --title "$title"
  mergegate gate impact "$task_id" --risk "$risk" --symbols "$symbol_count"

  # Assign to agent
  local effective_agent="${agent:-${LARC_OPENCLAW_CMD:-openclaw}}"
  local node
  node=$(hostname 2>/dev/null || echo "local")
  local assign_cmd=(mergegate gate assign "$task_id" --agent "$effective_agent" --node "$node")
  [[ -n "$files" ]] && assign_cmd+=(--files "$files")
  "${assign_cmd[@]}"

  log_ok "Synced queue item $queue_id → MergeGate task $task_id"

  # If gate=approval, trigger Lark Approval
  if [[ "$gate" == "approval" ]]; then
    log_info "Gate is 'approval' — creating Lark Approval instance for $task_id"
    _mg_approve "$task_id" --queue-id "$queue_id"
  else
    log_info "Gate is '$gate' — no Lark Approval required"
    echo "$task_id"
  fi
}

# ── approve: create Lark Approval → validate on success ──────────────────────

_mg_approve() {
  local task_id="${1:-}"; shift || true
  local queue_id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --queue-id) queue_id="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$task_id" ]] && { log_error "Usage: larc mergegate approve <task-id> [--queue-id <id>]"; return 1; }

  # Require Lark Approval code
  local approval_code="${LARC_APPROVAL_CODE:-}"
  if [[ -z "$approval_code" ]]; then
    log_warn "LARC_APPROVAL_CODE not set — cannot create Lark Approval instance"
    log_info "Set LARC_APPROVAL_CODE in ~/.larc/config.env or manually validate: larc mergegate validate"
    return 1
  fi

  # Build approval title from task_id and optional queue item
  local approval_title="MergeGate: $task_id"
  if [[ -n "$queue_id" ]]; then
    local queue_json
    queue_json=$(_ingress_get_local_queue_item "$queue_id" 2>/dev/null || echo "")
    if [[ -n "$queue_json" ]]; then
      local msg
      msg=$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('message_text','')[:80])" "$queue_json" 2>/dev/null || echo "")
      [[ -n "$msg" ]] && approval_title="MergeGate: $task_id — $msg"
    fi
  fi

  log_info "Creating Lark Approval for $task_id"

  # Source approve.sh if not already loaded
  [[ "$(type -t _approve_create)" != "function" ]] && source "${LIB_DIR}/approve.sh" 2>/dev/null

  # Submit the approval instance with the task_id as the key reference
  local approval_out
  if ! approval_out=$(cmd_approve create \
    --approval-code "$approval_code" \
    --title "$approval_title" 2>&1); then
    log_warn "Lark Approval creation failed: $approval_out"
    log_info "Proceeding without Lark Approval — manually approve in Lark and run: larc mergegate validate"
    return 0
  fi

  log_ok "Lark Approval submitted for $task_id"
  log_info "Waiting for approver action in Lark. When approved, run:"
  log_info "  larc mergegate validate"
  echo "$task_id"
}
