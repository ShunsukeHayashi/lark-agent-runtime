#!/usr/bin/env bash
# lib/auth.sh — larc auth subcommands
#
# Commands:
#   larc auth suggest "<task description>"
#       Infer required Lark scopes from a task description and display them
#
#   larc auth router "<task description>"
#       Intent-aware auth decision: returns user / bot / blocked + reason + min scopes
#       3-rule logic: User-mandatory → External tenant DM blocked → Bot default
#
#   larc auth check [--task <task_type>] [--profile <profile_name>]
#       Check current auth state and permission scopes
#       If scopes are missing, runs lark-cli auth login --scope "..." to issue auth URL
#
#   larc auth login [--scope "<scope ...>"] [--profile <profile_name>]
#       Start authorization for the given scopes and display the auth URL
#
# Scope mapping is defined in config/scope-map.json

cmd_auth() {
  local action="${1:-help}"; shift || true
  case "$action" in
    suggest) _auth_suggest "$@" ;;
    router)  _auth_router "$@" ;;
    check)   _auth_check "$@" ;;
    login)   _auth_login "$@" ;;
    help|--help|-h) _auth_help ;;
    *)
      log_error "Unknown subcommand: $action"
      _auth_help
      return 1
      ;;
  esac
}

_auth_help() {
  cat <<EOF

${BOLD}larc auth${RESET} — Lark permission and scope management

${BOLD}Commands:${RESET}
  ${CYAN}router${RESET} "<task description>"      Intent-aware decision: user / bot / blocked + min scopes
  ${CYAN}suggest${RESET} "<task description>"     Infer required scopes from task description
  ${CYAN}check${RESET} [--task <type>]            Check current permission state (suggests login if gaps found)
         [--profile <name>]
  ${CYAN}login${RESET} [--scope "<scope ...>"]    Issue auth URL for specified scopes
         [--profile <name>]

${BOLD}Examples:${RESET}
  larc auth router "send IM notification to team"
  larc auth router "create calendar event for tomorrow"
  larc auth suggest "create expense report and route to approval flow"
  larc auth check
  larc auth check --task create_expense
  larc auth check --profile writer
  larc auth login --scope "docs:document:copy base:record:create"
  larc auth login --profile backoffice_agent

EOF
}

# ── auth router ──────────────────────────────────────────────────────────────
# Intent-aware auth decision based on 3-rule logic from Auth Routing design doc:
#   Rule 1 — User-mandatory: Calendar write / Approval instance / Approval task act → user
#   Rule 2 — External tenant DM blocked: send DM to external tenant → blocked (error 230038)
#   Rule 3 — Default → bot (tenant_access_token is sufficient)
#
# Meegle Story: #23312641 | GitHub Issue: #32
# Design doc: https://miyabi-ai.larksuite.com/wiki/AxO6wFROninCFWknoDmjBTc0pRl

