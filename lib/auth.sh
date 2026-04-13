#!/usr/bin/env bash
# lib/auth.sh — larc auth subcommands
#
# Commands:
#   larc auth suggest "<task description>"
#       Infer required Lark scopes from a task description and display them
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
  ${CYAN}suggest${RESET} "<task description>"     Infer required scopes from task description
  ${CYAN}check${RESET} [--task <type>]            Check current permission state (suggests login if gaps found)
         [--profile <name>]
  ${CYAN}login${RESET} [--scope "<scope ...>"]    Issue auth URL for specified scopes
         [--profile <name>]

${BOLD}Examples:${RESET}
  larc auth suggest "create expense report and route to approval flow"
  larc auth check
  larc auth check --task create_expense
  larc auth check --profile writer
  larc auth login --scope "docs:document:copy base:record:create"
  larc auth login --profile backoffice_agent

EOF
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

map_path = sys.argv[1]
task_desc = sys.argv[2].lower()

with open(map_path, "r", encoding="utf-8") as f:
    scope_map = json.load(f)

tasks = scope_map.get("tasks", {})
profiles = scope_map.get("profiles", {})

# Keyword → task key mapping
KEYWORD_MAP = {
    # Documents
    r"document|doc|read.*doc": ["read_document"],
    r"create.*doc|write.*doc|new.*doc": ["create_document"],
    r"edit.*doc|update.*doc|modify.*doc": ["update_document"],
    # Wiki
    r"wiki|knowledge base|knowledge hub": ["read_wiki", "write_wiki"],
    r"wiki.*create|wiki.*update|wiki.*write": ["write_wiki"],
    # Drive
    r"drive|upload.*file|create.*file": ["create_drive_file"],
    r"read.*drive|list.*file|file.*list": ["read_drive"],
    r"create.*folder|manage.*file": ["manage_drive"],
    # Base/Bitable
    r"base|bitable|record.*create|table.*create": ["create_base_record"],
    r"read.*base|read.*record|read.*table": ["read_base"],
    r"manage.*base|manage.*bitable": ["manage_base"],
    # Messages
    r"send.*message|send.*notification|im.*send|message.*send": ["send_message"],
    r"read.*message|read.*chat|chat.*history": ["read_message"],
    # Calendar
    r"calendar|schedule|event|meeting.*schedule": ["read_calendar"],
    r"create.*calendar|create.*event|create.*schedule": ["write_calendar"],
    # Expense / Approval
    r"expense|reimbursement": ["create_expense"],
    r"approval|approve|submit.*flow|trigger.*flow": ["submit_approval"],
    r"read.*approval|check.*approval|approval.*status": ["read_approval"],
    # Contact
    r"contact|user.*info|employee.*info|directory|hr": ["read_contact"],
    # Task
    r"task|todo|to-do": ["read_task", "write_task"],
    r"create.*task|new.*task": ["write_task"],
    # Attendance
    r"attendance|check.?in|check.?out|timesheet": ["read_attendance"],
    # Minutes
    r"minutes|miaoji|meeting.*notes": ["read_minutes"],
    r"meeting.*record|vc|video.*meeting": ["read_vc"],
    # Sheets
    r"sheet|spreadsheet|excel|csv": ["manage_sheets"],
    # Slides
    r"slide|ppt|presentation": ["manage_slides"],
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

print(f"\n  Detected tasks:")
for tk in sorted(matched_tasks):
    t = tasks[tk]
    print(f"    - {tk}: {t.get('description','')}")

print(f"\n  Required scopes ({len(all_scopes)}):")
for scope, from_task in sorted(all_scopes.items()):
    print(f"    {scope}  (← {from_task})")

print(f"\n  Recommended identity: {', '.join(sorted(all_identities))}")

scope_str = " ".join(sorted(all_scopes.keys()))
print(f"\n  To issue auth URL:")
print(f"    larc auth login --scope \"{scope_str}\"")

# Suggest profiles
print(f"\n  Or use a profile for bulk setup:")
for pname, pdata in profiles.items():
    p_scopes = set(pdata["scopes"])
    needed = set(all_scopes.keys())
    if needed.issubset(p_scopes):
        print(f"    larc auth login --profile {pname}  # {pdata['description']}")
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
