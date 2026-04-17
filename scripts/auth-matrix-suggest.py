#!/usr/bin/env python3
"""
auth-matrix-suggest.py — larc auth suggest + API マトリクス照合

`larc auth suggest` の出力に加え、各スコープが実際にどの Lark API に対応し、
LARC サポート状況 (Supported/Partial/Not Supported) がどうかを表示する。

Usage:
  python3 scripts/auth-matrix-suggest.py "<task description>"
  python3 scripts/auth-matrix-suggest.py "承認申請を作成してルーティングする"

Exit codes:
  0 — all suggested scopes are Supported
  1 — one or more scopes are Partial or Not Supported (caller should warn)
"""

import json
import os
import re
import subprocess
import sys

BASE_TOKEN = "XYgXbe45faGty9sebpWjw54Tprh"
TABLE_ID   = "tblyj3uXRpKZMBqv"
VIEW_ID    = "vewrMVILb7"

SCOPE_MAP_PATH = os.path.join(
    os.path.dirname(os.path.dirname(__file__)),
    "config", "scope-map.json"
)

# ANSI colors
BOLD   = "\033[1m"
GREEN  = "\033[32m"
YELLOW = "\033[33m"
RED    = "\033[31m"
CYAN   = "\033[36m"
RESET  = "\033[0m"