_auth_router() {
  local task_desc="${*}"

  if [[ -z "$task_desc" ]]; then
    log_error "Please provide a task description in quotes"
    echo "  Example: larc auth router \"send IM notification to team\""
    return 1
  fi

  local map_path
  map_path="$(_load_scope_map)" || return 1

  log_head "Auth routing decision: \"${task_desc}\""

  python3 - "$map_path" "$task_desc" <<'PYEOF'
import sys
import json
import re

map_path = sys.argv[1]
task_desc = sys.argv[2].lower()

with open(map_path, "r", encoding="utf-8") as f:
    scope_map = json.load(f)

# ── Minimum scope sets (from PRD spec) ──────────────────────────────────────
MIN_SCOPES = {
    "bot_read":  ["im:message:readonly"],
    "bot_send":  ["im:message:send_as_bot"],
    "user_send": ["im:message"],
    "base_write": ["bitable:app"],
    "wiki_write": ["wiki:node:create"],
    "calendar_write": ["calendar:calendar"],
    "approval_create": ["approval:instance:write"],
    "approval_act": ["approval:task:write"],
}

BOLD  = "\033[1m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
RED   = "\033[31m"
CYAN  = "\033[36m"
RESET = "\033[0m"

# ── Rule 1: User-mandatory operations ───────────────────────────────────────
# These operations MUST be attributed to a real named person.
USER_MANDATORY_PATTERNS = [
    (r"calendar|schedule\s+\w*\s*(?:meeting|event|call|appointment)|book\s+\w*\s*(?:room|meeting)",
     "Calendar write requires user attribution", ["calendar:calendar"]),
    (r"(?:submit|create|route)\s+\w*\s*approval|approval\s+(?:instance|flow|request)",
     "Approval instance creation must be attributed to the submitter", ["approval:instance:write"]),
    (r"(?:approve|reject|act\s+on)\s+\w*\s*approval|approval\s+task",
     "Approval task action must be performed as the named approver", ["approval:task:write"]),
    (r"on\s+behalf\s+of|as\s+the\s+user|user.?attributed",
     "Explicitly requested user attribution", []),
]

# ── Rule 2: External tenant DM blocked ──────────────────────────────────────
# Sending DMs to users in a different Lark tenant is blocked by Lark API.
# Error 230038: "The operator does not have the permission to send messages."
EXTERNAL_TENANT_PATTERNS = [
    r"external\s+(?:user|tenant|organization|company|member)",
    r"(?:user|member)\s+(?:from|at|in)\s+(?:another|different|other)\s+(?:tenant|org|company)",
    r"cross.tenant|inter.tenant",
    r"outside\s+(?:our|the)\s+(?:org|organization|tenant|company)",
]

# ── Rule 3: Bot default ──────────────────────────────────────────────────────
# All other operations default to bot (tenant_access_token).
BOT_SCOPE_PATTERNS = {
    r"send\s+\w*\s*(?:message|notification|alert|chat)|notify": ["im:message:send_as_bot"],
    r"read\s+\w*\s*message|message\s+history|chat\s+history": ["im:message:readonly"],
    r"read\s+\w*\s*(?:doc|document)|view\s+\w*\s*doc": ["docs:doc:readonly"],
    r"wiki|knowledge\s*base": ["wiki:wiki:readonly"],
    r"(?:create|update|write)\s+\w*\s*wiki": ["wiki:node:create"],
    r"base|bitable|crm|record": ["base:record:readonly"],
    r"(?:create|add|insert)\s+\w*\s*record": ["bitable:app", "base:record:created"],
    r"drive|upload\s+\w*\s*file": ["drive:file:create"],
    r"read\s+\w*\s*drive|list\s+file": ["drive:drive:readonly"],
}

decision = None
reason = ""
required_scopes = []
rule_applied = ""

# Check Rule 2 first (hard block)
for pattern in EXTERNAL_TENANT_PATTERNS:
    if re.search(pattern, task_desc):
        decision = "blocked"
        reason = (
            "External tenant DM is blocked by Lark API.\n"
            "  Error 230038: operator does not have permission to send messages to external users.\n"
            "  Workaround: invite external user as a guest, then use their open_id."
        )
        rule_applied = "Rule 2 — External tenant DM blocked"
        required_scopes = []
        break

# Check Rule 1 (user-mandatory)
if decision is None:
    for pattern, r_reason, r_scopes in USER_MANDATORY_PATTERNS:
        if re.search(pattern, task_desc):
            decision = "user"
            reason = r_reason
            required_scopes = r_scopes
            rule_applied = "Rule 1 — User-mandatory operation"
            break

# Rule 3 fallback (bot default)
if decision is None:
    decision = "bot"
    rule_applied = "Rule 3 — Bot default"
    reason = "This operation does not require user attribution; bot (tenant_access_token) is sufficient."
    for pattern, scopes in BOT_SCOPE_PATTERNS.items():
        if re.search(pattern, task_desc):
            required_scopes.extend(scopes)
    required_scopes = sorted(set(required_scopes)) or ["im:message:send_as_bot"]

# ── Output ───────────────────────────────────────────────────────────────────
decision_colors = {"user": GREEN, "bot": CYAN, "blocked": RED}
dc = decision_colors.get(decision, "")

print(f"\n  {BOLD}Auth decision:{RESET} {dc}{decision.upper()}{RESET}")
print(f"  {BOLD}Rule applied:{RESET} {rule_applied}")
print(f"  {BOLD}Reason:{RESET} {reason}")

if required_scopes:
    print(f"\n  {BOLD}Minimum required scopes:{RESET}")
    for s in required_scopes:
        print(f"    {s}")
    scope_str = " ".join(required_scopes)
    if decision != "blocked":
        print(f"\n  To authorize:")
        print(f"    larc auth login --scope \"{scope_str}\"")
else:
    if decision == "blocked":
        print(f"\n  {RED}No authorization path available.{RESET}")
        print(f"  See: docs/known-issues/lark-external-user-api-gap.md")

print()
PYEOF

  return $?
}

