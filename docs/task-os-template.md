# Task OS Template — LARC × Lark Project (Meegle) 統合設計

> LARCのタスクキューとLark Project（Meegle）を統合し、エージェントがタイプレスに
> タスクの検出→理解→実行→報告を完結するための一般化テンプレート。

## 設計原則

| 原則 | 内容 |
|------|------|
| **Single Source of Truth** | Lark Project（Meegle）が全タスク・ゴール・進捗の唯一の管理場所 |
| **Typeless** | 音声入力 → AI処理 → 音声出力。キーボード不要で運用可能 |
| **Context Complete** | Meegle Story + LARC memory + git history から自動復元 |
| **Zero Ceremony** | 明示的なライフサイクル管理不要。ステータス遷移は自動化 |

---

## 1. Meegle ストーリー構造

### フィールド設計

| フィールド | 用途 | 型 |
|-----------|------|-----|
| `name` | タスク名 `[category] name — description` | text |
| `priority` | 優先度 P0=今週 / P1=月次 / P2=バックログ | select |
| `work_item_status` | ライフサイクル状態 | select |
| `description` | コンテキスト文書（下記テンプレート） | multi-text |
| `tags` | 戦略カテゴリ（カスタマイズ可能） | multi-select |
| コメント | 進捗ログ（エージェントが自動投稿） | — |

### タイトル命名規則

```
[カテゴリ] リポジトリ名 — 日本語一行説明
```

カテゴリ例: `platform`, `products`, `tools`, `ops`, `content`, `voice`, `courses`, `personal`

### description テンプレート

```markdown
## 戦略的位置づけ
{このタスクが上位目標とどう接続するか}

## 完了条件
- [ ] 条件1
- [ ] 条件2

## リポジトリ
- GitHub: {owner}/{repo}
- ローカル: {パス}

## 関連リソース
- {Wiki URL / 設計書パス / 外部リンク}

## 現在のブロッカー
（エージェントが自動更新）
```

---

## 2. LARC ↔ Meegle ステータスマッピング

### デフォルトマッピング

| LARC アクション | Meegle ステータス | state_key (カスタマイズ) |
|---|---|---|
| `ingress enqueue` | スタート | `${LARC_MEEGLE_STATE_START}` |
| `ingress run-once` | 開発中 | `${LARC_MEEGLE_STATE_IN_PROGRESS}` |
| `ingress done` | 終了 | `${LARC_MEEGLE_STATE_DONE}` |
| `ingress fail` | レビュー待ち | `${LARC_MEEGLE_STATE_REVIEW}` |

### config.env に追加する変数

```bash
# Meegle (Lark Project) 連携
LARC_MEEGLE_PROJECT_KEY="<your_project_key>"
LARC_MEEGLE_WORK_ITEM_TYPE="story"
LARC_MEEGLE_TEMPLATE_ID="<your_template_id>"
LARC_MEEGLE_STATE_START="<state_key>"
LARC_MEEGLE_STATE_IN_PROGRESS="<state_key>"
LARC_MEEGLE_STATE_DONE="<state_key>"
LARC_MEEGLE_STATE_REVIEW="<state_key>"
```

---

## 3. コンテキスト自動復元シーケンス

セッション開始時にエージェントが実行する手順:

```
Step 1: Meegle MQL で P0 アクティブ一覧を取得
  search_by_mql(project_key, "SELECT `name`, `work_item_status` ... WHERE `priority` = 'P0'")

Step 2: 各ストーリーの description からコンテキスト文書を抽出
  get_workitem_brief(work_item_id) → description フィールド
  list_workitem_comments(work_item_id) → 直近のコメント

Step 3: LARC memory で関連メモリを検索
  larc memory search --query "<キーワード>" --days 14

Step 4: git log で最終コミットを確認
  git -C <repo_path> log -1 --format='%ar: %s'

Step 5: 優先順位リストを生成し、音声で報告
  announce '<サマリー>' --home
```

---

## 4. 自動レビューパターン

### 朝のルーティン（平日）

```bash
# 1. Meegle P0 を直接取得
lark-cli project search-by-mql \
  --project-key $LARC_MEEGLE_PROJECT_KEY \
  --mql "SELECT \`name\`, \`work_item_status\` FROM ... WHERE \`priority\` = 'P0'"

# 2. Google Home / 音声デバイスで読み上げ
announce "今日のP0は${COUNT}件です。${SUMMARY}" --home

# 3. LARC enqueue で詳細分析を委託
larc ingress enqueue --text "朝の確認..." --agent main --source morning-cron
```

### 週次レビュー（月曜）

```bash
# P0/P1 カウント取得
# 各プロジェクトの git log -1 で最終コミット日確認
# ルール:
#   P0 で 2週間以上未活動 → P1 降格提案
#   P1 で 直近7日以内にコミット → P0 昇格提案
# Guardian（人間）承認後に実行
```

---

## 5. done/fail 時の推奨アクション

```bash
# 1. LARC 完了記録
larc ingress done --queue-id <id> --note "<実施内容>"

# 2. Meegle にコメント追加
# MCP: add_comment(project_key, work_item_id, "[LARC完了] <内容>")

# 3. Meegle ステータス遷移
# MCP: transition_state(project_key, work_item_id, state_key)

# 4. 音声報告
announce '<完了サマリー>' --home
```

---

## 6. Typeless 作業フロー

```
[cron] → Meegle P0取得 → 音声読み上げ
[人間] 音声指示 → 音声認識ツール → テキスト → Claude Code / Lark IM
[エージェント] Meegle description + LARC memory + git log → コンテキスト復元
[実行] 実装 → PR → Meegle コメント + ステータス遷移
[報告] 音声フィードバック（Google Home / ローカルスピーカー）
```

---

## 7. 禁止事項

- タスクの二重管理（Meegle が唯一の真実）
- Guardian承認なしの P0/P1 昇降格
- 画面確認を前提とした報告（音声出力を基本とする）
- LARC done/fail を記録せずにセッションを終了すること

---

## 8. セットアップ手順

### Step 1: Lark Project の空間を作成

Meegle UIで空間を作成し、ストーリー型のワークアイテムを定義。

### Step 2: config.env に Meegle 変数を追加

```bash
cat >> ~/.larc/config.env << 'EOF'
LARC_MEEGLE_PROJECT_KEY="your_project_key"
LARC_MEEGLE_WORK_ITEM_TYPE="story"
LARC_MEEGLE_TEMPLATE_ID="your_template_id"
EOF
```

### Step 3: ステータスの state_key を取得

```bash
# Meegle MCP または lark-cli で取得
# get_transitable_states(project_key, work_item_id, work_item_type, user_key)
```

### Step 4: cron スクリプトを配置

`~/.larc/scripts/morning-check.sh` と `~/.larc/scripts/weekly-review.sh` を配置し、
launchd / cron で定期実行。

---

*Version: 1.0.0 | Created: 2026-04-16*
