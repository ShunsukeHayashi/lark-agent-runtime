#!/usr/bin/env bash
# scripts/setup-workspace.sh — Automatically provision agent workspace on Lark Drive
#
# Example:
#   ./scripts/setup-workspace.sh \
#     --agent main \
#     --drive-folder fldcnXXXXXXXX \
#     --base-token bascXXXXXXXX
#
# What this does:
#   1. Create folder structure in Lark Drive
#   2. Upload template files (SOUL.md / USER.md / MEMORY.md)
#   3. Auto-create 4 tables in Lark Base:
#      - agents_registry   : agent registration info
#      - agent_memory      : long-term memory / session context
#      - agent_heartbeat   : health check / state log
#      - agent_logs        : operations audit log

set -euo pipefail

# ── Color / log helpers ──────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log_info()  { echo -e "${BLUE}[setup]${RESET} $*"; }
log_ok()    { echo -e "${GREEN}[setup]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[setup]${RESET} $*"; }
log_error() { echo -e "${RED}[setup]${RESET} $*" >&2; }
log_head()  { echo -e "\n${BOLD}${CYAN}▶ $*${RESET}"; }
log_step()  { echo -e "  ${CYAN}→${RESET} $*"; }

# ── Resolve script dir → project root ──────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_DIR="$PROJECT_ROOT/agent-workspace/templates"
CONFIG_DIR="$PROJECT_ROOT/config"
SCOPE_MAP="$CONFIG_DIR/scope-map.json"

# ── Defaults ──────────────────────────────────────────────────────────────
AGENT_ID=""
DRIVE_FOLDER_TOKEN=""
BASE_TOKEN=""
DRY_RUN=false
SKIP_DRIVE=false
SKIP_BASE=false
VERBOSE=false

# ── Argument parsing ────────────────────────────────────────────────────────
usage() {
  cat <<EOF

${BOLD}Usage:${RESET}
  $0 --agent <id> --drive-folder <token> --base-token <token> [options]

${BOLD}Required:${RESET}
  --agent <id>              Agent ID (e.g., main, office-assistant)
  --drive-folder <token>    Parent folder Drive token (e.g., fldcnXXXXXX)
  --base-token <token>      Lark Base app_token (e.g., bascXXXXXX)

${BOLD}Options:${RESET}
  --dry-run                 Show what would be done without executing
  --skip-drive              Skip Drive folder creation and upload
  --skip-base               Skip Lark Base table creation
  --verbose                 Show verbose logs
  -h, --help                Show this help

${BOLD}Examples:${RESET}
  $0 --agent main --drive-folder fldcnABCDEF --base-token bascXYZ123
  $0 --agent dev --drive-folder fldcnABCDEF --base-token bascXYZ123 --dry-run

EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent)        AGENT_ID="$2";          shift 2 ;;
    --drive-folder) DRIVE_FOLDER_TOKEN="$2"; shift 2 ;;
    --base-token)   BASE_TOKEN="$2";         shift 2 ;;
    --dry-run)      DRY_RUN=true;            shift ;;
    --skip-drive)   SKIP_DRIVE=true;         shift ;;
    --skip-base)    SKIP_BASE=true;          shift ;;
    --verbose)      VERBOSE=true;            shift ;;
    -h|--help)      usage; exit 0 ;;
    *) log_error "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# ── Validation ─────────────────────────────────────────────────────────────
[[ -z "$AGENT_ID" ]]           && { log_error "--agent is required"; usage; exit 1; }
[[ -z "$DRIVE_FOLDER_TOKEN" ]] && [[ "$SKIP_DRIVE" == "false" ]] && {
  log_error "--drive-folder is required (or use --skip-drive)"; usage; exit 1; }
[[ -z "$BASE_TOKEN" ]]         && [[ "$SKIP_BASE" == "false" ]] && {
  log_error "--base-token is required (or use --skip-base)"; usage; exit 1; }

if ! command -v lark-cli &>/dev/null; then
  log_error "lark-cli not found. Install: npm install -g @larksuite/cli"
  exit 1
fi

