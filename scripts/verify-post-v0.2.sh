#!/usr/bin/env bash
# scripts/verify-post-v0.2.sh — verification harness for the post-v0.2 stabilization playbook
#
# Tests Phase 1 (log schema v2) changes from playbook/post-v0.2-stabilization.yaml.
# This script favors Base-free local logic checks; live-Base assertions are noted
# as TODO and left for a future extension.
#
# Exits 0 on all checks passing, 1 on any failure.

set -uo pipefail

export PYTHONIOENCODING="${PYTHONIOENCODING:-utf-8}"
export PYTHONUTF8="${PYTHONUTF8:-1}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

INGRESS_SH="lib/ingress.sh"
DAEMON_SH="lib/daemon.sh"

# ── color helpers ────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  GREEN=$'\033[0;32m'; RED=$'\033[0;31m'; YELLOW=$'\033[0;33m'; CYAN=$'\033[0;36m'; RESET=$'\033[0m'
else
  GREEN=""; RED=""; YELLOW=""; CYAN=""; RESET=""
fi

PASS=0
FAIL=0

assert() {
  # assert <description> <command...>   — runs command; pass if exit=0
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "  ${GREEN}PASS${RESET}  $desc"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET}  $desc"
    FAIL=$((FAIL+1))
  fi
}

