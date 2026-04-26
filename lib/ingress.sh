#!/usr/bin/env bash
# lib/ingress.sh — Minimal bot ingress and queue ledger
#
# Purpose:
#   Convert inbound Lark messages into normalized queued tasks.
#   This is the first step toward an agentic runtime loop:
#     message -> scope/gate inference -> queue ledger

cmd_ingress() {
  local action="${1:-help}"; shift || true
  case "$action" in
    enqueue) _ingress_enqueue "$@" ;;
    list)    _ingress_list "$@" ;;
    openclaw) _ingress_openclaw "$@" ;;
    next)    _ingress_next "$@" ;;
    run-once) _ingress_run_once "$@" ;;
    execute-stub) _ingress_execute_stub "$@" ;;
    execute-apply) _ingress_execute_apply "$@" ;;
    followup) _ingress_followup "$@" ;;
    approve) _ingress_approve "$@" ;;
    resume)  _ingress_resume "$@" ;;
    delegate) _ingress_delegate "$@" ;;
    context) _ingress_context "$@" ;;
    handoff) _ingress_handoff "$@" ;;
    done)    _ingress_done "$@" ;;
    fail)    _ingress_fail "$@" ;;
    recover) _ingress_recover "$@" ;;
    verify)  _ingress_verify "$@" ;;
    stats)   _ingress_stats "$@" ;;
    prune)   _ingress_prune "$@" ;;
    retry)   _ingress_retry "$@" ;;
    help|--help|-h) _ingress_help ;;
    *)
      log_error "Unknown ingress action: $action"
      _ingress_help
      return 1
      ;;
  esac
}

_ingress_help() {
  cat <<EOF

${BOLD}larc ingress${RESET} — Normalize inbound Lark events into queued tasks

${BOLD}Commands:${RESET}
  ${CYAN}enqueue${RESET}   Create a queue item from message text / stdin
  ${CYAN}list${RESET}      List queued items from Base or local cache
  ${CYAN}openclaw${RESET}  Build or dispatch the next-step bundle for an OpenClaw agent
                 --agent <id>       Target agent for bundle lookup (default: main)
                 --queue-id <id>    Force a specific queue item
                 --days <N>         Retrieval window for context commands (default: 14)
                 --execute          Dispatch directly via openclaw agent
                 --gateway          Use gateway mode instead of --local embedded mode
  ${CYAN}next${RESET}      Pull the next actionable queue item for an agent
  ${CYAN}run-once${RESET}  Claim the next actionable queue item for an agent
  ${CYAN}execute-stub${RESET} Show a placeholder execution plan for an in-progress item
  ${CYAN}execute-apply${RESET} Run safe adapter actions for an in-progress item
  ${CYAN}followup${RESET}  Show partial items that still require manual follow-up
  ${CYAN}approve${RESET}   Mark a blocked approval item as approved
  ${CYAN}resume${RESET}    Move an approved item back to pending
  ${CYAN}delegate${RESET}  Assign a queue item to the best specialist agent
  ${CYAN}context${RESET}   Build a retrieval bundle for a queue item
  ${CYAN}handoff${RESET}   Build a delegated handoff bundle for an assigned agent
  ${CYAN}done${RESET}      Mark a queue item as completed
  ${CYAN}fail${RESET}      Mark a queue item as failed
  ${CYAN}verify${RESET}    End-to-end pipeline verification: enqueue → Base write → audit log
  ${CYAN}stats${RESET}     Show counts by status / gate and top failure reasons
  ${CYAN}prune${RESET}     Delete failed queue items matching filters (dry-run by default)
  ${CYAN}retry${RESET}     Reset failed items to pending so the worker will retry

${BOLD}Examples:${RESET}
  larc ingress enqueue --text "Please route this expense to approval" --sender ou_xxx --source im
  echo "Create CRM record and send a follow-up message" | larc ingress enqueue --agent crm-agent
  larc ingress enqueue --text "Upload the file to drive and update the wiki" --dry-run
  larc ingress list --agent main
  larc ingress openclaw --agent main --days 14
  larc ingress openclaw --queue-id 1234 --execute
  larc ingress openclaw --queue-id 1234 --gateway --execute
  larc ingress next --agent crm-agent --days 14
  larc ingress run-once --agent crm-agent --days 14 --dry-run
  larc ingress execute-stub --queue-id 1234
  larc ingress execute-apply --queue-id 1234 --dry-run
  larc ingress followup --agent crm-agent
  larc ingress approve --queue-id 1234
  larc ingress resume --queue-id 1234
  larc ingress delegate --queue-id 1234
  larc ingress context --queue-id 1234 --days 14
  larc ingress handoff --queue-id 1234 --days 14
  larc ingress done --queue-id 1234 --note "Completed by crm-agent"
  larc ingress fail --queue-id 1234 --note "Approval context was missing"

EOF
}

_ingress_enqueue() {
  local text=""
  local agent_id="main"
  local source="im"
  local sender=""
  local event_id=""
  local dry_run=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --text) text="$2"; shift 2 ;;
      --agent) agent_id="$2"; shift 2 ;;
      --source) source="$2"; shift 2 ;;
      --sender) sender="$2"; shift 2 ;;
      --event-id) event_id="$2"; shift 2 ;;
      --dry-run) dry_run=true; shift ;;
      *)
        log_warn "Unknown option: $1"
        shift
        ;;
    esac
  done

  if [[ -z "$text" ]] && ! [[ -t 0 ]]; then
    text=$(cat)
  fi

  [[ -z "$text" ]] && {
    log_error "Usage: larc ingress enqueue --text \"...\" [--agent main] [--sender ou_xxx] [--source im] [--dry-run]"
    return 1
  }

  local map_path gate_path
  map_path="$SCRIPT_DIR/config/scope-map.json"
  gate_path="$SCRIPT_DIR/config/gate-policy.json"
  [[ ! -f "$map_path" ]] && { log_error "scope-map.json not found"; return 1; }
  [[ ! -f "$gate_path" ]] && { log_error "gate-policy.json not found"; return 1; }

  local summary_json
  summary_json=$(python3 - "$map_path" "$gate_path" "$text" "$agent_id" "$source" "$sender" "$event_id" <<'PY'
import json
import re
import sys
import uuid
from datetime import datetime, timezone

map_path, gate_path, task_desc, agent_id, source, sender, event_id = sys.argv[1:8]
task_desc_l = task_desc.lower()

with open(map_path, "r", encoding="utf-8") as f:
    scope_map = json.load(f)
with open(gate_path, "r", encoding="utf-8") as f:
    gate_policy = json.load(f)

tasks = scope_map.get("tasks", {})
gate_tasks = gate_policy.get("tasks", {})

KEYWORD_MAP = {
    r"\bdoc\b|document": ["read_document"],
    r"\bnotion\b|campaign\s+brief|campaign\s+plan|marketing\s+brief": ["read_document"],
    r"create\s+\w*\s*doc|write\s+\w*\s*doc|new\s+doc": ["create_document"],
    r"(?:create|draft|write|build|prepare|sync)\s+(?:\w+\s+){0,4}(?:campaign|marketing)\s+(?:brief|doc|document|plan)": ["create_document"],
    r"edit\s+\w*\s*doc|update\s+\w*\s*doc|modify\s+\w*\s*doc": ["update_document"],
    r"(?:update|edit|revise|sync)\s+(?:\w+\s+){0,4}(?:campaign|marketing)\s+(?:brief|doc|document|plan)": ["update_document"],
    r"wiki|knowledge\s*base|knowledge\s*hub": ["read_wiki"],
    r"wiki.*(?:create|update|write|add|edit)|(?:create|update|write|add|edit).*wiki": ["write_wiki"],
    r"update\s+wiki|write\s+to\s+wiki": ["write_wiki"],
    r"upload\b|attach\s+\w*\s*file|create\s+file\b": ["create_drive_file"],
    r"read\s+\w*\s*drive|list\s+file|file\s+list|browse\s+drive": ["read_drive"],
    r"create\s+folder|manage\s+file|move\s+file|delete\s+file": ["manage_drive"],
    r"\bbase\b|\bbitable\b": ["read_base"],
    r"\bsfa\b|\bma\b|marketing\s+automation|lead\s+segment|lead\s+list|campaign\s+performance|\bfunnel\b": ["read_base"],
    r"create\s+\w*\s*record|record\s+create|add\s+\w*\s*record|new\s+\w*\s*record|insert\s+\w*\s*record": ["create_base_record"],
    r"update\s+(?:\w+\s+){0,3}record|edit\s+(?:\w+\s+){0,3}record|modify\s+(?:\w+\s+){0,3}record|patch\s+\w*\s*record": ["update_base_record"],
    r"read\s+\w*\s*(?:record|table)|list\s+\w*\s*record": ["read_base"],
    r"manage\s+\w*\s*(?:base|bitable|table)": ["manage_base"],
    r"(?:create|add|new|log|insert|register)\s+(?:\w+\s+){0,3}(?:crm|customer|lead|deal|prospect|opportunity)\b": ["create_crm_record"],
    r"(?:crm|lead|deal|prospect|opportunity)\s+(?:\w+\s+){0,3}(?:create|add|new)\b": ["create_crm_record"],
    r"\bcrm\b|customer\s+record|lead\s+record|deal\s+record|\bpipeline\b|\bprospect\b|\bopportunity\b": ["read_base"],
    r"(?=.*(?:create|add|new|log)\s+(?:\w+\s+){0,3}(?:crm|customer|lead|deal|prospect))(?=.*(?:send|message|notify))": ["send_crm_followup"],
    r"send\s+\w*\s*message|send\s+\w*\s*notification|send\s+\w*\s*(?:chat|im)|message\s+send": ["send_message"],
    r"\bslack\b|sales\s+team|notify\s+(?:the\s+)?sales|send\s+(?:the\s+)?sales\s+team": ["send_message"],
    r"follow.?up\s+message|send\s+follow.?up": ["send_message"],
    r"notify\s+(?:the\s+)?\w+|send\s+\w*\s*alert": ["send_message"],
    r"read\s+\w*\s*message|read\s+\w*\s*chat|chat\s+history|message\s+history": ["read_message"],
    r"calendar|read\s+\w*\s*event|list\s+\w*\s*event": ["read_calendar"],
    r"schedule\s+(?:a\s+)?(?:\S+\s+){0,3}(?:meeting|call|event|appointment)|create\s+\w*\s*(?:event|meeting|appointment)|book\s+\w*\s*(?:room|meeting|slot)": ["write_calendar"],
    r"\bexpense\b|\breimbursement\b|expense\s+report|expense\s+claim|receipt\s+submission": ["create_expense"],
    r"(?:submit|send|create|trigger|start)\s+\w*\s*approval|approval\s+flow|approval\s+request|route\s+\w+\s+to\s+approval": ["submit_approval"],
    r"(?:approve|reject|process|handle)\s+\w*\s*approval|approval\s+task|approver|reject\s+task": ["act_approval_task"],
    r"(?:check|read|get|view)\s+\w*\s*approval|approval\s+status|pending\s+approval": ["read_approval"],
    r"contact|employee\s+info|user\s+info|directory|lookup\s+user|find\s+user|\bhr\b": ["read_contact"],
    r"update\s+\w*\s*contact|manage\s+\w*\s*contact|add\s+\w*\s*employee": ["manage_contact"],
    r"create\s+\w*\s*task|new\s+\w*\s*task|add\s+\w*\s*task|assign\s+\w*\s*task": ["write_task"],
    r"(?<!approval\s)\btask\b|\btodo\b|to-do|checklist": ["read_task"],
    r"ocr|receipt|領収書|レシート|scan\s+image|read\s+image|extract\s+text|画像.*テキスト|テキスト.*画像": ["ocr_image"],
    r"attendance|check.?in|check.?out|timesheet|punch\s+in|punch\s+out|clock\s+in": ["read_attendance"],
    r"minutes|miaoji|meeting\s+notes|transcript": ["read_minutes"],
    r"video\s+meeting|vc\s+record|video\s+conference\s+record": ["read_vc"],
    r"spreadsheet|sheet|excel|\bcsv\b": ["manage_sheets"],
    r"slide|\bppt\b|presentation|deck": ["manage_slides"],
}

matched_tasks = set()
for pattern, task_keys in KEYWORD_MAP.items():
    if re.search(pattern, task_desc_l):
        for tk in task_keys:
            if tk in tasks:
                matched_tasks.add(tk)

all_scopes = sorted({scope for tk in matched_tasks for scope in tasks[tk]["scopes"]})
identities = {tasks[tk]["identity"] for tk in matched_tasks}
display_identities = set(identities)
if "either" in display_identities and ("user" in display_identities or "bot" in display_identities):
    display_identities.discard("either")
if display_identities == {"user", "bot"}:
    authority = "user or bot"
elif len(display_identities) == 1:
    authority = list(display_identities)[0]
else:
    authority = "either"

gate_rank = {"none": 0, "preview": 1, "approval": 2}
highest_gate = "none"
highest_risk = "none"
for tk in sorted(matched_tasks):
    g = gate_tasks.get(tk, {})
    gate = g.get("gate", "none")
    risk = g.get("risk", "none")
    if gate_rank.get(gate, 0) > gate_rank.get(highest_gate, 0):
        highest_gate = gate
        highest_risk = risk

status = {
    "none": "pending",
    "preview": "pending_preview",
    "approval": "blocked_approval",
}.get(highest_gate, "pending")

queue_id = str(uuid.uuid4())
created_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

print(json.dumps({
    "queue_id": queue_id,
    "agent_id": agent_id,
    "source": source or "im",
    "sender": sender,
    "event_id": event_id,
    "message_text": task_desc,
    "task_types": sorted(matched_tasks),
    "scopes": all_scopes,
    "authority": authority,
    "gate": highest_gate,
    "risk": highest_risk,
    "status": status,
    "created_at": created_at,
}, ensure_ascii=False))
PY
)

  [[ -z "$summary_json" ]] && { log_error "Failed to build ingress summary"; return 1; }

  if [[ "$dry_run" == "true" ]]; then
    python3 - "$summary_json" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
print("")
print("  Queue item preview")
print(f"    queue_id:   {d['queue_id']}")
print(f"    agent_id:   {d['agent_id']}")
print(f"    source:     {d['source']}")
print(f"    sender:     {d.get('sender') or '-'}")
print(f"    task_types: {', '.join(d['task_types']) if d['task_types'] else '(none matched)'}")
print(f"    scopes:     {', '.join(d['scopes']) if d['scopes'] else '(none)'}")
print(f"    authority:  {d['authority']}")
print(f"    gate:       {d['gate']}")
print(f"    status:     {d['status']}")
PY
    return 0
  fi

  _ingress_write_local "$agent_id" "$summary_json"

  if [[ -n "$LARC_BASE_APP_TOKEN" ]]; then
    _ingress_write_base "$summary_json"
    _ingress_write_audit_log "$summary_json" "enqueued"
    # Issue #40: approval-gated tasks need a dedicated blocked_approval audit row so the
    # 🟡 要確認・承認 view can surface them. Otherwise only "enqueued" is recorded and
    # the human-pending state is invisible to operators.
    local _enq_status
    _enq_status=$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('status',''))" "$summary_json" 2>/dev/null)
    if [[ "$_enq_status" == "blocked_approval" ]]; then
      local _blocked_json
      _blocked_json=$(python3 -c '
import json, sys
d = json.loads(sys.argv[1])
d["next_human_action"] = "approve in Lark UI"
print(json.dumps(d, ensure_ascii=False))
' "$summary_json")
      _ingress_write_audit_log "$_blocked_json" "blocked_approval"
    fi
  else
    log_warn "LARC_BASE_APP_TOKEN not set — recorded to local queue only"
  fi

  python3 - "$summary_json" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
print("")
print(f"Queued: {d['queue_id']}")
print(f"  status: {d['status']}")
print(f"  gate:   {d['gate']}")
print(f"  tasks:  {', '.join(d['task_types']) if d['task_types'] else '(none matched)'}")
PY
}

