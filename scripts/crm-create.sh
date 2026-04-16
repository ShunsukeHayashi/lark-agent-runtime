#!/usr/bin/env bash
# =============================================================================
# crm-create — CRM record creation with auto 連番 + date assignment
# =============================================================================
# Usage:
#   crm-create contact  --name "山田太郎" [--open-id ou_xxx] [--tag "既存顧客"] [--source "SNS"]
#   crm-create company  --name "株式会社ABC" [--scale "01.1〜10名"] [--industry "IT"]
#   crm-create deal     --name "AIコンサル契約" [--contact "山田太郎"] [--stage "01.見込み"] [--amount 500000]
#   crm-create activity --title "初回ヒアリング" --contact "山田太郎" [--type "ヒアリング"] [--date "2026-04-16"]
#   crm-create score    --contact "山田太郎" [--open-id ou_xxx] [--score 70]
# =============================================================================
set -euo pipefail

BASE_TOKEN="${LARC_CRM_BASE_TOKEN:-Zpl6bfi0uaoRBosu4KPjrWROpwh}"
CMD="${1:-}"
shift || true

log() { echo "[crm-create] $*" >&2; }
die() { echo "[crm-create] ERROR: $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Get next 連番 for a table
# ---------------------------------------------------------------------------
next_seq() {
  local table="$1"
  local result
  result=$(lark-cli base +record-list \
    --base-token "$BASE_TOKEN" \
    --table-id "$table" 2>&1)

  python3 - "$table" << 'PY'
import sys, json

table = sys.argv[1]
raw = sys.stdin.read()

# Read from parent process via stdin pipe
import subprocess
import os

# Re-run since we need the data
proc = subprocess.run(
    ['lark-cli','base','+record-list','--base-token',
     os.environ.get('LARC_CRM_BASE_TOKEN','Zpl6bfi0uaoRBosu4KPjrWROpwh'),
     '--table-id', table],
    capture_output=True, text=True
)
d = json.loads(proc.stdout)
dd = d['data']
field_names = dd['fields']
fn2col = {name: i for i, name in enumerate(field_names)}
data_rows = dd['data']

seq_col = fn2col.get('連番')
vals = []
for row in data_rows:
    if seq_col is not None:
        v = row[seq_col]
        if v:
            sv = v[0] if isinstance(v, list) else v
            try:
                vals.append(int(str(sv)))
            except ValueError:
                pass

max_seq = max(vals, default=0)
print(f"{max_seq + 1:03d}")
PY
}

# ---------------------------------------------------------------------------
# Epoch ms helper
# ---------------------------------------------------------------------------
now_ms() { python3 -c "import time; print(int(time.time()*1000))"; }
date_ms() {
  # Convert "YYYY-MM-DD" to epoch ms
  python3 -c "import datetime, time; print(int(datetime.datetime.strptime('$1','%Y-%m-%d').timestamp()*1000))"
}

# ---------------------------------------------------------------------------
# Parse key=value args
# ---------------------------------------------------------------------------
declare -A OPTS
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)     OPTS[name]="$2"; shift 2;;
    --open-id)  OPTS[open_id]="$2"; shift 2;;
    --tag)      OPTS[tag]="$2"; shift 2;;
    --source)   OPTS[source]="$2"; shift 2;;
    --scale)    OPTS[scale]="$2"; shift 2;;
    --industry) OPTS[industry]="$2"; shift 2;;
    --stage)    OPTS[stage]="$2"; shift 2;;
    --amount)   OPTS[amount]="$2"; shift 2;;
    --contact)  OPTS[contact]="$2"; shift 2;;
    --title)    OPTS[title]="$2"; shift 2;;
    --type)     OPTS[type]="$2"; shift 2;;
    --date)     OPTS[date]="$2"; shift 2;;
    --score)    OPTS[score]="$2"; shift 2;;
    --note)     OPTS[note]="$2"; shift 2;;
    *) die "Unknown option: $1";;
  esac
done

