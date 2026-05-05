#!/usr/bin/env bash
# scripts/auth-router-check.sh — replay auth router regression cases (#57)

set -euo pipefail

export PYTHONIOENCODING="${PYTHONIOENCODING:-utf-8}"
export PYTHONUTF8="${PYTHONUTF8:-1}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

LARC_BIN="${LARC_BIN:-bin/larc}"

usage() {
  cat <<EOF
Usage: scripts/auth-router-check.sh [--case N] [--list]

Options:
  --case N   Run only the specified case number
  --list     Print available cases and exit
  --help     Show this help
EOF
}

selected_case=""
list_only=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --case) selected_case="$2"; shift 2 ;;
    --list) list_only=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *)
      echo "[auth-router-check] unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

# case_id|label|expected_decision|expected_scopes_csv_or_dash|prompt
cases=(
  "1|en bot notification|BOT|im:message:send_as_bot|send IM notification to team"
  "2|en calendar create|USER|calendar:calendar.event:create|create calendar event for tomorrow"
  "3|jp calendar create|USER|calendar:calendar.event:create|カレンダー予定を作成"
  "4|jp meeting register|USER|calendar:calendar.event:create|会議予定を登録"
  "5|jp schedule setup|USER|calendar:calendar.event:create|面談をスケジュール設定"
  "6|en external dm|BLOCKED|-|send DM to external user"
  "7|jp external tenant dm|BLOCKED|-|外部テナントの取引先にDM送信"
  "8|jp guest message|BLOCKED|-|ゲストにメッセージ送信"
  "9|en approval submit|USER|approval:instance:write|submit expense approval request"
  "10|jp approval submit|USER|approval:instance:write|承認申請を作成"
  "11|jp approval task|USER|approval:task:write|請求書発行の承認をお願いします"
  "12|en approval task|USER|approval:task:write|approve approval task"
  "13|jp drive list|BOT|drive:drive.metadata:readonly|Drive ファイル一覧取得"
  "14|jp drive read|BOT|drive:drive.metadata:readonly|Drive ファイルを読み取り"
  "15|en drive list|BOT|drive:drive.metadata:readonly|list files in Drive"
  "16|jp drive upload|BOT|drive:file:create|Drive ファイルをアップロード"
  "17|en drive upload|BOT|drive:file:create|upload file to drive"
  "18|jp wiki read|BOT|wiki:space:read|Wiki ノード読み取り"
  "19|en wiki read|BOT|wiki:space:read|read wiki page for onboarding"
  "20|jp internal message|BOT|im:message:send_as_bot|チームに通知送信"
)

if [[ "$list_only" == "true" ]]; then
  for entry in "${cases[@]}"; do
    IFS="|" read -r case_id label expected_decision expected_scopes prompt <<<"$entry"
    printf '%s\t%s\t%s\t%s\t%s\n' "$case_id" "$label" "$expected_decision" "$expected_scopes" "$prompt"
  done
  exit 0
fi

parse_router_output() {
  python3 -c '
import re, sys
text = re.sub(r"\x1b\[[0-9;]*m", "", sys.stdin.read())
decision = ""
scopes = []
capture = False
for line in text.splitlines():
    if "Auth decision:" in line:
        decision = line.split("Auth decision:", 1)[1].strip().split()[0]
    if "Minimum required scopes:" in line:
        capture = "(none inferred)" not in line
        continue
    if capture:
        stripped = line.strip()
        if not stripped or stripped.startswith("To authorize:"):
            capture = False
            continue
        if re.fullmatch(r"[A-Za-z0-9:._-]+", stripped):
            scopes.append(stripped)
print(decision)
print(",".join(scopes))
'
}

compare_scopes() {
  local expected_csv="$1"
  local actual_csv="$2"
  python3 - "$expected_csv" "$actual_csv" <<'PY'
import sys
expected_raw, actual_raw = sys.argv[1], sys.argv[2]
expected = set() if expected_raw == "-" else {x for x in expected_raw.split(",") if x}
actual = {x for x in actual_raw.split(",") if x}
if expected != actual:
    print(f"expected scopes={sorted(expected)} actual={sorted(actual)}", file=sys.stderr)
    sys.exit(1)
PY
}

pass_count=0
fail_count=0

for entry in "${cases[@]}"; do
  IFS="|" read -r case_id label expected_decision expected_scopes prompt <<<"$entry"
  if [[ -n "$selected_case" && "$selected_case" != "$case_id" ]]; then
    continue
  fi

  output=$("$LARC_BIN" auth router "$prompt")
  parsed=$(printf '%s\n' "$output" | parse_router_output)
  actual_decision=$(sed -n '1p' <<<"$parsed")
  actual_scopes=$(sed -n '2p' <<<"$parsed")

  if [[ "$actual_decision" == "$expected_decision" ]] && compare_scopes "$expected_scopes" "$actual_scopes"; then
    printf 'PASS  [%s] %s\n' "$case_id" "$label"
    pass_count=$((pass_count + 1))
  else
    printf 'FAIL  [%s] %s\n' "$case_id" "$label" >&2
    printf '  prompt: %s\n' "$prompt" >&2
    printf '  expected: %s / %s\n' "$expected_decision" "$expected_scopes" >&2
    printf '  actual:   %s / %s\n' "$actual_decision" "${actual_scopes:--}" >&2
    fail_count=$((fail_count + 1))
  fi
done

printf '\nTotal: %d pass / %d fail\n' "$pass_count" "$fail_count"
[[ "$fail_count" -eq 0 ]]
