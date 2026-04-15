
# docs +mention-link（mention_doc による被リンク作成）

> **前置条件：** 先阅读 [`../lark-shared/SKILL.md`](../../lark-shared/SKILL.md)

Larkの相関図（被リンク）を機能させるには `mention_doc` ブロックが必要。
URLをテキストとして貼る（`text_run`）だけでは**被リンクとして認識されない**。

---

## なぜ mention_doc が必要か

| 挿入方法 | 内部ブロック型 | 被リンク認識 |
|---|---|---|
| `lark-cli docs +update` にURLを書く | `text_run` | されない |
| テーブル内にURLを書く | `text_run` | されない |
| `www.larksuite.com` ドメインのURL | `text_run` | されない |
| Lark raw API で `mention_doc` を作成 | `mention_doc` | **される ✅** |

**重要**: lark-cliのmarkdown変換は常に `text_run` を生成する。`mention_doc` は raw Blocks API でのみ作成できる。

---

## Step 1: URLブロックのblock_idを特定する

```bash
lark-cli api GET /open-apis/docx/v1/documents/<doc_id>/blocks \
  --params '{"page_size":200}' | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
for item in d.get('data',{}).get('items',[]):
    if item.get('block_type') == 2:
        for el in item.get('text',{}).get('elements',[]):
            content = el.get('text_run',{}).get('content','')
            if 'larksuite.com/docx/' in content:
                token = content.split('/docx/')[-1].strip()
                print(f'block_id: {item[\"block_id\"]} | token: {token}')
"
```

**注意**: ドキュメントが200ブロックを超える場合は `page_token` でページネーションが必要（下記スクリプト参照）。

---

## Step 2: text_run → mention_doc に置き換える

```bash
lark-cli api PATCH /open-apis/docx/v1/documents/<doc_id>/blocks/<block_id> \
  --data '{
    "update_text_elements": {
      "elements": [
        {
          "mention_doc": {
            "token": "<リンク先のdoc_token>",
            "obj_type": 22,
            "url": "https://<テナント>.jp.larksuite.com/docx/<token>",
            "title": "<ドキュメントのタイトル>"
          }
        }
      ]
    }
  }'
```

**固定値**: `obj_type: 22` = docx（新形式ドキュメント）は必須。省略するとmention_docが正しく作られない。

---

## スクリプト（一括処理）

`scripts/lark-mention-link.py` を使う（実行可能スクリプト）:

```bash
# text_run URLを検出して一覧表示
python3 scripts/lark-mention-link.py scan <doc_id>

# テナント内の全URLをmention_docに変換
python3 scripts/lark-mention-link.py fix <doc_id>

# 全ドキュメントを一括スキャン（broken URL検出）
python3 scripts/lark-mention-link.py audit
```

---

## テナント固定情報（みやびGK）

```
テナントドメイン: miyabi-g-k.jp.larksuite.com
obj_type (docx): 22
URL形式: https://miyabi-g-k.jp.larksuite.com/docx/<token>
```

---

## よくあるミス

| ミス | 結果 |
|---|---|
| `www.larksuite.com` ドメインを使う | text_runになり被リンク不可 |
| テーブル内にURLを書く | text_runになり被リンク不可 |
| `obj_type` を省略する | mention_docが正しく作られない |
| ページネーションなしで大きなドキュメントをスキャン | 後半のブロックを見逃す |

---

## 参考

- [lark-doc-update](lark-doc-update.md) — ドキュメント更新
- [lark-knowledge-graph](../../docs/lark-knowledge-graph-linking.md) — ナレッジグラフ設計ルール
- [scripts/lark-mention-link.py](../../scripts/lark-mention-link.py) — 実行可能スクリプト
