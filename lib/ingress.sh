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
    next)    _ingress_next "$@" ;;
    run-once) _ingress_run_once "$@" ;;
    execute-stub) _ingress_execute_stub "$@" ;;
    approve) _ingress_approve "$@" ;;
    resume)  _ingress_resume "$@" ;;
    delegate) _ingress_delegate "$@" ;;
    context) _ingress_context "$@" ;;
    handoff) _ingress_handoff "$@" ;;
    done)    _ingress_done "$@" ;;
    fail)    _ingress_fail "$@" ;;
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
  ${CYAN}next${RESET}      Pull the next actionable queue item for an agent
  ${CYAN}run-once${RESET}  Claim the next actionable queue item for an agent
  ${CYAN}execute-stub${RESET} Show a placeholder execution plan for an in-progress item
  ${CYAN}approve${RESET}   Mark a blocked approval item as approved
  ${CYAN}resume${RESET}    Move an approved item back to pending
  ${CYAN}delegate${RESET}  Assign a queue item to the best specialist agent
  ${CYAN}context${RESET}   Build a retrieval bundle for a queue item
  ${CYAN}handoff${RESET}   Build a delegated handoff bundle for an assigned agent
  ${CYAN}done${RESET}      Mark a queue item as completed
  ${CYAN}fail${RESET}      Mark a queue item as failed

${BOLD}Examples:${RESET}
  larc ingress enqueue --text "Please route this expense to approval" --sender ou_xxx --source im
  echo "Create CRM record and send a follow-up message" | larc ingress enqueue --agent crm-agent
  larc ingress enqueue --text "Upload the file to drive and update the wiki" --dry-run
  larc ingress list --agent main
  larc ingress next --agent crm-agent --days 14
  larc ingress run-once --agent crm-agent --days 14 --dry-run
  larc ingress execute-stub --queue-id 1234
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
    r"create\s+\w*\s*doc|write\s+\w*\s*doc|new\s+doc": ["create_document"],
    r"edit\s+\w*\s*doc|update\s+\w*\s*doc|modify\s+\w*\s*doc": ["update_document"],
    r"wiki|knowledge\s*base|knowledge\s*hub": ["read_wiki"],
    r"wiki.*(?:create|update|write|add|edit)|(?:create|update|write|add|edit).*wiki": ["write_wiki"],
    r"update\s+wiki|write\s+to\s+wiki": ["write_wiki"],
    r"upload\b|attach\s+\w*\s*file|create\s+file\b": ["create_drive_file"],
    r"read\s+\w*\s*drive|list\s+file|file\s+list|browse\s+drive": ["read_drive"],
    r"create\s+folder|manage\s+file|move\s+file|delete\s+file": ["manage_drive"],
    r"\bbase\b|\bbitable\b": ["read_base"],
    r"create\s+\w*\s*record|record\s+create|add\s+\w*\s*record|new\s+\w*\s*record|insert\s+\w*\s*record": ["create_base_record"],
    r"update\s+(?:\w+\s+){0,3}record|edit\s+(?:\w+\s+){0,3}record|modify\s+(?:\w+\s+){0,3}record|patch\s+\w*\s*record": ["update_base_record"],
    r"read\s+\w*\s*(?:record|table)|list\s+\w*\s*record": ["read_base"],
    r"manage\s+\w*\s*(?:base|bitable|table)": ["manage_base"],
    r"(?:create|add|new|log|insert|register)\s+(?:\w+\s+){0,3}(?:crm|customer|lead|deal|prospect|opportunity)\b": ["create_crm_record"],
    r"(?:crm|lead|deal|prospect|opportunity)\s+(?:\w+\s+){0,3}(?:create|add|new)\b": ["create_crm_record"],
    r"\bcrm\b|customer\s+record|lead\s+record|deal\s+record|\bpipeline\b|\bprospect\b|\bopportunity\b": ["read_base"],
    r"(?=.*(?:create|add|new|log)\s+(?:\w+\s+){0,3}(?:crm|customer|lead|deal|prospect))(?=.*(?:send|message|notify))": ["send_crm_followup"],
    r"send\s+\w*\s*message|send\s+\w*\s*notification|send\s+\w*\s*(?:chat|im)|message\s+send": ["send_message"],
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
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent) agent_id="$2"; shift 2 ;;
      --days) days="$2"; shift 2 ;;
      *) log_warn "Unknown option: $1"; shift ;;
    esac
  done

  local queue_json
  queue_json=$(_ingress_find_next_local_queue_item "$agent_id")
  if [[ -z "$queue_json" ]]; then
    echo "(no actionable queue item for $agent_id)"
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

