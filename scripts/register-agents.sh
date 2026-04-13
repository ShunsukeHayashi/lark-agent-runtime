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

python3 - "$FILE_PATH" "$DRY_RUN" "$ROOT_DIR" <<'PY'
import sys, json
import yaml

path, dry_run_flag, root_dir = sys.argv[1], sys.argv[2], sys.argv[3]
dry_run = dry_run_flag == "true"

with open(path, "r", encoding="utf-8") as fh:
    data = yaml.safe_load(fh) or {}

agents = data.get("agents")
if not isinstance(agents, list):
    raise SystemExit("[register-agents] error: 'agents' must be a list in YAML")

import subprocess, os, shlex

larc_bin = os.path.join(root_dir, "bin", "larc")

for index, agent in enumerate(agents, start=1):
    if not isinstance(agent, dict):
        raise SystemExit(f"[register-agents] error: agents[{index}] must be a mapping")

    agent_id   = str(agent.get("id", "")).strip()
    name       = str(agent.get("name", "")).strip()
    model      = str(agent.get("model", "claude-sonnet-4-6")).strip()
    workspace  = str(agent.get("workspace", "")).strip()
    chat_id    = str(agent.get("chat_id", "")).strip()
    scopes_raw = agent.get("scopes") or []
    scopes     = ",".join(str(s).strip() for s in scopes_raw if str(s).strip())

    if not agent_id or not name:
        raise SystemExit(f"[register-agents] error: agents[{index}] requires id and name")

    print(f"\n[register-agents] agent {index}/{len(agents)}: {agent_id}")

    cmd = [larc_bin, "agent", "register", "--id", agent_id, "--name", name,
           "--model", model]
    if workspace:
        cmd += ["--workspace", workspace]
    if chat_id:
        cmd += ["--chat", chat_id]
    if scopes:
        print(f"[register-agents]   scopes: {scopes}")
        cmd += ["--scopes", scopes]

    if dry_run:
        print("[register-agents] dry-run: " + " ".join(shlex.quote(c) for c in cmd))
    else:
        result = subprocess.run(cmd, capture_output=False)
        if result.returncode != 0:
            print(f"[register-agents] warning: agent '{agent_id}' returned exit {result.returncode}")

print("\n[register-agents] done")
PY

echo ""
echo "[register-agents] done"
