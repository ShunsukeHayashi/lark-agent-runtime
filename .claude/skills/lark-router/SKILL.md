---
name: lark-router
description: |
  Lark API 操作前に最適な認証種別（user/bot/blocked）と最小スコープセットを自動判定するスキル。
  `larc auth router "<task>"` を使って 3ルール判断ロジックを実行し、
  その結果に基づいて `lark-cli --as user` / `lark-cli --as bot` を選択する。
  Use when: Lark APIを呼び出す前に認証種別を決定するとき、
  user token と bot token のどちらを使うべきか不明なとき、
  外部テナントへのDM送信を試みる前（error 230038 の事前回避）。
---

# lark-router — Lark Auth Router スキル

## 3ルール早見表

| ルール | 条件 | 判定 | 代表例 |
|---|---|---|---|
| Rule 1 | User名義必須操作 | `user` | Calendar書き込み / 承認インスタンス / 承認タスク承認 |
| Rule 2 | 外部テナントDM | `blocked` | error 230038 — 外部ユーザーへのDM |
| Rule 3 | その他全て | `bot` | IM通知 / Base読み取り / Wiki参照 |

## 実行フロー

### Step 1: ルーター実行

```bash
larc auth router "<task description>"
```

出力例:
```
Auth decision: BOT
Rule applied:  Rule 3 — Bot default
Reason:        IM notification does not require user attribution
Minimum scopes: im:message:send_as_bot
```

### Step 2: 判定に基づいて lark-cli を実行

| 判定 | lark-cli フラグ |
|---|---|
| `user` | `lark-cli --as user <command>` |
| `bot` | `lark-cli <command>`（デフォルトはbot） |
| `blocked` | 実行しない → ユーザーに報告 |

### Step 3: blocked の場合

```
外部テナントへのDMはLark API で不可 (error 230038)。
対応策:
  A) 管理コンソールでゲスト招待 → open_id で直接指定
  B) オープンリンク共有 (open_sharing=anyone_readable)
参照: docs/known-issues/lark-external-user-api-gap.md
```

## スコープ認可

```bash
# ルーター実行後、スコープが不足している場合
larc auth login --scope "<router output の scopes>"

# または既存プロファイルを使用
larc auth login --profile writer        # 一般書き込み操作
larc auth login --profile backoffice_agent  # 全スコープ
```

## 最小スコープセット早見表

| 操作 | スコープ |
|---|---|
| Bot IM読み取り | `im:message:readonly` |
| Bot IM送信 | `im:message:send_as_bot` |
| User IM送信 | `im:message` |
| Base書き込み | `bitable:app` |
| Wiki書き込み | `wiki:node:create` |
| Calendar書き込み | `calendar:calendar` |
| 承認インスタンス作成 | `approval:instance:write` |
| 承認タスク承認/却下 | `approval:task:write` |

## テストケース（regression）

```bash
larc auth router "send IM notification to team"    # → BOT
larc auth router "create calendar event"            # → USER
larc auth router "send DM to external user"         # → BLOCKED
larc auth router "submit expense approval"          # → USER
larc auth router "read wiki page"                   # → BOT
```

## 関連

- 実装: `lib/auth.sh` — `_auth_router()` (GitHub Issue #32)
- 設計doc: `docs/permission-model.md`
- 既知制約: `docs/known-issues/lark-external-user-api-gap.md`
- Meegle Story: #23312641
