# LARC クイックスタート — テストユーザー向けガイド

> **対象**: Lark（飛書）を使っている方で、AI エージェントをローカル PC から試したい方  
> **前提**: MacOS / Linux、Lark アカウント、Claude Code インストール済み

---

## 概要

LARC（Lark Agent Runtime CLI）は、Claude Code から Lark のバックオフィス業務を AI エージェントが処理できるようにするランタイムです。

```
あなた（Claude Code）
    ↓ larc コマンド
LARC ランタイム
    ↓ lark-cli
Lark API（Drive / Base / IM / Approval…）
```

---

## Step 0 — 前提確認

```bash
# 必要なツール
which python3   # Python 3.8 以上
which node      # Node.js（lark-cli のインストールに必要）
```

---

## Step 1 — インストール

```bash
# 1. lark-cli のインストール（未インストールの場合）
npm install -g @larksuite/cli

# 2. LARC インストール（~/.larc/runtime/ に自動配置）
curl -fsSL https://raw.githubusercontent.com/ShunsukeHayashi/lark-agent-runtime/main/scripts/install.sh | bash
```

インストール後の確認：

```bash
larc version   # バージョンが表示されれば OK
```

> **重要**: LARC は `~/.larc/runtime/` にインストールされます。このディレクトリ内のファイルは直接編集しないでください（エージェントも触りません）。更新は `larc update` で行ってください。

---

## Step 2 — lark-cli アプリ設定 + Lark 認証

### 2-1. アプリ情報を入手

テスト担当者から **App ID** と **App Secret** を受け取ってください。

> テスト担当者の方はこちら → [Lark アプリ設定ガイド](lark-app-setup.md)

### 2-2. lark-cli にアプリを登録

```bash
lark-cli config init \
  --app-id   <受け取った App ID> \
  --app-secret-stdin \
  --brand    lark
# → プロンプトが出たら App Secret を入力
```

### 2-3. Lark アカウントでログイン

```bash
lark-cli auth login   # ブラウザが開きます。Lark アカウントでログイン

# 確認
lark-cli auth status
# → "tokenStatus": "valid" が表示されれば OK
```

> **既存 Lark ユーザーの方へ**: ログイン後、LARC が作成するのは以下の2フォルダのみです。既存のファイル・プロジェクトには一切触れません。
> - `larc-workspace/` — SOUL/USER/MEMORY/HEARTBEAT ドキュメント
> - `larc-workdir/` — エージェントの成果物置き場

---

## Step 3 — セットアップ（1コマンド）

```bash
# ドライランで確認
larc quickstart --dry-run

# 問題なければ実行
larc quickstart
```

`larc quickstart` が自動で行うこと（7ステップ）：

| ステップ | 内容 |
|---------|------|
| 1 | Lark 認証確認 |
| 2 | 既存 LARC 設定の検出（再実行時はスキップ） |
| 3 | Lark Drive に `larc-workspace/`・`larc-workdir/` を作成 |
| 4 | LARC-memory Base（DB）と5テーブルを作成 |
| 5 | SOUL / USER / MEMORY / HEARTBEAT ドキュメントを作成 |
| 6 | `~/.larc/config.env` を生成 |
| 7 | `main` エージェントを登録 |

---

## Step 4 — 動作確認

```bash
# 状態確認
larc status

# ブートストラップ（identity ドキュメントを読み込む）
larc bootstrap --agent main

# テストタスクを送信
larc ingress enqueue \
  --text "テスト: ドキュメントを確認してください" \
  --agent main \
  --source claude-code

# キューを確認
larc ingress list --agent main

# タスクを処理
larc ingress run-once --agent main

# 完了
larc ingress done --queue-id <表示された queue_id>
```

---

## 日常的な使い方

### Claude Code でタスクを投げる

```bash
# 依頼テキストをエンキュー
larc ingress enqueue --text "先月の経費レポートを作成してください" --agent main

# 処理（Claude Code が判断して実行）
larc ingress run-once --agent main
```

### デーモンモード（常時稼働）

```bash
# バックグラウンドで自動ポーリング
larc daemon start --agent main --interval 30

# 状態確認
larc daemon status

# ログ確認
larc daemon logs

# 停止
larc daemon stop
```

### メモリ管理

```bash
# Lark Base から最新メモリを取得
larc memory pull

# ローカルの記憶を Lark Base に保存
larc memory push

# キーワード検索
larc memory search --query "承認" --days 14
```

---

## トラブルシューティング

### `lark-cli auth status` が invalid を返す

```bash
lark-cli auth login   # 再ログイン
```

### `larc quickstart` でフォルダ作成に失敗する

権限が不足している可能性があります。Lark の管理者に `drive:drive` スコープの付与を依頼してください。

### タスクが `in_progress` のままになる

```bash
larc ingress list --agent main   # 状態を確認
larc ingress fail --queue-id <id> --note "タイムアウト"   # 手動でフェイル
```

---

## アーキテクチャ（参考）

```
Claude Code（会話UI）
    ↓ Bash ツール
larc コマンド
    ├── larc ingress enqueue   → Lark Base: agent_queue (pending)
    ├── larc ingress run-once  → Lark Base: agent_queue (in_progress)
    ├── larc ingress done      → Lark Base: agent_queue (done)
    │                          → Lark Base: agent_logs
    │                          → Lark IM: 完了通知
    └── larc bootstrap         → Lark Drive: SOUL/USER/MEMORY/HEARTBEAT 読み込み
```

---

## 次のステップ

- `larc auth suggest "タスク内容"` — 必要な権限を自動診断
- `larc task create --title "..."` — Lark タスクを作成
- `larc approve list` — 承認待ちを確認
- `docs/` フォルダ内のガイドを参照

サポートは [GitHub Issues](https://github.com/ShunsukeHayashi/lark-agent-runtime/issues) へ。
