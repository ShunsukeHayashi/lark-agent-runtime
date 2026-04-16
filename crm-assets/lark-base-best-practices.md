# Lark Base ベストプラクティス — みやびAI標準

> **適用範囲**: LARC Agent Runtime と連携する全 Lark Base  
> **設計方針**: LARC が追加API呼び出しなしにコンテキストを把握できる構造を最優先とする

---

## 1. 主キー設計（セマンティックID）

### 設計思想

Lark Base の先頭フィールドは **人間とLARCエージェントの両方が一目で文脈を理解できるセマンティックID** として設計する。

IDそのものが「種別・時系列・連番・内容」を持つことで、LARCのLookup回数を最小化し、人間も追加操作なしに把握できる。

### フォーマット

```
{種別コード}-{YYYYMM}-{NNN} | {文脈サマリー}
```

| 要素 | 役割 | 例 |
|------|------|----|
| 種別コード（3〜5文字大文字） | LARCのルーティングキー | `CNT` `ORG` `DEAL` |
| YYYYMM | 時系列ソートの基準 | `202504` |
| NNN（3桁連番） | 月内ユニーク保証 | `001` `002` |
| ` \| ` | 構造部と文脈部の区切り（固定） | — |
| 文脈サマリー | 人間・LLM向けの自然言語情報 | `窪内優也` `LOP` |

### 種別コード一覧（SFA/CRM）

| テーブル | 種別コード | 例 |
|---------|-----------|-----|
| contacts | `CNT` | `CNT-202504-001 \| 窪内優也` |
| companies | `ORG` | `ORG-202504-001 \| LOP` |
| deals | `DEAL` | `DEAL-202504-001 \| LOP Consortium...` |
| activities | `ACT` | `ACT-202504-001 \| 4/15 外部MTG` |
| lead_scores | `SCORE` | `SCORE-202504-001 \| 窪内優也` |

### 実装方法

先頭フィールドは **Formula 型** で実装する。AutoNumber フィールドを別途作成し参照する。

```
# contacts の例
"CNT-" & TEXT(初回接触日,"YYYYMM") & "-" & TEXT(連番,"000") & " | " & 名前

# フォールバック（初回接触日が空の場合）
"CNT-" & IF(ISBLANK(初回接触日), TEXT(CREATED_TIME(),"YYYYMM"), TEXT(初回接触日,"YYYYMM")) & "-" & TEXT(連番,"000") & " | " & IF(ISBLANK(名前),"(未設定)",名前)
```

**実装手順（API）：**

```bash
# 1. AutoNumber フィールドを追加
lark-cli base +field-create \
  --base-token {BASE_TOKEN} \
  --table-id {TABLE_ID} \
  --json '{"field_name":"連番","type":"auto_number"}'

# 2. 先頭フィールドを Formula 型に変更
lark-cli base +field-update \
  --base-token {BASE_TOKEN} \
  --table-id {TABLE_ID} \
  --field-id {PRIMARY_FIELD_ID} \
  --i-have-read-guide \
  --json '{"name":"ID","type":"formula","property":{"expression":"\"CNT-\" & IF(ISBLANK(初回接触日), TEXT(CREATED_TIME(),\"YYYYMM\"), TEXT(初回接触日,\"YYYYMM\")) & \"-\" & TEXT(連番,\"000\") & \" | \" & IF(ISBLANK(名前),\"(未設定)\",名前)"}}'
```

**注意事項：**

- 月999件以内のテーブルは3桁（`"000"`）。月1,000件超の見込みがある場合は4桁（`"0000"`）を使用する
- フォーミュラ内のフィールド名は `lark-cli base +field-list` で取得した表示名と完全一致させる
- `TEXT()` の書式文字列はLark Base独自仕様（Excel/Google Sheetsと異なる場合がある）
- 先頭フィールドのfield_idは `+field-list` で `is_primary=true` のフィールドから取得する

### LARCでの活用

```bash
# 種別コードだけでワークフロー分岐
if echo "$record_id" | grep -q "^CNT-"; then
  # contacts 処理
elif echo "$record_id" | grep -q "^DEAL-"; then
  # deals 処理
fi

# 月次集計（YYYYMM部分で絞り込み）
larc base search --filter "ID contains '202504'"
```

---

## 2. フィールド命名規則

### 基本原則

| 原則 | 内容 |
|------|------|
| **シンプルな日本語** | 業務担当者が直感的に理解できる表現 |
| **絵文字は使用しない** | API経由での文字列マッチングが不安定になるため |
| **30文字以内** | 表示崩れ防止 |
| **Link フィールド名** | `{参照先テーブル}_Link` 形式（例: `所属会社_Link`） |
| **一貫した用語** | 同じ意味のフィールドは全テーブルで同名 |

### 推奨パターン

