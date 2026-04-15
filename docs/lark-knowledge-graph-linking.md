# Lark ナレッジグラフ リンキング スキル
### みやびドキュメント群の相関図・被リンク管理

> 作成：2026-04-14
> 目的：Larkドキュメント間を mention_doc で接続し、相関図・情報探索経路を維持するためのルールと手順

---

## なぜこれが重要か

Lark の相関図（被リンク）は `mention_doc` ブロックがないと機能しない。URLテキストでは認識されない。正しく接続されたグラフは：

- **エージェント**が文脈を効率よく辿れる（上位→下位→関連の順で取得）
- **人間**が相関図から全体の構造を一目で把握できる
- **新ドキュメント追加時**にどこに繋ぐべきかが明確になる

---

## グラフ構造ルール（4層 + リンク種別）

### 4層アーキテクチャ

```
Layer 0：技術基盤    ← LARCの実装が裏付ける根拠
    ↓
Layer 1：戦略        ← なぜ・誰に・どこへ（中心ハブ）
    ↓
Layer 2：業務ツール  ← どうやって届けるか（順序あり）
    ↓
Layer 3：発信        ← 外の世界への出口（連動あり）

全層 → インデックス  ← 迷ったら戻る地図
```

### リンク種別（必ず意味を持たせる）

| 種別 | 方向 | 見出しラベル |
|---|---|---|
| 根拠リンク | 下位 → 上位 | `▼ このドキュメントの根拠` |
| 定義リンク | 上位 → 下位 | `▼ ここから生まれたもの` |
| 順序リンク | 前 → 後 | `▼ 次のステップ` / `▼ 前のステップ` |
| 連動リンク | 横 → 横（同層） | `▼ 連動コンテンツ` |
| 帰還リンク | 全ドキュメント → INDEX | `▼ インデックスに戻る` |

### ルール一覧

```
ルール1：各ドキュメントは必ず「上の層」へのリンクを持つ
ルール2：Layer 2内の順序関係は必ずリンクで表現する（診断→提案書）
ルール3：発信コンテンツ（Layer 3）は根拠ドキュメントへのリンクを持つ
ルール4：全ドキュメントにINDEXへの帰還リンクを入れる
ルール5：新ドキュメントを追加したら必ずINDEXを更新する
ルール6：リンクは必ずmention_docで作成する（URLテキスト不可）
```

---

## mention_doc の作り方（技術手順）

### Step 1：URLブロックのblock_idを特定

```python
import subprocess, json

def get_url_blocks(doc_id):
    result = subprocess.run(
        ["lark-cli", "api", "GET",
         f"/open-apis/docx/v1/documents/{doc_id}/blocks",
         "--params", '{"page_size":200}'],
        capture_output=True, text=True
    )
    d = json.loads(result.stdout)
    found = []
    for item in d.get("data", {}).get("items", []):
        if item.get("block_type") == 2:
            for el in item.get("text", {}).get("elements", []):
                content = el.get("text_run", {}).get("content", "")
                if "miyabi-g-k.jp.larksuite.com/docx/" in content:
                    token = content.split("/docx/")[-1].strip()
                    found.append((item["block_id"], token))
    return found
```

### Step 2：text_run → mention_doc に変換

```python
TENANT = "https://miyabi-g-k.jp.larksuite.com/docx"

def patch_mention(doc_id, block_id, token, title):
    body = json.dumps({
        "update_text_elements": {
            "elements": [{
                "mention_doc": {
                    "token": token,
                    "obj_type": 22,          # docx固定
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
    resp = json.loads(result.stdout)
    return resp.get("code") == 0
```

### Step 3：全ドキュメントに一括適用

```python
DOCS = {
    "TOKEN": "タイトル",
    # ... 全ドキュメントのマッピング
}

for doc_id in DOCS:
    for block_id, token in get_url_blocks(doc_id):
        if token in DOCS:
            ok = patch_mention(doc_id, block_id, token, DOCS[token])
            print(f"{'✓' if ok else '✗'} {DOCS[doc_id]} → {DOCS[token]}")
```

---

## 定期クリーンアップ手順

### クリーンアップが必要なタイミング

- 新しいドキュメントを追加した
- ドキュメントを削除・統合した
- リンク切れが発生した（被リンクが表示されなくなった）
- 3ヶ月ごとの定期見直し

### クリーンアップチェックリスト

```
[ ] INDEXドキュメントに全ドキュメントが登録されているか
[ ] 全ドキュメントにINDEXへの帰還リンクがあるか
[ ] 全リンクがtext_runではなくmention_docになっているか
[ ] 削除されたドキュメントへのリンクが残っていないか
[ ] 新ドキュメントの層（Layer 0〜3）が正しく設定されているか
[ ] 順序関係（診断→提案書など）が維持されているか
```

### text_run 混入の検出スクリプト