_ingress_list() {
  local agent_id="main"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent) agent_id="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  log_head "Ingress queue (${agent_id})"

  local queue_file="$LARC_CACHE/queue/${agent_id}.jsonl"
  if [[ -f "$queue_file" ]]; then
    python3 - "$queue_file" <<'PY'
import json, sys
path = sys.argv[1]
found = False
with open(path, "r", encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        found = True
        d = json.loads(line)
        assigned = d.get('assigned_agent_id')
        suffix = f" -> {assigned}" if assigned else ""
        print(f"{d.get('queue_id','-')}  [{d.get('status','-')} / {d.get('gate','-')}]  {str(d.get('message_text',''))[:100]}{suffix}")
if not found:
    print("(no queue items)")
PY
    return 0
  fi

  if [[ -n "$LARC_BASE_APP_TOKEN" ]]; then
    local table_id
    table_id=$(_get_or_create_queue_table)
    local base_output
    base_output=$(lark-cli base +record-list \
      --base-token "$LARC_BASE_APP_TOKEN" \
      --table-id "$table_id" 2>/dev/null | python3 -c '
import json, sys
resp = json.load(sys.stdin)
d = resp.get("data", resp)
fields = d.get("fields", [])
rows = d.get("data", [])
target_agent = "'"${agent_id}"'"
if not fields or not rows:
    print("")
    sys.exit(0)
def idx(name):
    try: return fields.index(name)
    except ValueError: return None
qi = idx("queue_id"); ai = idx("agent_id"); si = idx("status"); gi = idx("gate"); mi = idx("message_text")
found = False
for row in rows:
    if ai is not None and ai < len(row) and str(row[ai]) == target_agent:
        found = True
        q = row[qi] if qi is not None and qi < len(row) else "-"
        s = row[si] if si is not None and si < len(row) else "-"
        g = row[gi] if gi is not None and gi < len(row) else "-"
        m = row[mi] if mi is not None and mi < len(row) else "-"
        print(f"{q}  [{s} / {g}]  {str(m)[:100]}")
if not found:
    print("")
' || true)
    if [[ -n "${base_output//$'\n'/}" ]]; then
      printf '%s\n' "$base_output"
      return 0
    fi
    log_warn "No queue rows returned from Base — falling back to local queue"
  fi

  echo "(no queue items)"
}

_ingress_next() {
  local agent_id="main"
  local days="14"
  local raw_json=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent) agent_id="$2"; shift 2 ;;
      --days) days="$2"; shift 2 ;;
      --raw-json) raw_json=true; shift ;;
      *) log_warn "Unknown option: $1"; shift ;;
    esac
  done

  local queue_json=""
  if [[ -n "${LARC_BASE_APP_TOKEN:-}" ]]; then
    queue_json=$(_ingress_find_next_base_queue_item "$agent_id")
    if [[ -n "$queue_json" ]]; then
      local _desync_check
      _desync_check=$(_ingress_base_local_desync_status "$queue_json")
      if [[ -n "$_desync_check" ]]; then
        local _dsync_qid _dsync_status
        _dsync_qid=${_desync_check%%$'\t'*}
        _dsync_status=${_desync_check##*$'\t'}
        log_warn "Base/local desync: $_dsync_qid is locally $_dsync_status but Base shows pending — skipping"
        queue_json=""
      fi
    fi
  fi
  [[ -z "$queue_json" ]] && queue_json=$(_ingress_find_next_local_queue_item "$agent_id")

  if [[ -z "$queue_json" ]]; then
    [[ "$raw_json" == "true" ]] || echo "(no actionable queue item for $agent_id)"
    return 0
  fi

  # Raw JSON output for programmatic consumers (e.g. worker.sh)
  if [[ "$raw_json" == "true" ]]; then
    echo "$queue_json"
    return 0
  fi

  local status
  status=$(python3 - "$queue_json" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
print(d.get("status", ""))
PY
)

  if [[ "$status" == "delegated" ]]; then
    _ingress_render_bundle "handoff" "$queue_json" "$days"
  else
    _ingress_render_bundle "context" "$queue_json" "$days"
  fi
}

_ingress_openclaw() {
  local agent_id="main"
  local queue_id=""
  local days="14"
  local execute=false
  local local_mode=true
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent) agent_id="$2"; shift 2 ;;
      --queue-id) queue_id="$2"; shift 2 ;;
      --days) days="$2"; shift 2 ;;
      --execute) execute=true; shift ;;
      --gateway) local_mode=false; shift ;;
      *) log_warn "Unknown option: $1"; shift ;;
    esac
  done

  local queue_json=""
  if [[ -n "$queue_id" ]]; then
    queue_json=$(_ingress_get_queue_item_anywhere "$queue_id")
    [[ -z "$queue_json" ]] && { log_error "Queue item not found (local or Base): $queue_id"; return 1; }
  else
    if [[ -n "${LARC_BASE_APP_TOKEN:-}" ]]; then
      queue_json=$(_ingress_find_next_base_queue_item "$agent_id")
      if [[ -n "$queue_json" ]]; then
        local _desync_check
        _desync_check=$(_ingress_base_local_desync_status "$queue_json")
        if [[ -n "$_desync_check" ]]; then
          local _dsync_qid _dsync_status
          _dsync_qid=${_desync_check%%$'\t'*}
          _dsync_status=${_desync_check##*$'\t'}
          log_warn "Base/local desync: $_dsync_qid is locally $_dsync_status but Base shows pending — skipping"
          queue_json=""
        fi
      fi
    fi
    [[ -z "$queue_json" ]] && queue_json=$(_ingress_find_next_local_queue_item "$agent_id")
    if [[ -z "$queue_json" ]]; then
      echo "(no actionable queue item for $agent_id)"
      return 0
    fi
  fi

  if [[ "$execute" == "true" ]]; then
    local current_status
    current_status=$(python3 - "$queue_json" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
print(d.get("status", ""))
PY
)
    case "$current_status" in
      pending|pending_preview|delegated)
        queue_json=$(_ingress_prepare_claimed_queue_item "$queue_json" "$agent_id")
        ;;
    esac
  fi

  local payload_json
  payload_json=$(_ingress_build_openclaw_payload "$queue_json" "$days" "$local_mode")

  _ingress_render_bundle "openclaw" "$queue_json" "$days" "$payload_json"

  if [[ "$execute" != "true" ]]; then
    return 0
  fi

  local target_agent prompt dispatch_mode session_id
  # Extract target_agent, dispatch_mode, session_id in one subprocess; prompt stays separate
  # because it is multi-line (the full OpenClaw bundle text).
  IFS=$'\t' read -r target_agent dispatch_mode session_id < <(python3 - "$payload_json" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
print(d.get("target_agent", "main") + "\t" +
      ("local" if d.get("local_mode", True) else "gateway") + "\t" +
      d.get("session_id", ""))
PY
  ) || { target_agent="main"; dispatch_mode="local"; session_id=""; }
  prompt=$(python3 - "$payload_json" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
print(d.get("prompt", ""))
PY
)

  [[ -z "$prompt" ]] && { log_error "OpenClaw prompt is empty"; return 1; }
  [[ -z "$session_id" ]] && { log_error "OpenClaw session_id is empty"; return 1; }

  log_info "Dispatching queue item to OpenClaw agent: $target_agent ($dispatch_mode)"
  if [[ "$dispatch_mode" == "local" ]]; then
    openclaw agent --agent "$target_agent" --session-id "$session_id" --local --json --message "$prompt"
  else
    openclaw agent --agent "$target_agent" --session-id "$session_id" --json --message "$prompt"
  fi
}

_ingress_run_once() {
  local agent_id="main"
  local days="14"
  local dry_run=false
  local queue_id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent) agent_id="$2"; shift 2 ;;
      --days) days="$2"; shift 2 ;;
      --queue-id) queue_id="$2"; shift 2 ;;
      --dry-run) dry_run=true; shift ;;
      *) log_warn "Unknown option: $1"; shift ;;
    esac
  done

  local queue_json
  if [[ -n "$queue_id" ]]; then
    queue_json=$(_ingress_get_local_queue_item "$queue_id")
    if [[ -z "$queue_json" ]]; then
      log_info "Not found locally; checking Lark Base for $queue_id..."
      queue_json=$(_ingress_get_base_queue_item "$queue_id")
    fi
    [[ -z "$queue_json" ]] && { log_error "Queue item not found (local or Base): $queue_id"; return 1; }
    local current_status effective_agent
    current_status=$(python3 - "$queue_json" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
print(d.get("status", ""))
PY
)
    effective_agent=$(python3 - "$queue_json" "$agent_id" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
requested = sys.argv[2]
current = d.get("assigned_agent_id") or d.get("worker_agent_id") or d.get("agent_id") or "main"
print(current if requested == "main" else requested)
PY
)
    case "$current_status" in
      pending|pending_preview|delegated) ;;
      *)
        log_error "Queue item $queue_id is '$current_status'; run-once expects pending, pending_preview, or delegated"
        return 1
        ;;
    esac
    agent_id="$effective_agent"
  else
    # Base-first: try Lark Base, fall back to local JSONL
    if [[ -n "${LARC_BASE_APP_TOKEN:-}" ]]; then
      queue_json=$(_ingress_find_next_base_queue_item "$agent_id")
    fi
    if [[ -z "$queue_json" ]]; then
      queue_json=$(_ingress_find_next_local_queue_item "$agent_id")
    fi
  fi
  if [[ -z "$queue_json" ]]; then
    echo "(no actionable queue item for $agent_id)"
    return 0
  fi

  local claimed_json="$queue_json"
  if [[ "$dry_run" != "true" ]]; then
    claimed_json=$(_ingress_prepare_claimed_queue_item "$queue_json" "$agent_id")
  fi

  if [[ "$dry_run" == "true" ]]; then
    log_info "Dry-run: next actionable item for $agent_id"
    _ingress_render_bundle "run-once" "$claimed_json" "$days"
    return 0
  fi

  local queue_id
  queue_id=$(python3 - "$claimed_json" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
print(d.get("queue_id", ""))
PY
)
  log_ok "Claimed queue item $queue_id for $agent_id"
  _ingress_render_bundle "run-once" "$claimed_json" "$days"
}

_ingress_execute_stub() {
  local queue_id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --queue-id) queue_id="$2"; shift 2 ;;
      *) log_warn "Unknown option: $1"; shift ;;
    esac
  done

  [[ -z "$queue_id" ]] && { log_error "Usage: larc ingress execute-stub --queue-id <id>"; return 1; }

  local queue_json
  queue_json=$(_ingress_get_queue_item_anywhere "$queue_id")
  [[ -z "$queue_json" ]] && { log_error "Queue item not found (local or Base): $queue_id"; return 1; }

  local current_status
  current_status=$(python3 - "$queue_json" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
print(d.get("status", ""))
PY
)
  if [[ "$current_status" != "in_progress" ]]; then
    log_error "Queue item $queue_id is '$current_status'; execute-stub expects in_progress"
    return 1
  fi

  python3 - "$queue_json" "${LARC_DRIVE_FOLDER_TOKEN:-}" <<'PY'
import json, os, re, sys
exec(open(os.environ["_LARC_SCENARIO_PY"]).read())

queue = json.loads(sys.argv[1])
drive_folder_token = sys.argv[2]
task_types = queue.get("task_types", [])
message = queue.get("message_text") or ""

TASK_PLANS = {
    "create_crm_record": "Create or upsert the CRM/Base record for the target customer or lead.",
    "send_crm_followup": "Prepare a follow-up outbound message after the CRM record is updated.",
    "send_message": "Send the prepared chat notification through Lark IM.",
    "create_expense": "Prepare the expense payload and collect receipts or supporting details.",
    "submit_approval": "Create the approval instance or route the prepared record into approval.",
    "read_base": "Read the relevant Base rows required to complete the task.",
    "update_base_record": "Patch the target Base record with the new task outcome.",
    "create_document": "Draft the new document content in the target workspace.",
    "update_document": "Apply the requested edits to the existing document.",
    "write_wiki": "Update the target wiki page or knowledge node with the final content.",
    "write_calendar": "Create or update the meeting/event entry in Calendar.",
}

TASK_ADAPTERS = {
    "create_crm_record": "larc memory push --agent {agent}",
    "send_crm_followup": "larc send --agent {agent} \"Follow-up prepared from queue {queue_id}\"",
    "send_message": "larc send --agent {agent} \"{message}\"",
    "create_expense": "larc approve gate create_expense",
    "submit_approval": "larc approve create",
    "read_base": "larc memory search --query \"{message}\" --days 30",
    "update_base_record": "larc memory push --agent {agent}",
    "create_document": "larc send --agent {agent} \"Draft document requested: {message}\"",
    "update_document": "larc send --agent {agent} \"Update document requested: {message}\"",
    "write_wiki": "larc send --agent {agent} \"Wiki update requested: {message}\"",
    "write_calendar": "larc send --agent {agent} \"Calendar action requested: {message}\"",
}

TASK_OPENCLAW_TOOLS = {
    "create_crm_record": ["feishu_bitable_app_table_record"],
    "update_base_record": ["feishu_bitable_app_table_record"],
    "read_base": ["feishu_bitable_app_table_record", "feishu_search_doc_wiki"],
    "read_document": ["feishu_fetch_doc", "feishu_search_doc_wiki"],
    "send_crm_followup": ["feishu_im_user_message"],
    "send_message": ["feishu_im_user_message"],
    "create_expense": ["feishu_bitable_app_table_record", "feishu_drive_file"],
    "submit_approval": ["feishu_bitable_app_table_record"],
    "create_document": ["feishu_create_doc"],
    "update_document": ["feishu_fetch_doc", "feishu_update_doc"],
    "write_wiki": ["feishu_search_doc_wiki", "feishu_update_doc"],
    "write_calendar": ["feishu_calendar_event"],
}

