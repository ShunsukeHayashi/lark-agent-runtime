# LARC Phase 2 — Auth Router 実装プレイブック

**Meegle Story**: #23312641 [platform] larc — Auth Router / Scope管理 / Gate制御  
**PRD**: https://miyabi-ai.larksuite.com/wiki/VfzwwryQBiMpyjkHyOaj1bqBpUe  
**設計参照**: https://miyabi-ai.larksuite.com/wiki/AxO6wFROninCFWknoDmjBTc0pRl  
**作成日**: 2026-04-16

---

## スペック（PRD完了条件より）

| # | 完了条件 | 対応 Issue |
|---|---|---|
| 1 | `larc auth suggest` が intent-aware で Auth種別+最小Scopeを自動提案 | Issue #A |
| 2 | `lark-router` Claude Code スキル実装 | Issue #B |
| 3 | User token 自動リフレッシュ | Issue #C |

---

## Issue #A: `larc auth router` — Intent-aware Auth Router

### 実装スペック

**入力**: タスク説明文（自然言語）  
**出力**: `user` / `bot` / `blocked` + 理由 + 最小スコープセット

**3ルール判断ロジック**（Auth Routing設計docより）:

```
Rule 1 — User名義必須操作:
  対象: Calendar書き込み / 承認インスタンス作成 / 承認タスク承認
  → 判定: user (user_access_token 必須)

Rule 2 — 外部テナントDM不可:
  条件: 送信先が外部テナントユーザー
  → 判定: blocked (error: 230038)
  → 理由表示: "外部テナントへのDMはLark APIで不可"

Rule 3 — その他:
  → 判定: bot (tenant_access_token で十分)
```

**最小Scopeセット**:

| 操作 | 最小スコープ |
|---|---|
| Bot読み取り | `im:message:readonly` |
| Bot送信 | `im:message:send_as_bot` |
| User送信 | `im:message` |
| Base書き込み | `bitable:app` |
| Wiki書き込み | `wiki:node:create` |

**新規コマンド追加**:

```bash
larc auth router "<task description>"
# 出力例:
#   Auth decision: bot
#   Reason: IM notification does not require user attribution
#   Required scopes: im:message:send_as_bot
```

**変更ファイル**: `lib/auth.sh` — `cmd_auth()` に `router` subcommand 追加

**テスト**:

```bash
larc auth router "send IM notification to team"
# → bot + im:message:send_as_bot

larc auth router "create calendar event for tomorrow"
# → user + calendar:calendar

larc auth router "send DM to external user"
# → blocked + error 230038 explanation
```

---

## Issue #B: `lark-router` Claude Code スキル

### 実装スペック

**保存先**: `~/study/larc/.claude/skills/lark-router/SKILL.md`

**スキルの役割**:
- エージェントが Lark API 操作前に `larc auth router` を呼ぶためのガイド
- 出力結果に基づいて `lark-cli --as user` / `lark-cli --as bot` を自動選択

**SKILL.md 必須項目**:
- frontmatter: name, description (use/don't-use conditions)
- Auth Router 3ルールの早見表
- `larc auth router` 実行フロー
- blocked ケースのエラーハンドリング

**変更ファイル**: 新規 `lark-router/SKILL.md`

---

## Issue #C: User Token 自動リフレッシュ

### 実装スペック

**問題**: User access token の有効期限（通常2時間）が切れると認証エラーが発生し、エージェントが止まる

**解決策**: `larc auth refresh` コマンドを追加

```bash
larc auth refresh [--agent <id>]
# user_access_token の有効期限をチェック
# 期限 < 10分 → 自動でリフレッシュ実行
# リフレッシュ成功 → 新トークンを ~/.larc/cache/ に保存
```

**変更ファイル**: `lib/auth.sh` — `_auth_refresh()` 関数追加

**テスト**:

```bash
# トークンステータス確認
larc auth check
# → "Token expires in: 8m" → 自動リフレッシュ実行

# 強制リフレッシュ
larc auth refresh --force
```

---

## 実装順序

```
[1] Issue #A 立てる → feature/auth-router-intent-aware ブランチ
    → lib/auth.sh に router subcommand 追加
    → auth-suggest-cases.md にテストケース追加
    → PR #X

[2] Issue #B 立てる → feature/lark-router-skill ブランチ
    → .claude/skills/lark-router/SKILL.md 作成
    → PR #Y

[3] Issue #C 立てる → feature/auth-token-refresh ブランチ
    → lib/auth.sh に refresh subcommand 追加
    → PR #Z

[4] 全PR マージ → Meegle state_6 提出（林さん承認待ち）
```

---

## Definition of Done

- [ ] `larc auth router "send IM notification"` → `bot` 返却
- [ ] `larc auth router "create calendar event"` → `user` 返却
- [ ] `larc auth router "DM to external"` → `blocked` + error 230038
- [ ] lark-router SKILL.md が `.claude/skills/` に存在する
- [ ] `larc auth refresh` でトークンが更新される
- [ ] auth-suggest-cases.md にルーターテストケースが追加されている
- [ ] 全テスト通過（regression: 8 cases 全件 passing）

---

## Meegle ↔ GitHub 連結マップ

| Meegle フィールド | 値 |
|---|---|
| work_item_id | 23312641 |
| wiki (PRD) | VfzwwryQBiMpyjkHyOaj1bqBpUe |
| GitHub repo | ShunsukeHayashi/lark-agent-runtime |
| GitHub Issues | #A (auth-router) / #B (lark-router-skill) / #C (auth-refresh) |
| state_6 承認者 | 林 駿甫 |
