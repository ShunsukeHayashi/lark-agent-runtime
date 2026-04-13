#!/usr/bin/env bash
# scripts/live-check.sh — ordered live verification for current MVP slice

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

AGENT_ID="main"
CHAT_ID="${LARC_IM_CHAT_ID:-}"
TASK_TITLE="larc live-check $(date +%Y-%m-%d)"
TASK_DUE="+1d"
REGISTER_AGENT=false
REGISTER_AGENT_ID="smoke-agent"
REGISTER_AGENT_NAME="Smoke Agent"
REGISTER_WORKSPACE="Smoke test"

usage() {
  cat <<EOF
Usage: scripts/live-check.sh [options]

Options:
  --agent <id>              Target agent for bootstrap/memory checks (default: main)
  --chat <chat_id>          Send a live test message to this chat_id
  --task-title <title>      Title used for task creation check
  --task-due <expr>         Due value passed to 'larc task create' (default: +1d)
  --register-agent          Also run 'larc agent register' as part of the check
  --register-id <id>        Agent ID for registration check (default: smoke-agent)
  --register-name <name>    Display name for registration check
  --register-workspace <text>
                            Workspace description for registration check
  --help                    Show this help

Environment:
  Requires LARC_DRIVE_FOLDER_TOKEN and LARC_BASE_APP_TOKEN to be configured
  via ~/.larc/config.env or exported in the shell.

Examples:
  scripts/live-check.sh
  scripts/live-check.sh --chat oc_xxx
  scripts/live-check.sh --register-agent --chat oc_xxx
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent) AGENT_ID="$2"; shift 2 ;;
    --chat) CHAT_ID="$2"; shift 2 ;;
    --task-title) TASK_TITLE="$2"; shift 2 ;;
    --task-due) TASK_DUE="$2"; shift 2 ;;
    --register-agent) REGISTER_AGENT=true; shift ;;
    --register-id) REGISTER_AGENT_ID="$2"; shift 2 ;;
    --register-name) REGISTER_AGENT_NAME="$2"; shift 2 ;;
    --register-workspace) REGISTER_WORKSPACE="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *)
      echo "[live] unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -f "$HOME/.larc/config.env" ]]; then
  # shellcheck source=/dev/null
  source "$HOME/.larc/config.env"
fi

CHAT_ID="${CHAT_ID:-${LARC_IM_CHAT_ID:-}}"

require_env() {
  local name="$1"
  local value="${!name:-}"
  if [[ -z "$value" ]]; then
    echo "[live] missing required config: $name" >&2
    echo "[live] run 'larc init' or export $name before retrying" >&2
    exit 1
  fi
}

run_step() {
  local label="$1"
  shift
  echo ""
  echo "[live] $label"
  "$@"
}

require_env "LARC_DRIVE_FOLDER_TOKEN"
require_env "LARC_BASE_APP_TOKEN"

run_step "syntax" bash -n bin/larc
run_step "smoke baseline" scripts/smoke-check.sh
run_step "status" bin/larc status
run_step "auth check" bin/larc auth check
run_step "bootstrap" bin/larc bootstrap --agent "$AGENT_ID" --force
run_step "memory push" bin/larc memory push --agent "$AGENT_ID"
run_step "memory pull" bin/larc memory pull --agent "$AGENT_ID"
run_step "memory list" bin/larc memory list --agent "$AGENT_ID"
run_step "task create" bin/larc task create --title "$TASK_TITLE" --due "$TASK_DUE"

if [[ "$REGISTER_AGENT" == "true" ]]; then
  if [[ -n "$CHAT_ID" ]]; then
    run_step "agent register" \
      bin/larc agent register \
        --id "$REGISTER_AGENT_ID" \
        --name "$REGISTER_AGENT_NAME" \
        --workspace "$REGISTER_WORKSPACE" \
        --chat "$CHAT_ID"
  else
    echo ""
    echo "[live] agent register skipped"
    echo "[live] pass --chat <chat_id> or set LARC_IM_CHAT_ID before using --register-agent"
  fi
fi

if [[ -n "$CHAT_ID" ]]; then
  run_step "send message" \
    bin/larc send "larc live-check $(date +%Y-%m-%dT%H:%M:%S)" \
      --agent "$AGENT_ID" \
      --chat "$CHAT_ID"
else
  echo ""
  echo "[live] send message skipped"
  echo "[live] pass --chat <chat_id> or set LARC_IM_CHAT_ID to include IM verification"
fi

echo ""
echo "[live] OK"
echo "[live] core MVP slice verified for agent: $AGENT_ID"
echo "[live] note: task completion and approval instance creation remain separate checks"
