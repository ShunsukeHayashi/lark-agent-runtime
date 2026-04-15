# LARC クイックスタート — テストユーザー向けガイド

> **対象**: Lark（飛書）を使っている方で、AI エージェントをローカル PC から試したい方  
> **前提**: MacOS / Linux、Lark アカウント、Claude Code インストール済み

---

## 概要

LARC（Lark Agent Runtime CLI）は、OpenClaw と Lark IM を接続する Bridge ランタイムです。

```
Lark IM メッセージ
    ↓ LARC daemon（IM poller）が検知
larc ingress enqueue
    ↓ worker が pickup
openclaw agent（タスク実行）
    ↓ larc send で返信
Lark IM に返信
```

> **Lark プラグイン（extensions/lark/）は不要です。**  
> LARC が lark-cli 経由で直接 Lark API を呼ぶため、OpenClaw の Lark ネイティブプラグインがなくても完全に動作します。

---

## Step 0 — OpenClaw + LARC スキルのセットアップ

LARC は OpenClaw エージェントのランタイム層です。**最初に OpenClaw を用意してください。**

```bash
# OpenClaw がインストールされているか確認
which openclaw

# OpenClaw に LARC ランタイムスキルをインストール
bash scripts/install-openclaw-larc-runtime-skill.sh
```

> **LARC はスタンドアロンのエージェントではありません。**  
> OpenClaw が実行主体であり、LARC は Lark 側の権限・キュー・監査・文脈取得を担う実行レイヤーです。

その他の前提確認：

```bash
which python3    # Python 3.8 以上
which node       # Node.js（lark-cli のインストールに必要）
```

---

## Step 1 — インストール

```bash
# 1. lark-cli のインストール（未インストールの場合）
npm install -g @larksuite/cli

# 2. LARC インストール（~/.larc/runtime/ に自動配置）
curl -fsSL https://raw.githubusercontent.com/ShunsukeHayashi/lark-agent-runtime/main/scripts/install.sh | bash

# 確認
larc version
```

> **重要**: LARC は `~/.larc/runtime/` にインストールされます。このディレクトリ内のファイルは直接編集しないでください。更新は `larc update` で行ってください。

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
# 状態確認（接続・デーモン・キュー統計を一覧表示）
larc status

# ブートストラップ（identity ドキュメントを読み込む）
larc bootstrap --agent main

# テストタスクを送信
larc ingress enqueue \
  --text "テスト: 動作確認してください" \
  --agent main \
  --source claude-code

# キューを確認
larc ingress list --agent main
```

---

## Step 5 — デーモン起動（自動ループ）

OpenClaw がインストール済みの場合：

```bash
larc daemon start --agent main --interval 30
```

これだけで以下のループが完全自動で動きます：

```
Lark IM メッセージ
    ↓ 自動（30秒ごとにポーリング）
キュー登録
    ↓ 自動（worker が pickup）
openclaw agent 実行
    ↓ 自動（larc send で返信）
Lark IM に返信
```

### デーモン管理

```bash
larc daemon status   # 状態確認
larc daemon logs     # ログ確認
larc daemon stop     # 停止
```

---

## 実行モード

| モード | 動作 | 状態 |
|--------|------|------|
| **Supervised** | Claude Code が手動で `larc ingress run-once` を呼ぶ → バンドルを確認して実行 | ✅ 安定 |
| **OpenClaw-assisted** | OpenClaw が `larc ingress openclaw --execute` を呼ぶ → ゲート・監査は LARC が担当 | ✅ 安定 |
| **Experimental IM loop** | `larc daemon start` — IM メッセージを自動エンキューして OpenClaw に自動ディスパッチ | 🧪 実験的 |

> **IM デーモンループは実験段階です。** 本番用途には Supervised または OpenClaw-assisted を使用してください。

---

## 日常的な使い方

### Supervised モード（Claude Code のみ）

```bash
larc ingress enqueue --text "先月の経費レポートを作成してください" --agent main
larc ingress run-once --agent main
```

### Autonomous モード（デーモン稼働中）

Lark IM にメッセージを送るだけ。以降は自動です。

```bash
# 単発実行（デーモン外で手動実行する場合）
larc ingress openclaw --execute --agent main
```

### メモリ管理

```bash
larc memory pull                       # Lark Base から最新メモリを取得
larc memory push                       # ローカルの記憶を Lark Base に保存
larc memory search --query "承認" --days 14  # キーワード検索
```

---

## トラブルシューティング

### `lark-cli auth status` が invalid を返す

```bash
lark-cli auth login   # 再ログイン
```

### `larc quickstart` でフォルダ作成に失敗する

権限が不足している可能性があります。Lark の管理者に `drive:drive` スコープの付与を依頼してください。

### タスクが `in_progress` のままになる（ワーカークラッシュ後）

デーモン再起動時に自動回復します。手動で回復する場合：

```bash
larc ingress recover --agent main        # スタックしたアイテムを pending にリセット
larc ingress list --agent main           # 状態を確認
```

### Lark IM に返信が来ない

```bash
# デーモンが稼働しているか確認
larc daemon status

# OpenClaw が認識されているか確認
larc status   # OpenClaw: installed (openclaw) と表示されれば OK

# ワーカーログを確認
larc daemon logs worker
```

### IM ポーラーが自分のメッセージをエンキューしてしまう（echo loop）

デーモンを再起動してください。起動時にボット自身の open_id を自動取得してフィルタします：

```bash
larc daemon stop && larc daemon start --agent main
```

---

## アーキテクチャ

```
Lark IM
    ↓ IM poller（30秒ごと）
larc ingress enqueue   → Lark Base: agent_queue (pending)
    ↓ worker
larc ingress openclaw  → openclaw agent（LLM実行）
                       → larc send（Lark IM 返信）
                       → larc ingress done → Lark Base: agent_queue (done)
                                           → Lark Base: agent_logs
```

---

## 次のステップ

- `larc auth suggest "タスク内容"` — 必要な権限を自動診断
- `larc task create --title "..."` — Lark タスクを作成
- `larc approve list` — 承認待ちを確認
- `docs/` フォルダ内のガイドを参照

サポートは [GitHub Issues](https://github.com/ShunsukeHayashi/lark-agent-runtime/issues) へ。