```
# 良い例
名前 / 会社名 / 案件名 / タイトル
担当者 / 役職 / 所属会社
ステータス / 優先度 / 備考
所属会社_Link / 関連コンタクト_Link

# 悪い例（使用禁止）
👤作成者 / 📞即時架電 / 🏢経営陣   ← 絵文字 → API不安定
作成者名前 / 担当者の名前           ← 冗長
sts / dept / nm                    ← 略語不統一
```

### 共通フィールド（全テーブル共通で使う場合）

| フィールド名 | 型 | 用途 |
|------------|-----|------|
| `ID` | formula | セマンティックID（先頭・主キー） |
| `連番` | auto_number | IDフォーミュラの参照用 |
| `備考` | text | 自由記述 |
| `作成日時` | created_time | 自動記録 |
| `更新日時` | modified_time | 自動記録 |

---

## 3. ステータス・選択肢の設計規則

### 番号プレフィックス（必須）

全ての select フィールドの選択肢には **2桁の番号プレフィックス** を付ける。

```
00.{ステージ名}
01.{ステージ名}
...
99.{終端・例外}
```

**理由：**
- Lark Base は API で選択肢の表示順序を保証しない
- LARCが `stage >= "02."` のような文字列比較でステージ進行度を判断できる
- 番号で並び順が視覚的に確定する

### SFA/CRM 標準ステージ定義

#### オンボーディングステージ（contacts）

```
00.未開始
01.グループ作成依頼中    ← LARCトリガーポイント
02.グループ作成済
03.ウェルカム送信済
04.ヒアリング中
05.提案済
06.完了
99.離脱
```

#### 商談ステージ（deals）

```
00.初期接触
01.ヒアリング
02.提案
03.見積
04.交渉
05.受注
99.失注
```

#### MAステージ（lead_scores）

```
00.リード
01.MQL
02.SQL
03.商談化
04.顧客
99.離脱
```

#### 活動種別（activities）

```
00.初回接触
01.オンボーディング開始
02.ヒアリング
03.提案
04.フォローアップ
05.契約
99.その他
```

### 色設定ルール

| ステージ位置 | 色 | color値 |
|-------------|-----|---------|
| 開始・初期（00〜01） | 青 | `6` |
| 進行中（02〜04） | オレンジ / 黄 | `1` `2` |
| 完了・成功（05〜06） | 緑 | `4` |
| 終端・例外（99） | 赤 | `0` |
| 保留・その他 | グレー | `10` |

---

## 4. テーブル設計規則

### 基本構造

全テーブルは以下の構成を基本とする：

```
[0] ID            formula     セマンティックID（先頭・主キー・自動計算）
[1] {主要名称}    text        人間可読な主要識別子（例: 名前、会社名）
[2] 連番          auto_number IDフォーミュラの参照用（非表示推奨）
    ...           ...         業務フィールド
    作成日時      created_time 自動記録
    更新日時      modified_time 自動記録
    備考          text         自由記述
```

### Link フィールド規則

```
# 命名: {参照先テーブルの主要名称}_Link
所属会社_Link     → companies テーブルへのリンク
関連コンタクト_Link → contacts テーブルへのリンク
関連案件_Link     → deals テーブルへのリンク

# 対応するテキスト参照（Lookup 代替）
所属会社          → text型。Link先の表示名を手動/LARC更新
関連コンタクト    → text型。同上
```

### エンティティリレーション

```
companies ←── contacts ←── lead_scores
               │
               ├── deals ──→ companies
               │
               └── activities ──→ deals
```

---

## 5. ワークフロー自動化規則

### API vs GUI の境界

| 操作 | 方法 | コマンド |
|------|------|---------|
| ワークフロー枠の作成 | API（lark-cli） | `+workflow-create` |
| ワークフローの有効化 | API（lark-cli） | `+workflow-enable` |
| トリガー条件の設定 | **GUI必須** | — |
| アクション詳細の設定 | **GUI必須** | — |

> `lark-cli +workflow-create` はワークフロー名のみ作成可能。トリガー・アクションの詳細設定はLark Base GUI上での操作が必要。

### LARC Daemon パターン（推奨）

Lark Base オートメーションの代替として LARC daemon がポーリングで処理する：

```bash
# ステータス変化をトリガーにする場合
# 1. Lark Base オートメーション（GUI）: ステータスフィールドを更新するだけ
# 2. LARC daemon: 該当ステータスのレコードを検出 → 処理 → ステータスを次へ更新

larc daemon start --agent main --interval 300   # 5分ポーリング
```

**適用場面：**
- グループチャット作成・メッセージ送信（Lark automation APIで不可能な処理）
- 複数テーブルの横断更新
- 外部API連携
- カスタムロジック（パーソナライズメッセージ等）

---

## 6. LARC連携規則

### フィールド命名（LARC処理用）

LARCが読み書きするフィールドは以下の命名規則に従う：

```
{処理名}フラグ     checkbox   LARCのトリガーポイント（例: オンボーディング開始フラグ）
{処理名}チャット_ID text       LARCが作成したチャットのID
{処理名}ステージ   select     00.〜 番号プレフィックス付き
{処理名}開始日時   datetime   LARCが記録するタイムスタンプ
{処理名}完了日時   datetime   LARCが記録するタイムスタンプ
処理済             checkbox   二重処理防止フラグ（activitiesに必須）
```