# ── Load scope map ──────────────────────────────────────────────
_get_scope_map_path() {
  local script_dir
  # Parent of lib/ is project root
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  echo "${script_dir}/../config/scope-map.json"
}

_load_scope_map() {
  local map_path
  map_path="$(_get_scope_map_path)"
  if [[ ! -f "$map_path" ]]; then
    log_error "scope-map.json not found: $map_path"
    return 1
  fi
  echo "$map_path"
}

# ── auth suggest ──────────────────────────────────────────────────────────
_auth_suggest() {
  local task_desc="${*}"

  if [[ -z "$task_desc" ]]; then
    log_error "Please provide a task description in quotes"
    echo "  Example: larc auth suggest \"create expense report and request approval\""
    return 1
  fi

  local map_path
  map_path="$(_load_scope_map)" || return 1

  log_head "Scope inference: \"${task_desc}\""

  # Keyword matching to detect relevant tasks and scopes
  python3 - "$map_path" "$task_desc" <<'PYEOF'
import sys
import json
import re
import os

map_path = sys.argv[1]
task_desc = sys.argv[2].lower()
scope_map_dir = os.path.dirname(os.path.realpath(map_path))

with open(map_path, "r", encoding="utf-8") as f:
    scope_map = json.load(f)

tasks = scope_map.get("tasks", {})
profiles = scope_map.get("profiles", {})

# Keyword → task key mapping
# Rules:
# - Patterns are matched against lowercased task_desc
# - Order matters: more specific patterns first within a category
# - Bidirectional verbs: both "create record" and "record create" must match
# - Compound tasks: "crm record + send message" should trigger both base AND im scopes
KEYWORD_MAP = {
    # ── Documents ──────────────────────────────────────────────────────
    r"\bdoc\b|document": ["read_document"],
    r"create\s+\w*\s*doc|write\s+\w*\s*doc|new\s+doc": ["create_document"],
    r"edit\s+\w*\s*doc|update\s+\w*\s*doc|modify\s+\w*\s*doc": ["update_document"],

    # ── Wiki ───────────────────────────────────────────────────────────
    r"wiki|knowledge\s*base|knowledge\s*hub": ["read_wiki"],
    r"wiki.*(?:create|update|write|add|edit)|(?:create|update|write|add|edit).*wiki": ["write_wiki"],
    r"update\s+wiki|write\s+to\s+wiki": ["write_wiki"],

    # ── Drive ──────────────────────────────────────────────────────────
    # "upload X file", "upload file", "upload to drive", "attach file"
    r"upload\b|attach\s+\w*\s*file|create\s+file\b": ["create_drive_file"],
    r"read\s+\w*\s*drive|list\s+file|file\s+list|browse\s+drive": ["read_drive"],
    r"create\s+folder|manage\s+file|move\s+file|delete\s+file": ["manage_drive"],

    # ── Base / Bitable (fixed: both word orders) ────────────────────────
    r"\bbase\b|\bbitable\b": ["read_base"],
    # "create record", "create a record", "create crm record", "record create"
    r"create\s+\w*\s*record|record\s+create|add\s+\w*\s*record|new\s+\w*\s*record|insert\s+\w*\s*record": ["create_base_record"],
    # "update record", "edit record", "modify record"
    r"update\s+(?:\w+\s+){0,3}record|edit\s+(?:\w+\s+){0,3}record|modify\s+(?:\w+\s+){0,3}record|patch\s+\w*\s*record": ["update_base_record"],
    r"read\s+\w*\s*(?:record|table)|list\s+\w*\s*record": ["read_base"],
    r"manage\s+\w*\s*(?:base|bitable|table)": ["manage_base"],

    # ── CRM ────────────────────────────────────────────────────────────
    # create verb + CRM entity → create_crm_record
    r"(?:create|add|new|log|insert|register)\s+(?:\w+\s+){0,3}(?:crm|customer|lead|deal|prospect|opportunity)\b": ["create_crm_record"],
    r"(?:crm|lead|deal|prospect|opportunity)\s+(?:\w+\s+){0,3}(?:create|add|new)\b": ["create_crm_record"],
    # CRM entity mention without an explicit write verb should default to read, not update
    r"\bcrm\b|customer\s+record|lead\s+record|deal\s+record|\bpipeline\b|\bprospect\b|\bopportunity\b": ["read_base"],
    # CRM create + explicit send/notify intent → dedicated compound task
    r"(?=.*(?:create|add|new|log)\s+(?:\w+\s+){0,3}(?:crm|customer|lead|deal|prospect))(?=.*(?:send|message|notify))": ["send_crm_followup"],

    # ── Messages / IM ──────────────────────────────────────────────────
    r"send\s+\w*\s*message|send\s+\w*\s*notification|send\s+\w*\s*(?:chat|im)|message\s+send": ["send_message"],
    r"follow.?up\s+message|send\s+follow.?up": ["send_message"],
    # "notify X" where X is any person/group
    r"notify\s+(?:the\s+)?\w+|send\s+\w*\s*alert": ["send_message"],
    r"read\s+\w*\s*message|read\s+\w*\s*chat|chat\s+history|message\s+history": ["read_message"],

    # ── Calendar ───────────────────────────────────────────────────────
    r"calendar|read\s+\w*\s*event|list\s+\w*\s*event": ["read_calendar"],
    # "schedule a meeting", "schedule a follow-up meeting", "book a meeting"
    r"schedule\s+(?:a\s+)?(?:\S+\s+){0,3}(?:meeting|call|event|appointment)|create\s+\w*\s*(?:event|meeting|appointment)|book\s+\w*\s*(?:room|meeting|slot)": ["write_calendar"],

    # ── Expense / Approval ─────────────────────────────────────────────
    # bare "expense" or "reimbursement" in any context → create_expense
    r"\bexpense\b|\breimbursement\b|expense\s+report|expense\s+claim|receipt\s+submission": ["create_expense"],
    # "route X to approval", "submit approval", "approval flow" → submit_approval
    r"(?:submit|send|create|trigger|start)\s+\w*\s*approval|approval\s+flow|approval\s+request|route\s+\w+\s+to\s+approval": ["submit_approval"],
    r"(?:approve|reject|process|handle)\s+\w*\s*approval|approval\s+task|approver|reject\s+task": ["act_approval_task"],
    r"(?:check|read|get|view)\s+\w*\s*approval|approval\s+status|pending\s+approval": ["read_approval"],

    # ── Contact / Directory ────────────────────────────────────────────
    r"contact|employee\s+info|user\s+info|directory|lookup\s+user|find\s+user|\bhr\b": ["read_contact"],
    r"update\s+\w*\s*contact|manage\s+\w*\s*contact|add\s+\w*\s*employee": ["manage_contact"],

    # ── Task / Todo ────────────────────────────────────────────────────
    r"create\s+\w*\s*task|new\s+\w*\s*task|add\s+\w*\s*task|assign\s+\w*\s*task": ["write_task"],
    r"(?<!approval\s)\btask\b|\btodo\b|to-do|checklist": ["read_task"],

    # ── Attendance ─────────────────────────────────────────────────────
    r"attendance|check.?in|check.?out|timesheet|punch\s+in|punch\s+out|clock\s+in": ["read_attendance"],

    # ── Minutes / VC ───────────────────────────────────────────────────
    r"minutes|miaoji|meeting\s+notes|transcript": ["read_minutes"],
    r"video\s+meeting|vc\s+record|video\s+conference\s+record": ["read_vc"],

    # ── Sheets ─────────────────────────────────────────────────────────
    r"spreadsheet|sheet|excel|\bcsv\b": ["manage_sheets"],

    # ── Slides ─────────────────────────────────────────────────────────
    r"slide|\bppt\b|presentation|deck": ["manage_slides"],
}

matched_tasks = set()
for pattern, task_keys in KEYWORD_MAP.items():
    if re.search(pattern, task_desc):
        for tk in task_keys:
            if tk in tasks:
                matched_tasks.add(tk)

if not matched_tasks:
    print("\n  No matching scopes found.")
    print("  Try a more specific description, or specify directly:")
    print(f"    larc auth check --task <task_type>")
    print(f"\n  Available task types: {', '.join(sorted(tasks.keys()))}")
    sys.exit(0)

# Aggregate scopes
all_scopes = {}
all_identities = set()
for tk in sorted(matched_tasks):
    t = tasks[tk]
    for s in t["scopes"]:
        all_scopes[s] = tk
    all_identities.add(t["identity"])

display_identities = set(all_identities)
if "either" in display_identities and ("user" in display_identities or "bot" in display_identities):
    display_identities.discard("either")
identity_label = ", ".join(sorted(display_identities))
if display_identities == {"user", "bot"}:
    identity_label = "user or bot"
elif not identity_label:
    identity_label = "either"

authority_notes = scope_map.get("authority_notes", {})

print(f"\n  Detected tasks:")
for tk in sorted(matched_tasks):
    t = tasks[tk]
    print(f"    - {tk}: {t.get('description','')}")

print(f"\n  Required scopes ({len(all_scopes)}):")
for scope, from_task in sorted(all_scopes.items()):
    print(f"    {scope}  (← {from_task})")

# Authority explanation
effective_identity = "either" if display_identities == {"user", "bot"} else list(display_identities)[0] if len(display_identities) == 1 else "either"
note = authority_notes.get(effective_identity, {})
print(f"\n  Authority: {note.get('label', identity_label)}")
if note.get("when"):
    print(f"    Why: {note['when']}")
if note.get("provision"):
    print(f"    How to provision: {note['provision']}")

scope_str = " ".join(sorted(all_scopes.keys()))
print(f"\n  To issue auth URL:")
print(f"    larc auth login --scope \"{scope_str}\"")

# Known API limitation warnings — surface before caller invests effort
TASK_WARNINGS = {
    "manage_contact": (
        "WARN: 外部テナントユーザー（別会社のLarkアカウント）はAPIで検索・一覧取得できません。\n"
        "      外部ユーザーを追加するには：\n"
        "        A) 管理コンソール (admin.larksuite.com) でゲスト招待後、open_id で操作\n"
        "        B) 相手にopen_idを確認してもらい --member_type openid で直接指定\n"
        "      参照: docs/known-issues/lark-external-user-api-gap.md"
    ),
    "manage_wiki": (
        "WARN: Wiki メンバー追加で外部ユーザーのメールアドレス検索はできません (131005エラー)。\n"
        "      外部ユーザーを Wiki に追加するには：\n"
        "        A) 管理コンソールでゲスト招待後、open_id で wiki members create を実行\n"
        "        B) open_sharing=anyone_readable でリンク公開（Larkアカウント不要）\n"
        "      参照: docs/known-issues/lark-external-user-api-gap.md"
    ),
    "read_contact": (
        "NOTE: 外部テナントのユーザーは GET /contact/v3/users などで返りません（内部ユーザーのみ）。\n"
        "      参照: docs/known-issues/lark-external-user-api-gap.md"
    ),
}

YELLOW = "\033[33m"; RESET_C = "\033[0m"; BOLD_C = "\033[1m"
warnings_shown = set()
for tk in sorted(matched_tasks):
    if tk in TASK_WARNINGS and tk not in warnings_shown:
        warnings_shown.add(tk)
        print(f"\n  {YELLOW}{BOLD_C}⚠  Known limitation ({tk}):{RESET_C}")
        for line in TASK_WARNINGS[tk].split("\n"):
            print(f"  {YELLOW}{line}{RESET_C}")

# Suggest profiles
print(f"\n  Or use a profile for bulk setup:")
for pname, pdata in profiles.items():
    p_scopes = set(pdata["scopes"])
    needed = set(all_scopes.keys())
    if needed.issubset(p_scopes):
        print(f"    larc auth login --profile {pname}  # {pdata['description']}")

# Execution gates
gate_policy_path = os.path.join(scope_map_dir, "gate-policy.json")
if os.path.exists(gate_policy_path):
    with open(gate_policy_path) as gf:
        gate_policy = json.load(gf)
    gate_tasks = gate_policy.get("tasks", {})
    gates_needed = []
    for tk in sorted(matched_tasks):
        g = gate_tasks.get(tk, {})
        risk = g.get("risk", "none")
        gate = g.get("gate", "none")
        if gate != "none":
            gates_needed.append((tk, risk, gate))
    if gates_needed:
        colors = {"preview": "\033[33m", "approval": "\033[31m"}
        RESET = "\033[0m"
        BOLD = "\033[1m"
        print(f"\n  {BOLD}Execution gates required:{RESET}")
        for tk, risk, gate in gates_needed:
            gc = colors.get(gate, "")
            print(f"    {tk:<28} → {gc}{gate}{RESET}  (risk: {risk})")
        print(f"\n    Run: larc approve gate <task_type>  for next-step guidance")
PYEOF

  local exit_code=$?
  return $exit_code
}

