# base2pdf テンプレート集

`larc base2pdf` で使うテンプレート。Markdown + YAML frontmatter で記述。

## ディレクトリ構成

```
templates/base2pdf/
├── README.md (このファイル)
├── common/                  # 全業種共通テンプレ
│   ├── invoice-standard.md  # 標準請求書
│   ├── quote-standard.md    # 標準見積書 (TODO)
│   ├── contract-nda.md      # NDA (TODO)
│   └── report-monthly.md    # 月次報告書 (TODO)
├── manufacturing/           # 製造業 (TODO)
├── real-estate/             # 不動産業 (TODO)
├── salon/                   # サロン業 (TODO)
├── shigyo/                  # 士業 (TODO)
├── restaurant/              # 飲食業 (TODO)
├── used-car/                # 中古車販売業 (TODO)
└── event/                   # イベンター (TODO)
```

ユーザー追加テンプレは `~/.larc/templates/base2pdf/<industry>/` に置かれ、同名なら built-in より優先。

## テンプレ作成方法

3 通り:

### A. Lark Doc から取り込み（最も簡単・WYSIWYG）

1. Lark Doc を新規作成
2. 帳票のレイアウトを書く（罫線・装飾・ロゴ も Doc 機能で）
3. データを差し込みたい場所に `{{customer_name}}` のように書くだけ
4. 保存して URL コピー
5. `larc base2pdf install-template --from-doc <url> --name <name> --industry <industry>`

`{{var}}` を自動検出して `required_fields` 生成。`calculations` を後から追加したければ `~/.larc/templates/base2pdf/<industry>/<name>.md` を直接編集。

### B. AI に作ってもらう

Claude Code で `Skill base2pdf-agent` を起動 → 「請求書テンプレ作って。明細あって税込・税抜両方表示。振込先欄入れて」のように自然言語で依頼。Claude が Markdown 生成 → `install-template --from-stdin` で取り込み。

### C. 手書き .md ファイル

```bash
larc base2pdf install-template --file ./my-template.md --name my-invoice --industry common
```

## テンプレ仕様

### frontmatter

```yaml
---
name: invoice-standard         # テンプレ名（generate --template <ここ>）
industry: common               # 業種カテゴリ
description: 説明文（list-templates に表示）
required_fields:               # 必須フィールド（実装は後続、現状はドキュメント）
  - invoice_number
  - customer_name
  - items
calculations:                  # 計算式（評価順序保持、Python 3.7+ dict insertion order）
  subtotal: sum(items.amount)
  tax: subtotal * 0.10
  total: subtotal + tax
---
```

### 本文 Markdown 記法

| 記法 | 意味 | 例 |
|------|------|-----|
| `{{var}}` | 変数置換 | `{{customer_name}}` |
| `{{nested.field}}` | ネスト参照 | `{{address.zip}}` |
| `{{#each list}} ... {{/each}}` | リスト展開 | 明細行ループ |
| `{{calc_var}}` | calculation 結果 | `{{total}}` |

### calculation 記法

| 形式 | 例 | 意味 |
|------|-----|------|
| `sum(list.field)` | `sum(items.amount)` | リスト合計 |
| `var * number` | `subtotal * 0.10` | 数値演算 |
| `var + var` | `subtotal + tax` | 変数同士 |
| `var / var` | `total / count` | 除算 |

評価は frontmatter `calculations` の順番。前に定義した変数を後で参照できる。

## サンプル

### 請求書（最小構成）

```markdown
---
name: invoice-minimal
industry: common
description: 最小請求書
required_fields: [invoice_number, customer_name, total]
---

# 請求書 {{invoice_number}}

{{customer_name}} 様

ご請求金額: ¥{{total}}
```

### 請求書（明細 + 税計算）

`templates/base2pdf/common/invoice-standard.md` を参照。

## トラブルシューティング

| 症状 | 原因 | 対処 |
|------|------|------|
| 計算結果が 0 | calculation 式の構文エラー | `describe-template --name X` で frontmatter 確認 |
| 表が崩れる | `{{#each}}` ブロック内の改行が余分 | 1 行 = 1 行にまとめる |
| `--markdown invalid file path` | 古い lark-cli 仕様 | v0.1.0+ では lib/base2pdf.sh 内で対応済 |

## 関連

- LARC Skill: `lark-harness/lib/base2pdf.sh`
- Python レンダラー: `lark-harness/scripts/base2pdf-render.py`
- Claude Skill: `~/.claude/skills/base2pdf-agent/SKILL.md`