# ── Dry-run wrapper ──────────────────────────────────────────────────────────
run_cmd() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "  ${YELLOW}[dry-run]${RESET} $*"
  else
    [[ "$VERBOSE" == "true" ]] && echo -e "  ${BLUE}[exec]${RESET} $*"
    "$@"
  fi
}

create_drive_folder() {
  local parent_token="$1"
  local folder_name="$2"
  lark-cli drive files create_folder \
    --data "{\"folder_token\":\"${parent_token}\",\"name\":\"${folder_name}\"}" \
    --jq '.token // .file.token // .data.token' 2>/dev/null || echo ""
}

upload_drive_file() {
  local folder_token="$1"
  local file_path="$2"
  local file_name="$3"
  lark-cli drive +upload \
    --folder-token "$folder_token" \
    --file "$file_path" \
    --name "$file_name" &>/dev/null
}

create_base_field() {
  local table_id="$1"
  local field_name="$2"
  local field_type="${3:-text}"
  lark-cli base +field-create \
    --base-token "$BASE_TOKEN" \
    --table-id "$table_id" \
    --json "{\"name\":\"${field_name}\",\"type\":\"${field_type}\"}" >/dev/null 2>&1 || true
}

# ── Generate template files ────────────────────────────────────────────────
_render_soul_template() {
  local agent_id="$1"
  local today
  today=$(date +%Y-%m-%d)
  cat <<EOF
# SOUL — Agent '${agent_id}' Identity

## Basic Info
- Agent ID: ${agent_id}
- Created: ${today}
- Model: claude-sonnet-4-6

## Role and Principles
- Assist with office and back-office tasks through Lark
- Principle of least privilege: only execute necessary operations
- Log all executed operations to Lark Base (agent_logs)
- Confirm via Lark IM before executing when uncertain
- Prioritize user privacy and data security above all else

## Initial Permission Scopes
- Read: drive:drive:readonly, docs:doc:readonly, base:record:readonly
- Write: im:message:send_as_bot (notifications only)
- Requires approval: drive:file:create, base:record:created, approval:approval:write

## References
- USER.md   : user profile
- MEMORY.md : long-term memory and ongoing tasks
EOF
}

_render_user_template() {
  local agent_id="$1"
  local today
  today=$(date +%Y-%m-%d)
  cat <<EOF
# USER — User Profile (${agent_id})

Last updated: ${today}

## Basic Info
- Name: (please configure)
- Language: English
- Timezone: UTC
- Lark User ID: (please configure)

## Preferences and Work Style
- Present summaries as bullet points
- Always confirm before executing operations that require approval
- Create reports in English

## Related Channels
- Notification chat_id: (set in larc init)
- Approval flow: (please configure)
EOF
}

_render_memory_template() {
  local agent_id="$1"
  local today
  today=$(date +%Y-%m-%d)
  cat <<EOF
# MEMORY — Long-term Memory (${agent_id})

Last updated: ${today}

## Key Context
(memories accumulate here; sync with: larc memory push)

## Ongoing Tasks
(in-progress tasks are recorded here)

## Important Past Decisions
(significant decisions and config changes are recorded here)

## Errors and Cautions
(recurring mistakes and watch-outs are recorded here)
EOF
}

_render_daily_memory_template() {
  local agent_id="$1"
  local today
  today=$(date +%Y-%m-%d)
  cat <<EOF
# Daily Context — ${today}

## Agent
- ${agent_id}

## Priority Tasks
- (fetched from Lark Project)

## Notes
(none)

## Carry-over Items
(none)
EOF
}

