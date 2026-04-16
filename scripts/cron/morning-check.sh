#!/bin/bash
# 朝の確認スクリプト — 平日実行（推奨: 09:00-09:30）
# Task OS: Meegle P0を直接取得 → 音声読み上げ → LARC enqueue
#
# 設置先: ~/.larc/scripts/morning-check.sh (install.sh がコピー)
# launchd/cron で定期実行

set -e
trap 'echo "[morning-check] エラー終了: exit $?" >&2' ERR

source ~/.larc/config.env 2>/dev/null || true
export PATH="$HOME/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

LOG_TAG="[morning-check]"
echo "$LOG_TAG $(date '+%Y-%m-%d %H:%M') 開始"

# ── Task OS 設定読み込み ─────────────────────────────────────────────
# agents.yaml の task_os セクションから読み込み、または環境変数で上書き
MEEGLE_PROJECT_KEY="${LARC_MEEGLE_PROJECT_KEY:-}"
MEEGLE_SPACE_NAME="${LARC_MEEGLE_SPACE_NAME:-製品開発}"
MEEGLE_TYPE_NAME="${LARC_MEEGLE_TYPE_NAME:-開発要件}"

if [[ -z "$MEEGLE_PROJECT_KEY" ]]; then
  echo "$LOG_TAG LARC_MEEGLE_PROJECT_KEY 未設定 — Meegle連携スキップ"
fi

# ── Phase 1: Meegle P0 直接取得 ─────────────────────────────────────
P0_SUMMARY=""
if [[ -n "$MEEGLE_PROJECT_KEY" ]] && command -v lark-cli &>/dev/null; then
  P0_JSON=$(lark-cli project search-by-mql \
    --project-key "$MEEGLE_PROJECT_KEY" \
    --mql "SELECT \`name\`, \`work_item_status\` FROM \`${MEEGLE_SPACE_NAME}\`.\`${MEEGLE_TYPE_NAME}\` WHERE \`priority\` = 'P0'" \
    2>/dev/null || echo "")

  if [[ -n "$P0_JSON" ]]; then
    P0_SUMMARY=$(echo "$P0_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    items = []
    for group in data.get('data', {}).values():
        if not isinstance(group, list):
            continue
        for item in group:
            fields = {f['key']: f for f in item.get('moql_field_list', [])}
            name = fields.get('name', {}).get('value', {}).get('string_value', '?')
            status_list = fields.get('work_item_status', {}).get('value', {}).get('key_label_value_list', [])
            status = status_list[0].get('label', '?') if status_list else '?'
            items.append(f'{name}({status})')
    if items:
        print(f'今日のP0は{len(items)}件です。')
        for i, item in enumerate(items[:5], 1):
            print(f'{i}. {item}')
        if len(items) > 5:
            print(f'他{len(items)-5}件')
    else:
        print('P0タスクはありません')
except Exception as e:
    print(f'P0取得エラー: {e}')
" 2>/dev/null || echo "P0一覧の取得に失敗しました")
  fi
fi

# ── 音声読み上げ（announce が利用可能な場合）────────────────────────
if command -v announce &>/dev/null; then
  if [[ -n "$P0_SUMMARY" ]]; then
    echo "$LOG_TAG P0サマリー: $P0_SUMMARY"
    announce "おはようございます。${P0_SUMMARY}" --home 2>/dev/null &
  else
    announce "おはようございます。P0一覧の取得をスキップしました。" --home 2>/dev/null &
  fi
fi

# ── Phase 2: LARC enqueue で詳細分析を委託 ───────────────────────────
if command -v larc &>/dev/null; then
  larc ingress enqueue \
    --text "朝の確認（自動）: Meegle P0のうち「スタート」「開発中です」を一覧取得。今日着手すべきものを優先度順に整理し、Lark IM に送信する。" \
    --agent main \
    --source morning-cron
fi

echo "$LOG_TAG 完了"
