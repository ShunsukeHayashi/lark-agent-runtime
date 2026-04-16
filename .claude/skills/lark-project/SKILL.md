---
name: lark-project
version: 2.0.0
description: "Lark Project（飛書プロジェクト）：合同会社みやび全プロジェクト管理。P0/P1/P2優先度別ビュー、カテゴリ別ビュー、MQL検索、ステータス管理、週次レビュー支援。"
---

# Lark Project MCP — 合同会社みやび プロジェクト管理スキル

> **重要**: ツール呼び出し前に必ず `ToolSearch` で対象ツールのスキーマをロードすること。
> 例: `ToolSearch("select:mcp__lark-project__search_by_mql,mcp__lark-project__list_todo")`

---

## 現在の空間情報（固定値）

| 項目 | 値 |
|------|-----|
| 空間名 | 製品開発 |
| project_key | `69dbca561543d1dedeb3c926` |
| ワークアイテム種別 | `story`（開発要件） |
| テンプレートID | `334993` |
| URL | https://project.larksuite.com/69dbca561543d1dedeb3c926/story |

---

## ショートカットコマンド

ユーザーが以下の表現をしたら、対応するMQLを即実行する。

### 「今日やること / 待办確認」

```
→ list_todo(action="todo", page_num=1)
```

### 「今週のタスク」

```
→ list_todo(action="this_week", page_num=1)
```

### 「P0プロジェクト一覧」

```
→ search_by_mql(
    project_key="69dbca561543d1dedeb3c926",
    mql="SELECT `name`, `work_item_status`, `priority` FROM `製品開発`.`開発要件` WHERE `priority` = 'P0'"
  )
```

### 「P1プロジェクト一覧」

```
→ search_by_mql(
    project_key="69dbca561543d1dedeb3c926",
    mql="SELECT `name`, `work_item_status`, `priority` FROM `製品開発`.`開発要件` WHERE `priority` = 'P1'"
  )
```

### 「開発中のプロジェクト」

```
→ search_by_mql(
    project_key="69dbca561543d1dedeb3c926",
    mql="SELECT `name`, `priority` FROM `製品開発`.`開発要件` WHERE `work_item_status` = '開発中です'"
  )
```

### 「○○を検索」（プロジェクト名の一部）

```
→ search_by_mql(
    project_key="69dbca561543d1dedeb3c926",
    mql="SELECT `name`, `priority`, `work_item_status` FROM `製品開発`.`開発要件` WHERE `name` like '%○○%'"
  )
```

### 「全プロジェクト一覧」

```
→ search_by_mql(
    project_key="69dbca561543d1dedeb3c926",
    mql="SELECT `name`, `priority`, `work_item_status` FROM `製品開発`.`開発要件` WHERE `priority` is not null"
  )
※ 50件超の場合は session_id で翌ページ取得
```

---

## ビュー構成（作成済み）

### 優先度別（日常メイン）