# ── PHASE 1: Create Drive folder structure ────────────────────────────────────
setup_drive() {
  log_head "PHASE 1: Create Lark Drive workspace folder"

  local workspace_folder_token=""
  local memory_folder_token=""

  # 1-1. Create agent-${AGENT_ID} folder
  log_step "Creating agent-${AGENT_ID} folder..."
  if [[ "$DRY_RUN" == "false" ]]; then
    workspace_folder_token=$(create_drive_folder "$DRIVE_FOLDER_TOKEN" "agent-${AGENT_ID}")

    if [[ -z "$workspace_folder_token" ]]; then
      log_warn "Folder creation failed. Using existing folder."
      workspace_folder_token="$DRIVE_FOLDER_TOKEN"
    else
      log_ok "Workspace folder created: $workspace_folder_token"
    fi
  else
    echo -e "  ${YELLOW}[dry-run]${RESET} lark-cli drive files create_folder --data '{\"folder_token\":\"$DRIVE_FOLDER_TOKEN\",\"name\":\"agent-${AGENT_ID}\"}'"
    workspace_folder_token="<workspace_folder_token>"
  fi

  # 1-2. Create memory/ subfolder
  log_step "Creating memory/ subfolder..."
  if [[ "$DRY_RUN" == "false" ]]; then
    memory_folder_token=$(create_drive_folder "${workspace_folder_token}" "memory")

    if [[ -n "$memory_folder_token" ]]; then
      log_ok "memory/ folder created: $memory_folder_token"
    else
      log_warn "memory/ folder creation skipped"
    fi
  else
    echo -e "  ${YELLOW}[dry-run]${RESET} lark-cli drive files create_folder --data '{\"folder_token\":\"<workspace_folder_token>\",\"name\":\"memory\"}'"
  fi

  # 1-3. Upload template files
  log_head "PHASE 1b: Upload template files"

  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf '$tmpdir'" EXIT

  # Generate and upload SOUL.md
  log_step "Generating and uploading SOUL.md..."
  _render_soul_template "$AGENT_ID" > "$tmpdir/SOUL.md"
  if [[ "$DRY_RUN" == "false" ]]; then
    if upload_drive_file "${workspace_folder_token}" "$tmpdir/SOUL.md" "SOUL.md"; then
      log_ok "SOUL.md uploaded"
    else
      log_warn "SOUL.md upload failed (check Drive permissions)"
    fi
  else
    echo -e "  ${YELLOW}[dry-run]${RESET} lark-cli drive +upload --folder-token <workspace_folder_token> --file SOUL.md --name SOUL.md"
  fi

  # Generate and upload USER.md
  log_step "Generating and uploading USER.md..."
  _render_user_template "$AGENT_ID" > "$tmpdir/USER.md"
  if [[ "$DRY_RUN" == "false" ]]; then
    if upload_drive_file "${workspace_folder_token}" "$tmpdir/USER.md" "USER.md"; then
      log_ok "USER.md uploaded"
    else
      log_warn "USER.md upload failed"
    fi
  else
    echo -e "  ${YELLOW}[dry-run]${RESET} lark-cli drive +upload --folder-token <workspace_folder_token> --file USER.md --name USER.md"
  fi

  # Generate and upload MEMORY.md
  log_step "Generating and uploading MEMORY.md..."
  _render_memory_template "$AGENT_ID" > "$tmpdir/MEMORY.md"
  if [[ "$DRY_RUN" == "false" ]]; then
    if upload_drive_file "${workspace_folder_token}" "$tmpdir/MEMORY.md" "MEMORY.md"; then
      log_ok "MEMORY.md uploaded"
    else
      log_warn "MEMORY.md upload failed"
    fi
  else
    echo -e "  ${YELLOW}[dry-run]${RESET} lark-cli drive +upload --folder-token <workspace_folder_token> --file MEMORY.md --name MEMORY.md"
  fi

  # Generate and upload daily memory file
  log_step "Generating and uploading memory/$(date +%Y-%m-%d).md..."
  _render_daily_memory_template "$AGENT_ID" > "$tmpdir/$(date +%Y-%m-%d).md"
  if [[ "$DRY_RUN" == "false" ]]; then
    if [[ -n "$memory_folder_token" ]] && upload_drive_file "${memory_folder_token}" "$tmpdir/$(date +%Y-%m-%d).md" "$(date +%Y-%m-%d).md"; then
      log_ok "Daily memory file uploaded"
    else
      log_warn "Daily memory file upload failed"
    fi
  else
    echo -e "  ${YELLOW}[dry-run]${RESET} lark-cli drive +upload --folder-token <memory_folder_token> --file $(date +%Y-%m-%d).md --name $(date +%Y-%m-%d).md"
  fi

  # Also save locally to template directory
  if [[ "$DRY_RUN" == "false" ]]; then
    local local_tmpl="$TEMPLATE_DIR/${AGENT_ID}"
    mkdir -p "$local_tmpl/memory"
    cp "$tmpdir/SOUL.md"   "$local_tmpl/SOUL.md"
    cp "$tmpdir/USER.md"   "$local_tmpl/USER.md"
    cp "$tmpdir/MEMORY.md" "$local_tmpl/MEMORY.md"
    cp "$tmpdir/$(date +%Y-%m-%d).md" "$local_tmpl/memory/$(date +%Y-%m-%d).md"
    log_ok "Local templates saved: $local_tmpl"
  else
    log_info "Skipping local template save (dry-run mode)"
  fi

  # Export for use in later phases
  WORKSPACE_FOLDER_TOKEN="$workspace_folder_token"
  MEMORY_FOLDER_TOKEN="$memory_folder_token"
}

