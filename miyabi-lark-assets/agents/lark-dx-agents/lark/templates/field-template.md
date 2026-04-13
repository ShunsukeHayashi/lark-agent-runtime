# フィールド設計テンプレート

## フィールド基本情報

```yaml
field_name: "{{フィールド名}}"
field_type: "{{型}}"
is_primary: false # 主キーの場合はtrue
is_required: false # 必須の場合はtrue
description: "{{フィールドの説明}}"
```

## フィールドタイプ別設定

### Text（テキスト）

```yaml
type: "text"
max_length: 500 # 推奨: 30文字以内
usage: "名称、コード、説明文"
example: "👥会社名", "📋商品コード"
```

### Number（数値）

```yaml
type: "number"
format: "0,0" # カンマ区切り
precision: 2 # 小数点以下桁数
usage: "数量、件数"
example: "📊完了件数", "🎯目標数"
```

### Currency（通貨）

```yaml
type: "currency"
currency_code: "JPY"
usage: "金額、売上"
example: "💰受注金額", "💳MRR"
```

### Date/DateTime（日付・日時）

```yaml
type: "date" # or "datetime"
format: "YYYY-MM-DD"
usage: "期限、開始日、完了日"
example: "📅期限", "📅契約開始日"
```

### Single Select（単一選択）

```yaml
type: "single_select"
options:
  - name: "00.{{選択肢1}}"
    color: "🔵標準青"
  - name: "01.{{選択肢2}}"
    color: "🟡標準黄色"
  - name: "02.{{選択肢3}}"
    color: "💚標準緑"
usage: "ステータス、カテゴリ"
example: "📊ステータス", "🎯顧客タイプ"
```

### Multi Select（複数選択）

```yaml
type: "multi_select"
options:
  - "{{タグ1}}"
  - "{{タグ2}}"
  - "{{タグ3}}"
usage: "タグ、複数属性"
example: "🏷️タグ", "🎯対応地域"
```

### User（ユーザー）

```yaml
type: "user"
allow_multiple: false # 複数選択可否
usage: "担当者、責任者"
example: "👤担当者", "👑承認者"
```

### Link（リンク）

```yaml
type: "link"
link_to:
  table: "{{リンク先テーブル名}}"
  bidirectional: true
usage: "テーブル間連携"
example: "👥顧客", "🔗関連プロジェクト"
```

### Formula（数式）

```yaml
type: "formula"
formula: "{{数式}}"
usage: "計算、条件判定"
examples:
  - 主キー生成: "CONCATENATE(YEAR(作成時間), '年', MONTH(作成時間), '月', DAY(作成時間), '日-', 担当者, '-', ステータス)"
  - 達成率: "実績 / 目標 × 100"
  - 期限判定: "IF(TODAY() > 期限, '超過', '期限内')"
```

### Lookup（参照）

```yaml
type: "lookup"
link_field: "{{リンクフィールド名}}"
lookup_field: "{{参照するフィールド名}}"
usage: "リンク先の情報を参照"
example: "会社名（顧客管理より）"
```

### Rollup（集計）

```yaml
type: "rollup"
link_field: "{{リンクフィールド名}}"
rollup_field: "{{集計するフィールド名}}"
function: "COUNT" # or "SUM", "AVERAGE", "MAX", "MIN"
usage: "リンク先の集計"
example: "案件数", "総売上"
```

## 識学理論準拠フィールド例

### 責任と権限の明確化

```yaml
- "👤作成者": User型
- "👥担当者": User型
- "👑承認者": User型
- "🎯最終責任者": User型
- "👁️確認者": User型
```

### 結果重視の評価

```yaml
- "📈売上実績": Currency型
- "🎯達成率": Percentage型
- "📊完了件数": Number型
- "💰受注金額": Currency型
- "⏱️処理時間": Number型
```

### 階層の明確化

```yaml
ステータスフィールド（Single Select）:
  - "00.申請中" → 🔵標準青
  - "01.主任確認中" → 🔷淡い青
  - "02.課長審査中" → 🟡標準黄色
  - "03.部長承認中" → 🧡標準オレンジ
  - "04.承認完了" → 💚標準緑
  - "99.却下" → ❤️標準赤
```

---

**最終更新**: 2025-10-18
