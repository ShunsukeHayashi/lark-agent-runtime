# LARC クイックスタート — OpenClaw 前提ガイド

> **対象**: OpenClaw から Lark 仕事フローを扱いたい方
> **前提**: macOS / Linux、Lark アカウント、OpenClaw 利用環境、Lark アプリ認証情報

---

## 概要

LARC（Lark Agent Runtime CLI）は、OpenClaw の下で Lark 実行を統制する runtime です。

```
OpenClaw Agent
    ↓ OpenClaw Feishu/Lark channel
Lark chat app / bot 接続
    ↓ official openclaw-lark plugin
Lark の原子的な操作
    ↓
LARC
    - auth suggest
    - approve gate
    - queue / delegation
    - memory / audit
    ↓
Lark tenant surfaces
```

LARC 単体の「常駐 IM ボット」を先に立てるのではなく、`OpenClaw Agent -> OpenClaw Feishu/Lark channel -> official openclaw-lark plugin + LARC` を主経路として使います。

> **重要**: `larc daemon start` による IM 自動ループはまだ experimental です。
> テストユーザー導線では、まず OpenClaw から LARC bundle を使う運用を案内してください。
>
> **会話入口の原則**: テストユーザーや運用担当者が実際に話しかけるのは、OpenClaw の Feishu/Lark channel が作る chat app / bot です。
> `lark-cli` 用の App ID / App Secret は LARC runtime の認証用であり、ユーザー向け chat app を別に立ち上げるための導線ではありません。

---

## Step 0 — OpenClaw / Feishu channel / plugin / LARC の役割を分けて理解する

オンボーディングで混同しやすいので、最初に役割を分けます。

| 層 | 役割 |
|---|---|
| OpenClaw Feishu/Lark channel | **実際にユーザーが会話する chat app / bot** を接続し、DM / group message の入口を作る |
| official `openclaw-lark` plugin | OpenClaw から Lark API の原子的操作を行う |
| LARC | 権限説明、ゲート、queue、監査、memory、write-back を統制する |

Lark の chat app と OpenClaw の紐付けは、plugin ではなく **OpenClaw の Feishu/Lark channel** 側で行います。ユーザー案内もこの chat app / bot に統一してください。

## Step 1 — OpenClaw + LARC スキルのセットアップ

LARC は OpenClaw エージェントのランタイム層です。**最初に OpenClaw を用意してください。**

```bash
# OpenClaw がインストールされているか確認
which openclaw

# OpenClaw に LARC ランタイムスキルをインストール
bash scripts/install-openclaw-larc-runtime-skill.sh

# 確認
openclaw skills list | rg larc-runtime
```

> **LARC はスタンドアロンのエージェントではありません。**  
> OpenClaw が実行主体であり、LARC は Lark 側の権限・キュー・監査・文脈取得を担う実行レイヤーです。
>
> **別途必要**: OpenClaw 側では
> 1. Feishu/Lark channel の接続
> 2. 公式 `openclaw-lark` プラグイン
> の両方が必要です。LARC はその代替ではなく、実行統制レイヤーです。

その他の前提確認：

```bash
which python3    # Python 3.8 以上
which node       # Node.js（lark-cli のインストールに必要）
```

---

## Step 2 — インストール

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

## Step 3 — OpenClaw の Feishu/Lark channel を接続する

chat app / bot と OpenClaw の紐付けは、ここで行います。`openclaw-lark` plugin の役割ではありません。

```bash
openclaw channels login --channel feishu
openclaw gateway restart
```

DM の pairing や group 設定が必要なら、OpenClaw channel 側で設定します。

```bash
openclaw pairing list feishu
openclaw pairing approve feishu <CODE>
```

> group chat を使う場合は、`groupPolicy`、`groupAllowFrom`、`requireMention` も OpenClaw 側の Feishu channel 設定で調整してください。
>
> **ここで作られた chat app / bot が、ユーザーに案内すべき唯一の会話入口です。**

## Step 4 — official `openclaw-lark` plugin を利用可能にする

Lark の原子的操作は official plugin 側で実行します。plugin は会話入口そのものではなく、OpenClaw が接続した chat app / bot の背後で API 操作を担います。