# ── PHASE 2: Auto-create Lark Base tables ─────────────────────────────────────
setup_base() {
  log_head "PHASE 2: Auto-create Lark Base tables"

  # ─────────────────────────────────────────────────────────────
  # Table creation helper: creates table only if it doesn't exist
  # Args: <table_name> <field_spec...>
  # ─────────────────────────────────────────────────────────────
  _create_table_if_missing() {
    local table_name="$1"
    shift
    local fields=("$@")

    log_step "Checking ${table_name} table..."

    if [[ "$DRY_RUN" == "true" ]]; then
      echo -e "  ${YELLOW}[dry-run]${RESET} lark-cli base +table-create --base-token $BASE_TOKEN --name ${table_name}"
      return 0
    fi

    # Check if table already exists
    local existing_id
    existing_id=$(lark-cli base +table-list \
      --base-token "$BASE_TOKEN" \
      --jq ".items[] | select(.name == \"${table_name}\") | .table_id" \
      2>/dev/null | head -1 || echo "")

    if [[ -n "$existing_id" ]]; then
      log_warn "  ${table_name} already exists (table_id: $existing_id) — skipping"
      return 0
    fi

    # Create table
    local table_id
    table_id=$(lark-cli base +table-create \
      --base-token "$BASE_TOKEN" \
      --name "${table_name}" \
      --jq '.table.table_id // .table_id' 2>/dev/null || echo "")

    if [[ -n "$table_id" ]]; then
      local field_spec
      for field_spec in "${fields[@]}"; do
        local field_name="${field_spec%%:*}"
        local field_type="${field_spec#*:}"
        create_base_field "$table_id" "$field_name" "$field_type"
      done
      log_ok "  ${table_name} table created: $table_id"
    else
      log_warn "  ${table_name} table creation failed (check permissions)"
    fi
  }

  # 2-1. agents_registry table
  _create_table_if_missing "agents_registry" \
    "agent_id:text" "name:text" "model:text" "workspace:text" "chat_id:text" \
    "drive_folder:text" "base_token:text" "status:text" "profile:text" \
    "registered_at:text" "last_active_at:text"

  # 2-2. agent_memory table
  _create_table_if_missing "agent_memory" \
    "date:text" "content:text" "agent_id:text" "created_at:text" "updated_at:text"

  # 2-3. agent_heartbeat table
  _create_table_if_missing "agent_heartbeat" \
    "agent_id:text" "status:text" "message:text" "session_id:text" "lark_connected:text" \
    "drive_ok:text" "base_ok:text" "last_task:text" "error_count:number" \
    "timestamp:text" "notes:text"

  # 2-4. agent_logs table
  _create_table_if_missing "agent_logs" \
    "agent_id:text" "event:text" "action:text" "target:text" "status:text" \
    "scopes_used:text" "user_id:text" "session_id:text" "timestamp:text" "detail:text"
}

