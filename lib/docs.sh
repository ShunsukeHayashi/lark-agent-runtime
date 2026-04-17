#!/usr/bin/env bash
# lib/docs.sh — larc docs: wrapper around lark-cli docs with input validation
# LARC wraps lark-cli and validates args before passing through.

cmd_docs() {
  local subcmd="${1:-}"
  if [[ -z "$subcmd" ]]; then
    _docs_usage
    exit 1
  fi

  # Intercept +update to validate --markdown flag
  if [[ "$subcmd" == "+update" ]]; then
    _docs_validate_update_args "$@"
    # Validation passed — execute via lark-cli
    lark-cli docs "$@"
    return $?
  fi

  # All other docs subcommands pass through directly
  lark-cli docs "$@"
}

# ---------------------------------------------------------------------------
# Validate args for `lark-cli docs +update`
# Detects absolute path passed to --markdown and aborts with a clear error.
# ---------------------------------------------------------------------------
_docs_validate_update_args() {
  local i=1
  local args=("$@")
  local total=${#args[@]}

  while (( i < total )); do
    local key="${args[$i]}"
    if [[ "$key" == "--markdown" ]]; then
      local val_idx=$(( i + 1 ))
      if (( val_idx >= total )); then
        log_error "--markdown requires a value"
        exit 1
      fi
      local val="${args[$val_idx]}"

      # Detect absolute path: starts with /
      if [[ "$val" == /* ]]; then
        echo ""
        echo "╔══════════════════════════════════════════════════════════════╗" >&2
        echo "║  ERROR: --markdown に絶対パスを渡すことは禁止されています      ║" >&2
        echo "╚══════════════════════════════════════════════════════════════╝" >&2
        echo "" >&2
        echo "  渡された値: $val" >&2
        echo "" >&2
        echo "  絶対パスを --markdown に渡すと、パス文字列がそのままドキュメントに" >&2
        echo "  挿入されます（ファイルの内容は読み込まれません）。" >&2
        echo "" >&2
        echo "  ✅ 正しい使い方:" >&2
        echo "     @相対パス : lark docs +update --doc <id> --mode overwrite --markdown @./content.md" >&2
        echo "     stdin    : cat content.md | lark docs +update --doc <id> --mode overwrite --markdown -" >&2
        echo "" >&2
        echo "  絶対パスのファイルを使う場合:" >&2
        echo "     cp $val ./content.md" >&2
        echo "     larc docs +update --doc <id> --mode overwrite --markdown @./content.md" >&2
        echo "     rm ./content.md" >&2
        echo "" >&2
        exit 1
      fi

      # Detect if value looks like an absolute path missing the @ prefix
      # (no newline, ends in .md/.txt, doesn't start with @ or -)
      if [[ "$val" != "@"* && "$val" != "-" && "$val" == *"/"* && "$val" != *$'\n'* ]]; then
        # Could be a relative path without @ prefix — also an error
        echo "" >&2
        echo "╔══════════════════════════════════════════════════════════════╗" >&2
        echo "║  ERROR: --markdown にファイルパスを直接渡すことは禁止です      ║" >&2
        echo "╚══════════════════════════════════════════════════════════════╝" >&2
        echo "" >&2
        echo "  渡された値: $val" >&2
        echo "" >&2
        echo "  ファイルパスを渡すには @ プレフィックスが必要です。" >&2
        echo "" >&2
        echo "  ✅ 正しい使い方:" >&2
        echo "     @相対パス : --markdown @./content.md" >&2
        echo "     stdin    : --markdown -" >&2
        echo "     文字列   : --markdown \"## 見出し\n\n内容\"" >&2
        echo "" >&2
        exit 1
      fi
    fi
    (( i++ ))
  done
}

_docs_usage() {
  cat >&2 <<'EOF'

larc docs — lark-cli docs のラッパー（入力バリデーション付き）

使い方:
  larc docs +update  --doc <doc_id> --mode <mode> --markdown <value>  [options]
  larc docs +fetch   --doc <doc_id>
  larc docs +create  --markdown <value>  [options]
  larc docs +search  <query>

--markdown の渡し方:
  @./相対パス   ファイルの内容を渡す（✅ 推奨）
  -             stdin から読み込む（✅ 推奨）
  "文字列"      インライン文字列（✅ OK）
  /絶対パス     ❌ 禁止 — パス文字列がそのままドキュメントに挿入されます

詳細は lark-cli docs --help を参照してください。
EOF
}
