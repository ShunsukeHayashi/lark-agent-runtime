# Purchase Request Example

経費精算ではなく、購買申請や小さな稟議を想定した承認サンプルです。

## 想定テンプレート

- テンプレート名: `Sandbox Purchase Request`
- 入力項目:
  - `item_name`
  - `reason`
  - `amount`
  - `needed_by`
- 承認ノード:
  - 1 段承認

この例は「何を買うか」「なぜ必要か」を明示したいテンプレート向けです。

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
  --user-id ou_a832c0fb41861056c9dc0d9789c69b88 \
  --form-file ./approval-work/form.json \
  --payload-file ./approval-work/extra.json
```

## 4. live

```bash
scripts/approval-check.sh \
  --approval-code YOUR_APPROVAL_CODE \
  --user-id ou_a832c0fb41861056c9dc0d9789c69b88 \
  --form-file ./approval-work/form.json \
  --payload-file ./approval-work/extra.json \
  --live
```
