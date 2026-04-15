#!/usr/bin/env bash
# lib/memory.sh — Bidirectional sync between Lark Base and local memory
# Manages OpenClaw memory/*.md / MEMORY.md in Lark Base

cmd_memory() {
  local action="${1:-}"; shift || true
  case "$action" in
    pull) _memory_pull "$@" ;;
    push) _memory_push "$@" ;;
    list) _memory_list "$@" ;;
    search) _memory_search "$@" ;;
    *)
      echo "Usage: larc memory <pull|push|list|search>"
      echo "  pull [--agent ID] [--date YYYY-MM-DD]  Lark Base → local"
      echo "  push [--agent ID] [--date YYYY-MM-DD]  local → Lark Base"
      echo "  list [--agent ID]                     list memory entries"
      echo "  search --query <text> [--agent ID] [--days N]  search memory entries"
      ;;
  esac
}

_memory_pull() {
  local date
  date="$(date +%Y-%m-%d)"
  local agent_id="main"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --date) date="$2"; shift 2 ;;
      --agent) agent_id="$2"; shift 2 ;;
      *) date="$1"; shift ;;
    esac
  done

  log_head "memory pull — fetching memory from Lark Base (${agent_id} / $date)"

  [[ -z "$LARC_BASE_APP_TOKEN" ]] && {
    log_error "LARC_BASE_APP_TOKEN is not set"
    return 1
  }

  local table_id
  table_id=$(_get_or_create_memory_table)

  # Fetch record for the target date
  local raw_response
  raw_response=$(lark-cli base +record-list \
    --base-token "$LARC_BASE_APP_TOKEN" \
    --table-id "$table_id" \
    2>/dev/null || echo "")

  local ws="$LARC_CACHE/workspace/$agent_id"
  mkdir -p "$ws/memory"

  # Parse the response: data.data (rows), data.fields (field names), data.record_id_list
  local content
  content=$(echo "$raw_response" | python3 -c "
import sys, json
resp = json.load(sys.stdin)
d = resp.get('data', {})
rows = d.get('data', [])
fields = d.get('fields', [])
target_date = '${date}'
target_agent = '${agent_id}'
# Find date/agent_id/content column indices
try:
    date_idx = fields.index('date')
    agent_idx = fields.index('agent_id')
    content_idx = fields.index('content')
except ValueError:
    sys.exit(0)
for row in rows:
    if len(row) > max(date_idx, agent_idx, content_idx):
        if str(row[date_idx]) == target_date and str(row[agent_idx]) == target_agent:
            print(row[content_idx] or '')
            sys.exit(0)
" 2>/dev/null || echo "")

  if [[ -z "$content" ]]; then
    log_warn "No memory record found in Lark Base for ${date}"
    return 0
  fi

  # Restore content as-is
  local output="$ws/memory/${date}.md"
  echo "$content" > "$output"

  log_ok "Saved: $output"
}

_memory_push() {
  local date
  date="$(date +%Y-%m-%d)"
  local agent_id="main"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --date) date="$2"; shift 2 ;;
      --agent) agent_id="$2"; shift 2 ;;
      *) date="$1"; shift ;;
    esac
  done
  local ws="$LARC_CACHE/workspace/$agent_id"
  local source_file="$ws/memory/${date}.md"

  log_head "memory push — writing local memory to Lark Base (${agent_id} / $date)"

  [[ ! -f "$source_file" ]] && {
    log_error "Source file not found: $source_file"
    return 1
  }
  [[ -z "$LARC_BASE_APP_TOKEN" ]] && {
    log_error "LARC_BASE_APP_TOKEN is not set"
    return 1
  }

  local content
  content=$(cat "$source_file")

  local table_id
  table_id=$(_get_or_create_memory_table)

  # Search for existing record
  local existing_id
  existing_id=$(lark-cli base +record-list \
    --base-token "$LARC_BASE_APP_TOKEN" \
    --table-id "$table_id" \
    --jq ".items[] | select(.fields.date == \"${date}\" and .fields.agent_id == \"${agent_id}\") | .record_id" \
    2>/dev/null | head -1 || echo "")

  if [[ -n "$existing_id" ]]; then
    lark-cli base +record-upsert \
      --base-token "$LARC_BASE_APP_TOKEN" \
      --table-id "$table_id" \
      --record-id "$existing_id" \
      --json "{\"date\": \"${date}\", \"content\": $(echo "$content" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))'), \"agent_id\": \"${agent_id}\", \"updated_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
      &>/dev/null && log_ok "Updated (record: $existing_id)" || log_warn "Update failed"
  else
    lark-cli base +record-upsert \
      --base-token "$LARC_BASE_APP_TOKEN" \
      --table-id "$table_id" \
      --json "{\"date\": \"${date}\", \"content\": $(echo "$content" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))'), \"agent_id\": \"${agent_id}\", \"created_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
      &>/dev/null && log_ok "Created" || log_warn "Create failed"
  fi
}

_memory_list() {
  local agent_id="main"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent) agent_id="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  log_head "memory list — memory entries in Lark Base (${agent_id})"
  [[ -z "$LARC_BASE_APP_TOKEN" ]] && {
    log_error "LARC_BASE_APP_TOKEN is not set"; return 1
  }

  local table_id
  table_id=$(_get_or_create_memory_table)

  lark-cli base +record-list \
    --base-token "$LARC_BASE_APP_TOKEN" \
    --table-id "$table_id" \
    --jq ".items[] | select(.fields.agent_id == \"${agent_id}\") | {date: .fields.date, updated: .fields.updated_at}" \
    2>/dev/null || log_warn "No memory entries found"
}