> 公式手順は `larksuite/openclaw-lark` README と OpenClaw の `docs/channels/feishu.md` を参照してください。

## Step 5 — lark-cli アプリ設定 + Lark 認証

### 2-1. アプリ情報を入手

テスト担当者から **App ID** と **App Secret** を受け取ってください。

> テスト担当者の方はこちら → [Lark アプリ設定ガイド](lark-app-setup.md)
>
> **注意**: ここで設定するアプリ資格情報は LARC runtime の認証に使います。ユーザー向け chat app を新たに案内する手順ではありません。

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

## Step 6 — セットアップ（1コマンド）

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

## Step 7 — 動作確認

```bash
# 状態確認（接続・OpenClaw 検出・キュー統計を一覧表示）
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

# OpenClaw に渡す bundle を表示
larc ingress openclaw --agent main --days 14
```

---

## Step 8 — 推奨運用（OpenClaw 補助）

推奨フローは、OpenClaw から LARC bundle を読み、Lark 操作は公式 `openclaw-lark` プラグインで行い、状態更新は LARC に返す形です。

```bash
# queue を OpenClaw 向けに整形
larc ingress openclaw --queue-id <id> --agent main --days 14

# OpenClaw へ直接 dispatch する場合
larc ingress openclaw --queue-id <id> --execute
```

LARC 側で重視するのは次です。

- `auth suggest` で必要権限を説明する
- `approve gate` で実行ゲートを決める
- `ingress` で queue / delegation / done / fail を管理する
- `memory` と audit に結果を残す

---

## Step 9 — experimental 自動ループ

`larc daemon start` はまだ experimental です。テストや検証用には使えますが、現時点ではこれを主要オンボーディング導線として案内しません。

```bash
larc daemon start --agent main --interval 30
larc daemon status
larc daemon logs
larc daemon stop
```

---

## 実行モード

| モード | 動作 | 状態 |
|--------|------|------|
| **recommended** | OpenClaw Feishu/Lark channel + official openclaw-lark plugin + LARC | OpenClaw が**ユーザー向け chat app / bot**を接続し、plugin が原子的操作、LARC が権限・ゲート・queue を統制 | ✅ 推奨 |
| **Supervised** | OpenClaw / Claude Code + LARC | `larc ingress openclaw` や `run-once` で bundle を確認しながら進める | ✅ 安定 |
| **OpenClaw-assisted** | OpenClaw が `larc ingress openclaw --execute` を呼ぶ。公式 `openclaw-lark` が原子的な Lark 操作を行い、LARC がゲート・監査を担当 | ✅ 安定 |
| **Experimental IM loop** | `larc daemon start` — IM メッセージを自動エンキューして OpenClaw に自動ディスパッチ | 🧪 実験的 |

> **IM デーモンループは実験段階です。** 本番用途には Supervised または OpenClaw-assisted を使用してください。

---

## 日常的な使い方

### 推奨モード（OpenClaw 前提）

```bash
larc ingress enqueue --text "先月の経費レポートを作成してください" --agent main
larc ingress openclaw --agent main --days 14
```

### supervised 補助実行

```bash
larc ingress run-once --agent main
larc ingress execute-stub --queue-id <id>
larc ingress execute-apply --queue-id <id> --dry-run
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

### OpenClaw から先に進まない

```bash
openclaw skills list | rg larc-runtime
larc status
larc ingress openclaw --agent main --days 14
```

### experimental 自動ループで IM が不安定

```bash
larc daemon stop && larc daemon start --agent main
larc daemon logs
```

---

## アーキテクチャ

```
OpenClaw Agent
    ↓ OpenClaw Feishu/Lark channel
Lark chat app / bot 接続
    ↓ official openclaw-lark plugin
Lark atomic operations
    ↓
LARC
    → auth suggest / approve gate
    → agent_queue / agent_logs
    → delegation / memory / audit
```

---

## 次のステップ

- `larc auth suggest "タスク内容"` — 必要な権限を自動診断
- `larc task create --title "..."` — Lark タスクを作成
- `larc approve list` — 承認待ちを確認
- `docs/` フォルダ内のガイドを参照

サポートは [GitHub Issues](https://github.com/ShunsukeHayashi/lark-agent-runtime/issues) へ。
