#!/usr/bin/env bash
# scripts/enqueue.sh — larc ingress enqueue + 事前スコープチェック
#
# Usage:
#   scripts/enqueue.sh --text "<task>" [--agent <agent>] [--source <source>] [--skip-check]
#
# 通常の larc ingress enqueue に加え、タスクテキストを auth-matrix-suggest.py で
# 事前チェックし、Not Supported / Partial スコープがあれば警告を表示する。
#
# --skip-check  スコープチェックをスキップして即エンキュー
# --yes         警告が出ても確認なしで続行

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUGGEST_PY="${SCRIPT_DIR}/auth-matrix-suggest.py"

# ── 引数パース ─────────────────────────────────────────────────────────────
TEXT=""
AGENT="main"
SOURCE="claude-code"
SKIP_CHECK=false
YES=false
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --text)         TEXT="$2";   shift 2 ;;
    --agent)        AGENT="$2";  shift 2 ;;
    --source)       SOURCE="$2"; shift 2 ;;
    --skip-check)   SKIP_CHECK=true; shift ;;
    --yes|-y)       YES=true; shift ;;
    *)              EXTRA_ARGS+=("$1"); shift ;;
  esac
done

if [[ -z "$TEXT" ]]; then
  echo "Usage: $0 --text \"<task description>\" [--agent main] [--source claude-code] [--skip-check] [--yes]"
  exit 1
fi

BOLD="\033[1m"; YELLOW="\033[33m"; GREEN="\033[32m"; RED="\033[31m"; CYAN="\033[36m"; RESET="\033[0m"

echo -e "${BOLD}▶ LARC enqueue with pre-flight check${RESET}"
echo -e "  Task: ${CYAN}${TEXT}${RESET}"
echo -e "  Agent: ${AGENT} | Source: ${SOURCE}"
echo ""

# ── スコープチェック ────────────────────────────────────────────────────────
if [[ "$SKIP_CHECK" == "false" ]] && [[ -f "$SUGGEST_PY" ]]; then
  echo -e "${BOLD}[1/2] Scope pre-flight check...${RESET}"
  echo ""

  set +e
  python3 "$SUGGEST_PY" "$TEXT" 2>&1
  CHECK_EXIT=$?
  set -e

  echo ""

  if [[ $CHECK_EXIT -ne 0 ]]; then
    # Issues found (Partial or Not Supported)
    echo -e "${YELLOW}${BOLD}⚠  スコープに制限が見つかりました。${RESET}"
    echo -e "${YELLOW}   Partial/Not Supported の API が含まれています。${RESET}"
    echo ""

    if [[ "$YES" == "false" ]]; then
      read -r -p "  続行しますか？ [y/N] " ans
      if [[ "$ans" != "y" && "$ans" != "Y" ]]; then
        echo -e "${RED}中止しました。${RESET}"
        exit 1
      fi
    else
      echo -e "  ${YELLOW}--yes フラグにより続行します。${RESET}"
    fi
  else
    echo -e "${GREEN}✓ スコープチェック OK — 全スコープ Supported${RESET}"
  fi
  echo ""
else
  echo -e "${YELLOW}[スコープチェックスキップ]${RESET}"
  echo ""
fi

# ── エンキュー ───────────────────────────────────────────────────────────
echo -e "${BOLD}[2/2] Enqueueing task...${RESET}"
larc ingress enqueue \
  --text "$TEXT" \
  --agent "$AGENT" \
  --source "$SOURCE" \
  "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}"