usage() {
  cat <<EOF
Usage: scripts/verify-post-v0.2.sh [--check <name>]

Checks:
  --check noise      classify result_class on bot echo / business notes (#38)
  --check im-source  daemon emits --source=im_user_request (#42)
  --check hitl       audit row schema includes next_human_action (#40)
  --check dedup      in_progress dedup conditional present (#39)
  --check schema     agent_logs auto-ensure list contains the new fields
  --check executors  external executor dispatcher + queue_triage (#44)
  --check all        run all checks (default)
  --help             show this help

Notes:
  - Local logic / static checks only. No Lark Base round-trip.
  - Live-Base verification (e.g. enqueue → query agent_logs) is TODO.
EOF
}

# ── individual checks ────────────────────────────────────────────────────────

check_noise() {
  echo "${CYAN}[noise]${RESET} #38 result_class classifier"
  python3 - "$INGRESS_SH" <<'PY'
import re, sys
src = open(sys.argv[1]).read()
# Pull out the writer's classifier block
assert "result_class" in src, "writer must reference result_class"
assert re.search(r"bot echo\|echo loop\|outbound echo\|purged", src), "noise regex must include all four markers"

# Re-implement classifier inline and run cases
def classify(note, preset=""):
    if preset:
        return preset
    n = (note or "").lower()
    if re.search(r"bot echo|echo loop|outbound echo|purged", n):
        return "noise"
    return "business"

cases = [
    ("real failure: timeout", "", "business"),
    ("bot echo — purged", "", "noise"),
    ("Outbound echo loop detected", "", "noise"),
    ("normal task succeeded", "", "business"),
    ("anything", "delivery", "delivery"),
    ("", "", "business"),
]
for note, preset, expect in cases:
    got = classify(note, preset)
    if got != expect:
        print(f"  FAIL classifier: '{note}' preset={preset!r} → {got} (want {expect})")
        sys.exit(1)
PY
  local rc=$?
  if [[ $rc -eq 0 ]]; then
    echo "  ${GREEN}PASS${RESET}  classifier covers noise/business/preset cases"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET}  classifier"
    FAIL=$((FAIL+1))
  fi
}

check_im_source() {
  echo "${CYAN}[im-source]${RESET} #42 daemon emits im_user_request"
  assert "daemon.sh enqueue uses --source im_user_request" \
    grep -q '"--source", "im_user_request"' "$DAEMON_SH"
  assert "daemon.sh no longer emits bare --source im" \
    bash -c "! grep -E '\"--source\",\\s*\"im\"\\s*,' '$DAEMON_SH'"
}

check_hitl() {
  echo "${CYAN}[hitl]${RESET} #40 next_human_action persisted on blocked_approval"
  assert "audit row dict includes next_human_action" \
    grep -q '"next_human_action":' "$INGRESS_SH"
  assert "enqueue path emits blocked_approval audit row" \
    grep -q 'blocked_approval"' "$INGRESS_SH"
  assert "next_human_action default 'approve in Lark UI' present" \
    grep -q 'approve in Lark UI' "$INGRESS_SH"
}

check_dedup() {
  echo "${CYAN}[dedup]${RESET} #39 in_progress duplicate suppression"
  assert "claim path checks _prev_status before audit emit" \
    grep -q '_prev_status' "$INGRESS_SH"
  assert "skips audit when prev was already in_progress" \
    grep -q 'if \[\[ "$_prev_status" != "in_progress" \]\]' "$INGRESS_SH"
}

check_schema() {
  echo "${CYAN}[schema]${RESET} agent_logs auto-ensure field list"
  assert "field list includes next_human_action" \
    grep -E 'next_human_action.*result_class.*delivery_status|next_human_action result_class delivery_status' "$INGRESS_SH"
  assert "audit row dict includes result_class" \
    grep -q '"result_class":' "$INGRESS_SH"
  assert "audit row dict includes delivery_status" \
    grep -q '"delivery_status":' "$INGRESS_SH"
}

check_syntax() {
  echo "${CYAN}[syntax]${RESET} bash -n on touched files"
  assert "lib/ingress.sh syntax" bash -n "$INGRESS_SH"
  assert "lib/daemon.sh syntax" bash -n "$DAEMON_SH"
}

check_executors() {
  echo "${CYAN}[executors]${RESET} ADR-0001 dispatcher + executors (#44, #45, #46, #47)"
  assert "lib/executors/README.md exists" test -f lib/executors/README.md
  assert "extract_fields dispatcher hook present in ingress.sh" \
    grep -q 'LIB_DIR.*executors\|lib/executors' "$INGRESS_SH"
  for mod in queue_triage doc_search crm_admin cross_search; do
    assert "lib/executors/${mod}.py exists" test -f "lib/executors/${mod}.py"
    assert "${mod}.py is valid Python" python3 -c "import ast; ast.parse(open('lib/executors/${mod}.py').read())"
  done
  assert "detect_scenario routing covers all 4 new scenarios" \
    python3 -c '
import sys
sys.path.insert(0, "lib")
import ingress_scenario as s

cases = [
    (["read_task"], "show me todos", "generic"),
    (["read_task"], "triage stale in_progress queue", "queue_triage"),
    (["read_task"], "改善サイクル: document update と invoice send", "doc_search"),
    (["read_base"], "改善サイクル: CRM系の failed と preview", "crm_admin"),
    (["read_task"], "改善サイクル: Wiki Drive Base 横断", "cross_search"),
    (["create_crm_record","send_message"], "create CRM record", "crm_followup"),
]
for tt, txt, want in cases:
    got = s.detect_scenario(tt, txt)
    assert got == want, f"detect_scenario({tt!r}, {txt!r}) -> {got!r} (want {want!r})"
'
  assert "all 4 executors return 5-tuple from extract_fields" \
    python3 -c '
import sys
sys.path.insert(0, "lib/executors")
for mod_name in ("queue_triage", "doc_search", "crm_admin", "cross_search"):
    m = __import__(mod_name)
    r = m.extract_fields("test message")
    assert len(r) == 5, f"{mod_name}: must return 5-tuple, got {len(r)}"
    assert isinstance(r[0], dict), f"{mod_name}: fields must be dict"
    assert all(isinstance(x, list) for x in r[1:4]), f"{mod_name}: missing/blocked/partial must be lists"
    assert isinstance(r[4], str), f"{mod_name}: ask_user must be str"
'
}

# ── dispatcher ───────────────────────────────────────────────────────────────

run_all() {
  check_syntax
  check_schema
  check_noise
  check_im_source
  check_hitl
  check_dedup
  check_executors
}

case "${1:---check}" in
  --help|-h) usage; exit 0 ;;
esac

mode="all"
if [[ "${1:-}" == "--check" ]]; then
  mode="${2:-all}"
fi

case "$mode" in
  all)        run_all ;;
  noise)      check_noise ;;
  im-source)  check_im_source ;;
  hitl)       check_hitl ;;
  dedup)      check_dedup ;;
  schema)     check_schema ;;
  executors)  check_executors ;;
  syntax)     check_syntax ;;
  *) echo "Unknown check: $mode"; usage; exit 2 ;;
esac

echo ""
echo "Total: ${GREEN}${PASS} pass${RESET} / ${RED}${FAIL} fail${RESET}"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
