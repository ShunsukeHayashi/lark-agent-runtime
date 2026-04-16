# Meegle MCP Wiring

このプロジェクトでは `Meegle` を `lark-project` ツール群として扱います。

## 追加した配線

- `.deps/miyabi-mcp-bundle`
  - 実体: `/Users/shunsukehayashi/dev/01-miyabi/_mcp/miyabi-mcp-bundle`
- `.mcp.json`
  - project-local の `miyabi-mcp` サーバ定義
- `.claude/settings.local.json`
  - `lark-project` 系ツールの project-local allow list

## 確認ポイント

1. Claude Code をこの repo で開く
2. project-local `.mcp.json` が読み込まれることを確認する
3. `lark-project` スキルから `mcp__lark-project__search_by_mql` などが見えることを確認する

## 注意

- 2026-04-16 の Claude ログには `mcp__lark-project__search_by_mql` / `create_workitem` / `transition_state` などの実呼び出し痕跡があります
- ただし、現在確認できるローカル設定ファイル群には `lark-project` という名前の独立サーバ定義は見つかっていません
- `miyabi-mcp-bundle` も確認した範囲では `lark-project` 実装を含んでいません
- そのため、現時点の `.mcp.json` は「repo 配下から依存先を追えるようにするための暫定配線」です
- 実際の `lark-project` サーバ本体は、別の動的 ToolSearch 配信元または別環境の MCP 設定に存在する可能性があります

## 確認済みの事実

- Claude ログ:
  - `~/Library/Logs/Claude/main.log`
  - 2026-04-16 10:37 から 10:41 に `mcp__lark-project__*` の permission request が連続で発生
- 認証フロー:
  - `lark-cli auth login` が現行の実在コマンド
  - `--no-wait` / `--device-code` を使う Device Flow が利用可能
  - 過去メモでも「認証URLの有効期限は通常5分」とされている
- 現在のローカル設定:
  - `~/Library/Application Support/Claude/claude_desktop_config.json`
  - `~/.claude/settings.json`
  - `~/.mcp.json`
  - いずれにも `lark-project` サーバ定義はなし
- バンドル候補:
  - `/Users/shunsukehayashi/dev/01-miyabi/_mcp/miyabi-mcp-bundle`
  - 既知の `lark-project` ツール名実装は見つからず

## 現時点の判断

- `mcp__lark-project__*` は過去の Claude セッションで実際に使われていた
- ただし、その供給元は現在のローカル設定ファイルからは復元できていない
- 一方、認証そのものは `lark-cli auth login` ベースで復旧できる可能性が高い
- `lark-cli project ...` は現行の `lark-cli` には存在しないため、過去ドキュメント中の `lark-cli project search-by-mql` などは
  - 旧構想
  - 将来実装の想定
  - 別ラッパー/別バージョン前提
  のいずれかとして扱う必要がある
