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
  --check crm-split  CRM follow-up step audit split (#41)
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

check_crm_split() {
  echo "${CYAN}[crm-split]${RESET} #41 CRM follow-up step audit split"
  assert "crm_admin extractor tags retry_only_eligible groundwork" \
    grep -q 'retry_only_eligible' lib/executors/crm_admin.py
  assert "runtime has a dedicated step audit writer" \
    grep -q '_ingress_write_step_audit_log' "$INGRESS_SH"
  assert "partial CRM note includes step_done JSON key" \
    grep -q 'step_done' "$INGRESS_SH"
  assert "partial CRM note includes step_pending JSON key" \
    grep -q 'step_pending' "$INGRESS_SH"
  assert "partial CRM note includes resend-only closure key" \
    grep -q 'resend_only_can_close' "$INGRESS_SH"
  assert "send-only retry path skips create_crm_record" \
    grep -q 'send_only_retry\|retry_only_eligible' "$INGRESS_SH"
  assert "send-only retry emits one step audit row" bash -c '
set -euo pipefail
tmp_home=$(mktemp -d)
trap "rm -rf \"$tmp_home\"" EXIT
export HOME="$tmp_home"
export LARC_TENANT_ID=default
export LARC_HOME="$HOME/.larc"
export LARC_CACHE="$LARC_HOME/cache"
export LARC_CONFIG="$LARC_HOME/config.env"
export LARC_BASE_APP_TOKEN=""
export LIB_DIR="$PWD/lib"
export _LARC_SCENARIO_PY="$LIB_DIR/ingress_scenario.py"
mkdir -p "$LARC_CACHE/queue"
log_info() { :; }; log_ok() { :; }; log_warn() { :; }; log_error() { echo "$*" >&2; }; log_head() { :; }
source "$LIB_DIR/runtime-common.sh"
source "$LIB_DIR/ingress.sh"
cmd_send() { return 0; }
_ingress_write_step_audit_log() { printf "audit:%s:%s\n" "$2" "$3"; }
cat > "$LARC_CACHE/queue/main.jsonl" <<'"'"'JSON'"'"'
{"queue_id":"fixture-crm-retry-only","agent_id":"main","worker_agent_id":"main","source":"fixture","message_text":"Send follow-up message for Acme Verification: Thanks for joining onboarding.","task_types":["create_crm_record","send_crm_followup"],"scopes":[],"authority":"bot","gate":"preview","status":"in_progress","execution_note":"{\"scenario_id\":\"crm_followup\",\"step_done\":[\"create_crm_record\"],\"step_pending\":[\"send_followup_message\"],\"retry_only_eligible\":true,\"resend_only_can_close\":true}"}
JSON
out=$(_ingress_execute_apply --queue-id fixture-crm-retry-only)
[[ $(printf "%s\n" "$out" | grep -c "^audit:") -eq 1 ]]
printf "%s\n" "$out" | grep -q "^audit:send_crm_followup:done$"
'
  assert "missing CRM follow-up closes as partial without run steps" bash -c '
set -euo pipefail
tmp_home=$(mktemp -d)
trap "rm -rf \"$tmp_home\"" EXIT
export HOME="$tmp_home"
export LARC_TENANT_ID=default
export LARC_HOME="$HOME/.larc"
export LARC_CACHE="$LARC_HOME/cache"
export LARC_CONFIG="$LARC_HOME/config.env"
export LARC_BASE_APP_TOKEN=""
export LIB_DIR="$PWD/lib"
export _LARC_SCENARIO_PY="$LIB_DIR/ingress_scenario.py"
mkdir -p "$LARC_CACHE/queue"
log_info() { :; }; log_ok() { :; }; log_warn() { :; }; log_error() { echo "$*" >&2; }; log_head() { :; }
source "$LIB_DIR/runtime-common.sh"
source "$LIB_DIR/ingress.sh"
_ingress_write_step_audit_log() { :; }
cat > "$LARC_CACHE/queue/main.jsonl" <<'"'"'JSON'"'"'
{"queue_id":"fixture-crm-missing-followup","agent_id":"main","worker_agent_id":"main","source":"fixture","message_text":"CRM task for Acme Verification","task_types":["send_crm_followup"],"scopes":[],"authority":"bot","gate":"preview","status":"in_progress"}
JSON
_ingress_execute_apply --queue-id fixture-crm-missing-followup >/dev/null
python3 - "$LARC_CACHE/queue/main.jsonl" <<'"'"'PY'"'"'
import json, sys
row = json.loads(open(sys.argv[1], encoding="utf-8").readline())
note = json.loads(row["execution_note"])
assert row["status"] == "partial", row
assert note["step_pending"] == ["send_followup_message"], note
assert note["next_action"] == "manual_followup_required", note
PY
'
  assert "failed CRM create without completed steps closes as failed" bash -c '
set -euo pipefail
tmp_home=$(mktemp -d)
trap "rm -rf \"$tmp_home\"" EXIT
export HOME="$tmp_home"
export LARC_TENANT_ID=default
export LARC_HOME="$HOME/.larc"
export LARC_CACHE="$LARC_HOME/cache"
export LARC_CONFIG="$LARC_HOME/config.env"
export LARC_BASE_APP_TOKEN=""
export LIB_DIR="$PWD/lib"
export _LARC_SCENARIO_PY="$LIB_DIR/ingress_scenario.py"
mkdir -p "$LARC_CACHE/queue"
log_info() { :; }; log_ok() { :; }; log_warn() { :; }; log_error() { echo "$*" >&2; }; log_head() { :; }
source "$LIB_DIR/runtime-common.sh"
source "$LIB_DIR/ingress.sh"
openclaw() { return 1; }
cmd_send() { echo "unexpected send" >&2; return 1; }
_ingress_write_step_audit_log() { :; }
cat > "$LARC_CACHE/queue/main.jsonl" <<'"'"'JSON'"'"'
{"queue_id":"fixture-crm-create-fails","agent_id":"main","worker_agent_id":"main","source":"fixture","message_text":"Create a CRM record for Acme and send: Hello from sales.","task_types":["create_crm_record","send_crm_followup"],"scopes":[],"authority":"bot","gate":"preview","status":"in_progress"}
JSON
_ingress_execute_apply --queue-id fixture-crm-create-fails >/dev/null
python3 - "$LARC_CACHE/queue/main.jsonl" <<'"'"'PY'"'"'
import json, sys
row = json.loads(open(sys.argv[1], encoding="utf-8").readline())
note = json.loads(row["execution_note"])
assert row["status"] == "failed", row
assert note["step_done"] == [], note
assert note["step_failed"] == ["create_crm_record"], note
PY
'
  assert "generic follow-up request requires message body" bash -c '
set -euo pipefail
tmp_home=$(mktemp -d)
trap "rm -rf \"$tmp_home\"" EXIT
export HOME="$tmp_home"
export LARC_TENANT_ID=default
export LARC_HOME="$HOME/.larc"
export LARC_CACHE="$LARC_HOME/cache"
export LARC_CONFIG="$LARC_HOME/config.env"
export LARC_BASE_APP_TOKEN=""
export LIB_DIR="$PWD/lib"
export _LARC_SCENARIO_PY="$LIB_DIR/ingress_scenario.py"
mkdir -p "$LARC_CACHE/queue"
log_info() { :; }; log_ok() { :; }; log_warn() { :; }; log_error() { echo "$*" >&2; }; log_head() { :; }
source "$LIB_DIR/runtime-common.sh"
source "$LIB_DIR/ingress.sh"
openclaw() { return 0; }
cmd_send() { echo "unexpected send" >&2; return 1; }
_ingress_write_step_audit_log() { :; }
cat > "$LARC_CACHE/queue/main.jsonl" <<'"'"'JSON'"'"'
{"queue_id":"fixture-crm-generic-followup","agent_id":"main","worker_agent_id":"main","source":"fixture","message_text":"Create a CRM record for Acme and send a follow-up message","task_types":["create_crm_record","send_crm_followup"],"scopes":[],"authority":"bot","gate":"preview","status":"in_progress"}
JSON
_ingress_execute_apply --queue-id fixture-crm-generic-followup >/dev/null
python3 - "$LARC_CACHE/queue/main.jsonl" <<'"'"'PY'"'"'
import json, sys
row = json.loads(open(sys.argv[1], encoding="utf-8").readline())
note = json.loads(row["execution_note"])
assert row["status"] == "partial", row
assert note["step_done"] == ["create_crm_record"], note
assert note["step_pending"] == ["send_followup_message"], note
assert "followup_message" in note["missing_or_pending"], note
PY
'
  assert "string false retry flag does not skip create_crm_record" bash -c '
set -euo pipefail
tmp_home=$(mktemp -d)
trap "rm -rf \"$tmp_home\"" EXIT
export HOME="$tmp_home"
export LARC_TENANT_ID=default
export LARC_HOME="$HOME/.larc"
export LARC_CACHE="$LARC_HOME/cache"
export LARC_CONFIG="$LARC_HOME/config.env"
export LARC_BASE_APP_TOKEN=""
export LIB_DIR="$PWD/lib"
export _LARC_SCENARIO_PY="$LIB_DIR/ingress_scenario.py"
mkdir -p "$LARC_CACHE/queue"
log_info() { :; }; log_ok() { :; }; log_warn() { :; }; log_error() { echo "$*" >&2; }; log_head() { :; }
source "$LIB_DIR/runtime-common.sh"
source "$LIB_DIR/ingress.sh"
cat > "$LARC_CACHE/queue/main.jsonl" <<'"'"'JSON'"'"'
{"queue_id":"fixture-crm-false-string","agent_id":"main","worker_agent_id":"main","source":"fixture","message_text":"Create a CRM record for Acme and send: Hello from sales.","task_types":["create_crm_record","send_crm_followup"],"scopes":[],"authority":"bot","gate":"preview","status":"in_progress","execution_note":"{\"retry_only_eligible\":\"false\",\"resend_only_can_close\":\"false\"}"}
JSON
out=$(_ingress_execute_apply --queue-id fixture-crm-false-string --dry-run)
printf "%s\n" "$out" | grep -q -- "- run: create_crm_record"
! printf "%s\n" "$out" | grep -q -- "- skip: create_crm_record"
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
  check_crm_split
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
  crm-split)  check_crm_split ;;
  syntax)     check_syntax ;;
  *) echo "Unknown check: $mode"; usage; exit 2 ;;
esac

echo ""
echo "Total: ${GREEN}${PASS} pass${RESET} / ${RED}${FAIL} fail${RESET}"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