# ── auth check ────────────────────────────────────────────────────────────
_auth_check() {
  local task_type=""
  local profile_name=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --task)    task_type="$2";    shift 2 ;;
      --profile) profile_name="$2"; shift 2 ;;
      *) log_warn "Unknown option: $1"; shift ;;
    esac
  done

  log_head "Checking Lark permission state"

  # Verify lark-cli connection
  log_info "Checking lark-cli connection..."
  local identity_info
  if ! identity_info=$(python3 - <<'PY' 2>/dev/null
import json
import subprocess

raw = subprocess.check_output(["lark-cli", "auth", "status"], text=True)
data = json.loads(raw)
print(f"{data.get('userName', '-')} ({data.get('identity', '-')}) / {data.get('userOpenId', '-')}")
PY
  ); then
    log_warn "Could not retrieve lark-cli auth info"
    log_warn "Run 'lark-cli auth login' to authenticate"
    identity_info="unauthenticated"
  fi
  echo -e "  ${BOLD}Authenticated user:${RESET} $identity_info"
  echo ""

  # Check currently granted scopes (if lark-cli supports it)
  local current_scopes=""
  log_info "Fetching granted scopes..."
  current_scopes=$(python3 - <<'PY' 2>/dev/null || echo ""
import json
import subprocess

raw = subprocess.check_output(["lark-cli", "auth", "status"], text=True)
data = json.loads(raw)
print("\n".join((data.get("scope") or "").split()))
PY
  )

  if [[ -z "$current_scopes" ]]; then
    log_warn "  Could not retrieve scope list"
  else
    echo -e "  ${BOLD}Granted scopes:${RESET}"
    echo "$current_scopes" | while IFS= read -r scope; do
      echo -e "    ${GREEN}✓${RESET} $scope"
    done
    echo ""
  fi

  # If task/profile specified, check against required scopes
  if [[ -n "$task_type" ]] || [[ -n "$profile_name" ]]; then
    _auth_check_requirements "$task_type" "$profile_name" "$current_scopes"
  else
    # No spec: run basic permission tests
    _auth_check_basic
  fi
}

