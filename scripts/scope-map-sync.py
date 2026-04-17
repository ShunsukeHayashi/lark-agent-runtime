#!/usr/bin/env python3
"""
scope-map-sync.py — scope-map.json と Lark API マトリクス(Base)の照合・同期ツール

Usage:
  python3 scripts/scope-map-sync.py           # 差分レポート表示
  python3 scripts/scope-map-sync.py --fix     # scope-map.json を自動修正
  python3 scripts/scope-map-sync.py --export  # マトリクス全件を JSON 出力
"""

import json
import subprocess
import sys
import os
from collections import defaultdict

BASE_TOKEN = "XYgXbe45faGty9sebpWjw54Tprh"
TABLE_ID   = "tblyj3uXRpKZMBqv"
VIEW_ID    = "vewrMVILb7"

SCOPE_MAP_PATH = os.path.join(
    os.path.dirname(os.path.dirname(__file__)),
    "config", "scope-map.json"
)

# 旧スコープ → 新スコープの既知マッピング
SCOPE_ALIASES = {
    "docs:doc:readonly":       "docs:document:readonly",
    "docs:doc:create":         "docs:document",
    "docs:doc":                "docs:document",
    "wiki:wiki:readonly":      "wiki:space:read",
    "wiki:wiki":               "wiki:node:write",
    "wiki:wiki.node":          "wiki:node:create",
    "drive:drive:readonly":    "drive:drive.metadata:readonly",
    "drive:drive":             "drive:drive.metadata:write",
    "base:record:readonly":    "bitable:app:readonly",
    "base:record:created":     "bitable:app",
    "task:task:readonly":      "task:task:read",
    "task:task:writeonly":     "task:task:write",
    "attendance:record:readonly": "attendance:task:readonly",
}


def fetch_matrix():
    """API マトリクスの全レコードを取得する (col: 0=ID, 1=api_id, 4=min_scope, 5=all_scopes, 10=category, 11=auth_type, 12=larc_support)"""
    all_rows, all_rids = [], []
    offset = 0
    while True:
        r = subprocess.run(
            ["lark-cli", "base", "+record-list",
             "--base-token", BASE_TOKEN,
             "--table-id", TABLE_ID,
             "--view-id", VIEW_ID,
             "--limit", "100", "--offset", str(offset)],
            capture_output=True, text=True
        )
        d = json.loads(r.stdout)
        if not d.get("ok"):
            print(f"ERROR fetching matrix: {d.get('error',{}).get('message','')}")
            sys.exit(1)
        rows = d["data"]["data"]
        rids = d["data"]["record_id_list"]
        all_rows.extend(rows)
        all_rids.extend(rids)
        if len(rows) < 100:
            break
        offset += 100
    return all_rows, all_rids


def build_scope_index(rows):
    """スコープ → API 情報のインデックスを構築"""
    index = defaultdict(list)
    for row in rows:
        api_id   = row[1] or ""
        min_scope = row[4] or ""
        all_scopes = row[5] or ""
        cat      = row[10][0] if isinstance(row[10], list) and row[10] else ""
        sup      = row[12][0] if isinstance(row[12], list) and row[12] else ""
        if min_scope:
            index[min_scope].append({
                "api_id": api_id, "category": cat, "larc_support": sup
            })
        for s in all_scopes.split(","):
            s = s.strip()
            if s and s != min_scope:
                index[s].append({
                    "api_id": api_id, "category": cat, "larc_support": sup
                })
    return index


def load_scope_map():
    with open(SCOPE_MAP_PATH) as f:
        return json.load(f)


def report(scope_map, scope_index):
    tasks = scope_map.get("tasks", {})
    print(f"{'='*60}")
    print(f" scope-map.json × API マトリクス 照合レポート")
    print(f" scope-map tasks: {len(tasks)}  /  matrix APIs: {sum(1 for _ in scope_index)}")
    print(f"{'='*60}\n")

    ok, aliased, missing = [], [], []

    for task_name, task_data in tasks.items():
        scopes = task_data.get("scopes", [])
        identity = task_data.get("identity", "")
        hits, alias_hits, unknown = [], [], []

        for scope in scopes:
            if scope in scope_index:
                hits.append(scope)
            elif scope in SCOPE_ALIASES:
                new_scope = SCOPE_ALIASES[scope]
                if new_scope in scope_index:
                    alias_hits.append((scope, new_scope))
                else:
                    unknown.append(scope)
            else:
                unknown.append(scope)

        if hits and not alias_hits and not unknown:
            ok.append(task_name)
        elif alias_hits:
            aliased.append({
                "task": task_name, "identity": identity,
                "aliases": alias_hits, "unknown": unknown
            })
        else:
            missing.append({
                "task": task_name, "identity": identity,
                "scopes": scopes, "unknown": unknown
            })

    print(f"✅ 完全一致: {len(ok)}/{len(tasks)}")
    for t in ok:
        print(f"   {t}")

    print(f"\n🔄 スコープ名が旧形式 (要更新): {len(aliased)}")
    for item in aliased:
        print(f"   [{item['task']}] identity={item['identity']}")
        for old, new in item["aliases"]:
            print(f"     {old!r}  →  {new!r}")
        for u in item["unknown"]:
            print(f"     {u!r}  → (マトリクス未登録)")

    print(f"\n❌ マトリクス未登録: {len(missing)}")
    for item in missing:
        print(f"   [{item['task']}] identity={item['identity']}")
        for s in item["scopes"]:
            print(f"     scope: {s!r}")

    return aliased, missing


def fix_scope_map(scope_map, aliased):
    """SCOPE_ALIASES に基づいて scope-map.json のスコープ名を更新"""
    tasks = scope_map.get("tasks", {})
    fixed = 0
    for item in aliased:
        task_name = item["task"]
        scopes = tasks[task_name]["scopes"]
        new_scopes = []
        for s in scopes:
            if s in SCOPE_ALIASES:
                new_scopes.append(SCOPE_ALIASES[s])
                fixed += 1
            else:
                new_scopes.append(s)
        tasks[task_name]["scopes"] = new_scopes

    if fixed:
        with open(SCOPE_MAP_PATH, "w") as f:
            json.dump(scope_map, f, ensure_ascii=False, indent=2)
        print(f"\n✅ scope-map.json を更新しました ({fixed} スコープ修正)")
    else:
        print("\nNo changes needed.")


def export_matrix(rows, rids):
    out = []
    for i, row in enumerate(rows):
        out.append({
            "record_id": rids[i] if i < len(rids) else None,
            "api_id":      row[1],
            "resource":    row[2],
            "method":      row[3],
            "min_scope":   row[4],
            "all_scopes":  row[5],
            "description": row[6],
            "notes":       row[7],
            "user_oauth":  row[8],
            "tenant_bot":  row[9],
            "category":    row[10][0] if isinstance(row[10], list) and row[10] else row[10],
            "auth_type":   row[11][0] if isinstance(row[11], list) and row[11] else row[11],
            "larc_support":row[12][0] if isinstance(row[12], list) and row[12] else row[12],
        })
    print(json.dumps(out, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    args = sys.argv[1:]
    rows, rids = fetch_matrix()
    scope_index = build_scope_index(rows)

    if "--export" in args:
        export_matrix(rows, rids)
        sys.exit(0)

    scope_map = load_scope_map()
    aliased, missing = report(scope_map, scope_index)

    if "--fix" in args:
        fix_scope_map(scope_map, aliased)