# ── PHASE 3: Register initial record in agents_registry ─────────────────────
register_agent() {
  log_head "PHASE 3: Register agent in agents_registry"

  local today
  today=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "  ${YELLOW}[dry-run]${RESET} lark-cli base +record-upsert --base-token $BASE_TOKEN --table-id agents_registry ..."
    return 0
  fi

  _create_table_if_missing "agents_registry" \
    "agent_id:text" "name:text" "model:text" "workspace:text" "chat_id:text" \
    "drive_folder:text" "base_token:text" "status:text" "profile:text" \
    "registered_at:text" "last_active_at:text" >/dev/null

  # Check if already registered
  local existing
  existing=$(lark-cli base +record-list \
    --base-token "$BASE_TOKEN" \
    --table-id "agents_registry" \
    --jq ".items[] | select(.fields.agent_id == \"${AGENT_ID}\") | .record_id" \
    2>/dev/null | head -1 || echo "")

  if [[ -n "$existing" ]]; then
    log_warn "Agent '${AGENT_ID}' is already registered (record_id: $existing) — skipping"
    return
  fi

  local workspace_token="${WORKSPACE_FOLDER_TOKEN:-$DRIVE_FOLDER_TOKEN}"

  lark-cli base +record-upsert \
    --base-token "$BASE_TOKEN" \
    --table-id "agents_registry" \
    --json "{
      \"agent_id\":      \"${AGENT_ID}\",
      \"name\":          \"${AGENT_ID} agent\",
      \"model\":         \"claude-sonnet-4-6\",
      \"workspace\":     \"Lark Drive agent-${AGENT_ID}\",
      \"drive_folder\":  \"${workspace_token}\",
      \"base_token\":    \"${BASE_TOKEN}\",
      \"status\":        \"initializing\",
      \"profile\":       \"readonly\",
      \"registered_at\": \"${today}\",
      \"last_active_at\": \"${today}\"
    }" &>/dev/null && log_ok "Agent '${AGENT_ID}' registered in agents_registry" \
    || log_warn "Failed to register in agents_registry"
}

# ── PHASE 4: Print summary ───────────────────────────────────────────────────
print_summary() {
  log_head "Setup complete"

  echo ""
  echo -e "${BOLD}Agent ID:${RESET}         $AGENT_ID"
  if [[ "$SKIP_DRIVE" == "false" ]]; then
    echo -e "${BOLD}Drive folder:${RESET}     ${WORKSPACE_FOLDER_TOKEN:-$DRIVE_FOLDER_TOKEN}"
  fi
  if [[ "$SKIP_BASE" == "false" ]]; then
    echo -e "${BOLD}Base app_token:${RESET}   $BASE_TOKEN"
    echo -e "${BOLD}Tables created:${RESET}"
    echo -e "    - agents_registry"
    echo -e "    - agent_memory"
    echo -e "    - agent_heartbeat"
    echo -e "    - agent_logs"
  fi
  echo ""
  echo -e "${BOLD}Next steps:${RESET}"
  echo -e "  1. ${CYAN}larc init${RESET}  — configure tokens in CLI"
  echo -e "     LARC_DRIVE_FOLDER_TOKEN=${WORKSPACE_FOLDER_TOKEN:-$DRIVE_FOLDER_TOKEN}"
  echo -e "     LARC_BASE_APP_TOKEN=$BASE_TOKEN"
  echo ""
  echo -e "  2. ${CYAN}larc bootstrap --agent $AGENT_ID${RESET}  — load context from Lark"
  echo ""
  echo -e "  3. ${CYAN}larc auth check${RESET}  — verify current permission state"
  echo ""
  if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "  ${YELLOW}Note: --dry-run mode — no actual changes were made${RESET}"
    echo ""
  fi
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
  echo ""
  echo -e "${BOLD}${CYAN}=== larc setup-workspace v0.1.0 ===${RESET}"
  echo -e "Agent: ${BOLD}${AGENT_ID}${RESET}"
  [[ "$DRY_RUN" == "true" ]] && echo -e "${YELLOW}[DRY RUN — no changes will be made]${RESET}"
  echo ""

  WORKSPACE_FOLDER_TOKEN=""
  MEMORY_FOLDER_TOKEN=""

  if [[ "$SKIP_DRIVE" == "false" ]]; then
    setup_drive
  else
    log_warn "Skipping Drive setup (--skip-drive)"
    WORKSPACE_FOLDER_TOKEN="$DRIVE_FOLDER_TOKEN"
  fi

  if [[ "$SKIP_BASE" == "false" ]]; then
    setup_base
    register_agent
  else
    log_warn "Skipping Base table creation (--skip-base)"
  fi

  print_summary
}

main "$@"
