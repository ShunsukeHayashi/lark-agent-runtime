#!/bin/bash
# 月次レビュースクリプト — 毎月28日実行（推奨: 09:03）
# Task OS: Meegle全ストーリーの棚卸し → P2含む全件サマリー
#
# 設置先: ~/.larc/scripts/monthly-review.sh (install.sh がコピー)

set -e
trap 'echo "[monthly-review] エラー終了: exit $?" >&2' ERR

source ~/.larc/config.env 2>/dev/null || true
export PATH="$HOME/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

LOG_TAG="[monthly-review]"
echo "$LOG_TAG $(date '+%Y-%m-%d %H:%M') 開始"

MEEGLE_PROJECT_KEY="${LARC_MEEGLE_PROJECT_KEY:-}"

if command -v larc &>/dev/null; then
  larc ingress enqueue \
    --text "月次レビュー（自動）: Meegle P0・P1・P2全件を取得し棚卸しを実施。(1) 3ヶ月以上未活動のP2→終了/アーカイブ提案、(2) P0/P1/P2の配分バランス確認、(3) 戦略カテゴリ（技術基盤/プロダクト/発信/経営基盤）ごとの進捗サマリーを作成。結果をLark IMに送信。" \
    --agent main \
    --source monthly-cron
fi

if command -v announce &>/dev/null; then
  announce "月次レビューをLARCに委託しました。結果はLark IMに送信されます。" --home 2>/dev/null &
fi

echo "$LOG_TAG 完了"