_auth_check_basic() {
  log_info "Running basic permission tests..."
  echo ""

  local all_ok=true

  # Drive read test
  echo -e "  ${BOLD}Drive read (drive:drive:readonly):${RESET}"
  if [[ -n "$LARC_DRIVE_FOLDER_TOKEN" ]]; then
    if lark-cli drive files list --params "{\"folder_token\":\"${LARC_DRIVE_FOLDER_TOKEN}\"}" &>/dev/null; then
      echo -e "    ${GREEN}✓ OK${RESET}"
    else
      echo -e "    ${RED}✗ FAILED${RESET} — drive:drive:readonly may be missing"
      all_ok=false
    fi
  else
    echo -e "    ${YELLOW}⚠ SKIPPED${RESET} — LARC_DRIVE_FOLDER_TOKEN not set"
  fi

  # Base read test
  echo -e "  ${BOLD}Base read (base:record:readonly):${RESET}"
  if [[ -n "$LARC_BASE_APP_TOKEN" ]]; then
    if lark-cli base +table-list --base-token "$LARC_BASE_APP_TOKEN" &>/dev/null; then
      echo -e "    ${GREEN}✓ OK${RESET}"
    else
      echo -e "    ${RED}✗ FAILED${RESET} — base:record:readonly may be missing"
      all_ok=false
    fi
  else
    echo -e "    ${YELLOW}⚠ SKIPPED${RESET} — LARC_BASE_APP_TOKEN not set"
  fi

  echo ""
  if [[ "$all_ok" == "true" ]]; then
    log_ok "Basic permission tests: all OK"
  else
    log_warn "Some permission tests failed"
    echo ""
    echo -e "  To add missing scopes:"
    echo -e "    ${CYAN}larc auth login --profile readonly${RESET}  # minimum read permissions"
    echo -e "    ${CYAN}larc auth login --profile writer${RESET}    # includes write permissions"
  fi
}