def extract_fields(scenario_id, text):
    # ADR-0001 Hybrid: external executor module takes precedence over inline branches.
    # See lib/executors/README.md and docs/adr/0001-executor-architecture.md.
    import os as _os
    _exec_path = _os.path.join(_os.environ.get("LIB_DIR", "lib"), "executors", f"{scenario_id}.py")
    if _os.path.exists(_exec_path):
        _ns = {}
        exec(open(_exec_path).read(), _ns)
        if "extract_fields" in _ns:
            return _ns["extract_fields"](text)

    fields = {}
    missing = []
    blocked = []
    partial = []
    ask_user = ""

    if scenario_id == "ppal_marketing_ops":
        lower = text.lower()
        fields.update(load_scenario_defaults(lower))
        fields["output_folder_token"] = drive_folder_token
        fields["output_folder_strategy"] = "larc_workspace_default" if fields["output_folder_token"] else ""
        systems = []
        if "sfa" in lower:
            systems.append("sfa->ppal_base")
        if re.search(r"\bma\b|marketing automation", lower):
            systems.append("ma->ppal_base")
        if "notion" in lower:
            systems.append("notion->lark_docs")
        if "slack" in lower:
            systems.append("slack->lark_im")
        fields["source_systems"] = systems or ["ppal_base", "lark_docs", "lark_im"]
        goal_patterns = [
            r"(identify\s+[^.]+)",
            r"(follow.?up\s+[^.]+)",
            r"(create\s+[^.]+campaign[^.]+)",
            r"(draft\s+[^.]+campaign[^.]+)",
            r"(notify\s+[^.]+sales[^.]+)",
        ]
        campaign_goal = ""
        for pattern in goal_patterns:
            m = re.search(pattern, text, re.I)
            if m:
                campaign_goal = m.group(1).strip()
                break
        fields["campaign_goal"] = campaign_goal
        segment = ""
        for value in ("buyer", "lead", "nurture", "prospect", "hotlist", "hot lead", "active", "upsell"):
            if value in lower:
                segment = value
                break
        fields["segment_hint"] = segment
        fields["destination_target"] = "sales_team" if re.search(r"sales\s+team|slack|notify", lower) else ""
        title_suffix = segment.replace(" ", "-") if segment else "general"
        fields["document_title"] = f"PPAL Campaign Brief - {title_suffix.title()} - {queue.get('queue_id', '')[:8]}"
        if not fields["campaign_goal"]:
            missing.append("campaign_goal")
            blocked.append("campaign_goal")
            ask_user = "Please define the PPAL marketing goal first, for example which lead segment to target and what outcome to drive."
        ask_user = validate_runtime_fields(fields, missing, blocked, ask_user)
        if not fields["output_folder_token"]:
            missing.append("output_folder_token")
            blocked.append("output_folder_token")
            ask_user = ask_user or "The default LARC Drive folder is not configured. Set LARC_DRIVE_FOLDER_TOKEN before running this PPAL marketing flow."
        if not fields["segment_hint"]:
            missing.append("segment_hint")
            partial.append("segment_hint")
            ask_user = ask_user or "Please specify the target lead segment or funnel slice in PPAL Base."
        if not fields["destination_target"]:
            missing.append("destination_target")
            partial.append("destination_target")
            ask_user = ask_user or "Please specify where the campaign result should be sent, for example the sales team chat."
    elif scenario_id == "crm_followup":
        m = re.search(r"\bfor\s+([A-Za-z0-9._-][A-Za-z0-9._ -]{1,60})", text, re.I)
        q = re.search(r"['\"]([^'\"]{2,80})['\"]", text)
        customer_key = (m.group(1).strip() if m else (q.group(1).strip() if q else ""))
        fields["customer_key"] = customer_key
        fields["followup_message"] = text.strip() if re.search(r"follow.?up|send|message|notify", text, re.I) else ""
        if not fields["customer_key"]:
            missing.append("customer_key")
            blocked.append("customer_key")
            ask_user = "Please identify the target customer or lead before creating the CRM record."
        if not fields["followup_message"]:
            missing.append("followup_message")
            partial.append("followup_message")
            ask_user = ask_user or "Please provide the follow-up message content."
    elif scenario_id == "expense_approval":
        amount = re.search(r"\b(\d[\d,]*(?:\.\d+)?)\b", text)
        date = re.search(r"\b(20\d{2}-\d{2}-\d{2})\b", text)
        purpose = re.search(r"\bfor\s+(.+)$", text, re.I)
        fields["amount"] = amount.group(1) if amount else ""
        fields["expense_date"] = date.group(1) if date else ""
        fields["purpose"] = purpose.group(1).strip() if purpose else ""
        fields["expense_type"] = "expense" if re.search(r"expense|receipt|travel|meal|taxi", text, re.I) else ""
        for key in ("amount", "expense_type", "expense_date", "purpose"):
            if not fields.get(key):
                missing.append(key)
                blocked.append(key)
        if blocked:
            ask_user = "Please provide amount, expense type, date, and business purpose before approval."
    elif scenario_id == "document_update":
        ref = re.search(r"(https?://\S+|doc[cno][a-zA-Z0-9_-]+|wiki[a-zA-Z0-9_-]+)", text)
        fields["document_ref"] = ref.group(1) if ref else ""
        fields["edit_instruction"] = text.strip()
        if not fields["document_ref"]:
            missing.append("document_ref")
            blocked.append("document_ref")
            ask_user = "Please provide the target document or wiki reference."
        if not fields["edit_instruction"]:
            missing.append("edit_instruction")
            partial.append("edit_instruction")
            ask_user = ask_user or "Please provide the edit instruction for the target document."

    return fields, missing, blocked, partial, ask_user

scenario_id = detect_scenario(task_types, message)
fields, missing_fields, blocked_fields, partial_fields, ask_user_prompt = extract_fields(scenario_id, message)
finish_hint = []
adapter_cmds = []
tool_hints = []
for task_type in task_types:
    if task_type in {"create_crm_record", "update_base_record"}:
        finish_hint.append("Updated Base/CRM record")
    elif task_type in {"send_message", "send_crm_followup"}:
        finish_hint.append("Sent outbound message")
    elif task_type in {"create_expense", "submit_approval"}:
        finish_hint.append("Prepared expense/approval payload")
    elif task_type in {"create_document", "update_document", "write_wiki"}:
        finish_hint.append("Updated document content")
    elif task_type == "write_calendar":
        finish_hint.append("Scheduled calendar event")
    adapter = TASK_ADAPTERS.get(task_type)
    if adapter:
        adapter_cmds.append(adapter.format(
            agent=queue.get("worker_agent_id") or queue.get("assigned_agent_id") or queue.get("agent_id") or "main",
            queue_id=queue.get("queue_id"),
            message=message.replace('"', "'"),
        ))
    for tool in TASK_OPENCLAW_TOOLS.get(task_type, []):
        tool_hints.append(tool)

print("")
print("Execution stub plan")
print(f"  queue_id: {queue.get('queue_id')}")
print(f"  worker_agent_id: {queue.get('worker_agent_id') or queue.get('assigned_agent_id') or queue.get('agent_id')}")
print(f"  message: {queue.get('message_text')}")
print(f"  gate: {queue.get('gate')}")
print(f"  authority: {queue.get('authority')}")
print(f"  scenario_id: {scenario_id}")
print(f"  missing_fields: {', '.join(missing_fields) if missing_fields else '(none)'}")
print(f"  blocked_fields: {', '.join(blocked_fields) if blocked_fields else '(none)'}")
if ask_user_prompt:
    print(f"  ask_user_prompt: {ask_user_prompt}")
print("  planned_steps:")
if not task_types:
    print("    - No concrete task type was inferred; fall back to manual triage.")
else:
    for task_type in task_types:
        plan = TASK_PLANS.get(task_type, "Handle this task type with a manual or future specialized executor.")
        print(f"    - {task_type}: {plan}")
print("  adapter_commands:")
if not adapter_cmds:
    print("    - No direct adapter is defined yet; manual execution is required.")
else:
    for cmd in dict.fromkeys(adapter_cmds):
        print(f"    - {cmd}")
print("  official_plugin_tools:")
if not tool_hints:
    print("    - No official plugin tool hint is defined yet.")
else:
    for tool in dict.fromkeys(tool_hints):
        print(f"    - {tool}")
print(f"  suggested_finish_note: {'; '.join(dict.fromkeys(finish_hint)) if finish_hint else 'Completed placeholder execution path'}")
PY
}

_ingress_execute_apply() {
  local queue_id=""
  local dry_run=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --queue-id) queue_id="$2"; shift 2 ;;
      --dry-run) dry_run=true; shift ;;
      *) log_warn "Unknown option: $1"; shift ;;
    esac
  done

  [[ -z "$queue_id" ]] && { log_error "Usage: larc ingress execute-apply --queue-id <id> [--dry-run]"; return 1; }

  local queue_json
  queue_json=$(_ingress_get_queue_item_anywhere "$queue_id")
  [[ -z "$queue_json" ]] && { log_error "Queue item not found (local or Base): $queue_id"; return 1; }

  local current_status
  current_status=$(python3 - "$queue_json" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
print(d.get("status", ""))
PY
)
  if [[ "$current_status" != "in_progress" ]]; then
    log_error "Queue item $queue_id is '$current_status'; execute-apply expects in_progress"
    return 1
  fi

  local plan_json
  plan_json=$(python3 - "$queue_json" "${LARC_DRIVE_FOLDER_TOKEN:-}" <<'PY'
import json, os, re, sys
exec(open(os.environ["_LARC_SCENARIO_PY"]).read())

queue = json.loads(sys.argv[1])
drive_folder_token = sys.argv[2]
agent = queue.get("worker_agent_id") or queue.get("assigned_agent_id") or queue.get("agent_id") or "main"
message = (queue.get("message_text") or "").replace('"', "'")
task_types = queue.get("task_types", [])
results = []

TASK_OPENCLAW_TOOLS = {
    "create_crm_record": ["feishu_bitable_app_table_record"],
    "update_base_record": ["feishu_bitable_app_table_record"],
    "read_base": ["feishu_bitable_app_table_record", "feishu_search_doc_wiki"],
    "read_document": ["feishu_fetch_doc", "feishu_search_doc_wiki"],
    "send_crm_followup": ["feishu_im_user_message"],
    "send_message": ["feishu_im_user_message"],
    "create_expense": ["feishu_bitable_app_table_record", "feishu_drive_file"],
    "submit_approval": ["feishu_bitable_app_table_record"],
    "create_document": ["feishu_create_doc"],
    "update_document": ["feishu_fetch_doc", "feishu_update_doc"],
    "write_wiki": ["feishu_search_doc_wiki", "feishu_update_doc"],
    "write_calendar": ["feishu_calendar_event"],
}

def extract_fields(scenario_id, text):
    # ADR-0001 Hybrid: external executor module takes precedence over inline branches.
    # See lib/executors/README.md and docs/adr/0001-executor-architecture.md.
    import os as _os
    _exec_path = _os.path.join(_os.environ.get("LIB_DIR", "lib"), "executors", f"{scenario_id}.py")
    if _os.path.exists(_exec_path):
        _ns = {}
        exec(open(_exec_path).read(), _ns)
        if "extract_fields" in _ns:
            return _ns["extract_fields"](text)

    fields = {}
    missing = []
    blocked = []
    partial = []
    ask_user = ""

    if scenario_id == "ppal_marketing_ops":
        lower = text.lower()
        fields.update(load_scenario_defaults(lower))
        fields["output_folder_token"] = drive_folder_token
        fields["output_folder_strategy"] = "larc_workspace_default" if fields["output_folder_token"] else ""
        systems = []
        if "sfa" in lower:
            systems.append("sfa->ppal_base")
        if re.search(r"\bma\b|marketing automation", lower):
            systems.append("ma->ppal_base")
        if "notion" in lower:
            systems.append("notion->lark_docs")
        if "slack" in lower:
            systems.append("slack->lark_im")
        fields["source_systems"] = systems or ["ppal_base", "lark_docs", "lark_im"]
        goal_patterns = [
            r"(identify\s+[^.]+)",
            r"(follow.?up\s+[^.]+)",
            r"(create\s+[^.]+campaign[^.]+)",
            r"(draft\s+[^.]+campaign[^.]+)",
            r"(notify\s+[^.]+sales[^.]+)",
        ]
        campaign_goal = ""
        for pattern in goal_patterns:
            m = re.search(pattern, text, re.I)
            if m:
                campaign_goal = m.group(1).strip()
                break
        fields["campaign_goal"] = campaign_goal
        segment = ""
        for value in ("buyer", "lead", "nurture", "prospect", "hotlist", "hot lead", "active", "upsell"):
            if value in lower:
                segment = value
                break
        fields["segment_hint"] = segment
        fields["destination_target"] = "sales_team" if re.search(r"sales\s+team|slack|notify", lower) else ""
        if not fields["campaign_goal"]:
            missing.append("campaign_goal")
            blocked.append("campaign_goal")
            ask_user = "Please define the PPAL marketing goal first, for example which lead segment to target and what outcome to drive."
        ask_user = validate_runtime_fields(fields, missing, blocked, ask_user)
        if not fields["segment_hint"]:
            missing.append("segment_hint")
            partial.append("segment_hint")
            ask_user = ask_user or "Please specify the target lead segment or funnel slice in PPAL Base."
        if not fields["destination_target"]:
            missing.append("destination_target")
            partial.append("destination_target")
            ask_user = ask_user or "Please specify where the campaign result should be sent, for example the sales team chat."
    elif scenario_id == "crm_followup":
        m = re.search(r"\bfor\s+([A-Za-z0-9._-][A-Za-z0-9._ -]{1,60})", text, re.I)
        q = re.search(r"['\"]([^'\"]{2,80})['\"]", text)
        fields["customer_key"] = (m.group(1).strip() if m else (q.group(1).strip() if q else ""))
        fields["followup_message"] = text.strip() if re.search(r"follow.?up|send|message|notify", text, re.I) else ""
        if not fields["customer_key"]:
            missing.append("customer_key")
            blocked.append("customer_key")
            ask_user = "Please identify the target customer or lead before creating the CRM record."
        if not fields["followup_message"]:
            missing.append("followup_message")
            partial.append("followup_message")
            ask_user = ask_user or "Please provide the follow-up message content."
    elif scenario_id == "expense_approval":
        amount = re.search(r"\b(\d[\d,]*(?:\.\d+)?)\b", text)
        date = re.search(r"\b(20\d{2}-\d{2}-\d{2})\b", text)
        purpose = re.search(r"\bfor\s+(.+)$", text, re.I)
        fields["amount"] = amount.group(1) if amount else ""
        fields["expense_date"] = date.group(1) if date else ""
        fields["purpose"] = purpose.group(1).strip() if purpose else ""
        fields["expense_type"] = "expense" if re.search(r"expense|receipt|travel|meal|taxi", text, re.I) else ""
        for key in ("amount", "expense_type", "expense_date", "purpose"):
            if not fields.get(key):
                missing.append(key)
                blocked.append(key)
        if blocked:
            ask_user = "Please provide amount, expense type, date, and business purpose before approval."
    elif scenario_id == "document_update":
        ref = re.search(r"(https?://\S+|doc[cno][a-zA-Z0-9_-]+|wiki[a-zA-Z0-9_-]+)", text)
        fields["document_ref"] = ref.group(1) if ref else ""
        fields["edit_instruction"] = text.strip()
        if not fields["document_ref"]:
            missing.append("document_ref")
            blocked.append("document_ref")
            ask_user = "Please provide the target document or wiki reference."
        if not fields["edit_instruction"]:
            missing.append("edit_instruction")
            partial.append("edit_instruction")
            ask_user = ask_user or "Please provide the edit instruction for the target document."
    return fields, missing, blocked, partial, ask_user

scenario_id = detect_scenario(task_types, message)
fields, missing_fields, blocked_fields, partial_fields, ask_user_prompt = extract_fields(scenario_id, message)

for task_type in task_types:
    if task_type == "create_document":
        results.append({
            "task_type": task_type,
            "mode": "run",
            "dispatch": "openclaw",
            "message": (
                "Using the official openclaw-lark plugin, create a new Lark document "
                f"titled '{fields.get('document_title', 'PPAL Campaign Brief')}' "
                f"in Drive folder {fields.get('output_folder_token', '')}. "
                f"Use this request as the working brief: {message}. "
                f"Use PPAL Base token {fields.get('base_token', '')}, default view {fields.get('default_view_id', '')}, "
                f"and SSOT doc {fields.get('ssot_doc_url', '')} as context. "
                "Return the created document URL or token in the response."
            ),
            "note": "Requested campaign brief creation via OpenClaw",
            "tool_hints": TASK_OPENCLAW_TOOLS.get(task_type, []),
            "session_id": f"larc-step-{queue.get('queue_id', '')}-create-document"
        })
    elif task_type == "read_base":
        results.append({
            "task_type": task_type,
            "mode": "run",
            "dispatch": "openclaw",
            "message": (
                "Using the official openclaw-lark plugin, read the PPAL Base context "
                f"from app {fields.get('base_token', '')}, prioritizing view {fields.get('default_view_id', '')}, "
                f"user table {fields.get('user_table_id', '')}, cv table {fields.get('cv_table_id', '')}, "
                f"metrics table {fields.get('metrics_table_id', '')}, and source table {fields.get('source_table_id', '')}. "
                f"Focus on the campaign goal '{fields.get('campaign_goal', '')}' and segment '{fields.get('segment_hint', '')}'. "
                "Return only the key lead/funnel facts needed for the next document and message step."
            ),
            "note": "Requested PPAL Base context retrieval via OpenClaw",
            "tool_hints": TASK_OPENCLAW_TOOLS.get(task_type, []),
            "session_id": f"larc-step-{queue.get('queue_id', '')}-read-base"
        })
    elif task_type == "read_document":
        results.append({
            "task_type": task_type,
            "mode": "run",
            "dispatch": "openclaw",
            "message": (
                "Using the official openclaw-lark plugin, read the current SSOT document "
                f"{fields.get('ssot_doc_url', '')} for PPAL marketing operations. "
                f"Use it to support the campaign goal '{fields.get('campaign_goal', '')}'. "
                "Return only the sections that matter for the next campaign brief."
            ),
            "note": "Requested SSOT document retrieval via OpenClaw",
            "tool_hints": TASK_OPENCLAW_TOOLS.get(task_type, []),
            "session_id": f"larc-step-{queue.get('queue_id', '')}-read-document"
        })
    elif task_type == "send_crm_followup":
        results.append({
            "task_type": task_type,
            "mode": "run",
            "dispatch": "lark_send",
            "message": f"Follow-up prepared from queue {queue.get('queue_id')}",
            "note": "Sent CRM follow-up placeholder",
            "tool_hints": TASK_OPENCLAW_TOOLS.get(task_type, [])
        })
    elif task_type == "send_message":
        results.append({
            "task_type": task_type,
            "mode": "run",
            "dispatch": "lark_send",
            "message": message,
            "note": "Sent outbound message",
            "tool_hints": TASK_OPENCLAW_TOOLS.get(task_type, [])
        })
    else:
        results.append({
            "task_type": task_type,
            "mode": "skip",
            "note": "No safe auto-executor is defined yet",
            "tool_hints": TASK_OPENCLAW_TOOLS.get(task_type, [])
        })

if blocked_fields:
    for step in results:
        if step["task_type"] in task_types:
            step["mode"] = "blocked"
            step["note"] = f"Missing required fields: {', '.join(blocked_fields)}"

print(json.dumps({
    "agent": agent,
    "scenario_id": scenario_id,
    "required_fields": sorted(fields.keys()),
    "missing_fields": missing_fields,
    "blocked_fields": blocked_fields,
    "partial_fields": partial_fields,
    "ask_user_prompt": ask_user_prompt,
    "steps": results
}, ensure_ascii=False))
PY
)

  python3 - "$plan_json" <<'PY'
