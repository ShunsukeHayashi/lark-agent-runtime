#!/usr/bin/env bash
# context-refresh.sh — Miyabi SFA/CRM Context Refresh Daemon
# Runs every 30 min via cron; fetches all IM, CRM, LARC state → LARC memory
set -euo pipefail

LARC_DIR="$HOME/study/larc"
LOG_FILE="$LARC_DIR/logs/context-refresh.log"
DATE=$(date '+%Y-%m-%d')
DATETIME=$(date '+%Y-%m-%d %H:%M')
TMP=$(mktemp -d)

mkdir -p "$LARC_DIR/logs"
exec >> "$LOG_FILE" 2>&1
echo "=== Context Refresh: $DATETIME ==="

trap "rm -rf $TMP" EXIT

# Load env
source ~/.larc/config.env 2>/dev/null || true
CRM_BASE="Zpl6bfi0uaoRBosu4KPjrWROpwh"

# Python helper for columnar parsing
PYPARSE="$TMP/parse.py"
cat > "$PYPARSE" << 'PY'
import sys, json, re
path = sys.argv[1]
with open(path) as f:
    raw = f.read()
raw = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f]', '', raw)
try:
    d = json.loads(raw)
    dd = d['data']
    fn = dd['fields']
    rows = dd['data']
    rids = dd['record_id_list']
    fn2c = {n: i for i, n in enumerate(fn)}
    out = []
    for row, rid in zip(rows, rids):
        rec = {'_id': rid}
        for name, col in fn2c.items():
            v = row[col] if col < len(row) else None
            if v is not None:
                rec[name] = v
        out.append(rec)
    print(json.dumps(out, ensure_ascii=False))
except Exception as e:
    sys.stderr.write(f"parse error: {e}\n")
    print('[]')
PY

# ─── 1-5. Fetch CRM Tables ─────────────────────────────────────────────────
echo "[1/6] Fetching contacts..."
lark-cli base +record-list --base-token "$CRM_BASE" --table-id tblnPrQWJ0PoZhAe --limit 20 > "$TMP/contacts.json" 2>&1
CONTACTS=$(python3 "$PYPARSE" "$TMP/contacts.json")

echo "[2/6] Fetching deals..."
lark-cli base +record-list --base-token "$CRM_BASE" --table-id tblfzt6LLIOAGee9 --limit 20 > "$TMP/deals.json" 2>&1
DEALS=$(python3 "$PYPARSE" "$TMP/deals.json")

echo "[3/6] Fetching activities (latest 10)..."
lark-cli base +record-list --base-token "$CRM_BASE" --table-id tbl5inU8XXZyJkkA --limit 10 > "$TMP/acts.json" 2>&1
ACTIVITIES=$(python3 "$PYPARSE" "$TMP/acts.json")

echo "[4/6] Fetching IM messages..."
lark-cli im +chat-messages-list --chat-id "oc_50b4b99a03d290c8e368a3d84cdc01d7" \
  --page-size 3 > "$TMP/im_lop.json" 2>&1 || echo '[]' > "$TMP/im_lop.json"
LOP_MSG=$(python3 - "$TMP/im_lop.json" << 'PY'
import sys, json, re
with open(sys.argv[1]) as f:
    raw = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f]', '', f.read())
try:
    d = json.loads(raw)
    items = d.get('data',{}).get('items',[])
    msgs = []
    for m in items[:3]:
        body = m.get('body',{})
        ct = body.get('content','') if isinstance(body, dict) else str(body)
        sender = m.get('sender',{}).get('id','?')
        t = m.get('create_time','')
        msgs.append(f"{t}|{sender}|{ct[:80]}")
    print('\n'.join(msgs) if msgs else '(no messages)')
except Exception as e:
    print(f'error: {e}')
PY
)

echo "[5/6] Checking LARC queue..."
LARC_PENDING=$(larc ingress list --agent main --status pending 2>&1 | grep -c "\[pending" || echo "0")
LARC_INPROG=$(larc ingress list --agent main --status in_progress 2>&1 | grep -c "in_progress" || echo "0")

echo "[6/6] Writing memory..."
MEMORY_PATH="$HOME/.larc/cache/workspace/main/memory/${DATE}.md"
mkdir -p "$(dirname "$MEMORY_PATH")"

python3 - "$TMP/contacts.json" "$TMP/deals.json" "$TMP/acts.json" << PYEOF
import sys, json, re, os

def parse(path):
    with open(path) as f:
        raw = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f]', '', f.read())
    try:
        d = json.loads(raw)
        dd = d['data']
        fn = dd['fields']
        rows = dd['data']
        rids = dd['record_id_list']
        fn2c = {n: i for i, n in enumerate(fn)}
        out = []
        for row, rid in zip(rows, rids):
            rec = {}
            for name, col in fn2c.items():
                v = row[col] if col < len(row) else None
                if v is not None:
                    rec[name] = v
            out.append(rec)
        return out
    except:
        return []

contacts = parse(sys.argv[1])
deals = parse(sys.argv[2])
activities = parse(sys.argv[3])

c_lines = [f"  - {c.get('名前','?')} | stage:{str(c.get('オンボーディングステージ','?'))[:20]}" for c in contacts]
d_lines = [f"  - {d.get('ID','?')} | {d.get('案件名','?')[:30]} | stage:{str(d.get('ステージ','?'))[:20]}" for d in deals]
a_lines = [f"  - {a.get('ID','?')} | {a.get('タイトル','?')[:30]} | {a.get('ステータス','?')}" for a in activities[:5]]

content = f"""
---
## Context Refresh: $DATETIME

### Contacts ({len(contacts)})
{chr(10).join(c_lines) or "  (none)"}

### Deals ({len(deals)})
{chr(10).join(d_lines) or "  (none)"}

### Activities (latest {len(activities)})
{chr(10).join(a_lines) or "  (none)"}

### LOP Group (latest)
$LOP_MSG

### LARC Queue
- pending: $LARC_PENDING
- in_progress: $LARC_INPROG
"""

memory_path = os.path.expanduser("~/.larc/cache/workspace/main/memory/$DATE.md")
with open(memory_path, 'a') as f:
    f.write(content)
print(f"Appended to {memory_path}")
PYEOF

# Push to LARC Base
larc memory push --date "$DATE" 2>&1 | tail -1

# Announce
C_COUNT=$(echo "$CONTACTS" | python3 -c "import sys,json; print(len(json.loads(sys.stdin.read())))" 2>/dev/null || echo "?")
D_COUNT=$(echo "$DEALS" | python3 -c "import sys,json; print(len(json.loads(sys.stdin.read())))" 2>/dev/null || echo "?")
~/bin/announce "コンテキストリフレッシュ完了。コンタクト${C_COUNT}件、案件${D_COUNT}件を更新しました。" --home 2>/dev/null || true

echo "=== Done: $DATETIME ==="
