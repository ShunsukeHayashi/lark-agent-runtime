# Minimal Approval Example

承認テンプレートを作成したあと、`larc approve` の live 確認へ進むための最小サンプルです。

## 想定テンプレート

- テンプレート名: `Sandbox Expense Request`
- 入力項目:
  - `title`
  - `amount`
  - `date`
- 承認ノード:
  - 1 段承認

実際の項目名はテンプレート定義に合わせて変わるので、最終的には `larc approve scaffold-package` が生成した内容を優先してください。

## 1. approval_code を使って雛形を作る

```bash
larc approve scaffold-package \
  --approval-code YOUR_APPROVAL_CODE \
  --output-dir ./approval-work
```

## 2. このサンプルを参考に埋める

- [form.json](./form.json)
- [extra.json](./extra.json)

## 3. dry-run

```bash
scripts/approval-check.sh \
  --approval-code YOUR_APPROVAL_CODE \
  --user-id ou_REPLACE_WITH_REQUESTER_OPEN_ID \
  --form-file ./approval-work/form.json \
  --payload-file ./approval-work/extra.json
```

## 4. live

```bash
scripts/approval-check.sh \
  --approval-code YOUR_APPROVAL_CODE \
  --user-id ou_REPLACE_WITH_REQUESTER_OPEN_ID \
  --form-file ./approval-work/form.json \
  --payload-file ./approval-work/extra.json \
  --live
```