```python
def find_broken_links(doc_id):
    """mention_docではなくtext_runになっているURLを検出"""
    result = subprocess.run(
        ["lark-cli", "api", "GET",
         f"/open-apis/docx/v1/documents/{doc_id}/blocks",
         "--params", '{"page_size":200}'],
        capture_output=True, text=True
    )
    d = json.loads(result.stdout)
    broken = []
    for item in d.get("data", {}).get("items", []):
        if item.get("block_type") == 2:
            for el in item.get("text", {}).get("elements", []):
                content = el.get("text_run", {}).get("content", "")
                if "larksuite.com/docx/" in content:
                    broken.append({
                        "block_id": item["block_id"],
                        "url": content.strip()
                    })
    return broken

# 全ドキュメントをスキャン
for doc_id, title in DOCS.items():
    broken = find_broken_links(doc_id)
    if broken:
        print(f"⚠️  {title}: {len(broken)}個のtext_run URLを検出")
        for b in broken:
            print(f"   block_id: {b['block_id']}")
    else:
        print(f"✓ {title}: クリーン")
```

---

## みやびナレッジグラフ 現在の構成（2026-04-14）

### ドキュメント一覧（全11件）

| Layer | ドキュメント | doc_id |
|---|---|---|
| INDEX | 【インデックス】みやびナレッジグラフ — 地図 | CG26dL5geo7TCSxoAUGjLbDRpsc |
| -1 | SOUL — エージェントアイデンティティ・原則 | PsYzdraTioQaSyxMw1njEGfmpse |
| -1 | USER — ユーザープロフィール | JhovdiWUuoSEN3xX9JgjAPzwpff |
| -1 | MEMORY — 長期記憶 | LJoLd8L25oL00vxrUYTjdlR5p3f |
| -1 | HEARTBEAT — システム現在状態 | BtB6dDp5VoTXwmxeJUhj6uXtp6b |
| 0 | LARC技術基盤 — permission-first設計の根拠 | VHvDdNpUjo2jKAxbBfPjSiBnp3f |
| 1 | みやびAI導入支援事業 — 戦略ナレッジベース | JfuadlXTmoVOloxU60sjpleApAh |
| 2 | AI業務導入 権限設計診断シート | IGcVdyGb6ozLaLx9MKHjgEsdpsg |
| 2 | AIエージェント導入支援 提案書テンプレート | MCAfdZQ3LopTV8xPqGrj0LxspBf |
| 3 | note記事下書き — AIに鍵を全部渡していませんか | RDctdO04Vo4IqdxwqyrjFP69pcg |
| 3 | X投稿スレッド案 — note記事連動 | UeZKd12q0oudDVxpfGYjHe0Vp5b |

※ 除外（テスト/評価用）：LARC要件テスト / LARC-eval-test / LARC-eval-1776113139

### エッジ一覧（方向・種別付き、全39本）

```
INDEX → SOUL        [定義：Layer -1]
INDEX → USER        [定義：Layer -1]
INDEX → MEMORY      [定義：Layer -1]
INDEX → HEARTBEAT   [定義：Layer -1]
INDEX → TECH        [定義：Layer 0]
INDEX → STRAT       [定義：Layer 1]
INDEX → DIAG        [定義：Layer 2]
INDEX → PROP        [定義：Layer 2]
INDEX → NOTE        [定義：Layer 3]
INDEX → XPOST       [定義：Layer 3]

SOUL      → USER        [順序：Disclosure Chain ①→②]
SOUL      → TECH        [根拠：技術的実装元]
SOUL      → INDEX       [帰還]

USER      → SOUL        [順序：前のステップ]
USER      → MEMORY      [順序：Disclosure Chain ②→③]
USER      → INDEX       [帰還]

MEMORY    → USER        [順序：前のステップ]
MEMORY    → HEARTBEAT   [順序：Disclosure Chain ③→④]
MEMORY    → INDEX       [帰還]

HEARTBEAT → MEMORY      [順序：前のステップ]
HEARTBEAT → STRAT       [連携：現在状態→戦略]
HEARTBEAT → INDEX       [帰還]

TECH  → SOUL        [定義：読み込むDisclosure Chain]
TECH  → STRAT       [定義：根拠を使うもの]
TECH  → INDEX       [帰還]

STRAT → TECH        [根拠]
STRAT → SOUL        [文脈基盤]
STRAT → HEARTBEAT   [最新状態参照]
STRAT → DIAG        [定義：業務ツール]
STRAT → PROP        [定義：業務ツール]
STRAT → NOTE        [定義：発信]
STRAT → XPOST       [定義：発信]
STRAT → INDEX       [帰還]

DIAG  → STRAT       [根拠]
DIAG  → PROP        [順序：次のステップ]
DIAG  → INDEX       [帰還]

PROP  → STRAT       [根拠]
PROP  → DIAG        [順序：前のステップ]
PROP  → INDEX       [帰還]

NOTE  → STRAT       [根拠]
NOTE  → TECH        [根拠]
NOTE  → XPOST       [連動]
NOTE  → INDEX       [帰還]

XPOST → STRAT       [根拠]
XPOST → NOTE        [連動]
XPOST → INDEX       [帰還]
```

### テナント固定情報

```
テナントドメイン: miyabi-g-k.jp.larksuite.com
フォルダトークン: WRf8fJaN9lW35vdabukj8z9Epsc
obj_type (docx): 22
```

---

## よくあるミス（再掲）

| ミス | 被リンク認識 |
|---|---|
| `www.larksuite.com` ドメイン | ✗ されない |
| URLをテキストとして貼る | ✗ されない |
| テーブル内にURLを書く | ✗ されない |
| lark-cli markdown のURLは全て text_run になる | ✗ されない |
| `mention_doc` ブロックを raw API で作成 | ✓ される |
