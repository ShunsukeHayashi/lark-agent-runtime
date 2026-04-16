#!/usr/bin/env bash
# lib/agent.sh — Manage OpenClaw-compatible agents on Lark
# Equivalent to openclaw agents list / agents create
#
# A Lark agent consists of:
#   - Lark Bot (IM interaction)
#   - Lark Base records (configuration and state management)
#   - Lark Drive folder (workspace)
#   - lark-cli + larc (execution engine)

cmd_agent() {
  local action="${1:-list}"; shift || true
  case "$action" in
    list)     _agent_list "$@" ;;
    register) _agent_register "$@" ;;
    show)     _agent_show "$@" ;;
    remove)   _agent_remove "$@" ;;
    help|--help|-h) _agent_help ;;
    *) _agent_help; return 1 ;;
  esac
}

# ── Batch registration from YAML ─────────────────────────────────────────────
# Intercept 'larc agent register --from <file>' before _agent_register sees it
_agent_register() {
  # Fast path: check for --from flag before normal parsing
  local yaml_file="" dry_run=false remaining_args=()
  local args=("$@")
  local i=0
  while [[ $i -lt ${#args[@]} ]]; do
    case "${args[$i]}" in
      --from)
        i=$((i+1))
        yaml_file="${args[$i]:-}"
        ;;
      --dry-run)
        dry_run=true
        ;;
      *)
        remaining_args+=("${args[$i]}")
        ;;
    esac
    i=$((i+1))
  done

  if [[ -n "$yaml_file" ]]; then
    [[ ! -f "$yaml_file" ]] && { log_error "File not found: $yaml_file"; return 1; }
    _agent_register_from_yaml "$yaml_file" "$dry_run"
    return $?
  fi
  # Normal single-agent registration
  _agent_register_one "${remaining_args[@]+"${remaining_args[@]}"}"
}
_agent_register_from_yaml() {
  local yaml_file="$1"
  local dry_run="${2:-false}"
  log_head "Batch agent registration from $yaml_file${dry_run:+ (dry-run)}"

  local agents_json
  agents_json=$(python3 - "$yaml_file" <<'PY'
import sys, json
try:
    import yaml
    with open(sys.argv[1]) as f:
        data = yaml.safe_load(f) or {}
except ImportError:
    import re, sys as _sys
    print("[register] pyyaml not found; using regex fallback", file=_sys.stderr)
    with open(sys.argv[1]) as f:
        raw = f.read()
    # Minimal YAML parse: extract id/name/model/workspace/chat_id/scopes blocks
    blocks = re.split(r'\n(?=\s*- id:)', raw)
    agents = []
    for block in blocks:
        id_m = re.search(r'id:\s*(\S+)', block)
        name_m = re.search(r'name:\s*"?([^"\n]+)"?', block)
        if id_m and name_m:
            model_m = re.search(r'model:\s*(\S+)', block)
            ws_m = re.search(r'workspace:\s*(\S+)', block)
            chat_m = re.search(r'chat_id:\s*(\S+)', block)
            scopes = re.findall(r'-\s+([\w:]+)', block)
            agents.append({
                "id": id_m.group(1), "name": name_m.group(1).strip(),
                "model": model_m.group(1) if model_m else "claude-sonnet-4-6",
                "workspace": ws_m.group(1) if ws_m else "",
                "chat_id": chat_m.group(1) if chat_m else "",
                "scopes": scopes,
            })
    data = {"agents": agents}

agents = data.get("agents") or []
print(json.dumps(agents, ensure_ascii=False))
PY
)

  # Emit all agents as one delimited block (one python call total)
  # Use ASCII unit separator \x01 (non-whitespace) so empty fields are not collapsed by bash read
  local all_fields_tsv
  all_fields_tsv=$(echo "$agents_json" | python3 -c "
import json, sys
SEP = '\x01'
agents = json.load(sys.stdin)
for d in agents:
    print(SEP.join([
        d.get('id',''),
        d.get('name',''),
        d.get('model','claude-sonnet-4-6'),
        d.get('workspace',''),
        d.get('chat_id',''),
        ','.join(d.get('scopes',[])),
    ]))
")
  local total ok_count fail_count
  total=$(echo "$all_fields_tsv" | grep -c .)
  ok_count=0; fail_count=0
  local idx=0

  local _orig_ifs="$IFS"
  while IFS=$'\x01' read -r aid aname amodel aworkspace achat ascopes; do
    idx=$((idx+1))

    [[ -z "$aid" || -z "$aname" ]] && { log_warn "Skipping entry $idx: missing id or name"; fail_count=$((fail_count+1)); continue; }

    if [[ "$dry_run" == "true" ]]; then
      log_info "[$idx/$total] dry-run: would register $aid ($aname) model=$amodel"
      [[ -n "$aworkspace" ]] && log_info "          workspace=$aworkspace"
      [[ -n "$achat" ]]      && log_info "          chat_id=$achat"
      [[ -n "$ascopes" ]]    && log_info "          scopes=$ascopes"
      ok_count=$((ok_count+1))
      continue
    fi

    log_info "[$idx/$total] Registering: $aid ($aname)"
    local reg_args=(--id "$aid" --name "$aname" --model "$amodel")
    [[ -n "$aworkspace" ]] && reg_args+=(--workspace "$aworkspace")
    [[ -n "$achat" ]]      && reg_args+=(--chat "$achat")
    [[ -n "$ascopes" ]]    && reg_args+=(--scopes "$ascopes")

    if _agent_register_one "${reg_args[@]}" 2>&1; then
      ok_count=$((ok_count+1))
    else
      log_warn "Registration failed for $aid"
      fail_count=$((fail_count+1))
    fi
  done <<< "$all_fields_tsv"
  IFS="$_orig_ifs"

  echo ""
  log_ok "Batch complete: $ok_count/$total registered, $fail_count failed"
}

_agent_help() {
  cat <<EOF

Usage: larc agent <list|register|show|remove>

  larc agent list
  larc agent register --id <id> --name <name> [--model M] [--workspace W] [--chat oc_xxx] [--scopes s1,s2]
  larc agent register --from <agents.yaml>           Batch register from YAML file
  larc agent register --from <agents.yaml> --dry-run Preview without registering
  larc agent show <agent_id>
  larc agent remove <agent_id>

EOF
}

_agent_list() {
  log_head "Registered agents on Lark"

  [[ -z "$LARC_BASE_APP_TOKEN" ]] && {
    log_warn "LARC_BASE_APP_TOKEN not set — showing from local cache"
    _agent_list_local
    return
  }

  local table_id
  table_id=$(_get_or_create_agents_table)

  echo ""
  printf "%-20s %-25s %-20s %-35s\n" "ID" "Name" "Model" "Scopes"
  printf "%-20s %-25s %-20s %-35s\n" "----" "----" "-----" "------"

  local raw_json
  raw_json=$(lark-cli base +record-list \
    --base-token "$LARC_BASE_APP_TOKEN" \
    --table-id "$table_id" 2>/dev/null || echo "{}")

  echo "$raw_json" | python3 -c "
import sys, json
data = json.load(sys.stdin)
inner = data.get('data', data)
fields = inner.get('fields', [])
rows = inner.get('data', [])
if not fields or not rows:
    print('(no agents registered)')
    sys.exit(0)
def idx(name):
    try: return fields.index(name)
    except ValueError: return None
ai = idx('agent_id'); ni = idx('name'); mi = idx('model'); si = idx('scopes')
# Keep only the last (most recent) record per agent_id
latest = {}
for row in rows:
    def get(i): return str(row[i]) if i is not None and i < len(row) and row[i] else ''
    aid = get(ai)
    if aid:
        latest[aid] = row
for aid, row in latest.items():
    def get(i): return str(row[i]) if i is not None and i < len(row) and row[i] else '-'
    print(f'{aid:<20} {get(ni):<25} {get(mi):<20} {get(si):<35}')
" 2>/dev/null || log_warn "No agents registered"
}

_agent_list_local() {
  local cache_dir="$LARC_CACHE/workspace"
  if [[ -d "$cache_dir" ]]; then
    echo "Agents in local cache:"
    ls "$cache_dir" | while read -r id; do
      echo "  - $id"
    done
  else
    echo "(no agents)"
  fi
}

_agent_register_one() {
  log_head "Register agent"

  local agent_id="" name="" model="" workspace="" chat_id="" scopes=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id|--agent-id) agent_id="$2"; shift 2 ;;
      --name) name="$2"; shift 2 ;;
      --model) model="$2"; shift 2 ;;
      --workspace) workspace="$2"; shift 2 ;;
      --chat|--chat-id) chat_id="$2"; shift 2 ;;
      --scopes) scopes="$2"; shift 2 ;;
      *)
        log_warn "Unknown option: $1"
        shift
        ;;
    esac
  done

  # Only prompt interactively when stdin is a terminal
  if [[ -t 0 ]]; then
    [[ -z "$agent_id" ]] && read -r -p "Agent ID (e.g., office-assistant): " agent_id
    [[ -z "$name" ]] && read -r -p "Display name (e.g., Office Assistant): " name
    [[ -z "$model" ]] && read -r -p "Model (e.g., claude-sonnet-4-6) [Enter for default]: " model
    [[ -z "$workspace" ]] && read -r -p "Workspace description (e.g., back-office tasks): " workspace
    [[ -z "$chat_id" ]] && read -r -p "Notification chat_id (Lark IM, optional): " chat_id
  fi
  model="${model:-claude-sonnet-4-6}"

  [[ -z "$agent_id" ]] && { log_error "agent_id is required"; return 1; }
  [[ -z "$name" ]] && { log_error "name is required"; return 1; }

  # Create agent workspace folder in Drive
  log_info "Creating workspace folder in Lark Drive..."
  local folder_token
  folder_token=$(lark-cli drive files create_folder \
    --data "{\"folder_token\":\"${LARC_DRIVE_FOLDER_TOKEN}\",\"name\":\"agent-${agent_id}\"}" \
    --jq '.token // .file.token // .data.token' 2>/dev/null || echo "")

  if [[ -n "$folder_token" ]]; then
    log_ok "Drive folder created: $folder_token"
  else
    log_warn "Drive folder creation skipped"
  fi

  # Register agent record in Base (update if exists, else create)
  if [[ -n "$LARC_BASE_APP_TOKEN" ]]; then
    local table_id
    table_id=$(_get_or_create_agents_table)

    local record_json
    record_json=$(python3 -c "
import json, sys
print(json.dumps({
    'agent_id':      sys.argv[1],
    'name':          sys.argv[2],
    'model':         sys.argv[3],
    'workspace':     sys.argv[4],
    'chat_id':       sys.argv[5],
    'drive_folder':  sys.argv[6],
    'scopes':        sys.argv[7],
    'status':        'active',
    'registered_at': sys.argv[8],
}))" "$agent_id" "$name" "$model" "$workspace" "$chat_id" "$folder_token" "$scopes" "$(date -u +%Y-%m-%dT%H:%M:%SZ)")

    # Find existing record_id for this agent_id
    local existing_record_id
    existing_record_id=$(lark-cli base +record-list \
      --base-token "$LARC_BASE_APP_TOKEN" \
      --table-id "$table_id" 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
inner = data.get('data', data)
fields = inner.get('fields', [])
rows = inner.get('data', [])
record_ids = inner.get('record_id_list', [])
try:
    ai = fields.index('agent_id')
except ValueError:
    sys.exit(0)
for i, row in enumerate(rows):
    if ai < len(row) and str(row[ai]) == '${agent_id}' and i < len(record_ids):
        print(record_ids[i])
        break
" 2>/dev/null | tail -1 || echo "")

    local upsert_args=(--base-token "$LARC_BASE_APP_TOKEN" --table-id "$table_id" --json "$record_json")
    [[ -n "$existing_record_id" ]] && upsert_args+=(--record-id "$existing_record_id")

    lark-cli base +record-upsert "${upsert_args[@]}" &>/dev/null && log_ok "Agent registered in Lark Base"
  fi

  # Initialize local workspace
  local local_ws="$LARC_CACHE/workspace/${agent_id}"
  mkdir -p "$local_ws/memory"
  _create_agent_soul "$local_ws" "$agent_id" "$name" "$model"

  log_ok "Agent '$agent_id' registered"
  echo ""
  echo -e "${BOLD}Next steps:${RESET}"
  echo "  larc bootstrap --agent ${agent_id}  # load context from Lark"
  echo "  larc send \"Hello\" --agent ${agent_id}  # test message"
}

_create_agent_soul() {
  local ws="$1" agent_id="$2" name="$3" model="$4"
  cat > "$ws/SOUL.md" <<EOF
# SOUL — ${name} (${agent_id})

## Identity
- Agent ID: ${agent_id}
- Display name: ${name}
- Model: ${model}
- Registered: $(date +%Y-%m-%d)

## Role and Principles
- Assist with office and back-office tasks through Lark
- Principle of least privilege: only execute necessary operations
- Log all executed operations to Lark Base
- Confirm via Lark IM before executing when uncertain

## Permission Scopes
- Read: drive:file:readonly, docs:doc:readonly, base:record:readonly
- Write: im:message:send_as_bot (notifications only)
- Requires approval: drive:file:create, base:record:created, approval:*
EOF
}

_agent_show() {
  local agent_id="${1:-main}"
  log_head "Agent details: $agent_id"

  local ws="$LARC_CACHE/workspace/$agent_id"
  if [[ -f "$ws/SOUL.md" ]]; then
    cat "$ws/SOUL.md"
    echo ""
  fi

  if [[ -f "$ws/AGENT_CONTEXT.md" ]]; then
    echo -e "${BOLD}Last bootstrap:${RESET}"
    head -3 "$ws/AGENT_CONTEXT.md"
  fi
}

_agent_remove() {
  local agent_id="${1:-}"
  [[ -z "$agent_id" ]] && { echo "Usage: larc agent remove <agent_id>"; return 1; }

  log_warn "Removing agent '$agent_id'"
  read -r -p "Are you sure? [y/N] " ans
  [[ "$ans" != "y" ]] && { log_info "Aborted"; return 0; }

  # Delete local cache
  rm -rf "$LARC_CACHE/workspace/$agent_id"
  log_ok "Local cache deleted"

  # Delete record from Base
  if [[ -n "$LARC_BASE_APP_TOKEN" ]]; then
    local table_id record_id
    table_id=$(_get_or_create_agents_table)
    record_id=$(lark-cli base +record-list \
      --base-token "$LARC_BASE_APP_TOKEN" \
      --table-id "$table_id" 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
inner = data.get('data', data)
fields = inner.get('fields', [])
rows = inner.get('data', [])
try:
    ai = fields.index('agent_id')
    ri = fields.index('record_id') if 'record_id' in fields else None
except ValueError:
    sys.exit(0)
for row in rows:
    if ai < len(row) and str(row[ai]) == '${agent_id}':
        if ri is not None and ri < len(row):
            print(row[ri])
        break
" 2>/dev/null | head -1 || echo "")

    [[ -n "$record_id" ]] && {
      lark-cli base +record-delete \
        --base-token "$LARC_BASE_APP_TOKEN" \
        --table-id "$table_id" \
        --record-id "$record_id" \
        --yes &>/dev/null
      log_ok "Record deleted from Lark Base"
    }
  fi
}

_get_or_create_agents_table() {
  local table_id
  table_id=$(lark-cli base +table-list \
    --base-token "$LARC_BASE_APP_TOKEN" \
    --jq '.data.tables[] | select(.name == "agents_registry") | .id' \
    2>/dev/null | head -1 || echo "")

  if [[ -z "$table_id" ]]; then
    log_info "Creating agents_registry table..."
    local _create_json _create_err_msg _create_err_hint
    _create_json=$(lark-cli base +table-create \
      --base-token "$LARC_BASE_APP_TOKEN" \
      --name "agents_registry" 2>&1 || true)
    table_id=$(echo "$_create_json" | jq -r '.table.table_id // .table_id // empty' 2>/dev/null)
    if [[ -z "$table_id" || "$table_id" == "null" ]]; then
      _create_err_msg=$(echo  "$_create_json" | jq -r '.error.message // empty' 2>/dev/null)
      _create_err_hint=$(echo "$_create_json" | jq -r '.error.hint // empty'    2>/dev/null)
      log_error "Failed to ensure agents_registry table"
      [[ -n "$_create_err_msg"  ]] && log_error "  reason: $_create_err_msg"
      [[ -n "$_create_err_hint" ]] && log_error "  hint:   $_create_err_hint"
      return 1
    fi
    log_ok "agents_registry table created: $table_id"
  fi

  # Ensure custom fields exist (idempotent — lark-cli ignores duplicates)
  [[ -n "$table_id" ]] && {
    for field_name in agent_id name model workspace chat_id drive_folder base_token scopes status profile registered_at last_active_at; do
      lark-cli base +field-create --base-token "$LARC_BASE_APP_TOKEN" --table-id "$table_id" \
        --json "{\"name\":\"$field_name\",\"type\":\"text\"}" >/dev/null 2>&1 || true
    done
  }
  echo "$table_id"
}
