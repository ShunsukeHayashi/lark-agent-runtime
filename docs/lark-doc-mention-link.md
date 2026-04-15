# Lark ドキュメント被リンク（mention_doc）の正しい作り方

> 作成：2026-04-14
> 背景：lark-cli の `docs +update` でURLを貼ってもLarkの相関図・被リンクに反映されなかった問題の根本原因と解決策

---

## 問題の構造

Larkの「被リンク（相関図）」は、ドキュメント内に **`mention_doc` ブロック** が存在するときだけ認識される。

URLをテキストとして貼るだけでは **`text_run`（プレーンテキスト）** として保存され、被リンクとして認識されない。

| 挿入方法 | 内部ブロック型 | 被リンク認識 |
|---|---|---|
| lark-cli `docs +update` にURLを書く | `text_run` | **されない** |
| テーブル内にURLを書く | `text_run` | **されない** |
| `www.larksuite.com` ドメインのURL | `text_run` | **されない** |
| `miyabi-g-k.jp.larksuite.com` ドメインのURL（text_run） | `text_run` | **されない** |
| Lark raw API で `mention_doc` を作成 | `mention_doc` | **される ✅** |

---

## 正しい手順

### Step 1：テナントドメインを確認する

```
https://<テナント名>.jp.larksuite.com/docx/<token>
例：https://miyabi-g-k.jp.larksuite.com/docx/JfuadlXTmoVOloxU60sjpleApAh
```

`www.larksuite.com` ではなく、テナント固有ドメインを使うこと。

### Step 2：既存のtext_runブロックIDを特定する

```bash
lark-cli api GET /open-apis/docx/v1/documents/<doc_id>/blocks \
  --params '{"page_size":50}' | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
for item in d.get('data',{}).get('items',[]):
    if item.get('block_type') == 2:
        for el in item.get('text',{}).get('elements',[]):
            content = el.get('text_run',{}).get('content','')
            if '<テナント>' in content or 'larksuite' in content:
                token = content.split('/docx/')[-1].strip()
                print(f'block_id: {item[\"block_id\"]} | token: {token}')
"
```

### Step 3：text_runをmention_docに置き換える

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

**`obj_type: 22` = docx（新形式ドキュメント）** は固定値。

### Step 4（複数リンクを一括処理する場合）Python スクリプト

```python
import subprocess, json

TENANT = "https://miyabi-g-k.jp.larksuite.com/docx"

def patch_mention(doc_id, block_id, token, title):
    body = json.dumps({
        "update_text_elements": {
            "elements": [{
                "mention_doc": {
                    "token": token,
                    "obj_type": 22,
                    "url": f"{TENANT}/{token}",
                    "title": title
                }
            }]
        }
    })
    result = subprocess.run(
        ["lark-cli", "api", "PATCH",
         f"/open-apis/docx/v1/documents/{doc_id}/blocks/{block_id}",
         "--data", body],
        capture_output=True, text=True
    )
    resp = json.loads(result.stdout) if result.stdout else {}
    return "OK" if resp.get("code") == 0 else resp

# 例
patch_mention(
    doc_id="JfuadlXTmoVOloxU60sjpleApAh",
    block_id="doxjpQMGRInPWQZGgfSchmCdjrc",
    token="IGcVdyGb6ozLaLx9MKHjgEsdpsg",
    title="権限設計診断シート"
)
```

---

## よくあるミス

| ミス | 結果 |
|---|---|
| `www.larksuite.com` ドメインを使う | text_runになり被リンク不可 |
| テーブル内にURLを書く | text_runになり被リンク不可 |
| lark-cli `docs +update` のmarkdownにURLを書く | text_runになり被リンク不可 |
| `obj_type` を省略する | mention_docが正しく作られない可能性がある |
| `title` を省略する | Lark上で「タイトルなし」と表示される |

---

## Lark内部ブロックタイプ早見表

| block_type番号 | 種別 |
|---|---|
| 1 | page（ドキュメント本体） |
| 2 | text |
| 3 | heading1 |
| 4 | heading2 |
| 5 | heading3 |
| 22 | divider |
| mention_doc（inline element） | ドキュメント参照（被リンク対象） |

---

## みやびテナントの固定情報

```
テナントドメイン: miyabi-g-k.jp.larksuite.com
obj_type (docx): 22
URL形式: https://miyabi-g-k.jp.larksuite.com/docx/<token>
```
