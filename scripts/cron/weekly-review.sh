#!/bin/bash
# 週次レビュースクリプト — 毎週月曜実行（推奨: 09:05）
# Task OS: Meegle P0/P1取得 → git log比較 → 昇降格提案 → 音声報告
#
# 設置先: ~/.larc/scripts/weekly-review.sh (install.sh がコピー)
# launchd/cron で定期実行

set -e
trap 'echo "[weekly-review] エラー終了: exit $?" >&2' ERR

source ~/.larc/config.env 2>/dev/null || true
export PATH="$HOME/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

LOG_TAG="[weekly-review]"
echo "$LOG_TAG $(date '+%Y-%m-%d %H:%M') 開始"

# ── Task OS 設定読み込み ─────────────────────────────────────────────
MEEGLE_PROJECT_KEY="${LARC_MEEGLE_PROJECT_KEY:-}"
MEEGLE_SPACE_NAME="${LARC_MEEGLE_SPACE_NAME:-製品開発}"
MEEGLE_TYPE_NAME="${LARC_MEEGLE_TYPE_NAME:-開発要件}"
DEMOTE_DAYS="${LARC_MEEGLE_DEMOTE_THRESHOLD_DAYS:-14}"
PROMOTE_DAYS="${LARC_MEEGLE_PROMOTE_THRESHOLD_DAYS:-7}"

if [[ -z "$MEEGLE_PROJECT_KEY" ]]; then
  echo "$LOG_TAG LARC_MEEGLE_PROJECT_KEY 未設定 — Meegle連携スキップ"
fi

# ── Phase 1: Meegle P0/P1 カウント取得 ──────────────────────────────
REVIEW_SUMMARY=""
if [[ -n "$MEEGLE_PROJECT_KEY" ]] && command -v lark-cli &>/dev/null; then
  _count_by_priority() {
    local priority="$1"
    lark-cli project search-by-mql \
      --project-key "$MEEGLE_PROJECT_KEY" \
      --mql "SELECT \`name\` FROM \`${MEEGLE_SPACE_NAME}\`.\`${MEEGLE_TYPE_NAME}\` WHERE \`priority\` = '${priority}'" \
      2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('list', [{}])[0].get('count', 0))
except: print(0)
" 2>/dev/null || echo "0"
  }

  P0_COUNT=$(_count_by_priority "P0")
  P1_COUNT=$(_count_by_priority "P1")

  REVIEW_SUMMARY="週次レビューです。P0が${P0_COUNT}件、P1が${P1_COUNT}件。"
  REVIEW_SUMMARY+="降格基準: ${DEMOTE_DAYS}日未活動、昇格基準: ${PROMOTE_DAYS}日以内にコミット。"
  REVIEW_SUMMARY+="詳細レビューをLARCに委託します。"
fi

# ── 音声読み上げ ─────────────────────────────────────────────────────
if command -v announce &>/dev/null && [[ -n "$REVIEW_SUMMARY" ]]; then
  echo "$LOG_TAG $REVIEW_SUMMARY"
  announce "$REVIEW_SUMMARY" --home 2>/dev/null &
fi

# ── Phase 2: LARC enqueue で詳細レビューを委託 ──────────────────────
if command -v larc &>/dev/null; then
  larc ingress enqueue \
    --text "週次レビュー（自動）: Meegle P0・P1全件を取得。各プロジェクトのdescriptionに記載のローカルパスで git log -1 を実行し最終コミット日を確認。ルール: (1) P0で${DEMOTE_DAYS}日以上未活動→P1降格提案、(2) P1で直近${PROMOTE_DAYS}日以内にコミット→P0昇格提案。変更提案をLark IMに送信。昇降格の実行はGuardian承認後にのみ行う。" \
    --agent main \
    --source weekly-cron
fi

echo "$LOG_TAG 完了"