_memory_search() {
  local agent_id="main"
  local query=""
  local days="30"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent) agent_id="$2"; shift 2 ;;
      --query|-q) query="$2"; shift 2 ;;
      --days) days="$2"; shift 2 ;;
      *) log_warn "Unknown option: $1"; shift ;;
    esac
  done

  [[ -z "$query" ]] && {
    log_error "Usage: larc memory search --query <text> [--agent ID] [--days N]"
    return 1
  }

  log_head "memory search — ${agent_id} / query='${query}' / past ${days} days"
  [[ -z "$LARC_BASE_APP_TOKEN" ]] && {
    log_error "LARC_BASE_APP_TOKEN is not set"; return 1
  }

  local table_id
  table_id=$(_get_or_create_memory_table)

  # Collect all pages into a temp file to avoid argv size limits
  local tmp_file
  tmp_file=$(mktemp /tmp/larc-memory-search.XXXXXX.jsonl)
  local offset=0 has_more=true
  local fields_json=""
  while [[ "$has_more" == "true" ]]; do
    local page
    page=$(lark-cli base +record-list \
      --base-token "$LARC_BASE_APP_TOKEN" \
      --table-id "$table_id" \
      --limit 100 --offset "$offset" \
      2>/dev/null || echo "{}")
    # Extract rows and append; capture fields on first page
    if [[ -z "$fields_json" ]]; then
      fields_json=$(echo "$page" | python3 -c "import json,sys; d=json.load(sys.stdin).get('data',{}); print(json.dumps(d.get('fields',[])))" 2>/dev/null || echo "[]")
    fi
    echo "$page" | python3 -c "
import json,sys
d=json.load(sys.stdin).get('data',{})
for row in d.get('data',[]):
    print(json.dumps(row))
" 2>/dev/null >> "$tmp_file"
    has_more=$(echo "$page" | python3 -c "import json,sys; print(json.load(sys.stdin).get('data',{}).get('has_more','false'))" 2>/dev/null || echo "false")
    offset=$((offset + 100))
  done

  python3 - "$tmp_file" "$fields_json" "$agent_id" "$query" "$days" <<'PY'
import json, sys
from datetime import datetime, timedelta, timezone

tmp_file = sys.argv[1]
fields = json.loads(sys.argv[2])
target_agent = sys.argv[3]
query = sys.argv[4].lower()
days = int(sys.argv[5])

if not fields:
    print("(memory table fields not ready)")
    raise SystemExit(0)

def idx(name):
    try:
        return fields.index(name)
    except ValueError:
        return None

date_idx = idx("date")
agent_idx = idx("agent_id")
content_idx = idx("content")
updated_idx = idx("updated_at")

if None in (date_idx, agent_idx, content_idx):
    print("(memory table fields not ready)")
    raise SystemExit(0)

cutoff = datetime.now(timezone.utc).date() - timedelta(days=days)
matches = []
with open(tmp_file) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        row = json.loads(line)
        if max(date_idx, agent_idx, content_idx) >= len(row):
            continue
        if str(row[agent_idx]) != target_agent:
            continue
        raw_date = str(row[date_idx] or "")
        try:
            row_date = datetime.strptime(raw_date, "%Y-%m-%d").date()
        except ValueError:
            continue
        if row_date < cutoff:
            continue
        content = str(row[content_idx] or "")
        if query not in content.lower():
            continue
        snippet = " ".join(content.strip().split())
        if len(snippet) > 140:
            snippet = snippet[:137] + "..."
        updated = str(row[updated_idx]) if updated_idx is not None and updated_idx < len(row) else "-"
        matches.append((raw_date, updated, snippet))

if not matches:
    print("(no matches)")
    raise SystemExit(0)

for raw_date, updated, snippet in sorted(matches, reverse=True):
    print(f"{raw_date}  updated={updated}")
    print(f"  {snippet}")
PY
  rm -f "$tmp_file"
}

_get_or_create_memory_table() {
  local table_id
  table_id=$(lark-cli base +table-list \
    --base-token "$LARC_BASE_APP_TOKEN" \
    --jq '.data.tables[] | select(.name == "agent_memory") | .id' \
    2>/dev/null | head -1 || echo "")

  if [[ -z "$table_id" ]]; then
    log_info "Creating agent_memory table..."
    table_id=$(lark-cli base +table-create \
      --base-token "$LARC_BASE_APP_TOKEN" \
      --name "agent_memory" \
      --jq '.table.table_id // .table_id' 2>/dev/null || echo "")
    [[ -n "$table_id" ]] && {
      lark-cli base +field-create --base-token "$LARC_BASE_APP_TOKEN" --table-id "$table_id" --json '{"name":"date","type":"text"}' >/dev/null 2>&1 || true
      lark-cli base +field-create --base-token "$LARC_BASE_APP_TOKEN" --table-id "$table_id" --json '{"name":"content","type":"text"}' >/dev/null 2>&1 || true
      lark-cli base +field-create --base-token "$LARC_BASE_APP_TOKEN" --table-id "$table_id" --json '{"name":"agent_id","type":"text"}' >/dev/null 2>&1 || true
      lark-cli base +field-create --base-token "$LARC_BASE_APP_TOKEN" --table-id "$table_id" --json '{"name":"created_at","type":"text"}' >/dev/null 2>&1 || true
      lark-cli base +field-create --base-token "$LARC_BASE_APP_TOKEN" --table-id "$table_id" --json '{"name":"updated_at","type":"text"}' >/dev/null 2>&1 || true
    }

    [[ -z "$table_id" ]] && { log_error "Table creation failed"; return 1; }
    log_ok "agent_memory table created: $table_id"
  fi

  echo "$table_id"
}