_auth_check_requirements() {
  local task_type="$1"
  local profile_name="$2"
  local current_scopes="$3"

  local map_path
  map_path="$(_load_scope_map)" || return 1

  python3 - "$map_path" "$task_type" "$profile_name" "$current_scopes" <<'PYEOF'
import sys
import json

map_path    = sys.argv[1]
task_type   = sys.argv[2]
profile_name = sys.argv[3]
current_scopes_raw = sys.argv[4]

current_scopes = set(s.strip() for s in current_scopes_raw.splitlines() if s.strip())

with open(map_path, "r", encoding="utf-8") as f:
    scope_map = json.load(f)

tasks    = scope_map.get("tasks", {})
profiles = scope_map.get("profiles", {})

required_scopes = set()
label = ""

if task_type and task_type in tasks:
    required_scopes = set(tasks[task_type]["scopes"])
    label = f"task '{task_type}'"
elif task_type:
    print(f"\n  Unknown task type: {task_type}")
    print(f"  Available: {', '.join(sorted(tasks.keys()))}")
    sys.exit(1)

if profile_name and profile_name in profiles:
    required_scopes.update(profiles[profile_name]["scopes"])
    label = (label + " / " if label else "") + f"profile '{profile_name}'"
elif profile_name:
    print(f"\n  Unknown profile: {profile_name}")
    print(f"  Available: {', '.join(sorted(profiles.keys()))}")
    sys.exit(1)

if not required_scopes:
    print("\n  Please specify a task or profile")
    sys.exit(0)

print(f"\n  Checking: {label}")
print(f"  Required scopes ({len(required_scopes)}):\n")

missing = []
for scope in sorted(required_scopes):
    if current_scopes and scope in current_scopes:
        print(f"    \033[32m✓\033[0m {scope}")
    else:
        if current_scopes:
            print(f"    \033[31m✗\033[0m {scope}  ← not granted")
            missing.append(scope)
        else:
            print(f"    \033[33m?\033[0m {scope}  ← cannot verify")

if missing:
    missing_str = " ".join(missing)
    print(f"\n  \033[33m{len(missing)} missing scope(s) found.\033[0m")
    print(f"\n  To issue auth URL, run:")
    print(f"    larc auth login --scope \"{missing_str}\"")
elif current_scopes:
    print(f"\n  \033[32m✓ All required scopes are already granted.\033[0m")
else:
    scope_str = " ".join(sorted(required_scopes))
    print(f"\n  Could not verify scope grant status. Re-auth recommended:")
    print(f"    larc auth login --scope \"{scope_str}\"")
PYEOF

  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    return $exit_code
  fi

  # If missing scopes, offer to issue login URL now
  echo ""
  read -r -p "Issue auth URL for missing scopes now? [y/N] " ans
  if [[ "$ans" == "y" || "$ans" == "Y" ]]; then
    local map_path_inner
    map_path_inner="$(_load_scope_map)"
    local missing_scopes
    missing_scopes=$(python3 - "$map_path_inner" "$task_type" "$profile_name" "$current_scopes" <<'PYEOF2'
import sys, json
map_path, task_type, profile_name, cur_raw = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
current = set(s.strip() for s in cur_raw.splitlines() if s.strip())
with open(map_path) as f: m = json.load(f)
tasks, profiles = m.get("tasks",{}), m.get("profiles",{})
req = set()
if task_type in tasks: req.update(tasks[task_type]["scopes"])
if profile_name in profiles: req.update(profiles[profile_name]["scopes"])
missing = sorted(req - current) if current else sorted(req)
print(" ".join(missing))
PYEOF2
    )
    if [[ -n "$missing_scopes" ]]; then
      _auth_login --scope "$missing_scopes"
    else
      log_ok "No missing scopes"
    fi
  fi
}

