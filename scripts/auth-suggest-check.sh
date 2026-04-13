#!/usr/bin/env bash
# scripts/auth-suggest-check.sh — replay representative auth-suggest cases

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

LARC_BIN="${LARC_BIN:-bin/larc}"

usage() {
  cat <<EOF
Usage: scripts/auth-suggest-check.sh [--case N] [--list] [--verify]

Options:
  --case N   Run only the specified case number
  --list     Print the available cases and exit
  --verify   Check the reported scope count against the documented minimum
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
  "1|expense report + approval|2|create expense report and request approval"
  "2|read doc + update wiki|3|read a document and update the wiki page"
  "3|create crm + follow-up|5|create crm record and send a follow-up message"
  "4|update customer record|1|update the customer record after the meeting"
  "5|route expense + notify mgr|3|route expense to approval and notify the manager"
  "6|upload to drive + wiki|3|upload the contract file to drive and update the wiki with the key terms"
  "7|crm lead + schedule meeting|5|create a lead record and schedule a follow-up meeting"
  "8|attendance + timesheet|2|read the attendance records and generate a timesheet report"
)

if [[ "$list_only" == "true" ]]; then
  for entry in "${cases[@]}"; do
    IFS="|" read -r case_id label expected_count prompt <<<"$entry"
    printf '%s\t%s\t%s\t%s\n' "$case_id" "$label" "$expected_count" "$prompt"
  done
  exit 0
fi

run_case() {
  local case_id="$1"
  local label="$2"
  local expected_count="$3"
  local prompt="$4"
  local output=""
  local actual_count=""

  echo ""
  echo "=== Case ${case_id}: ${label} ==="
  echo "Prompt: ${prompt}"
  output=$("$LARC_BIN" auth suggest "$prompt")
  printf '%s\n' "$output"

  if [[ "$verify" == "true" ]]; then
    actual_count=$(printf '%s\n' "$output" | sed -n 's/.*Required scopes (\([0-9][0-9]*\)).*/\1/p' | head -1)
    if [[ -z "$actual_count" ]]; then
      echo "[auth-suggest-check] case ${case_id}: could not parse scope count" >&2
      return 1
    fi
    if [[ "$actual_count" != "$expected_count" ]]; then
      echo "[auth-suggest-check] case ${case_id}: expected ${expected_count} scopes, got ${actual_count}" >&2
      return 1
    fi
    echo "[auth-suggest-check] case ${case_id}: PASS (${actual_count} scopes)"
  fi
}

for entry in "${cases[@]}"; do
  IFS="|" read -r case_id label expected_count prompt <<<"$entry"
  if [[ -n "$selected_case" && "$selected_case" != "$case_id" ]]; then
    continue
  fi
  run_case "$case_id" "$label" "$expected_count" "$prompt"
done

echo ""
echo "[auth-suggest-check] done"