import json, sys
plan = json.loads(sys.argv[1])
print("")
print("Execute apply plan")
print(f"  agent: {plan['agent']}")
print(f"  scenario_id: {plan.get('scenario_id', 'generic')}")
print(f"  missing_fields: {', '.join(plan.get('missing_fields', [])) if plan.get('missing_fields') else '(none)'}")
if plan.get("ask_user_prompt"):
    print(f"  ask_user_prompt: {plan['ask_user_prompt']}")
for step in plan["steps"]:
    if step["mode"] == "run":
        hints = ", ".join(step.get("tool_hints", [])) or "-"
        dispatch = step.get("dispatch", "lark_send")
        print(f"  - run: {step['task_type']} -> {step['message']} [dispatch: {dispatch}] [tools: {hints}]")
    elif step["mode"] == "blocked":
        hints = ", ".join(step.get("tool_hints", [])) or "-"
        print(f"  - blocked: {step['task_type']} -> {step['note']} [tools: {hints}]")
    else:
        hints = ", ".join(step.get("tool_hints", [])) or "-"
        print(f"  - skip: {step['task_type']} -> {step['note']} [tools: {hints}]")
PY

  if [[ "$dry_run" == "true" ]]; then
    return 0
  fi

  # Unpack all plan fields in a single subprocess: blocked_fields, ask_user_prompt,
  # skipped_count, worker_agent, and run-mode steps (one JSON per line after the header).
  local _plan_out
  _plan_out=$(python3 - "$plan_json" <<'PY'
import json, sys
plan = json.loads(sys.argv[1])
print(",".join(plan.get("blocked_fields", [])))
print(plan.get("ask_user_prompt", ""))
print(sum(1 for s in plan["steps"] if s["mode"] == "skip"))
print(plan["agent"])
for step in plan["steps"]:
    if step["mode"] == "run":
        print(json.dumps(step, ensure_ascii=False))
PY
  )

  local blocked_fields worker_agent skipped_count run_steps
  blocked_fields=$(sed -n '1p' <<< "$_plan_out")
  if [[ -n "$blocked_fields" ]]; then
    log_error "Queue item $queue_id is blocked by missing required fields: $blocked_fields"
    local _ask
    _ask=$(sed -n '2p' <<< "$_plan_out")
    [[ -n "$_ask" ]] && echo "$_ask"
    return 1
  fi
  skipped_count=$(sed -n '3p' <<< "$_plan_out")
  worker_agent=$(sed -n '4p' <<< "$_plan_out")
  run_steps=$(sed -n '5,$p' <<< "$_plan_out")

  if [[ -z "$run_steps" ]]; then
    log_warn "No safe adapters to execute for queue item $queue_id"
    return 0
  fi

  local execution_notes=()
  while IFS= read -r step_json; do
    [[ -z "$step_json" ]] && continue
    local step_message step_note step_dispatch step_session_id
    # Extract all step fields in one subprocess; message is base64-encoded (may contain newlines).
    local _step_out
    _step_out=$(python3 - "$step_json" <<'PY'
import base64, json, sys
step = json.loads(sys.argv[1])
msg_b64 = base64.b64encode(step.get("message", "").encode()).decode()
print(msg_b64)
print(step.get("note", ""))
print(step.get("dispatch", "lark_send"))
print(step.get("session_id", ""))
PY
    )
    step_message=$(base64 --decode <<< "$(sed -n '1p' <<< "$_step_out")")
    step_note=$(sed -n '2p' <<< "$_step_out")
    step_dispatch=$(sed -n '3p' <<< "$_step_out")
    step_session_id=$(sed -n '4p' <<< "$_step_out")

    if [[ "$step_dispatch" == "openclaw" ]]; then
      openclaw agent --agent "$worker_agent" --session-id "${step_session_id:-larc-step-$queue_id}" --json --local --message "$step_message" >/dev/null
    else
      cmd_send --agent "$worker_agent" "$step_message"
    fi
    execution_notes+=("$step_note")
  done <<< "$run_steps"

  local finish_note
  finish_note=$(printf '%s; ' "${execution_notes[@]}")
  finish_note="${finish_note%; }"
  local final_status="done"
  if [[ "$skipped_count" != "0" ]]; then
    final_status="partial"
    if [[ -n "$finish_note" ]]; then
      finish_note="${finish_note}; Manual follow-up still required"
    else
      finish_note="Manual follow-up still required"
    fi
  fi
  _ingress_complete "$queue_id" "$final_status" "${finish_note:-Completed safe adapter execution}" "false"
}

_ingress_followup() {
  local agent_id=""
  local queue_id=""
  local days="14"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent) agent_id="$2"; shift 2 ;;
      --queue-id) queue_id="$2"; shift 2 ;;
      --days) days="$2"; shift 2 ;;
      *) log_warn "Unknown option: $1"; shift ;;
    esac
  done

  if [[ -n "$queue_id" ]]; then
    local queue_json
    queue_json=$(_ingress_get_queue_item_anywhere "$queue_id")
    [[ -z "$queue_json" ]] && { log_error "Queue item not found (local or Base): $queue_id"; return 1; }
    local status
    status=$(python3 - "$queue_json" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
print(d.get("status", ""))
PY
)
    if [[ "$status" != "partial" ]]; then
      log_error "Queue item $queue_id is '$status'; followup expects partial"
      return 1
    fi
    _ingress_render_bundle "followup" "$queue_json" "$days"
    return 0
  fi

  _ingress_list_partial_items "$agent_id"
}

_ingress_approve() {
  local queue_id=""
  local dry_run=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --queue-id) queue_id="$2"; shift 2 ;;
      --dry-run) dry_run=true; shift ;;
      *) log_warn "Unknown option: $1"; shift ;;
    esac
  done

  [[ -z "$queue_id" ]] && { log_error "Usage: larc ingress approve --queue-id <id> [--dry-run]"; return 1; }
  _ingress_transition "$queue_id" "blocked_approval" "approved" "Approval recorded; ready to resume execution." "$dry_run"
}

_ingress_resume() {
  local queue_id=""
  local dry_run=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --queue-id) queue_id="$2"; shift 2 ;;
      --dry-run) dry_run=true; shift ;;
      *) log_warn "Unknown option: $1"; shift ;;
    esac
  done

  [[ -z "$queue_id" ]] && { log_error "Usage: larc ingress resume --queue-id <id> [--dry-run]"; return 1; }
  _ingress_transition "$queue_id" "approved" "pending" "Queue item resumed after approval." "$dry_run"
}

_ingress_delegate() {
  local queue_id=""
  local dry_run=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --queue-id) queue_id="$2"; shift 2 ;;
      --dry-run) dry_run=true; shift ;;
      *) log_warn "Unknown option: $1"; shift ;;
    esac
  done

  [[ -z "$queue_id" ]] && { log_error "Usage: larc ingress delegate --queue-id <id> [--dry-run]"; return 1; }

  local queue_json
  queue_json=$(_ingress_get_queue_item_anywhere "$queue_id")
  [[ -z "$queue_json" ]] && { log_error "Queue item not found (local or Base): $queue_id"; return 1; }

  local current_status
  current_status=$(python3 - "$queue_json" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
print(d.get("status", ""))
PY
)
  case "$current_status" in
    pending|pending_preview) ;;
    *) log_error "Queue item $queue_id is '$current_status'; delegation expects pending or pending_preview"; return 1 ;;
  esac

  local selected_json
  selected_json=$(_ingress_select_best_agent "$queue_json")
  [[ -z "$selected_json" ]] && { log_error "No suitable agent found for queue item: $queue_id"; return 1; }

  local updated_json
  updated_json=$(python3 - "$queue_json" "$selected_json" <<'PY'
import json, sys
from datetime import datetime, timezone
queue = json.loads(sys.argv[1])
agent = json.loads(sys.argv[2])
queue["assigned_agent_id"] = agent["agent_id"]
queue["assigned_agent_name"] = agent.get("name", "")
queue["delegation_reason"] = agent.get("reason", "")
queue["status"] = "delegated"
queue["updated_at"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
print(json.dumps(queue, ensure_ascii=False))
PY
)

  if [[ "$dry_run" == "true" ]]; then
    python3 - "$updated_json" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
print("")
print(f"  queue_id: {d['queue_id']}")
print(f"  assigned_agent_id: {d.get('assigned_agent_id','-')}")
print(f"  assigned_agent_name: {d.get('assigned_agent_name','-')}")
print(f"  reason: {d.get('delegation_reason','-')}")
print(f"  new_status: {d['status']}")
PY
    return 0
  fi

  _ingress_replace_local_queue_item "$queue_id" "$updated_json"
  if [[ -n "$LARC_BASE_APP_TOKEN" ]]; then
    _ingress_write_base "$updated_json"
  fi
  log_ok "Delegated to $(python3 - "$updated_json" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
print(d.get("assigned_agent_id","-"))
PY
)"
}

_ingress_context() {
  local queue_id=""
  local days="14"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --queue-id) queue_id="$2"; shift 2 ;;
      --days) days="$2"; shift 2 ;;
      *) log_warn "Unknown option: $1"; shift ;;
    esac
  done

  [[ -z "$queue_id" ]] && { log_error "Usage: larc ingress context --queue-id <id> [--days N]"; return 1; }

  local queue_json
  queue_json=$(_ingress_get_queue_item_anywhere "$queue_id")
  [[ -z "$queue_json" ]] && { log_error "Queue item not found (local or Base): $queue_id"; return 1; }

  _ingress_render_bundle "context" "$queue_json" "$days"
}

_ingress_handoff() {
  local queue_id=""
  local days="14"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --queue-id) queue_id="$2"; shift 2 ;;
      --days) days="$2"; shift 2 ;;
      *) log_warn "Unknown option: $1"; shift ;;
    esac
  done

  [[ -z "$queue_id" ]] && { log_error "Usage: larc ingress handoff --queue-id <id> [--days N]"; return 1; }

  local queue_json
  queue_json=$(_ingress_get_queue_item_anywhere "$queue_id")
  [[ -z "$queue_json" ]] && { log_error "Queue item not found (local or Base): $queue_id"; return 1; }

  local current_status
  current_status=$(python3 - "$queue_json" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
print(d.get("status", ""))
PY
)
  if [[ "$current_status" != "delegated" ]]; then
    log_error "Queue item $queue_id is '$current_status'; handoff expects delegated"
    return 1
  fi

  _ingress_render_bundle "handoff" "$queue_json" "$days"
}

_ingress_done() {
  local queue_id=""
  local note="Completed successfully."
  local dry_run=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --queue-id) queue_id="$2"; shift 2 ;;
      --note) note="$2"; shift 2 ;;
      --dry-run) dry_run=true; shift ;;
      *) log_warn "Unknown option: $1"; shift ;;
    esac
  done

  [[ -z "$queue_id" ]] && { log_error "Usage: larc ingress done --queue-id <id> [--note <text>] [--dry-run]"; return 1; }
  _ingress_complete "$queue_id" "done" "$note" "$dry_run"
}