# ---------------------------------------------------------------------------
# Subcommand dispatch
# ---------------------------------------------------------------------------
case "$CMD" in

  contact|cnt)
    NAME="${OPTS[name]:-}" ; [[ -n "$NAME" ]] || die "--name is required"
    SEQ=$(next_seq contacts)
    TODAY_MS=$(now_ms)
    PAYLOAD=$(python3 - << PYEOF
import json, os
p = {
    "名前": "$NAME",
    "連番": "$SEQ",
    "初回接触日": $TODAY_MS,
}
if "${OPTS[open_id]:-}": p["open_id"] = "${OPTS[open_id]:-}"
if "${OPTS[tag]:-}":     p["タグ"] = "${OPTS[tag]:-}"
if "${OPTS[source]:-}":  p["流入元"] = "${OPTS[source]:-}"
print(json.dumps(p, ensure_ascii=False))
PYEOF
)
    log "Creating contact: $NAME (連番=$SEQ)"
    lark-cli base +record-upsert \
      --base-token "$BASE_TOKEN" \
      --table-id contacts \
      --json "$PAYLOAD"
    ;;

  company|org)
    NAME="${OPTS[name]:-}" ; [[ -n "$NAME" ]] || die "--name is required"
    SEQ=$(next_seq companies)
    TODAY_MS=$(now_ms)
    PAYLOAD=$(python3 - << PYEOF
import json
p = {
    "会社名": "$NAME",
    "連番": "$SEQ",
    "初回接触日": $TODAY_MS,
}
if "${OPTS[scale]:-}":    p["規模"] = "${OPTS[scale]:-}"
if "${OPTS[industry]:-}": p["業種"] = "${OPTS[industry]:-}"
print(json.dumps(p, ensure_ascii=False))
PYEOF
)
    log "Creating company: $NAME (連番=$SEQ)"
    lark-cli base +record-upsert \
      --base-token "$BASE_TOKEN" \
      --table-id companies \
      --json "$PAYLOAD"
    ;;

  deal)
    NAME="${OPTS[name]:-}" ; [[ -n "$NAME" ]] || die "--name is required"
    SEQ=$(next_seq deals)
    TODAY_MS=$(now_ms)
    PAYLOAD=$(python3 - << PYEOF
import json
p = {
    "案件名": "$NAME",
    "連番": "$SEQ",
    "初回接触日": $TODAY_MS,
}
if "${OPTS[contact]:-}": p["関連コンタクト"] = "${OPTS[contact]:-}"
if "${OPTS[stage]:-}":   p["ステージ"] = "${OPTS[stage]:-}"
if "${OPTS[amount]:-}":  p["金額"] = int("${OPTS[amount]:-0}")
print(json.dumps(p, ensure_ascii=False))
PYEOF
)
    log "Creating deal: $NAME (連番=$SEQ)"
    lark-cli base +record-upsert \
      --base-token "$BASE_TOKEN" \
      --table-id deals \
      --json "$PAYLOAD"
    ;;

  activity|act)
    TITLE="${OPTS[title]:-}" ; [[ -n "$TITLE" ]] || die "--title is required"
    SEQ=$(next_seq activities)
    DATE_MS="${OPTS[date]:-}"
    [[ -n "$DATE_MS" ]] && DATE_MS=$(date_ms "$DATE_MS") || DATE_MS=$(now_ms)
    PAYLOAD=$(python3 - << PYEOF
import json
p = {
    "タイトル": "$TITLE",
    "連番": "$SEQ",
    "日時": $DATE_MS,
}
if "${OPTS[contact]:-}": p["コンタクト名"] = "${OPTS[contact]:-}"
if "${OPTS[type]:-}":    p["活動種別"] = "${OPTS[type]:-}"
if "${OPTS[note]:-}":    p["内容サマリー"] = "${OPTS[note]:-}"
print(json.dumps(p, ensure_ascii=False))
PYEOF
)
    log "Creating activity: $TITLE (連番=$SEQ)"
    lark-cli base +record-upsert \
      --base-token "$BASE_TOKEN" \
      --table-id activities \
      --json "$PAYLOAD"
    ;;

  score|lead)
    CONTACT="${OPTS[contact]:-}" ; [[ -n "$CONTACT" ]] || die "--contact is required"
    SEQ=$(next_seq lead_scores)
    TODAY_MS=$(now_ms)
    PAYLOAD=$(python3 - << PYEOF
import json
p = {
    "コンタクト名": "$CONTACT",
    "連番": "$SEQ",
    "評価日": $TODAY_MS,
}
if "${OPTS[open_id]:-}": p["open_id"] = "${OPTS[open_id]:-}"
if "${OPTS[score]:-}":   p["スコア"] = int("${OPTS[score]:-0}")
print(json.dumps(p, ensure_ascii=False))
PYEOF
)
    log "Creating lead score for: $CONTACT (連番=$SEQ)"
    lark-cli base +record-upsert \
      --base-token "$BASE_TOKEN" \
      --table-id lead_scores \
      --json "$PAYLOAD"
    ;;

  ""|help)
    echo "Usage: crm-create <contact|company|deal|activity|score> [options]"
    echo ""
    echo "  contact  --name NAME [--open-id ou_xxx] [--tag TAG] [--source SOURCE]"
    echo "  company  --name NAME [--scale SCALE] [--industry INDUSTRY]"
    echo "  deal     --name NAME [--contact NAME] [--stage STAGE] [--amount N]"
    echo "  activity --title TITLE --contact NAME [--type TYPE] [--date YYYY-MM-DD] [--note NOTE]"
    echo "  score    --contact NAME [--open-id ou_xxx] [--score N]"
    ;;

  *)
    die "Unknown command: $CMD. Use: contact|company|deal|activity|score"
    ;;
esac
