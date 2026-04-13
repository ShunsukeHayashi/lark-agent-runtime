#!/usr/bin/env bash
# scripts/register-agents.sh — batch registration from YAML

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

FILE_PATH="agents.yaml"
DRY_RUN=false

usage() {
  cat <<EOF
Usage: scripts/register-agents.sh [options]

Options:
  --file <path>      YAML file to load (default: agents.yaml)
  --dry-run          Print commands without executing them
  --help             Show this help

YAML format:
  agents:
    - id: office-assistant
      name: Office Assistant
      model: claude-sonnet-4-6
      workspace: general
      chat_id: oc_xxx
      scopes:
        - docs:doc:readonly
        - im:message:send_as_bot

Notes:
  - Required keys: id, name
  - Optional keys: model, workspace, chat_id, scopes
  - scopes are currently informational only and are not written by larc agent register
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file) FILE_PATH="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *)
      echo "[register-agents] unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -f "$FILE_PATH" ]]; then
  echo "[register-agents] file not found: $FILE_PATH" >&2
  exit 1
fi

echo "[register-agents] source: $FILE_PATH"
echo "[register-agents] mode: $([[ "$DRY_RUN" == "true" ]] && echo dry-run || echo apply)"

python3 - "$FILE_PATH" <<'PY' | while IFS= read -r row; do
import sys
import json
import yaml

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as fh:
    data = yaml.safe_load(fh) or {}

agents = data.get("agents")
if not isinstance(agents, list):
    raise SystemExit("agents must be a list")

for index, agent in enumerate(agents, start=1):
    if not isinstance(agent, dict):
        raise SystemExit(f"agents[{index}] must be a mapping")
    agent_id = str(agent.get("id", "")).strip()
    name = str(agent.get("name", "")).strip()
    if not agent_id or not name:
        raise SystemExit(f"agents[{index}] requires id and name")
    model = str(agent.get("model", "")).strip()
    workspace = str(agent.get("workspace", "")).strip()
    chat_id = str(agent.get("chat_id", "")).strip()
    scopes = agent.get("scopes") or []
    if isinstance(scopes, list):
        scopes = ",".join(str(item).strip() for item in scopes if str(item).strip())
    else:
        scopes = str(scopes).strip()
    print(json.dumps({
        "id": agent_id,
        "name": name,
        "model": model,
        "workspace": workspace,
        "chat_id": chat_id,
        "scopes": scopes,
    }, ensure_ascii=False))
PY
  agent_id=$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read())["id"])' <<<"$row")
  name=$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read())["name"])' <<<"$row")
  model=$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read())["model"])' <<<"$row")
  workspace=$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read())["workspace"])' <<<"$row")
  chat_id=$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read())["chat_id"])' <<<"$row")
  scopes=$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read())["scopes"])' <<<"$row")

  echo ""
  echo "[register-agents] agent: $agent_id"

  cmd=(bin/larc agent register --id "$agent_id" --name "$name")
  [[ -n "$model" ]] && cmd+=(--model "$model")
  [[ -n "$workspace" ]] && cmd+=(--workspace "$workspace")
  [[ -n "$chat_id" ]] && cmd+=(--chat "$chat_id")

  if [[ -n "$scopes" ]]; then
    echo "[register-agents] note: scopes are informational for now -> $scopes"
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    printf '[register-agents] dry-run:'
    printf ' %q' "${cmd[@]}"
    printf '\n'
  else
    "${cmd[@]}"
  fi
done

echo ""
echo "[register-agents] done"