# ── auth login ────────────────────────────────────────────────────────────
_auth_login() {
  local scopes=""
  local profile_name=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --scope)   scopes="$2";       shift 2 ;;
      --profile) profile_name="$2"; shift 2 ;;
      *) log_warn "Unknown option: $1"; shift ;;
    esac
  done

  # Expand profile scopes if specified
  if [[ -n "$profile_name" ]]; then
    local map_path
    map_path="$(_load_scope_map)" || return 1

    local profile_scopes
    profile_scopes=$(python3 - "$map_path" "$profile_name" <<'PYEOF'
import sys, json
map_path, profile_name = sys.argv[1], sys.argv[2]
with open(map_path) as f: m = json.load(f)
profiles = m.get("profiles", {})
if profile_name not in profiles:
    print(f"ERROR: profile '{profile_name}' not found", file=sys.stderr)
    print(f"Available: {', '.join(sorted(profiles.keys()))}", file=sys.stderr)
    sys.exit(1)
print(" ".join(profiles[profile_name]["scopes"]))
PYEOF
    )
    if [[ $? -ne 0 ]]; then
      log_error "Failed to load profile: $profile_name"
      return 1
    fi

    # Merge with existing scopes
    if [[ -n "$scopes" ]]; then
      scopes="${scopes} ${profile_scopes}"
    else
      scopes="$profile_scopes"
    fi

    log_info "Using scopes from profile '$profile_name'"
  fi

  if [[ -z "$scopes" ]]; then
    log_error "Specify scopes: --scope \"<scope ...>\" or --profile <name>"
    echo ""
    echo "  Examples:"
    echo "    larc auth login --scope \"docs:document:copy base:record:create\""
    echo "    larc auth login --profile readonly"
    echo "    larc auth login --profile writer"
    echo ""
    echo "  Available profiles:"
    local map_path
    map_path="$(_load_scope_map)" 2>/dev/null || true
    if [[ -f "$map_path" ]]; then
      python3 -c "