_ingress_recover() {
  local agent_id="main"
  local timeout_minutes=60
  local dry_run=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent)   agent_id="$2"; shift 2 ;;
      --timeout) timeout_minutes="$2"; shift 2 ;;
      --dry-run) dry_run=true; shift ;;
      *) log_warn "Unknown option: $1"; shift ;;
    esac
  done

  local queue_file="${LARC_HOME:-$HOME/.larc}/cache/queue/${agent_id}.jsonl"
  [[ ! -f "$queue_file" ]] && { log_info "No queue file for agent '$agent_id'"; return 0; }

  log_head "ingress recover — agent=$agent_id timeout=${timeout_minutes}m dry_run=$dry_run"

  # Single pass: find stale items and emit updated JSON lines for non-dry-run,
  # or just IDs for dry-run. Output format: "<queue_id>\t<updated_json>" or "<queue_id>\t-"
  local result
  result=$(python3 - "$queue_file" "$timeout_minutes" "$dry_run" <<'PY'
import json, sys
from datetime import datetime, timedelta, timezone

queue_file, timeout_min, dry_run = sys.argv[1], int(sys.argv[2]), sys.argv[3] == "true"
cutoff = datetime.now(timezone.utc) - timedelta(minutes=timeout_min)
now_str = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

with open(queue_file) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        d = json.loads(line)
        if d.get("status") != "in_progress":
            continue
        started = d.get("started_at", "")
        try:
            started_dt = datetime.strptime(started, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
            if started_dt >= cutoff:
                continue
        except ValueError:
            pass  # no/invalid started_at — always stale
        if dry_run:
            print(f"{d['queue_id']}\t-")
        else:
            d["status"] = "pending"
            d["started_at"] = None
            d["last_transition_note"] = "reset by recover (stale in_progress)"
            d["updated_at"] = now_str
            print(f"{d['queue_id']}\t{json.dumps(d, ensure_ascii=False)}")
PY
)

  if [[ -z "$result" ]]; then
    log_ok "No stale in_progress items found (timeout=${timeout_minutes}m)"
    return 0
  fi

  local count=0
  while IFS=$'\t' read -r queue_id updated_json; do
    [[ -z "$queue_id" ]] && continue
    count=$((count + 1))
    if [[ "$dry_run" == "true" ]]; then
      log_info "[dry-run] would reset $queue_id → pending"
    else
      _ingress_replace_local_queue_item "$queue_id" "$updated_json"
      [[ -n "${LARC_BASE_APP_TOKEN:-}" ]] && _ingress_write_base "$updated_json" 2>/dev/null || true
      log_info "Reset $queue_id → pending"
    fi
  done <<< "$result"

  log_ok "Recovered $count stale item(s)"
}

_ingress_fail() {
  local queue_id=""
  local note="Execution failed."
  local dry_run=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --queue-id) queue_id="$2"; shift 2 ;;
      --note) note="$2"; shift 2 ;;
      --dry-run) dry_run=true; shift ;;
      *) log_warn "Unknown option: $1"; shift ;;
    esac
  done

  [[ -z "$queue_id" ]] && { log_error "Usage: larc ingress fail --queue-id <id> [--note <text>] [--dry-run]"; return 1; }
  _ingress_complete "$queue_id" "failed" "$note" "$dry_run"
}

_ingress_transition() {
  local queue_id="$1"
  local expected_status="$2"
  local new_status="$3"
  local transition_note="$4"
  local dry_run="${5:-false}"

  local queue_json
  queue_json=$(_ingress_get_queue_item_anywhere "$queue_id")
  [[ -z "$queue_json" ]] && { log_error "Queue item not found (local or Base): $queue_id"; return 1; }

  local current_status
  current_status=$(python3 - "$queue_json" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
print(d.get("status", ""))
PY
)

  if [[ "$current_status" != "$expected_status" ]]; then
    log_error "Queue item $queue_id is '$current_status', expected '$expected_status'"
    return 1
  fi

  local updated_json
  updated_json=$(python3 - "$queue_json" "$new_status" "$transition_note" <<'PY'
import json, sys
from datetime import datetime, timezone
d = json.loads(sys.argv[1])
d["status"] = sys.argv[2]
d["last_transition_note"] = sys.argv[3]
d["updated_at"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
print(json.dumps(d, ensure_ascii=False))
PY
)

  if [[ "$dry_run" == "true" ]]; then
    python3 - "$updated_json" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
print("")
print(f"  queue_id: {d['queue_id']}")
print(f"  new_status: {d['status']}")
print(f"  note: {d.get('last_transition_note', '-')}")
PY
    return 0
  fi

  local existing_local raw_agent_id
  existing_local=$(_ingress_get_local_queue_item "$queue_id")
  if [[ -z "$existing_local" ]]; then
    raw_agent_id=$(python3 - "$updated_json" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
print(d.get("agent_id") or "main")
PY
)
    _ingress_write_local "$raw_agent_id" "$updated_json"
  else
    _ingress_replace_local_queue_item "$queue_id" "$updated_json"
  fi
  if [[ -n "$LARC_BASE_APP_TOKEN" ]]; then
    _ingress_write_base "$updated_json"
    _ingress_write_audit_log "$updated_json" "$new_status"
  fi

  log_ok "$transition_note"
}

_ingress_complete() {
  local queue_id="$1"
  local final_status="$2"
  local final_note="$3"
  local dry_run="${4:-false}"

  local queue_json
  queue_json=$(_ingress_get_queue_item_anywhere "$queue_id")
  [[ -z "$queue_json" ]] && { log_error "Queue item not found (local or Base): $queue_id"; return 1; }

  local current_status
  current_status=$(python3 - "$queue_json" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
print(d.get("status", ""))
PY
)

  case "$current_status" in
    pending|pending_preview|delegated|in_progress|partial) ;;
    *)
      log_error "Queue item $queue_id is '$current_status'; completion expects pending, pending_preview, or delegated"
      return 1
      ;;
  esac

  local updated_json
  updated_json=$(python3 - "$queue_json" "$final_status" "$final_note" <<'PY'
import json, sys
from datetime import datetime, timezone
d = json.loads(sys.argv[1])
d["status"] = sys.argv[2]
d["execution_note"] = sys.argv[3]
d["completed_at"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
d["updated_at"] = d["completed_at"]
print(json.dumps(d, ensure_ascii=False))
PY
)

  if [[ "$dry_run" == "true" ]]; then
    python3 - "$updated_json" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
print("")
print(f"  queue_id: {d['queue_id']}")
print(f"  new_status: {d['status']}")
print(f"  note: {d.get('execution_note', '-')}")
print(f"  completed_at: {d.get('completed_at', '-')}")
PY
    return 0
  fi

  local existing_local raw_agent_id
  existing_local=$(_ingress_get_local_queue_item "$queue_id")
  if [[ -z "$existing_local" ]]; then
    raw_agent_id=$(python3 - "$updated_json" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
print(d.get("agent_id") or "main")
PY
)
    _ingress_write_local "$raw_agent_id" "$updated_json"
  else
    _ingress_replace_local_queue_item "$queue_id" "$updated_json"
  fi
  if [[ -n "$LARC_BASE_APP_TOKEN" ]]; then
    _ingress_write_base "$updated_json"
  fi
  log_ok "Queue item marked as $final_status"

  # Post-completion hooks (non-blocking — failures are logged, not fatal)
  _ingress_post_complete "$updated_json" "$final_status" || true
}

# ── Post-completion hooks ────────────────────────────────────────────────────

_ingress_post_complete() {
  local completed_json="$1"
  local final_status="$2"

  # 1. Write audit record to agent_logs in Lark Base
  _ingress_write_audit_log "$completed_json" "$final_status"

  # 2. Send IM notification if LARC_IM_CHAT_ID is set
  _ingress_notify_completion "$completed_json" "$final_status"
}

_ingress_write_audit_log() {
  local completed_json="$1"
  local final_status="$2"

  [[ -z "${LARC_BASE_APP_TOKEN:-}" ]] && return 0

  # Get agent_logs table id (pinned via env > process cache > lookup+create)
  local table_id="${LARC_LOG_TABLE_ID:-${_LARC_AUDIT_TABLE_ID:-}}"
  if [[ -z "$table_id" ]]; then
    table_id=$(_get_or_create_logs_table)
  fi
  [[ -z "$table_id" ]] && return 0
  export _LARC_AUDIT_TABLE_ID="$table_id"

  local audit_record
  audit_record=$(python3 - "$completed_json" "$final_status" <<'PY'
import json, re, sys
from datetime import datetime, timezone
d = json.loads(sys.argv[1])
status = sys.argv[2]
note = (d.get("execution_note") or "").lower()
# Issue #38: classify rows so failure KPI excludes notification noise.
# Caller may pre-set result_class explicitly; otherwise infer from execution_note.
result_class = d.get("result_class") or ""
if not result_class:
    if re.search(r"bot echo|echo loop|outbound echo|purged", note):
        result_class = "noise"
    else:
        result_class = "business"
row = {
    "log_at":        datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "agent_id":      d.get("worker_agent_id") or d.get("agent_id", ""),
    "queue_id":      d.get("queue_id", ""),
    "source":        d.get("source", ""),
    "sender":        d.get("sender", ""),
    "task_types":    ", ".join(d.get("task_types", [])),
    "gate":          d.get("gate", ""),
    "status":        status,
    "execution_note": d.get("execution_note", ""),
    "started_at":    d.get("started_at", ""),
    "completed_at":  d.get("completed_at", ""),
    "message_text":  (d.get("message_text") or "")[:200],
    "next_human_action": d.get("next_human_action", ""),
    "result_class":  result_class,
    "delivery_status": d.get("delivery_status", ""),
}
print(json.dumps(row, ensure_ascii=False))
PY
)

  local audit_out audit_rc
  audit_out=$(lark-cli base +record-upsert \
    --base-token "$LARC_BASE_APP_TOKEN" \
    --table-id "$table_id" \
    --json "$audit_record" 2>&1) || audit_rc=$?
  if [[ "${audit_rc:-0}" -eq 0 ]]; then
    log_ok "Audit log written to agent_logs"
  else
    log_warn "Audit log write failed: $audit_out"
  fi
}

_ingress_notify_completion() {
  local completed_json="$1"
  local final_status="$2"

  local chat_id="${LARC_IM_CHAT_ID:-}"
  [[ -z "$chat_id" ]] && return 0

  # Check if send.sh is loaded
  type cmd_send &>/dev/null || {
    [[ -f "${LIB_DIR:-}/send.sh" ]] && source "${LIB_DIR}/send.sh" 2>/dev/null || return 0
  }

  local msg
  msg=$(python3 - "$completed_json" "$final_status" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
status = sys.argv[2]
icon = "✅" if status == "done" else "❌" if status == "failed" else "⚠️"
qid  = d.get("queue_id", "")[:8]
note = d.get("execution_note", "") or ""
text = (d.get("message_text") or "")[:80]
agent = d.get("worker_agent_id") or d.get("agent_id", "")
lines = [
    f"{icon} [{agent}] {status.upper()}",
    f"  Task: {text}",
]
if note:
    lines.append(f"  Note: {note[:120]}")
lines.append(f"  ID: {qid}...")
print("\n".join(lines))
PY
)

  larc send --chat "$chat_id" "$msg" >/dev/null 2>&1 \
    && log_ok "Completion notification sent to IM" \
    || log_warn "IM notification failed (chat_id: $chat_id)"
}

_ingress_write_local() {
  local agent_id="$1"
  local summary_json="$2"
  local queue_dir="$LARC_CACHE/queue"
  local queue_file="$queue_dir/${agent_id}.jsonl"
  mkdir -p "$queue_dir"
  printf '%s\n' "$summary_json" >> "$queue_file"
  log_ok "Local queue updated: $queue_file"
}

_ingress_get_local_queue_item() {
  local queue_id="$1"
  local queue_dir="$LARC_CACHE/queue"
  local found=""
  if [[ ! -d "$queue_dir" ]]; then
    return 0
  fi

  found=$(python3 - "$queue_dir" "$queue_id" <<'PY'
import json, os, sys
queue_dir, queue_id = sys.argv[1], sys.argv[2]
for name in os.listdir(queue_dir):
    if not name.endswith(".jsonl"):
        continue
    path = os.path.join(queue_dir, name)
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            d = json.loads(line)
            if d.get("queue_id") == queue_id:
                print(json.dumps(d, ensure_ascii=False))
                raise SystemExit(0)
PY
)
  printf '%s' "$found"
}

_ingress_replace_local_queue_item() {
  local queue_id="$1"
  local updated_json="$2"
  local queue_dir="$LARC_CACHE/queue"
  python3 - "$queue_dir" "$queue_id" "$updated_json" <<'PY'
import json, os, sys
queue_dir, queue_id, updated_raw = sys.argv[1:4]
updated = json.loads(updated_raw)
for name in os.listdir(queue_dir):
    if not name.endswith(".jsonl"):
        continue
    path = os.path.join(queue_dir, name)
    rows = []
    changed = False
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            d = json.loads(line)
            if d.get("queue_id") == queue_id:
                rows.append(updated)
                changed = True
            else:
                rows.append(d)
    if changed:
        with open(path, "w", encoding="utf-8") as f:
            for row in rows:
                f.write(json.dumps(row, ensure_ascii=False) + "\n")
        raise SystemExit(0)
raise SystemExit(1)
PY
}

_ingress_base_record_list() {
  # Returns all rows from a Base table as JSON array of dicts (columnar format decoded).
  # Handles +record-list response: {data:{fields:[...], data:[[...],...]}}
  local table_id="$1"
  [[ -z "${LARC_BASE_APP_TOKEN:-}" ]] && echo "[]" && return 0

  local raw
  raw=$(lark-cli base +record-list \
    --base-token "$LARC_BASE_APP_TOKEN" \
    --table-id "$table_id" \
    2>/dev/null) || { echo "[]"; return 0; }

  python3 - "$raw" <<'PY'
import json, sys

raw = sys.argv[1]
try:
    data = json.loads(raw)
except Exception:
    print("[]"); sys.exit(0)

inner = data.get("data", {}) or {}
fields = inner.get("fields", [])
rows   = inner.get("data", [])

if not fields or not rows:
    print("[]"); sys.exit(0)

result = []
for row in rows:
    d = {}
    for i, fname in enumerate(fields):
        d[fname] = row[i] if i < len(row) else None
    result.append(d)

print(json.dumps(result, ensure_ascii=False))
PY
}

_ingress_find_next_base_queue_item() {
  # Query Lark Base agent_queue for next actionable item.
  local agent_id="$1"
  [[ -z "${LARC_BASE_APP_TOKEN:-}" ]] && return 0

  local table_id="${LARC_QUEUE_TABLE_ID:-}"
  if [[ -z "$table_id" ]]; then
    table_id=$(_get_or_create_queue_table 2>/dev/null) || return 0
  fi
  [[ -z "$table_id" ]] && return 0

  local all_rows
  all_rows=$(_ingress_base_record_list "$table_id")

  python3 - "$all_rows" "$agent_id" <<'PY'
import json, sys
from datetime import datetime, timezone

all_rows_raw, agent_id = sys.argv[1], sys.argv[2]

def parse_ts(value):
    if not value:
        return datetime.max.replace(tzinfo=timezone.utc)
    for candidate in (str(value), str(value).replace("Z", "+00:00")):
        try:
            return datetime.fromisoformat(candidate)
        except ValueError:
            pass
    return datetime.max.replace(tzinfo=timezone.utc)

try:
    all_rows = json.loads(all_rows_raw)
except Exception:
    sys.exit(0)

items = []
for d in all_rows:
    status   = d.get("status") or ""
    assigned = d.get("assigned_agent_id") or ""
    owner    = d.get("agent_id") or "main"

    if agent_id == "main":
        if status not in {"pending", "pending_preview"}:
            continue
        if assigned:
            continue
        if owner != "main":
            continue
    else:
        if status != "delegated":
            continue
        if assigned != agent_id:
            continue

    # Convert comma-separated strings back to arrays
    for list_field in ("task_types", "scopes"):
        val = d.get(list_field) or ""
        if isinstance(val, str):
            d[list_field] = [x.strip() for x in val.split(",") if x.strip()]
        elif val is None:
            d[list_field] = []
    items.append(d)

items.sort(key=lambda d: parse_ts(d.get("created_at")))
if items:
    print(json.dumps(items[0], ensure_ascii=False))
PY
}

