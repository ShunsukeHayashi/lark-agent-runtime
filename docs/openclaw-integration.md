# OpenClaw Integration

LARC は OpenClaw の **Bridge ランタイム**として動作します。OpenClaw の Lark ネイティブプラグイン（`extensions/lark/`）は不要です。

## アーキテクチャ

```
Lark IM
    ↓ LARC daemon（IM poller）
larc ingress enqueue / worker
    ↓
openclaw agent --local --json --message "<bundle>"
    ↓ larc send（lark-cli 経由で直接 Lark API）
Lark IM に返信
    ↓
larc ingress done
```

## Lark プラグインについて

`extensions/lark/` は OpenClaw の旧 SDK 形状（`ExtensionDefinition`）で書かれており、現 SDK（`OpenClawPluginDefinition` / `register(api)` パターン）とは非互換のため現在ロードできません。

**LARC Bridge では Lark プラグインを使いません。**  
`larc send`（内部で lark-cli を呼び出す）を使って Lark IM への返信を行います。これにより OpenClaw の Lark プラグインなしでも完全な双方向フローが実現します。

## OpenClaw へのプロンプト設計

`larc ingress openclaw --execute` が OpenClaw に渡すプロンプトには以下が含まれます：

- キューアイテムの詳細（queue_id, task_types, scopes, message）
- **必須返信ステップ**（タスク完了後に必ず実行）:
  ```bash
  larc ingress done --queue-id <id> --note "<summary>"
  larc send "<reply to user>"
  ```
- 使用推奨ツール（lark-cli 経由の Lark 操作）

## 実行フロー

```bash
# デーモン起動（完全自動ループ）
larc daemon start --agent main --interval 30

# 手動で単発実行する場合
larc ingress openclaw --queue-id <id> --execute
```

## Echo Loop 防止

IM poller は起動時にボット自身の `open_id` を取得し、ボット発信メッセージをスキップします。  
`LARC_ALLOW_FROM` 環境変数でホワイトリスト（受け付けるユーザーの open_id）を設定することもできます。

```bash
# ~/.larc/config.env に追記
LARC_ALLOW_FROM=ou_xxxxx,ou_yyyyy
```

## 将来の Lark プラグイン書き換えについて

OpenClaw の Lark プラグインを現 SDK に対応させる場合は `discord` extension を参考実装として使用してください（`register(api)` + `ChannelPlugin` shape）。ただし LARC Bridge で同等の機能が実現できているため、優先度は低めです。
