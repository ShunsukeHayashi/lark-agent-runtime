# テーブル設計テンプレート

## テーブル基本情報

```yaml
table_name: "{{テーブル名}}"
category: "マスター" # or "トランザクション"
description: "{{テーブルの説明}}"
```

## フィールド定義

### 主キーフィールド（最左端・必須）

```yaml
- field_name: "{{主キー名}}"
  type: "text" # or "formula"
  is_primary: true
  position: 1 # 最左端
  description: "レコードを一意に識別するフィールド"
  pattern:
    - "直接入力型（マスター）": "会社名", "商品コード"
    - "数式生成型（トランザクション）": "YY月DD日-担当者-ステータス"
```

### 基本フィールド

```yaml
- field_name: "{{フィールド名}}"
  type: "{{型}}"
  description: "{{説明}}"
  options: # single_select/multi_selectの場合
    - "{{選択肢1}}"
    - "{{選択肢2}}"
```

### 識学理論準拠フィールド

```yaml
責任者フィールド:
  - "👤作成者": User型
  - "👥担当者": User型
  - "👑承認者": User型
  - "🎯最終責任者": User型

結果フィールド:
  - "📈売上実績": Currency型
  - "🎯達成率": Percentage型
  - "📊完了件数": Number型
```

## リレーション定義

```yaml
links:
  - target_table: "{{リンク先テーブル名}}"
    link_type: "双方向" # or "単方向"
    lookup_fields:
      - "{{参照するフィールド1}}"
      - "{{参照するフィールド2}}"
    rollup_fields:
      - field: "{{集計するフィールド}}"
        function: "COUNT" # or "SUM", "AVERAGE"
        alias: "{{集計結果の表示名}}"
```

## ビュー定義

```yaml
views:
  - view_name: "{{ビュー名}}"
    view_type: "grid" # or "kanban", "calendar"
    filter:
      field: "{{フィールド名}}"
      operator: "equals" # or "contains", "greater_than"
      value: "{{値}}"
    sort:
      field: "{{ソートフィールド}}"
      order: "asc" # or "desc"
    group_by: "{{グループ化フィールド}}"
```

---

**最終更新**: 2025-10-18
