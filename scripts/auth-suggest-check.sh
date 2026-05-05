#!/usr/bin/env bash
# scripts/auth-suggest-check.sh — replay representative auth-suggest cases

set -euo pipefail

# Ensure Python subprocesses emit UTF-8 on Windows (cp1252 by default) — see #22
export PYTHONIOENCODING="${PYTHONIOENCODING:-utf-8}"
export PYTHONUTF8="${PYTHONUTF8:-1}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

LARC_BIN="${LARC_BIN:-bin/larc}"

usage() {
  cat <<EOF
Usage: scripts/auth-suggest-check.sh [--case N] [--list] [--verify]

Options:
  --case N   Run only the specified case number
  --list     Print the available cases and exit
  --verify   Check the reported scopes against the documented minimum set
  --help     Show this help

Purpose:
  Re-run representative office-task prompts against \`larc auth suggest\`
  so permission-intelligence regressions are easy to spot.
EOF
}

selected_case=""
list_only=false
verify=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --case) selected_case="$2"; shift 2 ;;
    --list) list_only=true; shift ;;
    --verify) verify=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *)
      echo "[auth-suggest-check] unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

# Keep these aligned with docs/auth-suggest-cases.md.
cases=(
  "1|expense report + approval|approval:instance:write,bitable:app|create expense report and request approval"
  "2|read doc + update wiki|docs:document:readonly,wiki:node:write,wiki:space:read|read a document and update the wiki page"
  "3|create crm + follow-up|bitable:app,bitable:app:readonly,contact:user.base:readonly,im:message:send_as_bot|create crm record and send a follow-up message"
  "4|update customer record|bitable:app,bitable:app:readonly,bitable:record|update the customer record after the meeting"
  "5|route expense + notify mgr|approval:instance:write,bitable:app,im:message:send_as_bot|route expense to approval and notify the manager"
  "6|upload to drive + wiki|drive:file:create,wiki:node:write,wiki:space:read|upload the contract file to drive and update the wiki with the key terms"
  "7|crm lead + schedule meeting|bitable:app,bitable:app:readonly,calendar:calendar.event:create,contact:user.base:readonly|create a lead record and schedule a follow-up meeting"
  "8|attendance + timesheet|attendance:task:readonly,sheets:spreadsheet|read the attendance records and generate a timesheet report"
  "9|Japanese invoice approval|approval:task:write|請求書発行の承認をお願いします"
)

if [[ "$list_only" == "true" ]]; then
  for entry in "${cases[@]}"; do
    IFS="|" read -r case_id label expected_scopes prompt <<<"$entry"
    printf '%s\t%s\t%s\t%s\n' "$case_id" "$label" "$expected_scopes" "$prompt"
  done
  exit 0
fi

run_case() {
  local case_id="$1"
  local label="$2"
  local expected_scopes_csv="$3"
  local prompt="$4"
  local output=""
  local actual_scopes=""
  local missing_scopes=()
  local extra_scopes=()

  echo ""
  echo "=== Case ${case_id}: ${label} ==="
  echo "Prompt: ${prompt}"
  output=$("$LARC_BIN" auth suggest "$prompt")
  printf '%s\n' "$output"

  if [[ "$verify" == "true" ]]; then
    actual_scopes=$(printf '%s\n' "$output" | python3 -c '
import re, sys
scopes = []
capture = False
for line in sys.stdin:
    if "Required scopes" in line or "Required minimum scopes" in line:
        capture = True
        continue
    if capture:
        if line.startswith("  Authority:"):
            break
        m = re.match(r"\s+([A-Za-z0-9:._-]+)\s+\(←", line)
        if m:
            scopes.append(m.group(1))
print("\n".join(scopes))
')
    if [[ -z "$actual_scopes" ]]; then
      echo "[auth-suggest-check] case ${case_id}: could not parse scopes" >&2
      return 1
    fi

    IFS=',' read -r -a expected_scope_arr <<<"$expected_scopes_csv"
    mapfile -t actual_scope_arr <<<"$actual_scopes"

    for scope in "${expected_scope_arr[@]}"; do
      if ! printf '%s\n' "${actual_scope_arr[@]}" | grep -Fqx -- "$scope"; then
        missing_scopes+=("$scope")
      fi
    done

    for scope in "${actual_scope_arr[@]}"; do
      [[ -z "$scope" ]] && continue
      if ! printf '%s\n' "${expected_scope_arr[@]}" | grep -Fqx -- "$scope"; then
        extra_scopes+=("$scope")
      fi
    done

    if [[ ${#missing_scopes[@]} -gt 0 ]]; then
      echo "[auth-suggest-check] case ${case_id}: missing scopes: ${missing_scopes[*]}" >&2
      return 1
    fi

    if [[ ${#extra_scopes[@]} -gt 0 ]]; then
      echo "[auth-suggest-check] case ${case_id}: PASS with extra scopes: ${extra_scopes[*]}"
    else
      echo "[auth-suggest-check] case ${case_id}: PASS"
    fi
  fi
}

for entry in "${cases[@]}"; do
  IFS="|" read -r case_id label expected_scopes prompt <<<"$entry"
  if [[ -n "$selected_case" && "$selected_case" != "$case_id" ]]; then
    continue
  fi
  run_case "$case_id" "$label" "$expected_scopes" "$prompt"
done

echo ""
echo "[auth-suggest-check] done"