| ビュー名 | view_id | 用途 | 確認頻度 |
|----------|---------|------|---------|
| 🔥 P0 アクティブ（今週触るもの） | `lqnAZG2Dg` | 今週コミット or 作業予定 (16件) | 毎朝 |
| 📋 P1 メンテナンス中 | `mXH0ZGhvR` | 安定運用、月1-2回 (12件) | 週1月曜 |
| 💤 P2 バックログ / 休眠 | `-sK0WGhDg` | 1ヶ月以上放置 (23件 ※kaggle重複#23282166削除後) | 月1月末 |

### カテゴリ別（横断検索）

| ビュー名 | view_id | 件数 |
|----------|---------|------|
| 🏗️ platform — 基盤・フレームワーク | `XSC0WM2vg` | 6 |
| 📦 products — エンドユーザー向け | `0ieAWM2Dg` | 15 |
| 🔧 tools — 開発ユーティリティ・CLI | `hHR1ZM2vR` | 16 |
| 🎙️ voice — 音声・TTS | `Bck1ZGhDg` | 3 |
| ⚙️ ops/content/other — 運用・コンテンツ | `jxm1WGhvg` | 12 |

---

## ステータスフロー

```
スタート → 開発中です → テスト中 → 公開待ち → 終了
                                              ↓
                     プロダクトレビュー待ち（方向性判断中）
```

| ステータス | option_id | 用途 |
|-----------|-----------|------|
| スタート | `sub_stage_1679654663853` | 登録直後 / 未着手 |
| 開発中です | `sub_stage_1679654941472` | コード書いてる最中 |
| テスト中 | `sub_stage_1679655004324` | 動作確認・レビュー |
| 公開待ち | `sub_stage_1679655030923` | デプロイ/リリース待ち |
| 終了 | `sub_stage_1679655085909` | 完了 or アーカイブ |
| プロダクトレビュー待ち | `sub_stage_1679654845402` | P2再開判断中 |

---

## フィールドリファレンス

| field_key | 名前 | 型 | 値の例 |
|-----------|------|-----|--------|
| `name` | タイトル | text | `[tools] mergegate — ...` |
| `priority` | 優先順位 | select | `0`=P0, `1`=P1, `2`=P2 |
| `work_item_status` | ステータス | select | 上記ステータス参照 |
| `description` | 詳細 | markdown | GitHub URL, ローカルパス等 |
| `schedule` | スケジュール期間 | schedule | `[開始ms, 終了ms]` |
| `tags` | ラベル | multi-select | 自由追加可 |
| `owner` | 作成者 | user | — |
| `current_status_operator` | 現在の担当者 | multi-user | — |
| `template` | テンプレート | — | `334993`（固定） |

---

## 新規プロジェクト登録手順

```
1. ToolSearch("select:mcp__lark-project__create_workitem")

2. create_workitem(
     project_key="69dbca561543d1dedeb3c926",
     work_item_type="story",
     fields=[
       {field_key: "template", field_value: "334993"},
       {field_key: "name", field_value: "[カテゴリ] プロジェクト名 — 一行説明"},
       {field_key: "priority", field_value: "0"},  // 0=P0, 1=P1, 2=P2
       {field_key: "description", field_value: "## 概要\n...\n## リポジトリ\n- GitHub: ...\n- ローカル: ..."}
     ]
   )

3. 対応するカテゴリビューに追加:
   update_fixed_view(view_id, work_item_id_list に追加)
```

### タイトル命名規則

```
[カテゴリ] リポジトリ名 — 日本語一行説明

カテゴリ: platform / products / tools / voice / ops / content / courses / plugins / personal / other
```

---

## 週次レビュー手順

```
1. P0一覧を取得:
   search_by_mql → WHERE `priority` = 'P0'

2. 各プロジェクトの最終コミットを確認:
   git -C ~/dev/{category}/{name} log -1 --format='%ar'

3. 2週間以上触っていない P0 → P1 に降格:
   update_field(work_item_id, field_key="priority", field_value="1")

4. 直近1週間にコミットがある P1 → P0 に昇格:
   update_field(work_item_id, field_key="priority", field_value="0")

5. ビューの更新:
   update_fixed_view で該当ビューのwork_item_id_listを更新
```

---

## MQL クイックリファレンス

### 基本構文

```sql
SELECT `field1`, `field2`
FROM `製品開発`.`開発要件`
WHERE `条件` = '値'
[ORDER BY `field` [ASC|DESC]]
[LIMIT [offset,] count]
```

- `SELECT *` 不可。フィールド明示必須
- フィールド名はバッククォート必須
- 文字列はシングルクォート
- `LIKE` は `%キーワード%` 形式（`[` `]` は使用不可）

### よく使うパターン

```sql
-- P0のみ
WHERE `priority` = 'P0'

-- 開発中
WHERE `work_item_status` = '開発中です'

-- 名前検索
WHERE `name` like '%mergegate%'

-- 今週更新
WHERE RELATIVE_DATETIME_BETWEEN(`updated_at`, 'past', '7d')

-- 全件取得
WHERE `priority` is not null
```

### 関数

| 関数 | 用途 |
|------|------|
| `current_login_user()` | 自分 |
| `RELATIVE_DATETIME_BETWEEN(f, 'past', 'Nd')` | 過去N日 |
| `RELATIVE_DATETIME_EQ(f, 'today')` | 今日 |
| `array_contains(f, 'val')` | 配列に含む |
| `status_time('状態名')` | 状態遷移時刻 |

---

## ツール一覧

### 必須ツール（先にToolSearchでロード）

| ツール | 用途 |
|--------|------|
| `search_by_mql` | MQL検索（メイン） |
| `list_todo` | 待办・今週タスク |
| `create_workitem` | プロジェクト登録 |
| `update_field` | フィールド更新（優先度変更等） |
| `transition_state` | ステータス遷移 |
| `create_fixed_view` | ビュー作成 |
| `update_fixed_view` | ビュー更新 |
| `add_comment` | コメント追加 |

### 参照系（必要時のみ）

| ツール | 用途 |
|--------|------|
| `search_project_info` | 空間情報 |
| `list_workitem_types` | ワークアイテム種別 |
| `list_workitem_field_config` | フィールド定義 |
| `get_workitem_brief` | 概要取得 |
| `get_transitable_states` | 遷移可能状態 |
| `get_view_detail` | ビュー詳細 |

---

---

## LARC Task OS 連携

> 詳細は `docs/task-os-template.md` 参照

### LARC ↔ Meegle ステータスマッピング

| LARC アクション | Meegle state_key | ステータス名 |
|---|---|---|
| enqueue（受付） | `sub_stage_1679654663853` | スタート |
| run-once（着手） | `sub_stage_1679654941472` | 開発中です |
| done（完了） | `sub_stage_1679655085909` | 終了 |
| fail（失敗） | `sub_stage_1679654845402` | プロダクトレビュー待ち |

### done/fail 時の3ステップ

```
1. larc ingress done --queue-id <id> --note "<内容>"
2. add_comment(project_key, work_item_id, "[LARC完了] <内容>")
3. transition_state(project_key, work_item_id, state_key)
```

### コンテキスト復元（セッション開始時）

```
1. search_by_mql → P0一覧取得
2. description / comments → コンテキスト文書抽出
3. larc memory search → 直近14日の関連メモリ
4. git log → 最終コミット日時
5. → 優先順位リスト → 音声報告
```

---

## 運用ドキュメント

- Task OS テンプレート: `docs/task-os-template.md`
- プレイブック: `~/dev/ops/lark-project-registration-playbook.md`
- 運用ガイド: `~/dev/ops/lark-project-ops-guide.md`
