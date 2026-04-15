# Lark アプリ設定ガイド — テスト担当者向け

> **対象**: LARC をテストユーザーに配布する担当者  
> **目的**: lark-cli が使用する Lark アプリを作成し、テストユーザーが `lark-cli config init` できる状態にする

---

## 概要

LARC は `lark-cli` 経由で Lark API を呼び出します。`lark-cli` には **OAuth クライアント**（App ID + App Secret）が必要です。

テスト配布の流れ：

```
担当者が Lark アプリを 1 つ作成
  → App ID と App Secret をテストユーザーに共有
  → 各ユーザーが lark-cli config init + lark-cli auth login
  → larc quickstart で環境構築完了
```

---

## Step A — Lark Developer Console でアプリを作成

### A-1. Developer Console にアクセス

| リージョン | URL |
|-----------|-----|
| Lark（グローバル） | https://open.larksuite.com/app |
| 飛書（中国） | https://open.feishu.cn/app |

### A-2. カスタムアプリを作成

1. **「Create Custom App」** をクリック
2. アプリ名を入力（例: `larc-test`）
3. 説明を入力（例: `LARC agent runtime - test`）
4. **「Create」** をクリック

### A-3. Bot（ロボット）を有効化

左サイドバー **「Features」→「Bot」** を選択し、**「Enable Bot」** をオンにする。

> Bot を有効にすることで、エージェントが IM メッセージを送信できるようになります。

---

## Step B — API スコープ（権限）を設定

左サイドバー **「Permissions & Scopes」** を選択。

### B-1. 必須スコープ（Scope）一覧

以下のスコープを追加してください：

#### Drive / 文書
| スコープ | 用途 |
|---------|------|
| `drive:drive` | Drive フォルダ・ファイル操作 |
| `drive:drive:readonly` | Drive 読み取り |
| `drive:file:create` | ファイル作成 |
| `docs:doc:readonly` | ドキュメント読み取り |

#### Base（多維表格）
| スコープ | 用途 |
|---------|------|
| `base:record:created` | Base レコード作成 |
| `base:record:readonly` | Base レコード読み取り |

#### IM（メッセージ）
| スコープ | 用途 |
|---------|------|
| `im:message:send_as_bot` | Bot としてメッセージ送信 |
| `im:message.file_link:readonly` | ファイルリンク読み取り |

#### Wiki（知識ベース）
| スコープ | 用途 |
|---------|------|
| `wiki:wiki:readonly` | Wiki 読み取り |

#### 承認・タスク
| スコープ | 用途 |
|---------|------|
| `approval:approval:readonly` | 承認フォーム読み取り |
| `approval:approval:write` | 承認フォーム作成 |
| `approval:instance:write` | 承認インスタンス送信 |
| `approval:task:write` | 承認タスク操作 |
| `task:task` | タスク作成・更新 |

### B-2. 「Save」して「Publish」

スコープ追加後、**「Save」→「Publish」** でアプリを公開します。

> **注意**: スコープ変更後は必ず再公開が必要です。

---

## Step C — App ID と App Secret を確認

左サイドバー **「Credentials & Basic Info」** を選択。

| 項目 | 場所 |
|-----|------|
| **App ID** | `app_id` フィールド |
| **App Secret** | 「View」ボタンをクリックして表示 |

この 2 つをテストユーザーに安全な方法（Lark IM の秘密メッセージ等）で共有してください。

---

## テストユーザーへの共有テンプレート

以下をテストユーザーに送信してください：

---

```
【LARC テスト参加者向け設定情報】

LARC の利用に必要な Lark アプリの認証情報です。

App ID:     cli_XXXXXXXXXXXXXXXX
App Secret: (別途お伝えします)

── 設定手順 ──────────────────────────
1. lark-cli をインストール（未インストールの場合）
   npm install -g @larksuite/cli

2. アプリを登録
   lark-cli config init \
     --app-id cli_XXXXXXXXXXXXXXXX \
     --app-secret-stdin \
     --brand lark
   （上記コマンドを実行後、App Secret を入力してください）

3. Lark アカウントでログイン（ブラウザが開きます）
   lark-cli auth login

4. LARC セットアップ
   larc quickstart

詳細: https://github.com/ShunsukeHayashi/lark-agent-runtime/blob/main/docs/quickstart-ja.md
────────────────────────────────────────
```

---

## よくある質問

### Q: テストユーザーごとに別アプリが必要？

**不要です。** 1 つのアプリを複数ユーザーで共有できます。各ユーザーは自分の Lark アカウントで `lark-cli auth login` してください。LARC が Lark Drive に作成するフォルダ（`larc-workspace/`, `larc-workdir/`）は各ユーザーの Drive に作成されます。

### Q: App Secret を安全に渡す方法は？

Lark IM の 1:1 メッセージ（暗号化済み）、または Signal など安全なチャネルを使用してください。メール・Slack パブリックチャンネルへの掲載は避けてください。

### Q: テスト終了後にアプリを削除すると？

アプリを削除するとすべてのユーザーの lark-cli が認証エラーになります。テスト期間中は削除しないでください。テスト終了後は Bot を無効化するだけで十分です。

### Q: 「Unconfigured app」エラーが出る

`lark-cli config init` を実行していない状態です。Step 2 の手順を再実行してください。

### Q: `lark-cli auth login` でブラウザが開かない

```bash
# 環境変数でブラウザを指定
BROWSER=open lark-cli auth login    # Mac
BROWSER=xdg-open lark-cli auth login  # Linux
```

---

## セキュリティ上の注意

- App Secret は **絶対に Git にコミットしない**でください
- `~/.larc/config.env` には App Secret は含まれません（lark-cli が管理）
- テスト終了後は Developer Console でアプリの Bot を無効化することを推奨します