_ingress_get_base_queue_item() {
  # Fetch a specific queue item from Lark Base by queue_id.
  local queue_id="$1"
  [[ -z "${LARC_BASE_APP_TOKEN:-}" ]] && return 0

  local table_id="${LARC_QUEUE_TABLE_ID:-}"
  if [[ -z "$table_id" ]]; then
    table_id=$(_get_or_create_queue_table 2>/dev/null) || return 0
  fi
  [[ -z "$table_id" ]] && return 0

  local all_rows
  all_rows=$(_ingress_base_record_list "$table_id")

  python3 - "$all_rows" "$queue_id" <<'PY'
import json, sys

all_rows_raw, queue_id = sys.argv[1], sys.argv[2]
try:
    all_rows = json.loads(all_rows_raw)
except Exception:
    sys.exit(0)

for d in all_rows:
    if d.get("queue_id") == queue_id:
        for list_field in ("task_types", "scopes"):
            val = d.get(list_field) or ""
            if isinstance(val, str):
                d[list_field] = [x.strip() for x in val.split(",") if x.strip()]
            elif val is None:
                d[list_field] = []
        print(json.dumps(d, ensure_ascii=False))
        raise SystemExit(0)
PY
}

_ingress_get_queue_item_anywhere() {
  local queue_id="$1"
  local queue_json=""
  queue_json=$(_ingress_get_local_queue_item "$queue_id")
  if [[ -z "$queue_json" && -n "${LARC_BASE_APP_TOKEN:-}" ]]; then
    queue_json=$(_ingress_get_base_queue_item "$queue_id")
  fi
  printf '%s' "$queue_json"
}

_ingress_base_local_desync_status() {
  local queue_json="$1"
  python3 - "$queue_json" "$LARC_CACHE/queue" <<'PY'
import json, os, sys
d = json.loads(sys.argv[1])
qid = d.get("queue_id", "")
queue_dir = sys.argv[2]
if qid and os.path.isdir(queue_dir):
    for name in os.listdir(queue_dir):
        if not name.endswith(".jsonl"):
            continue
        with open(os.path.join(queue_dir, name), encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                row = json.loads(line)
                if row.get("queue_id") == qid:
                    local_status = row.get("status", "")
                    if local_status in {"done", "failed", "partial", "cancelled"}:
                        print(f"{qid}\t{local_status}")
                    raise SystemExit(0)
PY
}

_ingress_find_next_local_queue_item() {
  local agent_id="$1"
  local queue_dir="$LARC_CACHE/queue"
  [[ -d "$queue_dir" ]] || return 0

  python3 - "$queue_dir" "$agent_id" <<'PY'
import json, os, sys
from datetime import datetime, timezone

queue_dir, agent_id = sys.argv[1:3]
items = []

def parse_ts(value):
    if not value:
        return datetime.max.replace(tzinfo=timezone.utc)
    for candidate in (value, value.replace("Z", "+00:00")):
        try:
            return datetime.fromisoformat(candidate)
        except ValueError:
            pass
    return datetime.max.replace(tzinfo=timezone.utc)

for name in os.listdir(queue_dir):
    if not name.endswith(".jsonl"):
        continue
    path = os.path.join(queue_dir, name)
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            d = json.loads(line)
            status = d.get("status", "")
            assigned = d.get("assigned_agent_id")
            owner = d.get("agent_id")
            if agent_id == "main":
                if status not in {"pending", "pending_preview"}:
                    continue
                if assigned:
                    continue
                if owner != "main":
                    continue
            else:
                if status != "delegated":
                    continue
                if assigned != agent_id:
                    continue
            items.append(d)

items.sort(key=lambda d: parse_ts(d.get("created_at")))
if items:
    print(json.dumps(items[0], ensure_ascii=False))
PY
}

_ingress_list_partial_items() {
  local agent_id_filter="${1:-}"
  local queue_dir="$LARC_CACHE/queue"
  [[ -d "$queue_dir" ]] || { echo "(no partial follow-up items)"; return 0; }

  python3 - "$queue_dir" "$agent_id_filter" <<'PY'
import json, os, sys

queue_dir, agent_id_filter = sys.argv[1:3]
items = []

for name in os.listdir(queue_dir):
    if not name.endswith(".jsonl"):
        continue
    path = os.path.join(queue_dir, name)
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            d = json.loads(line)
            if d.get("status") != "partial":
                continue
            effective_agent = d.get("worker_agent_id") or d.get("assigned_agent_id") or d.get("agent_id") or "main"
            if agent_id_filter and effective_agent != agent_id_filter:
                continue
            items.append(d)

if not items:
    print("(no partial follow-up items)")
else:
    for d in items:
        print(f"{d.get('queue_id','-')}  [{d.get('status','-')} / {d.get('gate','-')}]  {str(d.get('message_text',''))[:100]} -> {d.get('execution_note','manual follow-up required')}")
PY
}

_ingress_claim_queue_item() {
  local queue_json="$1"
  local worker_agent_id="$2"
  python3 - "$queue_json" "$worker_agent_id" <<'PY'
import json, sys
from datetime import datetime, timezone

d = json.loads(sys.argv[1])
d["worker_agent_id"] = sys.argv[2]
d["status"] = "in_progress"
started_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
d["started_at"] = started_at
d["updated_at"] = started_at
print(json.dumps(d, ensure_ascii=False))
PY
}

_ingress_prepare_claimed_queue_item() {
  local queue_json="$1"
  local worker_agent_id="$2"
  local claimed_json queue_id existing_local raw_agent_id

  claimed_json=$(_ingress_claim_queue_item "$queue_json" "$worker_agent_id")
  queue_id=$(python3 - "$claimed_json" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
print(d.get("queue_id", ""))
PY
)

  existing_local=$(_ingress_get_local_queue_item "$queue_id")
  if [[ -z "$existing_local" ]]; then
    raw_agent_id=$(python3 - "$claimed_json" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
print(d.get("agent_id") or "main")
PY
)
    _ingress_write_local "$raw_agent_id" "$claimed_json"
  else
    _ingress_replace_local_queue_item "$queue_id" "$claimed_json"
  fi

  if [[ -n "${LARC_BASE_APP_TOKEN:-}" ]]; then
    _ingress_write_base "$claimed_json" >&2
    # Issue #39: dedup. If the queue was already in_progress before this claim
    # (e.g., a re-claim or restart), don't emit another in_progress audit row.
    # Genuine retries (from partial/failed/pending → in_progress) still emit.
    local _prev_status
    _prev_status=$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('status',''))" "$queue_json" 2>/dev/null)
    if [[ "$_prev_status" != "in_progress" ]]; then
      _ingress_write_audit_log "$claimed_json" "in_progress" >&2
    fi
  fi

  printf '%s\n' "$claimed_json"
}

_ingress_select_best_agent() {
  local queue_json="$1"
  python3 - "$queue_json" "$SCRIPT_DIR/agents.yaml" <<'PY'
import json, sys, os

queue = json.loads(sys.argv[1])
agents_yaml = sys.argv[2]

def parse_agents_yaml(path):
    if not os.path.exists(path):
        return []
    agents = []
    current = None
    in_scopes = False
    with open(path, "r", encoding="utf-8") as f:
        for raw in f:
            line = raw.rstrip("\n")
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            if stripped == "agents:":
                continue
            if stripped.startswith("- id:"):
                if current:
                    agents.append(current)
                current = {"agent_id": stripped.split(":", 1)[1].strip(), "scopes": []}
                in_scopes = False
                continue
            if current is None:
                continue
            if stripped.startswith("name:"):
                current["name"] = stripped.split(":", 1)[1].strip()
            elif stripped.startswith("model:"):
                current["model"] = stripped.split(":", 1)[1].strip()
            elif stripped.startswith("workspace:"):
                current["workspace"] = stripped.split(":", 1)[1].strip()
            elif stripped.startswith("scopes:"):
                in_scopes = True
            elif in_scopes and stripped.startswith("- "):
                current["scopes"].append(stripped[2:].strip())
            elif not line.startswith("      "):
                in_scopes = False
        if current:
            agents.append(current)
    return agents

agents = parse_agents_yaml(agents_yaml)
required_scopes = set(queue.get("scopes", []))
message = (queue.get("message_text") or "").lower()
task_types = set(queue.get("task_types", []))

def workspace_bonus(text):
    score = 0
    if any(t in task_types for t in ("create_expense", "submit_approval")) and any(k in text for k in ("finance", "expense")):
        score += 3
    if any(t in task_types for t in ("create_crm_record", "send_crm_followup", "read_base")) and any(k in text for k in ("sales", "customer", "crm")):
        score += 3
    if any(t in task_types for t in ("create_document", "update_document", "write_wiki", "read_wiki", "create_drive_file")) and any(k in text for k in ("document", "wiki", "doc")):
        score += 3
    return score

best = None
best_score = -10**9
for agent in agents:
    aid = agent.get("agent_id", "")
    if aid in ("", "main"):
        continue
    agent_scopes = set(agent.get("scopes", []))
    coverage = len(required_scopes & agent_scopes)
    missing = len(required_scopes - agent_scopes)
    score = coverage * 10 - missing * 20
    score += workspace_bonus((agent.get("workspace") or "").lower())
    if aid in message:
        score += 2
    if score > best_score:
        best_score = score
        best = dict(agent)
        best["reason"] = f"coverage={coverage}, missing={missing}, workspace_score={workspace_bonus((agent.get('workspace') or '').lower())}"

if best and best_score >= 0:
    print(json.dumps(best, ensure_ascii=False))
PY
}

_ingress_build_openclaw_payload() {
  local queue_json="$1"
  local days="$2"
  local local_mode="${3:-true}"

  python3 - "$queue_json" "$days" "$local_mode" "${LARC_DRIVE_FOLDER_TOKEN:-}" <<'PY'
import json, os, re, shlex, sys
exec(open(os.environ["_LARC_SCENARIO_PY"]).read())

queue = json.loads(sys.argv[1])
days = int(sys.argv[2])
local_mode = sys.argv[3] == "true"
drive_folder_token = sys.argv[4]
queue_id = queue.get("queue_id", "")
target_agent = queue.get("worker_agent_id") or queue.get("assigned_agent_id") or queue.get("agent_id") or "main"
status = queue.get("status", "")
gate = queue.get("gate", "")
authority = queue.get("authority", "")
task_types = queue.get("task_types", [])
scopes = queue.get("scopes", [])
message = queue.get("message_text", "")
TASK_OPENCLAW_TOOLS = {
    "create_crm_record": ["feishu_bitable_app_table_record"],
    "update_base_record": ["feishu_bitable_app_table_record"],
    "read_base": ["feishu_bitable_app_table_record", "feishu_search_doc_wiki"],
    "read_document": ["feishu_fetch_doc", "feishu_search_doc_wiki"],
    "send_crm_followup": ["feishu_im_user_message"],
    "send_message": ["feishu_im_user_message"],
    "create_expense": ["feishu_bitable_app_table_record", "feishu_drive_file"],
    "submit_approval": ["feishu_bitable_app_table_record"],
    "create_document": ["feishu_create_doc"],
    "update_document": ["feishu_fetch_doc", "feishu_update_doc"],
    "write_wiki": ["feishu_search_doc_wiki", "feishu_update_doc"],
    "write_calendar": ["feishu_calendar_event"],
}
tool_hints = []
for task_type in task_types:
    for tool in TASK_OPENCLAW_TOOLS.get(task_type, []):
        if tool not in tool_hints:
            tool_hints.append(tool)

def extract_normalized_fields(scenario_id, text):
    lower = text.lower()
    if scenario_id != "ppal_marketing_ops":
        return {}
    normalization = []
    if "sfa" in lower:
        normalization.append("SFA -> PPAL Base")
    if re.search(r"\bma\b|marketing automation", lower):
        normalization.append("MA -> PPAL Base")
    if "notion" in lower:
        normalization.append("Notion -> Lark Docs/Wiki")
    if "slack" in lower:
        normalization.append("Slack -> Lark IM")
    fields = load_scenario_defaults(lower)
    fields.update({
        "output_folder_token": drive_folder_token,
        "output_folder_strategy": "larc_workspace_default" if drive_folder_token else "",
        "normalization": normalization or ["PPAL Base", "Lark Docs/Wiki", "Lark IM"],
    })
    return fields

scenario_id = detect_scenario(task_types, message)
normalized_fields = extract_normalized_fields(scenario_id, message)
session_id = f"larc-{target_agent}-{queue_id}"
next_action = "ready_for_execution"
if status == "partial":
    next_action = "manual_followup_required"
elif gate == "approval" and status not in {"done", "failed"}:
    next_action = "approval_or_controlled_execution_required"
elif gate == "preview" and status not in {"done", "failed"}:
    next_action = "preview_required"
elif status == "pending_preview":
    next_action = "preview_required"

operator_steps = [
    f"1. Read queue item {queue_id}.",
    "2. Use the official openclaw-lark plugin for atomic Feishu operations.",
    "3. Use LARC commands for governed workflow actions such as context, handoff, approve/resume, and done/fail.",
]
if status in {"pending", "pending_preview"}:
    operator_steps.append(f"4. Start with: larc ingress context --queue-id {queue_id} --days {days}")
    operator_steps.append(f"5. If a specialist is needed, run: larc ingress delegate --queue-id {queue_id}")
elif status == "delegated":
    operator_steps.append(f"4. Start with: larc ingress handoff --queue-id {queue_id} --days {days}")
elif status == "in_progress":
    operator_steps.append(f"4. Start with: larc ingress execute-stub --queue-id {queue_id}")
    operator_steps.append(f"5. Then review: larc ingress execute-apply --queue-id {queue_id} --dry-run")
elif status == "partial":
    operator_steps.append(f"4. Start with: larc ingress followup --queue-id {queue_id} --days {days}")
elif status == "blocked_approval":
    operator_steps.append(f"4. This item is blocked. Resume only through: larc ingress approve --queue-id {queue_id} && larc ingress resume --queue-id {queue_id}")

tool_lines = [f"- {tool}" for tool in tool_hints] if tool_hints else ["- No explicit tool hint yet; inspect the task manually."]

prompt_lines = [
    "You are the OpenClaw agent responsible for the next governed action in LARC.",
    "",
    "Queue item:",
    f"- queue_id: {queue_id}",
    f"- target_agent: {target_agent}",
    f"- status: {status}",
    f"- gate: {gate}",
    f"- authority: {authority}",
    f"- next_action: {next_action}",
    f"- scenario_id: {scenario_id}",
    f"- task_types: {', '.join(task_types) if task_types else '(none)'}",
    f"- scopes: {', '.join(scopes) if scopes else '(none)'}",
    f"- message: {message}",
]
if normalized_fields:
    prompt_lines.extend([
        "",
        "Normalized runtime context:",
        f"- base_token: {normalized_fields.get('base_token', '')}",
        f"- user_table_id: {normalized_fields.get('user_table_id', '')}",
        f"- cv_table_id: {normalized_fields.get('cv_table_id', '')}",
        f"- metrics_table_id: {normalized_fields.get('metrics_table_id', '')}",
        f"- source_table_id: {normalized_fields.get('source_table_id', '')}",
        f"- default_view_id: {normalized_fields.get('default_view_id', '')}",
        f"- ssot_doc_url: {normalized_fields.get('ssot_doc_url', '')}",
        f"- output_folder_token: {normalized_fields.get('output_folder_token', '')}",
        f"- output_folder_strategy: {normalized_fields.get('output_folder_strategy', '')}",
        f"- normalization: {', '.join(normalized_fields.get('normalization', []))}",
    ])
prompt_lines.extend([
    "",
    "Execution rules:",
    "- Prefer the official openclaw-lark plugin for atomic Lark/Feishu operations.",
    "- Use LARC commands for permission, gate, queue, lifecycle updates, and governed write-back steps.",
    "- Do not bypass approval requirements.",
    "",
    "Mandatory reply step (always run after completing the task):",
    f'  larc ingress done --queue-id {queue_id} --note "<one-line summary>"',
    f'  larc send "<human-readable reply to the user>"',
    "",
    "Recommended operator flow:",
    *operator_steps,
    "",
    "Preferred official openclaw-lark tools:",
    *tool_lines,
])
prompt = "\n".join(prompt_lines)

cmd = [
    "openclaw", "agent",
    "--agent", target_agent,
    "--session-id", session_id,
    "--json",
]
if local_mode:
    cmd.append("--local")
cmd.extend(["--message", prompt])
command_str = " ".join(shlex.quote(part) for part in cmd)

print(json.dumps({
    "target_agent": target_agent,
    "session_id": session_id,
    "prompt": prompt,
    "command": command_str,
    "local_mode": local_mode,
    "next_action": next_action,
    "scenario_id": scenario_id,
    "normalized_fields": normalized_fields,
    "tool_hints": tool_hints,
}, ensure_ascii=False))
PY
}

