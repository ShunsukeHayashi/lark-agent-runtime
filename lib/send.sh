#!/usr/bin/env bash
# lib/send.sh — Send messages to Lark IM
# Lark equivalent of: openclaw agent --agent main --json -m "..."

cmd_send() {
  local message="${1:-}"
  local agent_id="main"
  local chat_id="${LARC_IM_CHAT_ID:-}"

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent)  agent_id="$2"; shift 2 ;;
      --chat)   chat_id="$2"; shift 2 ;;
      *)        message="$1"; shift ;;
    esac
  done

  # Read from stdin if no message
  if [[ -z "$message" ]] && ! [[ -t 0 ]]; then
    message=$(cat)
  fi

  [[ -z "$message" ]] && {
    echo "Usage: larc send \"<message>\" [--agent <id>] [--chat <chat_id>]"
    echo "  Equivalent to: openclaw agent --agent main --json -m"
    return 1
  }

  log_head "send → agent '$agent_id'"

  # Resolve chat_id (fetch agent config from Base)
  if [[ -z "$chat_id" ]] && [[ -n "$LARC_BASE_APP_TOKEN" ]]; then
    chat_id=$(_resolve_agent_chat_id "$agent_id")
  fi

  [[ -z "$chat_id" ]] && {
    log_error "chat_id not set. Set LARC_IM_CHAT_ID or specify --chat"
    return 1
  }

  # Send message
  local timestamp
  timestamp=$(date +%Y-%m-%dT%H:%M:%S)
  local full_message="[larc → ${agent_id}] ${timestamp}

${message}"

  local run_id
  run_id=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || date +%s)

  lark-cli im messages send \
    --chat-id "$chat_id" \
    --msg-type "text" \
    --content "{\"text\": $(echo "$full_message" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')}" \
    &>/dev/null && {
    log_ok "Message sent"
    echo "Agent run started: ${run_id:0:8}-$(echo "$run_id" | tr -dc 'a-f0-9' | head -c4)-$(date +%s | tail -c4)"
  } || {
    log_error "Send failed"
    return 1
  }
}

_resolve_agent_chat_id() {
  local agent_id="$1"
  lark-cli base +record-list \
    --base-token "$LARC_BASE_APP_TOKEN" \
    --table-id "agents_registry" \
    --jq ".items[] | select(.fields.agent_id == \"${agent_id}\") | .fields.chat_id" \
    2>/dev/null | head -1 || echo ""
}