import json
with open('$map_path') as f: m = json.load(f)
for k, v in m.get('profiles',{}).items():
    print(f'    {k}: {v[\"description\"]}')
" 2>/dev/null || true
    fi
    return 1
  fi

  log_head "Starting Lark authorization"
  log_info "Scopes: $scopes"
  echo ""

  # Normalize scopes (deduplicate and sort)
  local normalized_scopes
  normalized_scopes=$(echo "$scopes" | tr ', ' '\n\n' | sed '/^$/d' | sort -u | tr '\n' ' ' | sed 's/[[:space:]]*$//')

  log_info "Running lark-cli auth login..."
  echo ""

  # Issue auth URL via lark-cli auth login
  if lark-cli auth login --scope "$normalized_scopes"; then
    echo ""
    log_ok "Auth URL issued. Open the URL in your browser and approve the permissions."
    echo ""
    echo -e "  After approving, verify permissions with:"
    echo -e "    ${CYAN}larc auth check${RESET}"
  else
    local exit_code=$?
    echo ""
    log_error "lark-cli auth login failed (exit: $exit_code)"
    echo ""
    echo -e "  To run manually:"
    echo -e "    ${CYAN}lark-cli auth login --scope \"$normalized_scopes\"${RESET}"
    echo ""
    echo -e "  You can also configure scopes directly in Lark Open Platform:"
    echo -e "    https://open.larksuite.com/app"
    return $exit_code
  fi
}
