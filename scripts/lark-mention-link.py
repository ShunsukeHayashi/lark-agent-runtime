#!/usr/bin/env python3
"""
lark-mention-link.py
====================
Lark ドキュメントの text_run URL を mention_doc に変換するスクリプト。
被リンク（相関図）として認識されるには mention_doc ブロックが必要。

使い方:
    python3 scripts/lark-mention-link.py scan <doc_id>   # URLを検出して一覧表示
    python3 scripts/lark-mention-link.py fix <doc_id>    # mention_docに変換
    python3 scripts/lark-mention-link.py audit           # 全ドキュメントをスキャン

テナント設定:
    TENANT = "https://your-tenant.jp.larksuite.com/docx"
    OBJ_TYPE = 22  # docx固定
"""

import json
import os
import subprocess
import sys

# ===== テナント設定 =====
TENANT = os.getenv("LARK_MENTION_TENANT_URL", "https://your-tenant.jp.larksuite.com/docx")
OBJ_TYPE = 22  # docx固定

# ===== ドキュメントマップ（必要に応じて置き換える）=====
DOCS = {
    "REPLACE_WITH_INDEX_DOC_TOKEN": "Index document",
    "REPLACE_WITH_SOURCE_DOC_TOKEN": "Source document",
    "REPLACE_WITH_TARGET_DOC_TOKEN": "Target document",
}

# ===== コア関数 =====

def get_all_blocks(doc_id: str) -> list:
    """ページネーション付きで全ブロックを取得する（200ブロック超に対応）"""
    all_items = []
    page_token = None
    while True:
        params = {"page_size": 200}
        if page_token:
            params["page_token"] = page_token
        r = subprocess.run(
            ["lark-cli", "api", "GET",
             f"/open-apis/docx/v1/documents/{doc_id}/blocks",
             "--params", json.dumps(params)],
            capture_output=True, text=True
        )
        if not r.stdout:
            break
        data = json.loads(r.stdout).get("data", {})
        all_items.extend(data.get("items", []))
        page_token = data.get("page_token")
        if not data.get("has_more", False):
            break
    return all_items


def find_text_run_urls(doc_id: str) -> list[tuple[str, str]]:
    """
    text_run になっているLark URL を検出する。
    戻り値: [(block_id, token), ...]
    """
    blocks = get_all_blocks(doc_id)
    found = []
    for item in blocks:
        if item.get("block_type") == 2:
            for el in item.get("text", {}).get("elements", []):
                content = el.get("text_run", {}).get("content", "")
                if "larksuite.com/docx/" in content:
                    token = content.split("/docx/")[-1].strip()
                    found.append((item["block_id"], token))
    return found


def patch_mention(doc_id: str, block_id: str, token: str, title: str) -> bool:
    """
    text_run ブロックを mention_doc に変換する。
    戻り値: True = 成功, False = 失敗
    """
    body = json.dumps({
        "update_text_elements": {
            "elements": [{
                "mention_doc": {
                    "token": token,
                    "obj_type": OBJ_TYPE,
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
    return resp.get("code") == 0


def count_mention_docs(doc_id: str, expected_tokens: list[str]) -> tuple[int, int]:
    """
    指定トークンへの mention_doc が何個あるかカウントする。
    戻り値: (見つかった数, 期待数)
    """
    blocks = get_all_blocks(doc_id)
    found_tokens = set()
    for item in blocks:
        if item.get("block_type") == 2:
            for el in item.get("text", {}).get("elements", []):
                m = el.get("mention_doc", {})
                if m.get("token") in expected_tokens:
                    found_tokens.add(m["token"])
    return len(found_tokens), len(expected_tokens)


# ===== CLI コマンド =====

def cmd_scan(doc_id: str):
    """doc_idのドキュメントにある text_run URL を一覧表示"""
    title = DOCS.get(doc_id, doc_id)
    print(f"📄 スキャン: {title}")
    found = find_text_run_urls(doc_id)
    if not found:
        print("  ✓ text_run URLなし（クリーン）")
    else:
        print(f"  ⚠️  {len(found)}個のtext_run URLを検出:")
        for block_id, token in found:
            linked_title = DOCS.get(token, f"不明({token[:8]}...)")
            print(f"     block_id: {block_id}")
            print(f"     → {linked_title}")


def cmd_fix(doc_id: str):
    """doc_idのドキュメントにある text_run URL を mention_doc に変換"""
    title = DOCS.get(doc_id, doc_id)
    print(f"🔧 修正: {title}")
    found = find_text_run_urls(doc_id)
    if not found:
        print("  ✓ 修正対象なし")
        return

    success = 0
    fail = 0
    for block_id, token in found:
        linked_title = DOCS.get(token, token)
        ok = patch_mention(doc_id, block_id, token, linked_title)
        status = "✓" if ok else "✗"
        print(f"  {status} {title[:20]} → {linked_title[:30]}")
        if ok:
            success += 1
        else:
            fail += 1

    print(f"\n  完了: {success}成功 / {fail}失敗")


def cmd_audit():
    """全ドキュメントをスキャンして text_run URL を検出・レポート"""
    if any(key.startswith("REPLACE_WITH_") for key in DOCS):
        print("DOCS マップを実テナント向けに設定してから audit を実行してください。")
        sys.exit(1)
    print("=" * 60)
    print("Lark ナレッジグラフ 監査レポート")
    print("=" * 60)

    total_broken = 0
    for doc_id, title in DOCS.items():
        broken = find_text_run_urls(doc_id)
        status = "✓" if not broken else f"⚠️  {len(broken)}個"
        print(f"{status:8} {title[:40]}")
        total_broken += len(broken)

    print("=" * 60)
    if total_broken == 0:
        print("✓ 全ドキュメントクリーン（被リンク正常）")
    else:
        print(f"⚠️  合計 {total_broken}個のtext_run URLを検出")
        print("  → `python3 scripts/lark-mention-link.py fix <doc_id>` で修正")


def cmd_fix_all():
    """全ドキュメントの text_run URL を一括修正"""
    if any(key.startswith("REPLACE_WITH_") for key in DOCS):
        print("DOCS マップを実テナント向けに設定してから fix-all を実行してください。")
        sys.exit(1)
    print("🔧 全ドキュメント一括修正")
    total_success = 0
    total_fail = 0
    for doc_id in DOCS:
        found = find_text_run_urls(doc_id)
        for block_id, token in found:
            linked_title = DOCS.get(token, token)
            ok = patch_mention(doc_id, block_id, token, linked_title)
            if ok:
                total_success += 1
            else:
                total_fail += 1
                print(f"  ✗ 失敗: {DOCS[doc_id]} → {linked_title}")

    print(f"\n完了: {total_success}成功 / {total_fail}失敗")


# ===== エントリポイント =====

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "scan":
        if len(sys.argv) < 3:
            print("使い方: python3 scripts/lark-mention-link.py scan <doc_id>")
            sys.exit(1)
        cmd_scan(sys.argv[2])

    elif cmd == "fix":
        if len(sys.argv) < 3:
            print("使い方: python3 scripts/lark-mention-link.py fix <doc_id>")
            sys.exit(1)
        cmd_fix(sys.argv[2])

    elif cmd == "fix-all":
        cmd_fix_all()

    elif cmd == "audit":
        cmd_audit()

    else:
        print(f"不明なコマンド: {cmd}")
        print("使い方: scan | fix | fix-all | audit")
        sys.exit(1)


if __name__ == "__main__":
    main()