# ── Keyword → task_type mapping (mirrors auth.sh KEYWORD_MAP) ─────────────
KEYWORD_MAP = {
    r"\bdoc\b|document":                                           ["read_document"],
    r"create\s+\w*\s*doc|write\s+\w*\s*doc|new\s+doc":            ["create_document"],
    r"edit\s+\w*\s*doc|update\s+\w*\s*doc|modify\s+\w*\s*doc":    ["update_document"],
    r"wiki|knowledge\s*base|knowledge\s*hub":                       ["read_wiki"],
    r"wiki.*(?:create|update|write|add|edit)|(?:create|update|write|add|edit).*wiki": ["write_wiki"],
    r"update\s+wiki|write\s+to\s+wiki":                            ["write_wiki"],
    r"upload\b|attach\s+\w*\s*file|create\s+file\b":               ["create_drive_file"],
    r"read\s+\w*\s*drive|list\s+file|file\s+list|browse\s+drive":  ["read_drive"],
    r"create\s+folder|manage\s+file|move\s+file|delete\s+file":    ["manage_drive"],
    r"\bbase\b|\bbitable\b":                                        ["read_base"],
    r"create\s+\w*\s*record|record\s+create|add\s+\w*\s*record|new\s+\w*\s*record|insert\s+\w*\s*record": ["create_base_record"],
    r"update\s+(?:\w+\s+){0,3}record|edit\s+(?:\w+\s+){0,3}record|modify\s+(?:\w+\s+){0,3}record|patch\s+\w*\s*record": ["update_base_record"],
    r"read\s+\w*\s*(?:record|table)|list\s+\w*\s*record":          ["read_base"],
    r"manage\s+\w*\s*(?:base|bitable|table)":                      ["manage_base"],
    r"(?:create|add|new|log|insert|register)\s+(?:\w+\s+){0,3}(?:crm|customer|lead|deal|prospect)": ["create_crm_record"],
    r"\bcrm\b|customer\s+record|lead\s+record|deal\s+record":      ["read_base"],
    r"(?=.*(?:create|add|new|log)\s+(?:\w+\s+){0,3}(?:crm|customer|lead|deal|prospect))(?=.*(?:send|message|notify))": ["send_crm_followup"],
    r"send\s+\w*\s*message|send\s+\w*\s*notification|notify\s+\w+": ["send_message"],
    r"follow.?up\s+message|send\s+follow.?up":                     ["send_message"],
    r"read\s+\w*\s*message|chat\s+history|message\s+history":      ["read_message"],
    r"calendar|read\s+\w*\s*event|list\s+\w*\s*event":             ["read_calendar"],
    r"schedule\s+(?:a\s+)?(?:\S+\s+){0,3}(?:meeting|call|event|appointment)|create\s+\w*\s*(?:event|meeting|appointment)|book\s+\w*\s*(?:room|meeting|slot)": ["write_calendar"],
    r"\bexpense\b|\breimbursement\b|expense\s+report":             ["create_expense"],
    r"(?:submit|send|create|trigger|start)\s+\w*\s*approval|approval\s+flow|approval\s+request|route\s+\w+\s+to\s+approval": ["submit_approval"],
    r"(?:approve|reject|process|handle)\s+\w*\s*approval|approval\s+task|approver|reject\s+task": ["act_approval_task"],
    r"(?:check|read|view|get)\s+\w*\s*approval|approval\s+status|pending\s+approval": ["read_approval"],
    r"contact|employee\s+info|user\s+info|directory|lookup\s+user|find\s+user|\bhr\b": ["read_contact"],
    r"update\s+\w*\s*contact|manage\s+\w*\s*contact|add\s+\w*\s*employee": ["manage_contact"],
    r"create\s+\w*\s*task|new\s+\w*\s*task|assign\s+\w*\s*task|add\s+\w*\s*task": ["write_task"],
    r"(?<!approval\s)\btask\b|\btodo\b|to-do":                     ["read_task"],
    r"attendance|check.?in|check.?out|timesheet":                  ["read_attendance"],
    r"minutes|miaoji|meeting\s+notes|transcript":                  ["read_minutes"],
    r"video\s+meeting|vc\s+record|video\s+conference\s+record":    ["read_vc"],
    r"spreadsheet|sheet|excel|\bcsv\b":                            ["manage_sheets"],
    r"slide|\bppt\b|presentation|deck":                            ["manage_slides"],
    r"ocr|image\s+(?:recognition|text)|text\s+from\s+image":       ["ocr_image"],
    # ── Japanese keywords ──────────────────────────────────────────
    r"承認|稟議|申請":                                              ["submit_approval"],
    r"承認タスク|承認作業|approve|reject":                          ["act_approval_task"],
    r"経費|精算|立替|領収":                                         ["create_expense"],
    r"メッセージ|通知|送信|チャット|IM":                            ["send_message"],
    r"ドキュメント|文書|Doc":                                       ["read_document"],
    r"ドキュメント作成|文書作成":                                   ["create_document"],
    r"カレンダー|予定|スケジュール|会議設定":                       ["write_calendar"],
    r"タスク作成|タスク追加":                                       ["write_task"],
    r"レコード作成|レコード追加":                                   ["create_base_record"],
    r"レコード更新|レコード編集":                                   ["update_base_record"],
    r"CRM|顧客|案件|リード":                                        ["create_crm_record"],
    r"ファイルアップロード|ファイル送信|添付":                       ["create_drive_file"],
    r"ナレッジ|知識|Wiki|ウィキ":                                   ["read_wiki"],
    r"会議録|議事録|妙記|Minutes":                                  ["read_minutes"],
    r"勤怠|出勤|退勤|打刻":                                         ["read_attendance"],
    r"スライド|プレゼン|PPT":                                       ["manage_slides"],
    r"スプレッドシート|表計算|シート":                              ["manage_sheets"],
    r"連絡先|ユーザー情報|社員検索":                                ["read_contact"],
}


def fetch_matrix():
    all_rows = []
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
            return []
        rows = d["data"]["data"]
        all_rows.extend(rows)
        if len(rows) < 100:
            break
        offset += 100
    return all_rows