### LARC からの標準操作

```bash
# レコード読み取り
lark-cli base +record-list \
  --base-token {BASE_TOKEN} \
  --table-id {TABLE_ID}

# レコード更新（ステージ遷移）
lark-cli base +record-batch-update \
  --base-token {BASE_TOKEN} \
  --table-id {TABLE_ID} \
  --json '{"record_id_list":["recXXX"],"patch":{"オンボーディングステージ":"02.グループ作成済"}}'

# グループ作成
lark-cli im +chat-create \
  --name "{グループ名}" \
  --users "{open_id}" \
  --owner "{オーナー open_id}"

# メッセージ送信
lark-cli im +messages-send \
  --chat-id "{chat_id}" \
  --type text \
  --content "{メッセージ}"
```

### activities テーブルへの操作ログ記録（必須）

LARCが実行した全操作は `activities` テーブルに記録する：

```bash
lark-cli base +record-upsert \
  --base-token {BASE_TOKEN} \
  --table-id {ACTIVITIES_TABLE_ID} \
  --json '{
    "fields": {
      "タイトル": "ACT-YYYYMM-NNN | {操作内容}",
      "活動種別": "01.オンボーディング開始",
      "コンタクト_Link": [{"id": "{record_id}"}],
      "内容サマリー": "{実行内容}",
      "処理済": true
    }
  }'
```

---

## 7. 実装チェックリスト

### テーブル作成時

- [ ] 先頭フィールドが Formula 型でセマンティックIDを生成しているか
- [ ] `連番`（auto_number）フィールドが存在するか
- [ ] セマンティックIDのフォーマット `{CODE}-{YYYYMM}-{NNN} | {サマリー}` が正しく生成されるか
- [ ] フィールド名に絵文字が含まれていないか
- [ ] select フィールドの選択肢に番号プレフィックス（`00.`〜）が付いているか

### Link フィールド設定時

- [ ] フィールド名が `{参照先}_Link` 形式か
- [ ] 双方向リンクが両テーブルに表示されているか
- [ ] `+field-list` で両テーブルのリンクfield_idが取得できるか

### LARC連携時

- [ ] LARCトリガーフィールド（フラグまたはステージ）が定義されているか
- [ ] `処理済` フラグで二重処理が防止されているか
- [ ] 全操作が `activities` テーブルに記録されるか

---

## 8. やらないこと（禁止事項）

| 禁止 | 理由 |
|------|------|
| フィールド名への絵文字 | API文字列マッチングの不安定化 |
| 組織階層（部長承認/課長確認）の設計 | 現フェーズ不要。チーム拡大時に再検討 |
| select 選択肢の番号プレフィックスなし | 表示順序がAPIで保証されない |
| 推測でフィールド名を指定 | `+field-list` で確認してから使用する |
| WikiノードトークンをBase tokenとして使用 | 必ずobj_tokenを取得して使用 |
| ダッシュボードブロックのCLI並列作成 | 順番依存のため直列実行が必要 |

---

**バージョン**: 1.0  
**作成日**: 2026-04-16  
**適用プロジェクト**: みやびAI SFA/CRM (Base token: `Zpl6bfi0uaoRBosu4KPjrWROpwh`)

---

## 9. 実装上の注意事項（API検証済み）

### 連番フィールドの実装

| アプローチ | 問題 | 推奨 |
|-----------|------|------|
| `auto_number` 型 | スタイル変更後にフォーミュラから参照不可になるバグあり | ❌ 使用しない |
| `text` 型（手動/LARC管理） | フォーミュラから正常に参照できる | ✅ 推奨 |

**`連番` フィールドは `text` 型で実装すること**。`auto_number` は表示用に使ってもよいが、フォーミュラ参照には使わない。

```bash
# 連番フィールドの作成（text型）
lark-cli base +field-create \
  --base-token {BASE_TOKEN} --table-id {TABLE_ID} \
  --json '{"field_name":"連番","type":"text"}'

# 新レコード作成時にLARCが連番を採番
# 当月の既存レコード数 + 1 でゼロパディング
COUNT=$(lark-cli base +record-list ... | python3 -c "カウント処理")
SEQ=$(printf "%03d" $((COUNT + 1)))
```

### CREATED_TIME() 非対応

フォーミュラフィールドで `CREATED_TIME()` は動作しない（値がnullになる）。

代替策：
- レコード作成時に日付フィールド（`初回接触日`等）を必須入力とする
- フォールバックは固定文字列 `"000000"` ではなく入力を必須化する運用ルールで対応

### フォーミュラ構文

フォーミュラ内のフィールド参照は **必ずブラケット `[フィールド名]` を使用** すること。

```
# 正: [初回接触日], [名前], [連番]
# 誤: 初回接触日, 名前, 連番
```

**バージョン更新**: 1.1（2026-04-16、API検証結果を追記）
