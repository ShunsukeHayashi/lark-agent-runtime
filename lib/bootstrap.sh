#!/usr/bin/env bash
# lib/bootstrap.sh — Reproduces OpenClaw-compatible disclosure chain from Lark Drive
#
# OpenClaw BOOTSTRAP.md loading order:
#   1. SOUL.md     → Agent identity and principles
#   2. USER.md     → User profile
#   3. memory/YYYY-MM-DD.md → Recent daily context
#   4. MEMORY.md   → Long-term memory
#
# Fetches these from their Lark equivalents and expands into ~/.larc/workspace/<agent_id>/

cmd_bootstrap() {
  local agent_id="main"
  local force=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent) agent_id="$2"; shift 2 ;;
      --force) force=true; shift ;;
      *) log_warn "Unknown option: $1"; shift ;;
    esac
  done

  log_head "bootstrap — loading agent '$agent_id' context from Lark"

  local ws="$LARC_CACHE/workspace/$agent_id"
  mkdir -p "$ws/memory"

  # ── Step 1: Get file list from agent folder in Drive ──────────
  log_info "Fetching file list from Lark Drive..."
  local file_list
  file_list=$(lark-cli drive files list --params "{\"folder_token\":\"${LARC_DRIVE_FOLDER_TOKEN}\"}" \
    --jq '.data.files // []' 2>/dev/null || echo "[]")

  if [[ "$file_list" == "[]" ]]; then
    log_warn "Drive folder empty or inaccessible: $LARC_DRIVE_FOLDER_TOKEN"
    log_info "Initializing local workspace from templates..."
    _bootstrap_from_templates "$ws" "$agent_id"
    return
  fi

  # ── Step 2: Download each disclosure file ────────────────────
  local today
  today=$(date +%Y-%m-%d)
  local yesterday
  yesterday=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d '-1 day' +%Y-%m-%d)

  declare -A disclosure_map=(
    ["SOUL.md"]="$ws/SOUL.md"
    ["USER.md"]="$ws/USER.md"
    ["MEMORY.md"]="$ws/MEMORY.md"
    ["RULES.md"]="$ws/RULES.md"
    ["HEARTBEAT.md"]="$ws/HEARTBEAT.md"
    ["memory/${today}.md"]="$ws/memory/${today}.md"
    ["memory/${yesterday}.md"]="$ws/memory/${yesterday}.md"
  )

  local downloaded=0
  local skipped=0

  local memory_folder_token=""
  memory_folder_token=$(echo "$file_list" | python3 -c "
import sys, json
items = json.load(sys.stdin)
for item in items:
    if item.get('name') == 'memory':
        print(item.get('token', ''))
        break
" 2>/dev/null || echo "")

  local memory_file_list="[]"
  if [[ -n "$memory_folder_token" ]]; then
    memory_file_list=$(lark-cli drive files list --params "{\"folder_token\":\"${memory_folder_token}\"}" \
      --jq '.data.files // []' 2>/dev/null || echo "[]")
  fi

  for filename in "${!disclosure_map[@]}"; do
    local target="${disclosure_map[$filename]}"
    local cache_age=0

    # Cache check
    if [[ -f "$target" ]] && [[ "$force" == "false" ]]; then
      cache_age=$(( $(date +%s) - $(stat -f '%m' "$target" 2>/dev/null || echo 0) ))
      if [[ $cache_age -lt $LARC_CACHE_TTL ]]; then
        skipped=$((skipped + 1))
        continue
      fi
    fi

    # Search for file token in Drive and download
    local base_name
    base_name=$(basename "$filename")
    local source_list="$file_list"
    if [[ "$filename" == memory/* ]]; then
      source_list="$memory_file_list"
    fi
    local file_token
    file_token=$(echo "$source_list" | python3 -c "
import sys, json, os
files = json.load(sys.stdin)
name = '${base_name}'
name_noext = os.path.splitext(name)[0]
for f in files:
    fname = f.get('name','')
    if fname == name or fname == name_noext:
        print(f.get('token',''))
        break
" 2>/dev/null || echo "")

    if [[ -n "$file_token" ]]; then
      mkdir -p "$(dirname "$target")"
      if lark-cli docs +fetch --doc "$file_token" --jq '.data.markdown' > "$target" 2>/dev/null && [[ -s "$target" ]]; then
        log_ok "  ✓ $filename"
        downloaded=$((downloaded + 1))
      else
        log_warn "  ✗ $filename (download failed)"
      fi
    else
      # Try fetching from Wiki
      _try_fetch_from_wiki "$filename" "$target" && downloaded=$((downloaded + 1)) || true
    fi
  done

  log_ok "Done: ${downloaded} downloaded, ${skipped} from cache"
  echo ""

  # ── Step 3: Consolidate as CLAUDE.md equivalent ─────────────────────────────
  _generate_agent_context "$ws" "$agent_id" "$today"
}

# Try fetching from Wiki
_try_fetch_from_wiki() {
  local filename="$1"
  local target="$2"

  [[ -z "$LARC_WIKI_SPACE_ID" ]] && return 1

  local page_title
  page_title=$(basename "$filename" .md)
  local wiki_token
  wiki_token=$(lark-cli wiki nodes list \
    --space-id "$LARC_WIKI_SPACE_ID" \
    --jq ".items[] | select(.title == \"${page_title}\") | .node_token" \
    2>/dev/null | head -1 || echo "")

  [[ -z "$wiki_token" ]] && return 1

  local obj_token
  obj_token=$(lark-cli wiki spaces get_node \
    --params "{\"token\":\"${wiki_token}\"}" \
    --jq '.node.obj_token' 2>/dev/null || echo "")

  [[ -z "$obj_token" ]] && return 1

  mkdir -p "$(dirname "$target")"
  lark-cli docs +fetch --doc "$obj_token" \
    --jq '.content' > "$target" 2>/dev/null && {
    log_ok "  ✓ $filename (Wiki)"
    return 0
  }
  return 1
}

# Initialize workspace from templates (when Drive is empty)
_bootstrap_from_templates() {
  local ws="$1"
  local agent_id="$2"
  local template_dir
  template_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/agent-workspace/templates"

  log_info "Expanding templates: $template_dir → $ws"

  if [[ -d "$template_dir" ]]; then
    cp -r "$template_dir/." "$ws/"
    # Replace agent_id placeholder
    find "$ws" -type f -name "*.md" | while read -r f; do
      sed -i '' "s/{{AGENT_ID}}/${agent_id}/g" "$f" 2>/dev/null || true
      sed -i '' "s/{{DATE}}/$(date +%Y-%m-%d)/g" "$f" 2>/dev/null || true
    done
    log_ok "Templates expanded: $ws"
    log_info "Next step: edit files then run 'larc bootstrap --force' to upload to Lark"
  else
    _create_minimal_workspace "$ws" "$agent_id"
  fi
}

# Generate minimal workspace
_create_minimal_workspace() {
  local ws="$1"
  local agent_id="$2"
  local today
  today=$(date +%Y-%m-%d)

  cat > "$ws/SOUL.md" <<EOF
# SOUL — Agent '${agent_id}' Identity

## Core Principles
- Assist user tasks accurately with minimum required permissions
- Confirm before executing when uncertain
- Always log executed operations

## Role
This agent assists with office and back-office tasks through Lark.
EOF

  cat > "$ws/USER.md" <<EOF
# USER — User Profile

## Basic Info
- Name: (please configure)
- Language: English
- Timezone: UTC

## Preferences and Principles
- (configure after running larc init)
EOF

  cat > "$ws/MEMORY.md" <<EOF
# MEMORY — Long-term Memory

Last updated: ${today}

## Key Context
(memories accumulate here)

## Ongoing Tasks
(in-progress tasks are recorded here)
EOF

  mkdir -p "$ws/memory"
  cat > "$ws/memory/${today}.md" <<EOF
# Daily Context — ${today}

## Today's Priority Tasks
- (auto-fetched from Lark Project)

## Continuing from Last Session
(none)
EOF

  log_ok "Minimal workspace created"
}

# Consolidate agent context into CLAUDE.md format
_generate_agent_context() {
  local ws="$1"
  local agent_id="$2"
  local today="$3"
  local output="$ws/AGENT_CONTEXT.md"

  log_info "Consolidating context → $output"

  {
    echo "# LARC Agent Context — ${agent_id} (${today})"
    echo "<!-- Auto-generated: larc bootstrap $(date +%Y-%m-%dT%H:%M:%S) -->"
    echo ""

    for file in SOUL.md USER.md RULES.md MEMORY.md "memory/${today}.md" HEARTBEAT.md; do
      local path="$ws/$file"
      if [[ -f "$path" ]]; then
        echo "---"
        echo "## [$(basename "$file" .md)]"
        cat "$path"
        echo ""
      fi
    done
  } > "$output"

  log_ok "Context file generated: $output"
  echo ""
  echo -e "${BOLD}To load into agent:${RESET}"
  echo -e "  cat $output"
  echo ""

  # Record bootstrap event to Lark Base (audit log)
  _log_bootstrap_event "$agent_id" "$today"
}

# Log bootstrap event to Lark Base (audit log)
_log_bootstrap_event() {
  local agent_id="$1"
  local today="$2"

  [[ -z "$LARC_BASE_APP_TOKEN" ]] && return

  local table_id
  table_id=$(lark-cli base +table-list \
    --base-token "$LARC_BASE_APP_TOKEN" \
    --jq '.items[] | select(.name == "agent_logs") | .table_id' \
    2>/dev/null | head -1 || echo "")

  [[ -z "$table_id" ]] && return

  lark-cli base +record-upsert \
    --base-token "$LARC_BASE_APP_TOKEN" \
    --table-id "$table_id" \
    --json "{
      \"agent_id\": \"${agent_id}\",
      \"event\": \"bootstrap\",
      \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
      \"date\": \"${today}\"
    }" &>/dev/null || true
}
