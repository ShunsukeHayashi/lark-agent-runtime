---
name: larc-runtime
version: 1.1.0
description: "LARC (Lark Agent Runtime): Claude Code が Lark バックオフィスタスクをエージェントとして実行するためのスキル。enqueue → run-once → done/fail のライフサイクル管理 + Meegle（Lark Project）との双方向連携。"
---

# LARC Runtime — Claude Code Agent Skill

**TRIGGER**: ユーザーが Lark への依頼、バックオフィスタスク、エージェント実行を要求したとき。

## このスキルでできること

- Lark Drive / Base / IM / 承認フロー / カレンダー / タスクへの操作
- タスクキューの管理（enqueue → run-once → done/fail）
- 権限診断と最小権限の確認
- エージェント登録と管理
- デーモン起動と状態確認

## 前提条件確認

```bash
larc status          # 設定・認証の状態確認
lark-cli auth status # Lark 認証トークン確認
```

## 基本フロー（Milestone 1: Claude Code のみ）

### 1. タスクをエンキュー

```bash
larc ingress enqueue \
  --text "<依頼内容>" \
  --agent main \
  --source claude-code
# → queue_id が返る
```

### 2. 権限確認（必要に応じて）

```bash
larc auth suggest "<依頼内容>"
# → 必要な scope と gate を表示
```

### 3. タスクを処理（クレーム）

```bash
# 自動ピックアップ（Base-first: 最古の pending を取得）
larc ingress run-once --agent main

# または特定の queue_id を指定
larc ingress run-once --queue-id <queue_id> --agent main
```

### 4. 実行コンテキストを確認

```bash
larc ingress context --queue-id <queue_id> --days 14
```

### 5. 完了 or 失敗を記録

```bash
larc ingress done --queue-id <queue_id> --note "<実施内容>"
larc ingress fail --queue-id <queue_id> --note "<失敗理由>"
```

## キュー管理

```bash
larc ingress list --agent main          # 全キューを確認
larc ingress list --agent main --status pending   # pending のみ
larc ingress followup --agent main      # partial（フォローアップ必要）を確認
```

## Approval フロー（gate=approval のとき）

```bash
# gate=approval のタスクは自動実行されない
larc ingress approve --queue-id <id>   # 承認済みとしてマーク
larc ingress resume  --queue-id <id>   # pending に戻して処理可能にする
```

## エージェント委譲

```bash
larc ingress delegate --queue-id <id>  # 最適なスペシャリストエージェントへ委譲
larc ingress handoff  --queue-id <id>  # 委譲バンドルを構築
```

## Lark 操作コマンド（lark-cli）

実際の Lark API 呼び出しは `lark-cli` を使う。各 Lark スキル（`lark-im`, `lark-base`, `lark-drive` など）を参照。

```bash
# IM メッセージ送信
larc send "メッセージ"

# Base レコード操作
lark-cli base +record-list --base-token $LARC_BASE_APP_TOKEN --table-id <tbl>
lark-cli base +record-upsert --base-token $LARC_BASE_APP_TOKEN --table-id <tbl> --json '{...}'

# Drive ファイル操作
lark-cli drive +upload --folder-token <folder> --file <path>
lark-cli drive +download --file-token <token> --output <path>
```

## セットアップ（新規ユーザー）

```bash
# ドライランで確認
larc quickstart --dry-run

# 実行（7ステップ自動化）
larc quickstart
```

## デーモンモード

```bash
larc daemon start --agent main --interval 30   # 自動ポーリング開始
larc daemon status                              # 状態確認
larc daemon logs                               # ログ表示
larc daemon stop                               # 停止
```

## よく使うワークフロー

### 経費処理

```bash
larc ingress enqueue --text "先月の交通費を集計して承認申請を作成してください" --agent main
larc ingress run-once --agent main
# → gate=approval の場合、承認後に resume
```

### ドキュメント作成

```bash
larc ingress enqueue --text "週次レポートを Lark Doc に作成してください" --agent main
larc ingress run-once --agent main
```

### メモリ同期

```bash
larc memory pull    # Lark Base から取得
larc memory push    # ローカルの記憶を保存
larc memory search --query "キーワード" --days 14
```

## エラー対処

| エラー | 原因 | 対処 |
|--------|------|------|
| `tokenStatus: invalid` | Lark トークン期限切れ | `lark-cli auth login` |
| `permission denied` | scope 不足 | `larc auth suggest "<タスク>"` で確認 |
| `no actionable queue item` | pending がない | `larc ingress list` で状態確認 |
| `is 'in_progress'` | 既にクレーム済み | `larc ingress done/fail --queue-id <id>` |

## Meegle (Lark Project) 連携 — Miyabi Task OS

LARCのライフサイクルイベントは Meegle ストーリーと自動同期する。

### ステータスマッピング

| LARC アクション | Meegle state_key | ステータス名 |
|---|---|---|
| enqueue（受付） | `sub_stage_1679654663853` | スタート |
| run-once（着手） | `sub_stage_1679654941472` | 開発中です |
| done（完了） | `sub_stage_1679655085909` | 終了 |
| fail（失敗） | `sub_stage_1679654845402` | プロダクトレビュー待ち |

### Meegle 固定値

```
project_key: 69dbca561543d1dedeb3c926
work_item_type: story
template_id: 334993
```

### done/fail 時の推奨アクション

```bash
# 1. LARC 完了
larc ingress done --queue-id <id> --note "<実施内容>"

# 2. Meegle にコメント追加（MCP経由）
# add_comment(project_key="69dbca561543d1dedeb3c926", work_item_id=<id>, content="[LARC完了] <内容>")

# 3. Meegle ステータス遷移（MCP経由）
# transition_state(project_key="69dbca561543d1dedeb3c926", work_item_id=<id>, state_key="sub_stage_1679655085909")

# 4. Google Home で報告
announce '<完了サマリー>' --home
```

### コンテキスト復元（セッション開始時）

```bash
# Meegle P0一覧を取得して作業対象を特定
# search_by_mql(project_key="69dbca561543d1dedeb3c926",
#   mql="SELECT `name`, `work_item_status`, `priority` FROM `製品開発`.`開発要件` WHERE `priority` = 'P0'")

# LARC memory で関連メモリを検索
larc memory search --query "<キーワード>" --days 14

# git log で最終コミットを確認
git -C ~/study/larc log -1 --format='%ar: %s'
```

## 設定ファイルの場所

```
~/.larc/config.env       # メイン設定（Base token, Drive folder token）
~/.larc/drive-index.env  # Drive/Base トークン索引（高速参照用）
~/.larc/cache/           # ローカルキャッシュ
```

## 環境変数（主要）

```bash
LARC_BASE_APP_TOKEN    # LARC-memory Base token
LARC_DRIVE_FOLDER_TOKEN # larc-workspace フォルダ token
LARC_WORK_FOLDER_TOKEN  # larc-workdir フォルダ token
LARC_IM_CHAT_ID        # IM 通知先チャット ID
LARC_QUEUE_TABLE_ID    # agent_queue テーブル ID（固定）
LARC_LOG_TABLE_ID      # agent_logs テーブル ID（固定）
```
