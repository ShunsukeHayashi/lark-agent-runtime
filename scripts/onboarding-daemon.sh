#!/usr/bin/env bash
# =============================================================================
# Onboarding Daemon — Lark CRM オンボーディング自動化
# =============================================================================
set -euo pipefail

BASE_TOKEN="${LARC_CRM_BASE_TOKEN:-Zpl6bfi0uaoRBosu4KPjrWROpwh}"
TABLE="contacts"
OWNER_OPEN_ID="ou_a832c0fb41861056c9dc0d9789c69b88"
NOTIFY_CHAT_ID="${LARC_IM_CHAT_ID:-oc_50b4b99a03d290c8e368a3d84cdc01d7}"
LOG_PREFIX="[onboarding-daemon]"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_PREFIX $*"; }
err() { log "ERROR: $*" >&2; }

TMPFILE=$(mktemp /tmp/onboarding-XXXXXX.json)
trap 'rm -f "$TMPFILE"' EXIT

# ---------------------------------------------------------------------------
# Step 1: Find contacts in stage "01.グループ作成依頼中"
# ---------------------------------------------------------------------------
log "Querying contacts ..."
lark-cli base +record-list \
  --base-token "$BASE_TOKEN" \
  --table-id "$TABLE" > "$TMPFILE" 2>&1

PENDING=$(python3 /dev/stdin << 'PY' "$TMPFILE"
import sys, json

with open(sys.argv[1]) as f:
    d = json.load(f)

dd = d['data']
record_ids = dd['record_id_list']
field_names = dd['fields']
data_rows   = dd['data']

fn2col = {name: i for i, name in enumerate(field_names)}
stage_col = fn2col.get('オンボーディングステージ')
name_col  = fn2col.get('名前')
oid_col   = fn2col.get('open_id')
chat_col  = fn2col.get('オンボーディングチャット_ID')

for i, row in enumerate(data_rows):
    stage_raw = row[stage_col] if stage_col is not None else []
    stage_val = stage_raw[0] if isinstance(stage_raw, list) and stage_raw else (stage_raw or '')
    if stage_val == '01.グループ作成依頼中':
        chat_raw = row[chat_col] if chat_col is not None else ''
        chat_val = chat_raw[0] if isinstance(chat_raw, list) and chat_raw else (chat_raw or '')
        print(json.dumps({
            'record_id': record_ids[i],
            'name': row[name_col] if name_col is not None else '',
            'open_id': row[oid_col] if oid_col is not None else '',
            'chat_id': chat_val,
        }, ensure_ascii=False))
PY
)

if [ -z "$PENDING" ]; then
  log "No contacts in 01.グループ作成依頼中 — nothing to do."
  exit 0
fi

COUNT=$(echo "$PENDING" | wc -l | tr -d ' ')
log "Found $COUNT contact(s) to process."

# ---------------------------------------------------------------------------
# Process each pending contact
# ---------------------------------------------------------------------------
echo "$PENDING" | while IFS= read -r contact_json; do
  RECORD_ID=$(echo "$contact_json" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d['record_id'])")
  NAME=$(echo "$contact_json"      | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d['name'])")
  OPEN_ID=$(echo "$contact_json"   | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d['open_id'])")
  EXISTING_CHAT=$(echo "$contact_json" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d['chat_id'])")

  log "Processing: $NAME ($RECORD_ID)"

  # -------------------------------------------------------------------------
  # Step 2: Create Lark group (skip if already created)
  # -------------------------------------------------------------------------
  if [ -n "$EXISTING_CHAT" ]; then
    log "  Group already exists: $EXISTING_CHAT"
    CHAT_ID="$EXISTING_CHAT"
  else
    log "  Creating group chat for $NAME ..."
    GROUP_JSON=$(lark-cli im +chat-create \
      --as bot \
      --name "みやび × $NAME" \
      --type private \
      --owner "$OWNER_OPEN_ID" \
      --users "$OPEN_ID" \
      --set-bot-manager 2>&1)

    if echo "$GROUP_JSON" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); exit(0 if d.get('ok') else 1)" 2>/dev/null; then
      CHAT_ID=$(echo "$GROUP_JSON" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d['data']['chat_id'])")
      log "  Group created: $CHAT_ID"

      # Save chat_id + advance to stage 02
      lark-cli base +record-upsert \
        --base-token "$BASE_TOKEN" \
        --table-id "$TABLE" \
        --record-id "$RECORD_ID" \
        --json "{\"オンボーディングチャット_ID\":\"$CHAT_ID\",\"オンボーディングステージ\":\"02.グループ作成済\"}" > /dev/null 2>&1 && \
        log "  Stage → 02.グループ作成済" || err "  Stage 02 update failed"
    else
      ERR=$(echo "$GROUP_JSON" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('error',{}).get('message','unknown'))" 2>/dev/null || echo "$GROUP_JSON")
      err "  Group creation failed: $ERR"
      lark-cli im +messages-send --as bot --chat-id "$NOTIFY_CHAT_ID" \
        --text "⚠️ オンボーディング失敗: $NAME のグループ作成に失敗\nエラー: $ERR" > /dev/null 2>&1 || true
      continue
    fi
  fi

  # -------------------------------------------------------------------------
  # Step 3: Send welcome message → stage 03
  # -------------------------------------------------------------------------
  log "  Sending welcome message ..."
  WELCOME="はじめまして！みやびの林 駿甫です。\n\nこのグループでは、AIとビジネスに関するご相談・サポートを行います。\n\nまずは現状のお困りごとや、AIで解決したいことを教えていただけますか？"

  SEND_JSON=$(lark-cli im +messages-send \
    --as bot \
    --chat-id "$CHAT_ID" \
    --text "$WELCOME" 2>&1)

  if echo "$SEND_JSON" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); exit(0 if d.get('ok') else 1)" 2>/dev/null; then
    log "  Welcome sent OK"
    NOW_MS=$(python3 -c "import time; print(int(time.time()*1000))")
    lark-cli base +record-upsert \
      --base-token "$BASE_TOKEN" \
      --table-id "$TABLE" \
      --record-id "$RECORD_ID" \
      --json "{\"オンボーディングステージ\":\"03.ウェルカム送信済\",\"オンボーディング開始日時\":$NOW_MS}" > /dev/null 2>&1 && \
      log "  Stage → 03.ウェルカム送信済" || err "  Stage 03 update failed"

    lark-cli im +messages-send --as bot --chat-id "$NOTIFY_CHAT_ID" \
      --text "✅ オンボーディング完了: $NAME\nグループ: $CHAT_ID\nステージ: 03.ウェルカム送信済" > /dev/null 2>&1 || true
  else
    ERR=$(echo "$SEND_JSON" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('error',{}).get('message','unknown'))" 2>/dev/null || echo "$SEND_JSON")
    err "  Welcome message failed: $ERR"
    lark-cli im +messages-send --as bot --chat-id "$NOTIFY_CHAT_ID" \
      --text "⚠️ ウェルカム送信失敗: $NAME ($CHAT_ID)\nエラー: $ERR" > /dev/null 2>&1 || true
  fi

done

log "Done."