_ingress_render_bundle() {
  local mode="$1"
  local queue_json="$2"
  local days="$3"
  local extra_json="${4:-}"

  [[ -z "$LARC_BASE_APP_TOKEN" ]] && {
    log_error "LARC_BASE_APP_TOKEN is not set"
    return 1
  }

  local memory_table_id
  memory_table_id=$(_get_or_create_memory_table)

  local raw_memory
  raw_memory=$(lark-cli base +record-list \
    --base-token "$LARC_BASE_APP_TOKEN" \
    --table-id "$memory_table_id" \
    2>/dev/null || echo "{}")

  python3 - "$mode" "$queue_json" "$raw_memory" "$days" "$extra_json" <<'PY'
import json, re, sys
from datetime import datetime, timedelta, timezone

mode = sys.argv[1]
queue = json.loads(sys.argv[2])
resp = json.loads(sys.argv[3])
days = int(sys.argv[4])

message_text = queue.get("message_text", "")
effective_agent = queue.get("assigned_agent_id") or queue.get("agent_id") or "main"
task_types = queue.get("task_types", [])
scopes = queue.get("scopes", [])

tokens = []
for token in re.findall(r"[A-Za-z0-9_-]{4,}", message_text.lower()):
    if token not in {"please", "route", "this", "that", "with", "from", "into", "after", "send"}:
        tokens.append(token)
for task_type in task_types:
    tokens.extend(re.findall(r"[a-z]{4,}", task_type.lower()))
token_set = set(tokens)

d = resp.get("data", resp)
rows = d.get("data", [])
fields = d.get("fields", [])

def idx(name):
    try:
        return fields.index(name)
    except ValueError:
        return None

date_idx = idx("date")
agent_idx = idx("agent_id")
content_idx = idx("content")
updated_idx = idx("updated_at")

cutoff = datetime.now(timezone.utc).date() - timedelta(days=days)
matches = []
if None not in (date_idx, agent_idx, content_idx):
    for row in rows:
        if max(date_idx, agent_idx, content_idx) >= len(row):
            continue
        if str(row[agent_idx]) != effective_agent:
            continue
        raw_date = str(row[date_idx] or "")
        try:
            row_date = datetime.strptime(raw_date, "%Y-%m-%d").date()
        except ValueError:
            continue
        if row_date < cutoff:
            continue
        content = str(row[content_idx] or "")
        lowered = content.lower()
        overlap = [t for t in token_set if t in lowered]
        if not overlap:
            continue
        updated = str(row[updated_idx]) if updated_idx is not None and updated_idx < len(row) else "-"
        snippet = " ".join(content.strip().split())
        if len(snippet) > 180:
            snippet = snippet[:177] + "..."
        matches.append({
            "date": raw_date,
            "updated_at": updated,
            "overlap": sorted(overlap),
            "snippet": snippet,
            "score": len(overlap),
        })

matches = sorted(matches, key=lambda x: (-x["score"], x["date"]))[:5]

def next_action(queue):
    gate = queue.get("gate")
    status = queue.get("status")
    if status == "partial":
        return "manual_followup_required"
    if gate == "approval" and status not in {"done", "failed"}:
        return "approval_or_controlled_execution_required"
    if gate == "preview" and status not in {"done", "failed"}:
        return "preview_required"
    if status == "pending_preview":
        return "preview_required"
    return "ready_for_execution"

if mode == "handoff":
    print("")
    print("Agent handoff bundle")
    print(f"  queue_id: {queue.get('queue_id')}")
    print(f"  assigned_agent_id: {queue.get('assigned_agent_id') or effective_agent}")
    print(f"  assigned_agent_name: {queue.get('assigned_agent_name') or '-'}")
    print(f"  status: {queue.get('status')}")
    print(f"  gate: {queue.get('gate')}")
    print(f"  authority: {queue.get('authority')}")
    print(f"  next_action: {next_action(queue)}")
    print(f"  task_types: {', '.join(task_types) if task_types else '(none)'}")
    print(f"  scopes: {', '.join(scopes) if scopes else '(none)'}")
    print(f"  message: {message_text}")
    print(f"  delegation_reason: {queue.get('delegation_reason') or '-'}")
    print(f"  retrieval_tokens: {', '.join(sorted(token_set)) if token_set else '(none)'}")
elif mode == "run-once":
    print("")
    print("Worker execution bundle")
    print(f"  queue_id: {queue.get('queue_id')}")
    print(f"  worker_agent_id: {queue.get('worker_agent_id') or effective_agent}")
    print(f"  effective_agent: {effective_agent}")
    print(f"  status: {queue.get('status')}")
    print(f"  gate: {queue.get('gate')}")
    print(f"  authority: {queue.get('authority')}")
    print(f"  next_action: {next_action(queue)}")
    print(f"  task_types: {', '.join(task_types) if task_types else '(none)'}")
    print(f"  scopes: {', '.join(scopes) if scopes else '(none)'}")
    print(f"  message: {message_text}")
    print(f"  retrieval_tokens: {', '.join(sorted(token_set)) if token_set else '(none)'}")
    print(f"  started_at: {queue.get('started_at') or '-'}")
elif mode == "openclaw":
    queue_id = queue.get("queue_id")
    status = queue.get("status")
    target_agent = queue.get("worker_agent_id") or queue.get("assigned_agent_id") or effective_agent
    extra = json.loads(sys.argv[5]) if len(sys.argv) > 5 and sys.argv[5] else {}
    commands = []
    if status in {"pending", "pending_preview"}:
        commands = [
            f"larc ingress context --queue-id {queue_id} --days {days}",
            f"larc ingress delegate --queue-id {queue_id}",
            f"larc ingress run-once --agent {target_agent} --days {days}",
        ]
    elif status == "delegated":
        commands = [
            f"larc ingress handoff --queue-id {queue_id} --days {days}",
            f"larc ingress run-once --agent {target_agent} --days {days}",
        ]
    elif status == "in_progress":
        commands = [
            f"larc ingress execute-stub --queue-id {queue_id}",
            f"larc ingress execute-apply --queue-id {queue_id} --dry-run",
            f"larc ingress done --queue-id {queue_id} --note \"Completed by {target_agent}\"",
        ]
    elif status == "partial":
        commands = [
            f"larc ingress followup --queue-id {queue_id} --days {days}",
            f"larc ingress done --queue-id {queue_id} --note \"Manual follow-up completed by {target_agent}\"",
            f"larc ingress fail --queue-id {queue_id} --note \"Unable to complete manual follow-up\"",
        ]
    elif status == "blocked_approval":
        commands = [
            f"larc ingress approve --queue-id {queue_id}",
            f"larc ingress resume --queue-id {queue_id}",
        ]
    elif status == "approved":
        commands = [f"larc ingress resume --queue-id {queue_id}"]
    else:
        commands = [f"larc ingress context --queue-id {queue_id} --days {days}"]

    print("")
    print("OpenClaw runtime bundle")
    print(f"  queue_id: {queue_id}")
    print(f"  target_agent: {target_agent}")
    print(f"  status: {status}")
    print(f"  gate: {queue.get('gate')}")
    print(f"  authority: {queue.get('authority')}")
    print(f"  next_action: {next_action(queue)}")
    print(f"  task_types: {', '.join(task_types) if task_types else '(none)'}")
    print(f"  scopes: {', '.join(scopes) if scopes else '(none)'}")
    print(f"  message: {message_text}")
    print(f"  retrieval_tokens: {', '.join(sorted(token_set)) if token_set else '(none)'}")
    if extra:
        if extra.get("scenario_id"):
            print(f"  scenario_id: {extra.get('scenario_id')}")
        if extra.get("session_id"):
            print(f"  openclaw_session_id: {extra.get('session_id')}")
        normalized_fields = extra.get("normalized_fields") or {}
        if normalized_fields:
            print(f"  normalized_fields: {json.dumps(normalized_fields, ensure_ascii=False)}")
        print(f"  openclaw_command: {extra.get('command')}")
        tool_hints = extra.get("tool_hints") or []
        print(f"  official_plugin_tools: {', '.join(tool_hints) if tool_hints else '(none)'}")
    print("  recommended_commands:")
    for cmd in commands:
        print(f"    - {cmd}")
elif mode == "followup":
    print("")
    print("Manual follow-up bundle")
    print(f"  queue_id: {queue.get('queue_id')}")
    print(f"  effective_agent: {effective_agent}")
    print(f"  status: {queue.get('status')}")
    print(f"  gate: {queue.get('gate')}")
    print(f"  authority: {queue.get('authority')}")
    print(f"  next_action: {next_action(queue)}")
    print(f"  task_types: {', '.join(task_types) if task_types else '(none)'}")
    print(f"  message: {message_text}")
    print(f"  execution_note: {queue.get('execution_note') or '-'}")
    print(f"  completed_at: {queue.get('completed_at') or '-'}")
    print(f"  retrieval_tokens: {', '.join(sorted(token_set)) if token_set else '(none)'}")
else:
    print("")
    print("Execution context bundle")
    print(f"  queue_id: {queue.get('queue_id')}")
    print(f"  effective_agent: {effective_agent}")
    print(f"  status: {queue.get('status')}")
    print(f"  gate: {queue.get('gate')}")
    print(f"  authority: {queue.get('authority')}")
    print(f"  task_types: {', '.join(task_types) if task_types else '(none)'}")
    print(f"  message: {message_text}")
    print(f"  retrieval_tokens: {', '.join(sorted(token_set)) if token_set else '(none)'}")

print("")
print("Relevant recent memory:")
if not matches:
    print("  (no related memory found)")
else:
    for item in matches:
        print(f"  - {item['date']}  overlap={','.join(item['overlap'])}")
        print(f"    {item['snippet']}")
PY
}

_ingress_verify() {
  log_head "LARC Ingress Pipeline Verification"

  local ok=0
  local fail=0

  # --- 1. Config check ---
  echo ""
  log_info "[1/5] Config"
  if [[ -n "${LARC_BASE_APP_TOKEN:-}" ]]; then
    log_ok "LARC_BASE_APP_TOKEN is set: ${LARC_BASE_APP_TOKEN:0:8}..."; ((ok++)) || true
  else
    log_error "LARC_BASE_APP_TOKEN is NOT set — queue and log writes will be skipped"; ((fail++)) || true
  fi

  if [[ -n "${LARC_QUEUE_TABLE_ID:-}" ]]; then
    log_ok "LARC_QUEUE_TABLE_ID pinned: $LARC_QUEUE_TABLE_ID"; ((ok++)) || true
  else
    log_warn "LARC_QUEUE_TABLE_ID not pinned — will resolve by name each call"
  fi

  if [[ -n "${LARC_LOG_TABLE_ID:-}" ]]; then
    log_ok "LARC_LOG_TABLE_ID pinned: $LARC_LOG_TABLE_ID"; ((ok++)) || true
  else
    log_warn "LARC_LOG_TABLE_ID not pinned — will resolve by name each call"
  fi

  # --- 2. Queue table ---
  echo ""
  log_info "[2/5] agent_queue table"
  if [[ -n "${LARC_BASE_APP_TOKEN:-}" ]]; then
    local queue_table_id
    queue_table_id=$(_get_or_create_queue_table 2>&1)
    if [[ -n "$queue_table_id" ]]; then
      log_ok "agent_queue table resolved: $queue_table_id"; ((ok++)) || true
    else
      log_error "agent_queue table resolution failed"; ((fail++)) || true
    fi
  else
    log_warn "Skipped (no LARC_BASE_APP_TOKEN)"
  fi

  # --- 3. Logs table ---
  echo ""
  log_info "[3/5] agent_logs table"
  if [[ -n "${LARC_BASE_APP_TOKEN:-}" ]]; then
    local logs_table_id
    logs_table_id=$(_get_or_create_logs_table 2>&1)
    if [[ -n "$logs_table_id" ]]; then
      log_ok "agent_logs table resolved: $logs_table_id"; ((ok++)) || true
    else
      log_error "agent_logs table resolution failed"; ((fail++)) || true
    fi
  else
    log_warn "Skipped (no LARC_BASE_APP_TOKEN)"
  fi

  # --- 4. Enqueue a test item (dry-run) ---
  echo ""
  log_info "[4/5] Enqueue (dry-run)"
  local dry_output
  dry_output=$(larc ingress enqueue --text "verify: OCR receipt test" --source verify --dry-run 2>&1)
  if echo "$dry_output" | grep -q "queue_id\|Queued"; then
    log_ok "Enqueue dry-run produced queue_id"; ((ok++)) || true
  else
    log_error "Enqueue dry-run produced no queue_id"; ((fail++)) || true
    echo "$dry_output"
  fi

  # --- 5. Live enqueue + Base write check ---
  echo ""
  log_info "[5/5] Live enqueue → Base write"
  if [[ -n "${LARC_BASE_APP_TOKEN:-}" ]]; then
    local live_output
    live_output=$(larc ingress enqueue --text "verify: pipeline check $(date +%s)" --source verify 2>&1)
    if echo "$live_output" | grep -q "Queue item recorded\|Queued"; then
      log_ok "Live enqueue → Base write succeeded"; ((ok++)) || true
    else
      log_error "Live enqueue → Base write may have failed"; ((fail++)) || true
      echo "$live_output"
    fi
  else
    log_warn "Skipped (no LARC_BASE_APP_TOKEN)"
  fi

  # --- Summary ---
  echo ""
  if [[ $fail -eq 0 ]]; then
    log_ok "All checks passed ($ok ok, $fail failed)"
  else
    log_warn "Verification complete: $ok ok, $fail failed — fix issues above"
  fi

  # --- Pin recommendations ---
  echo ""
  log_info "To pin table IDs and prevent wrong-Base selection, add to ~/.larc/config.env:"
  if [[ -n "${queue_table_id:-}" ]]; then
    echo "  LARC_QUEUE_TABLE_ID=\"$queue_table_id\""
  fi
  if [[ -n "${logs_table_id:-}" ]]; then
    echo "  LARC_LOG_TABLE_ID=\"$logs_table_id\""
  fi
}

