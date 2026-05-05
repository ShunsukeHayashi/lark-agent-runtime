---
name: invoice-standard
industry: common
description: 標準請求書テンプレ（共通基盤、全業種で使える）
required_fields:
  - invoice_number
  - invoice_date
  - customer_name
  - customer_address
  - items
calculations:
  subtotal: sum(items.amount)
  tax: subtotal * 0.10
  total: subtotal + tax
---

# 請求書

| | |
|---|---|
| 請求書番号 | {{invoice_number}} |
| 請求日 | {{invoice_date}} |
| 支払期限 | {{payment_due}} |

## 請求先

{{customer_name}} 様
{{customer_address}}

## 請求元

合同会社みやび
〒XXX-XXXX
振込先: XXX銀行 XXX支店 XXXX

---

## ご請求明細

| # | 品名 | 数量 | 単価 | 金額 |
|---|------|------|------|------|
{{#each items}}
| {{index}} | {{name}} | {{quantity}} | {{unit_price}} | ¥{{amount}} |
{{/each}}

| | |
|---|---:|
| 小計 | ¥{{subtotal}} |
| 消費税 (10%) | ¥{{tax}} |
| **ご請求金額合計** | **¥{{total}}** |

---

備考: {{note}}

以上、ご確認のほどよろしくお願いいたします。
