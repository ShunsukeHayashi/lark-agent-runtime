#!/usr/bin/env bash
# lib/heartbeat.sh — Record/read system state in Lark Base
# Manages OpenClaw HEARTBEAT.md in Lark Base

cmd_heartbeat() {
  local action="${1:-read}"; shift || true
  case "$action" in
    update|write) _heartbeat_update "$@" ;;
    read|show)    _heartbeat_read "$@" ;;
    *)            _heartbeat_read "$@" ;;
  esac
}

_heartbeat_update() {
  local agent_id="${1:-main}"
  local status="${2:-active}"
  local message="${3:-}"

  log_head "heartbeat update — '$agent_id'"

  [[ -z "$LARC_BASE_APP_TOKEN" ]] && {
    # Fallback to local
    local ws="$LARC_CACHE/workspace/$agent_id"
    mkdir -p "$ws"
    cat > "$ws/HEARTBEAT.md" <<EOF
# HEARTBEAT — ${agent_id}
Last updated: $(date +%Y-%m-%dT%H:%M:%S)
Status: ${status}
Message: ${message:-(none)}
EOF
    log_ok "Written locally: $ws/HEARTBEAT.md"
    return
  }

  local table_id
  table_id=$(_get_or_create_heartbeat_table)

  lark-cli base +record-upsert \
    --base-token "$LARC_BASE_APP_TOKEN" \
    --table-id "$table_id" \
    --json "{
      \"agent_id\": \"${agent_id}\",
      \"status\": \"${status}\",
      \"message\": \"${message}\",
      \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
    }" &>/dev/null && log_ok "Heartbeat recorded"
}

_heartbeat_read() {
  local agent_id="${1:-main}"
  log_head "heartbeat — state of '$agent_id'"

  # Check local cache first
  local ws="$LARC_CACHE/workspace/$agent_id"
  [[ -f "$ws/HEARTBEAT.md" ]] && cat "$ws/HEARTBEAT.md" && return

  [[ -z "$LARC_BASE_APP_TOKEN" ]] && {
    log_warn "No HEARTBEAT.md and no Base config"
    return
  }

  local table_id
  table_id=$(_get_or_create_heartbeat_table)

  lark-cli base +record-list \
    --base-token "$LARC_BASE_APP_TOKEN" \
    --table-id "$table_id" \
    --jq ".items | sort_by(.fields.timestamp) | reverse | .[0:5]" \
    2>/dev/null || log_warn "No records found"
}

_get_or_create_heartbeat_table() {
  local table_id
  table_id=$(lark-cli base +table-list \
    --base-token "$LARC_BASE_APP_TOKEN" \
    --jq '.items[] | select(.name == "agent_heartbeat") | .table_id' \
    2>/dev/null | head -1 || echo "")

  if [[ -z "$table_id" ]]; then
    table_id=$(lark-cli base +table-create \
      --base-token "$LARC_BASE_APP_TOKEN" \
      --name "agent_heartbeat" \
      --jq '.table.table_id // .table_id' 2>/dev/null || echo "")
    [[ -n "$table_id" ]] && {
      lark-cli base +field-create --base-token "$LARC_BASE_APP_TOKEN" --table-id "$table_id" --json '{"name":"agent_id","type":"text"}' >/dev/null 2>&1 || true
      lark-cli base +field-create --base-token "$LARC_BASE_APP_TOKEN" --table-id "$table_id" --json '{"name":"status","type":"text"}' >/dev/null 2>&1 || true
      lark-cli base +field-create --base-token "$LARC_BASE_APP_TOKEN" --table-id "$table_id" --json '{"name":"message","type":"text"}' >/dev/null 2>&1 || true
      lark-cli base +field-create --base-token "$LARC_BASE_APP_TOKEN" --table-id "$table_id" --json '{"name":"timestamp","type":"text"}' >/dev/null 2>&1 || true
    }
  fi
  echo "$table_id"
}
