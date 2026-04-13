# ワークフロー設計テンプレート

## ワークフロー基本情報

```yaml
workflow_name: "{{ワークフロー名}}"
workflow_type: "alert" # or "approval", "process"
description: "{{ワークフローの説明}}"
```

## トリガー設定

```yaml
trigger:
  type: "{{トリガータイプ}}"
  options:
    - "レコード作成時"
    - "レコード更新時"
    - "フィールド更新時"
    - "定期実行"
    - "手動実行"
  
  condition:
    field: "{{フィールド名}}"
    operator: "{{演算子}}"
    value: "{{値}}"
```

## アクション設定

```yaml
actions:
  - action_type: "{{アクションタイプ}}"
    options:
      - "フィールド値の更新"
      - "通知送信"
      - "レコード作成"
      - "外部連携"
      - "承認リクエスト"
    
    parameters:
      target_field: "{{対象フィールド}}"
      value: "{{設定値}}"
```

## ワークフロータイプ別テンプレート

### 1. アラートワークフロー

```yaml
name: "期限超過アラート"
trigger:
  type: "定期実行"
  schedule: "毎日9時"
condition:
  - field: "期限"
    operator: "less_than"
    value: "TODAY()"
  - field: "ステータス"
    operator: "not_equals"
    value: "完了"
actions:
  - type: "通知送信"
    recipient: "担当者"
    message: "【期限超過】{{タスク名}}の期限が過ぎています。至急対応してください。"
```

### 2. 承認ワークフロー

```yaml
name: "階層的承認プロセス"
trigger:
  type: "フィールド更新時"
  field: "ステータス"

flow:
  - step: 1
    condition:
      field: "ステータス"
      value: "00.申請中"
    action:
      type: "通知送信"
      recipient: "主任"
      message: "新規申請があります。確認してください。"
  
  - step: 2
    condition:
      field: "ステータス"
      value: "01.主任確認中"
    action:
      type: "通知送信"
      recipient: "課長"
      message: "主任確認が完了しました。審査をお願いします。"
  
  - step: 3
    condition:
      field: "ステータス"
      value: "02.課長審査中"
    action:
      type: "通知送信"
      recipient: "部長"
      message: "課長審査が完了しました。最終承認をお願いします。"
  
  - step: 4
    condition:
      field: "ステータス"
      value: "04.承認完了"
    actions:
      - type: "フィールド更新"
        field: "承認日"
        value: "TODAY()"
      - type: "通知送信"
        recipient: "申請者"
        message: "承認が完了しました。"
```

### 3. プロセスワークフロー

```yaml
name: "受注時の自動処理"
trigger:
  type: "フィールド更新時"
  field: "ステータス"
  value: "06.受注確定"

actions:
  - action: "レコード作成"
    target_table: "プロジェクト管理"
    fields:
      プロジェクト名: "{{案件名}}"
      顧客: "{{顧客}}"
      担当PM: "{{担当営業}}"
      プロジェクト金額: "{{受注金額}}"
      ステータス: "00.準備中"
  
  - action: "レコード作成"
    target_table: "売上管理"
    fields:
      年月: "{{YEAR-MONTH}}"
      売上実績: "{{受注金額}}"
  
  - action: "通知送信"
    recipient: "担当PM"
    message: "新規プロジェクトが作成されました。プロジェクト管理テーブルを確認してください。"
```

## エラーハンドリング

```yaml
error_handling:
  on_failure:
    action: "通知送信"
    recipient: "管理者"
    message: "ワークフロー「{{workflow_name}}」でエラーが発生しました。"
  
  retry:
    max_attempts: 3
    delay: 60 # seconds
  
  fallback:
    action: "ログ記録"
    location: "エラーログテーブル"
```

## 実装チェックリスト

- [ ] トリガー条件が明確に定義されているか
- [ ] アクションが正確に設定されているか
- [ ] 通知先が正しく指定されているか
- [ ] エラーハンドリングが適切か
- [ ] テスト実行で正常に動作するか
- [ ] パフォーマンスに問題がないか

---

**最終更新**: 2025-10-18