def build_scope_index(rows):
    """scope → [{ api_id, category, auth_type, larc_support, notes }]"""
    index = {}
    for row in rows:
        api_id     = row[1] or ""
        min_scope  = row[4] or ""
        all_scopes = row[5] or ""
        cat        = row[10][0] if isinstance(row[10], list) and row[10] else ""
        auth_type  = row[11][0] if isinstance(row[11], list) and row[11] else ""
        sup        = row[12][0] if isinstance(row[12], list) and row[12] else ""
        notes      = row[7] or ""
        entry = {"api_id": api_id, "category": cat,
                 "auth_type": auth_type, "larc_support": sup, "notes": notes}
        for s in ([min_scope] + [x.strip() for x in all_scopes.split(",") if x.strip()]):
            if s:
                index.setdefault(s, [])
                if entry not in index[s]:
                    index[s].append(entry)
    return index


def suggest(task_desc, scope_map, scope_index):
    tasks = scope_map.get("tasks", {})
    task_desc_lower = task_desc.lower()

    matched_tasks = set()
    for pattern, task_keys in KEYWORD_MAP.items():
        if re.search(pattern, task_desc_lower):
            for tk in task_keys:
                if tk in tasks:
                    matched_tasks.add(tk)

    if not matched_tasks:
        print(f"\n{YELLOW}No matching tasks found for: \"{task_desc}\"{RESET}")
        print(f"  Available task types: {', '.join(sorted(tasks.keys()))}")
        return 0

    # Collect all scopes
    all_scopes = {}
    for tk in sorted(matched_tasks):
        for s in tasks[tk]["scopes"]:
            all_scopes[s] = tk

    print(f"\n{BOLD}▶ auth-matrix-suggest: \"{task_desc}\"{RESET}\n")

    print(f"{BOLD}Detected tasks:{RESET}")
    for tk in sorted(matched_tasks):
        t = tasks[tk]
        print(f"  • {tk}: {t.get('description', '')}")

    print(f"\n{BOLD}Scope × Matrix チェック ({len(all_scopes)} scopes):{RESET}")
    print(f"  {'Scope':<45} {'Status':<16} {'API'}")
    print(f"  {'-'*44} {'-'*15} {'-'*30}")

    has_issues = False
    for scope in sorted(all_scopes.keys()):
        entries = scope_index.get(scope, [])
        if not entries:
            status_str = f"{YELLOW}?未登録{RESET}"
            api_str = "(matrix未登録)"
            has_issues = True
        else:
            # Dedupe larc_support
            supports = list({e["larc_support"] for e in entries if e["larc_support"]})
            apis = [e["api_id"] for e in entries[:2]]
            api_str = ", ".join(apis) + ("..." if len(entries) > 2 else "")

            if "Not Supported" in supports:
                status_str = f"{RED}Not Supported{RESET}"
                has_issues = True
            elif "Partial" in supports:
                status_str = f"{YELLOW}Partial{RESET}"
                has_issues = True
            else:
                status_str = f"{GREEN}Supported{RESET}"

        print(f"  {scope:<45} {status_str:<25} {api_str}")

        # Show notes for Partial/Not Supported
        if entries:
            for e in entries:
                sup = e.get("larc_support", "")
                note = e.get("notes", "")
                if sup in ("Partial", "Not Supported") and note:
                    print(f"    {YELLOW}→ {note}{RESET}")

    # Auth command
    scope_str = " ".join(sorted(all_scopes.keys()))
    print(f"\n{BOLD}To authorize:{RESET}")
    print(f"  larc auth login --scope \"{scope_str}\"")

    if has_issues:
        print(f"\n{YELLOW}{BOLD}⚠  一部のスコープに制限があります。上記の notes を確認してください。{RESET}")
        return 1
    else:
        print(f"\n{GREEN}✓ 全スコープが Supported です。{RESET}")
        return 0


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} \"<task description>\"")
        sys.exit(1)

    task_desc = " ".join(sys.argv[1:])

    with open(SCOPE_MAP_PATH) as f:
        scope_map = json.load(f)

    print(f"Fetching API matrix...", end=" ", flush=True)
    rows = fetch_matrix()
    scope_index = build_scope_index(rows)
    print(f"({len(rows)} APIs loaded)")

    exit_code = suggest(task_desc, scope_map, scope_index)
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