_ingress_write_base() {
  local summary_json="$1"
  local table_id
  table_id=$(_get_or_create_queue_table)

  local base_json
  base_json=$(python3 - "$summary_json" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
d["task_types"] = ", ".join(d.get("task_types", []))
d["scopes"] = ", ".join(d.get("scopes", []))
print(json.dumps(d, ensure_ascii=False))
PY
)

  local upsert_out upsert_rc
  upsert_out=$(lark-cli base +record-upsert \
    --base-token "$LARC_BASE_APP_TOKEN" \
    --table-id "$table_id" \
    --json "$base_json" 2>&1) || upsert_rc=$?
  if [[ "${upsert_rc:-0}" -eq 0 ]]; then
    log_ok "Queue item recorded in Lark Base"
  else
    log_warn "Base queue write failed: $upsert_out"
  fi
}

_ensure_table_fields() {
  # Ensure required fields exist on a table (idempotent — errors on duplicates are ignored).
  # Results are cached per table for 24h to avoid redundant API calls on every enqueue.
  local base_token="$1" table_id="$2"
  shift 2
  local cache_file="${LARC_CACHE_DIR:-$HOME/.larc/cache}/fields/${base_token}/${table_id}"

  # Skip if verified within the last 24 hours
  if [[ -f "$cache_file" ]] && find "$cache_file" -mtime -1 2>/dev/null | grep -q .; then
    return 0
  fi

  mkdir -p "$(dirname "$cache_file")"
  for field_name in "$@"; do
    lark-cli base +field-create \
      --base-token "$base_token" \
      --table-id "$table_id" \
      --json "{\"name\":\"$field_name\",\"type\":\"text\"}" \
      >/dev/null 2>&1 || true
  done
  touch "$cache_file"
}

_get_or_create_queue_table() {
  local table_id="${LARC_QUEUE_TABLE_ID:-}"

  if [[ -z "$table_id" ]]; then
    table_id=$(lark-cli base +table-list \
      --base-token "$LARC_BASE_APP_TOKEN" \
      --jq '.data.tables[] | select(.name == "agent_queue") | .id' \
      2>/dev/null | head -1 || echo "")
  fi

  if [[ -z "$table_id" ]]; then
    log_info "Creating agent_queue table..."
    table_id=$(lark-cli base +table-create \
      --base-token "$LARC_BASE_APP_TOKEN" \
      --name "agent_queue" \
      --jq '.table.table_id // .table_id' 2>/dev/null || echo "")
    [[ -z "$table_id" ]] && { log_error "Queue table creation failed"; return 1; }
    log_ok "agent_queue table created: $table_id"
  fi

  # Always ensure fields exist — even when table ID was pinned in config.env
  _ensure_table_fields "$LARC_BASE_APP_TOKEN" "$table_id" \
    queue_id agent_id source sender event_id message_text task_types scopes \
    authority gate risk status created_at assigned_agent_id worker_agent_id \
    started_at updated_at execution_note completed_at last_transition_note

  echo "$table_id"
}

_get_or_create_logs_table() {
  local table_id="${LARC_LOG_TABLE_ID:-}"

  if [[ -z "$table_id" ]]; then
    table_id=$(lark-cli base +table-list \
      --base-token "$LARC_BASE_APP_TOKEN" \
      --jq '.data.tables[] | select(.name == "agent_logs") | .id' \
      2>/dev/null | head -1 || echo "")
  fi

  if [[ -z "$table_id" ]]; then
    log_info "Creating agent_logs table..."
    table_id=$(lark-cli base +table-create \
      --base-token "$LARC_BASE_APP_TOKEN" \
      --name "agent_logs" \
      --jq '.table.table_id // .table_id' 2>/dev/null || echo "")
    [[ -z "$table_id" ]] && { log_warn "agent_logs table creation failed"; return 1; }
    log_ok "agent_logs table created: $table_id"
  fi

  # Always ensure fields exist — even when table ID was pinned in config.env
  _ensure_table_fields "$LARC_BASE_APP_TOKEN" "$table_id" \
    log_at agent_id queue_id source sender task_types gate status \
    execution_note started_at completed_at message_text \
    next_human_action result_class delivery_status

  echo "$table_id"
}

# ── T-009: Queue triage helpers (stats / prune / retry) ─────────────────────
# Operational tooling to cope with accumulated failed queue items.
# Operates on the local JSONL cache at $LARC_CACHE/queue/<agent_id>.jsonl.
# See GitHub issue #8.

_ingress_stats() {
  local agent_id="main"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent) agent_id="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local queue_file="$LARC_CACHE/queue/${agent_id}.jsonl"
  if [[ ! -f "$queue_file" ]]; then
    log_warn "No local queue file for agent: $agent_id"
    return 1
  fi

  log_head "Queue stats (${agent_id})"
  python3 - "$queue_file" <<'PY'
import json, sys, collections
path = sys.argv[1]
status_counts = collections.Counter()
gate_counts   = collections.Counter()
reason_counts = collections.Counter()
total = 0
oldest_pending = None
oldest_failed  = None
with open(path, "r", encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            d = json.loads(line)
        except Exception:
            continue
        total += 1
        st = d.get("status", "-")
        status_counts[st] += 1
        gate_counts[d.get("gate", "-")] += 1
        if st == "failed":
            reason = (d.get("last_transition_note") or "").strip() or "(no note)"
            reason_counts[reason[:80]] += 1
            ts = d.get("updated_at") or d.get("created_at") or ""
            if ts and (oldest_failed is None or ts < oldest_failed):
                oldest_failed = ts
        if st == "pending":
            ts = d.get("created_at") or ""
            if ts and (oldest_pending is None or ts < oldest_pending):
                oldest_pending = ts

print(f"  total:        {total}")
print(f"  by status:")
for s, n in status_counts.most_common():
    print(f"    {s:<15} {n}")
print(f"  by gate:")
for g, n in gate_counts.most_common():
    print(f"    {g:<15} {n}")
if reason_counts:
    print(f"  top failure reasons (truncated to 80 chars):")
    for r, n in reason_counts.most_common(5):
        print(f"    [{n:>3}] {r}")
if oldest_pending:
    print(f"  oldest pending: {oldest_pending}")
if oldest_failed:
    print(f"  oldest failed:  {oldest_failed}")
PY
}

# Prune queue items matching filters. By default dry-run; require --yes to delete.
_ingress_prune() {
  local agent_id="main"
  local status_filter="failed"
  local older_than=""
  local reason_match=""
  local dry_run=true

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent) agent_id="$2"; shift 2 ;;
      --status) status_filter="$2"; shift 2 ;;
      --older-than) older_than="$2"; shift 2 ;;
      --reason-match) reason_match="$2"; shift 2 ;;
      --dry-run) dry_run=true; shift ;;
      --yes) dry_run=false; shift ;;
      -h|--help)
        cat <<EOF
Usage: larc ingress prune [options]

Remove queue items matching all given filters. Dry-run by default.

Options:
  --agent <id>          Target agent (default: main)
  --status <status>     Filter by status (default: failed)
  --older-than <N>d     Filter items older than N days (e.g. 7d, 30d)
  --reason-match <re>   Python regex matched against last_transition_note
  --dry-run             Preview only (default)
  --yes                 Actually delete matched items (irreversible locally)

Examples:
  larc ingress prune --status failed --older-than 7d --dry-run
  larc ingress prune --status failed --reason-match "keychain" --yes
EOF
        return 0
        ;;
      *) shift ;;
    esac
  done

  local queue_file="$LARC_CACHE/queue/${agent_id}.jsonl"
  if [[ ! -f "$queue_file" ]]; then
    log_warn "No local queue file for agent: $agent_id"
    return 1
  fi

  local tmp_out; tmp_out="${queue_file}.prune.tmp"
  local matched; matched=$(python3 - "$queue_file" "$tmp_out" "$status_filter" "$older_than" "$reason_match" "$dry_run" <<'PY'
import json, sys, re
from datetime import datetime, timezone, timedelta

path, out_path, status_filter, older_than, reason_match, dry_run_s = sys.argv[1:7]
dry_run = dry_run_s.lower() == "true"

cutoff = None
if older_than:
    m = re.match(r"^(\d+)d$", older_than)
    if m:
        cutoff = datetime.now(timezone.utc) - timedelta(days=int(m.group(1)))

rx = re.compile(reason_match) if reason_match else None

matched = []
kept = []
with open(path, "r", encoding="utf-8") as f:
    for line in f:
        line_s = line.rstrip("\n")
        if not line_s.strip():
            continue
        try:
            d = json.loads(line_s)
        except Exception:
            kept.append(line_s)
            continue
        # status filter
        if status_filter and d.get("status") != status_filter:
            kept.append(line_s); continue
        # cutoff filter
        if cutoff:
            ts = d.get("updated_at") or d.get("created_at")
            try:
                dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
                if dt >= cutoff:
                    kept.append(line_s); continue
            except Exception:
                kept.append(line_s); continue
        # reason filter
        if rx:
            note = d.get("last_transition_note") or ""
            if not rx.search(note):
                kept.append(line_s); continue
        matched.append(d)

if not dry_run:
    with open(out_path, "w", encoding="utf-8") as f:
        for line in kept:
            f.write(line + "\n")

print(len(matched))
for m in matched[:5]:
    print(f"  {m.get('queue_id','-')}  [{m.get('status','-')}]  {str(m.get('last_transition_note') or m.get('message_text',''))[:80]}")
if len(matched) > 5:
    print(f"  ... ({len(matched) - 5} more)")
PY
  )

  local count; count=$(echo "$matched" | head -1)
  log_info "Matched: $count item(s)"
  echo "$matched" | tail -n +2

  if $dry_run; then
    log_info "(dry-run — pass --yes to actually delete)"
    rm -f "$tmp_out"
    return 0
  fi

  if [[ "$count" -eq 0 ]]; then
    rm -f "$tmp_out"
    log_info "Nothing to delete"
    return 0
  fi

  # Backup then swap.
  local backup="${queue_file}.bak.$(date +%Y%m%d-%H%M%S)"
  cp "$queue_file" "$backup"
  mv "$tmp_out" "$queue_file"
  log_ok "Deleted $count item(s). Backup: $backup"
}

# Retry a failed queue item (or batch) by resetting it to pending.
_ingress_retry() {
  local agent_id="main"
  local queue_id=""
  local all_failed=false
  local reason_match=""
  local dry_run=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent) agent_id="$2"; shift 2 ;;
      --queue-id) queue_id="$2"; shift 2 ;;
      --all-failed) all_failed=true; shift ;;
      --reason-match) reason_match="$2"; shift 2 ;;
      --dry-run) dry_run=true; shift ;;
      -h|--help)
        cat <<EOF
Usage: larc ingress retry [options]

Reset failed queue items back to pending so the worker will try again.

Options:
  --agent <id>          Target agent (default: main)
  --queue-id <id>       Retry a single queue item
  --all-failed          Retry every failed item (filterable by --reason-match)
  --reason-match <re>   Only retry items whose last_transition_note matches
  --dry-run             Preview only

Examples:
  larc ingress retry --queue-id 61cf1282-3682-...
  larc ingress retry --all-failed --reason-match "keychain" --dry-run
EOF
        return 0
        ;;
      *) shift ;;
    esac
  done

  if [[ -z "$queue_id" && "$all_failed" == "false" ]]; then
    log_error "Specify either --queue-id <id> or --all-failed"
    return 1
  fi

  local queue_file="$LARC_CACHE/queue/${agent_id}.jsonl"
  if [[ ! -f "$queue_file" ]]; then
    log_warn "No local queue file for agent: $agent_id"
    return 1
  fi

  local tmp_out; tmp_out="${queue_file}.retry.tmp"
  local updated; updated=$(python3 - "$queue_file" "$tmp_out" "$queue_id" "$all_failed" "$reason_match" "$dry_run" <<'PY'
import json, sys, re
from datetime import datetime, timezone

path, out_path, queue_id, all_failed_s, reason_match, dry_run_s = sys.argv[1:7]
all_failed = all_failed_s.lower() == "true"
dry_run    = dry_run_s.lower() == "true"
rx = re.compile(reason_match) if reason_match else None
now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

updated = []
lines_out = []
with open(path, "r", encoding="utf-8") as f:
    for line in f:
        line_s = line.rstrip("\n")
        if not line_s.strip():
            continue
        try:
            d = json.loads(line_s)
        except Exception:
            lines_out.append(line_s); continue
        match = False
        if queue_id and d.get("queue_id") == queue_id and d.get("status") == "failed":
            match = True
        elif all_failed and d.get("status") == "failed":
            if rx:
                note = d.get("last_transition_note") or ""
                if not rx.search(note):
                    lines_out.append(line_s); continue
            match = True
        if match:
            d["status"] = "pending"
            d["last_transition_note"] = f"retry requested at {now}"
            d["updated_at"] = now
            d["started_at"] = None
            updated.append(d)
        lines_out.append(json.dumps(d, ensure_ascii=False))

if not dry_run:
    with open(out_path, "w", encoding="utf-8") as f:
        for line in lines_out:
            f.write(line + "\n")

print(len(updated))
for u in updated[:5]:
    print(f"  {u.get('queue_id','-')}  -> pending")
if len(updated) > 5:
    print(f"  ... ({len(updated) - 5} more)")
PY
  )

  local count; count=$(echo "$updated" | head -1)
  log_info "Matched: $count item(s)"
  echo "$updated" | tail -n +2

  if $dry_run; then
    log_info "(dry-run — no changes written)"
    rm -f "$tmp_out"
    return 0
  fi

  if [[ "$count" -eq 0 ]]; then
    rm -f "$tmp_out"
    log_info "Nothing to retry"
    return 0
  fi

  local backup="${queue_file}.bak.$(date +%Y%m%d-%H%M%S)"
  cp "$queue_file" "$backup"
  mv "$tmp_out" "$queue_file"
  log_ok "Reset $count item(s) to pending. Backup: $backup"
}