_ingress_run_once() {
  local agent_id="main"
  local days="14"
  local dry_run=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent) agent_id="$2"; shift 2 ;;
      --days) days="$2"; shift 2 ;;
      --dry-run) dry_run=true; shift ;;
      *) log_warn "Unknown option: $1"; shift ;;
    esac
  done

  local queue_json
  queue_json=$(_ingress_find_next_local_queue_item "$agent_id")
  if [[ -z "$queue_json" ]]; then
    echo "(no actionable queue item for $agent_id)"
    return 0
  fi

  local claimed_json
  claimed_json=$(_ingress_claim_queue_item "$queue_json" "$agent_id")

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
  _ingress_replace_local_queue_item "$queue_id" "$claimed_json"
  if [[ -n "$LARC_BASE_APP_TOKEN" ]]; then
    _ingress_write_base "$claimed_json"
  fi

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
  queue_json=$(_ingress_get_local_queue_item "$queue_id")
  [[ -z "$queue_json" ]] && { log_error "Queue item not found locally: $queue_id"; return 1; }

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

  python3 - "$queue_json" <<'PY'
import json, sys

queue = json.loads(sys.argv[1])
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

finish_hint = []
adapter_cmds = []
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

print("")
print("Execution stub plan")
print(f"  queue_id: {queue.get('queue_id')}")
print(f"  worker_agent_id: {queue.get('worker_agent_id') or queue.get('assigned_agent_id') or queue.get('agent_id')}")
print(f"  message: {queue.get('message_text')}")
print(f"  gate: {queue.get('gate')}")
print(f"  authority: {queue.get('authority')}")
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
print(f"  suggested_finish_note: {'; '.join(dict.fromkeys(finish_hint)) if finish_hint else 'Completed placeholder execution path'}")
PY
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
  queue_json=$(_ingress_get_local_queue_item "$queue_id")
  [[ -z "$queue_json" ]] && { log_error "Queue item not found locally: $queue_id"; return 1; }

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
  queue_json=$(_ingress_get_local_queue_item "$queue_id")
  [[ -z "$queue_json" ]] && { log_error "Queue item not found locally: $queue_id"; return 1; }

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
  queue_json=$(_ingress_get_local_queue_item "$queue_id")
  [[ -z "$queue_json" ]] && { log_error "Queue item not found locally: $queue_id"; return 1; }

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
  queue_json=$(_ingress_get_local_queue_item "$queue_id")
  [[ -z "$queue_json" ]] && { log_error "Queue item not found locally: $queue_id"; return 1; }

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

  _ingress_replace_local_queue_item "$queue_id" "$updated_json"
  if [[ -n "$LARC_BASE_APP_TOKEN" ]]; then
    _ingress_write_base "$updated_json"
  fi

  log_ok "$transition_note"
}

_ingress_complete() {
  local queue_id="$1"
  local final_status="$2"
  local final_note="$3"
  local dry_run="${4:-false}"

  local queue_json
  queue_json=$(_ingress_get_local_queue_item "$queue_id")
  [[ -z "$queue_json" ]] && { log_error "Queue item not found locally: $queue_id"; return 1; }

  local current_status
  current_status=$(python3 - "$queue_json" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
print(d.get("status", ""))
PY
)

  case "$current_status" in
    pending|pending_preview|delegated|in_progress) ;;
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

  _ingress_replace_local_queue_item "$queue_id" "$updated_json"
  if [[ -n "$LARC_BASE_APP_TOKEN" ]]; then
    _ingress_write_base "$updated_json"
  fi
  log_ok "Queue item marked as $final_status"
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

_ingress_render_bundle() {
  local mode="$1"
  local queue_json="$2"
  local days="$3"

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

  python3 - "$mode" "$queue_json" "$raw_memory" "$days" <<'PY'
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
    if gate == "approval" and status in {"blocked_approval", "approved"}:
        return "approval_still_needed"
    if gate == "preview" or status == "pending_preview":
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

  lark-cli base +record-upsert \
    --base-token "$LARC_BASE_APP_TOKEN" \
    --table-id "$table_id" \
    --json "$base_json" \
    >/dev/null 2>&1 && log_ok "Queue item recorded in Lark Base" || log_warn "Base queue write failed"
}

_get_or_create_queue_table() {
  local table_id
  table_id=$(lark-cli base +table-list \
    --base-token "$LARC_BASE_APP_TOKEN" \
    --jq '.data.tables[] | select(.name == "agent_queue") | .id' \
    2>/dev/null | head -1 || echo "")

  if [[ -z "$table_id" ]]; then
    log_info "Creating agent_queue table..."
    table_id=$(lark-cli base +table-create \
      --base-token "$LARC_BASE_APP_TOKEN" \
      --name "agent_queue" \
      --jq '.table.table_id // .table_id' 2>/dev/null || echo "")
    [[ -z "$table_id" ]] && { log_error "Queue table creation failed"; return 1; }
    log_ok "agent_queue table created: $table_id"
  fi

  [[ -n "$table_id" ]] && {
    for field_name in queue_id agent_id source sender event_id message_text task_types scopes authority gate risk status created_at; do
      lark-cli base +field-create --base-token "$LARC_BASE_APP_TOKEN" --table-id "$table_id" \
        --json "{\"name\":\"$field_name\",\"type\":\"text\"}" >/dev/null 2>&1 || true
    done
  }

  echo "$table_id"
}
