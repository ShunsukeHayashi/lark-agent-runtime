#!/usr/bin/env bash
# billing.sh — LARC usage tracking + Stripe metered billing
# T-502: Per-tenant execution counting + Stripe usage reporting

set -uo pipefail

_BILLING_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_BILLING_SH_DIR}/runtime-common.sh"

larc_init_fallback_logs

BILLING_DIR="${LARC_HOME:-$HOME/.larc}/billing"
USAGE_FILE="${BILLING_DIR}/usage.jsonl"

# ── Usage tracking (local) ────────────────────────────────────────────────────

# Called by worker after each execution — records one event
billing_record_execution() {
  local agent_id="${1:-main}"
  local queue_id="${2:-}"
  local status="${3:-done}"  # done | failed

  mkdir -p "$BILLING_DIR"

  python3 - "$USAGE_FILE" "$agent_id" "$queue_id" "$status" <<'PY'
import json, sys
from datetime import datetime, timezone

usage_file, agent_id, queue_id, status = sys.argv[1:5]
tenant_id = __import__('os').environ.get("LARC_TENANT_ID", "default")

record = {
    "ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "tenant_id": tenant_id,
    "agent_id": agent_id,
    "queue_id": queue_id,
    "status": status,
}
import fcntl
with open(usage_file, "a", encoding="utf-8") as f:
    fcntl.flock(f.fileno(), fcntl.LOCK_EX)
    try:
        f.write(json.dumps(record, ensure_ascii=False) + "\n")
    finally:
        fcntl.flock(f.fileno(), fcntl.LOCK_UN)
PY
}

# Returns 0 (ok) or 1 (quota exceeded)
billing_check_quota() {
  local agent_id="${1:-main}"
  local quota="${LARC_MONTHLY_QUOTA:-}"

  # No quota configured — always allow
  [[ -z "$quota" ]] && return 0

  local current_month
  current_month=$(date +%Y-%m)

  local count=0
  if [[ -f "$USAGE_FILE" ]]; then
    count=$(python3 - "$USAGE_FILE" "$current_month" <<'PY'
import json, sys
usage_file, month = sys.argv[1:3]
count = 0
try:
    with open(usage_file) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            d = json.loads(line)
            if d.get("ts", "").startswith(month) and d.get("status") == "done":
                count += 1
except Exception:
    pass
print(count)
PY
)
  fi

  # Validate both values are integers before comparing
  if [[ "$count" =~ ^[0-9]+$ ]] && [[ "$quota" =~ ^[0-9]+$ ]] && [[ "$count" -ge "$quota" ]]; then
    log_warn "Monthly quota reached: $count/$quota executions (tenant: ${LARC_TENANT_ID:-default})"
    return 1
  fi
  return 0
}

# ── Local usage stats ─────────────────────────────────────────────────────────

_billing_compute_usage() {
  local months="${1:-1}"  # How many months back to include

  [[ -f "$USAGE_FILE" ]] || { echo "{}"; return; }

  python3 - "$USAGE_FILE" "$months" <<'PY'
import json, sys
from datetime import datetime, timezone, timedelta
from collections import defaultdict

usage_file = sys.argv[1]
months_back = int(sys.argv[2])

now = datetime.now(timezone.utc)
cutoff = (now - timedelta(days=months_back * 31)).strftime("%Y-%m")

monthly = defaultdict(lambda: {"done": 0, "failed": 0})
by_agent = defaultdict(int)

try:
    with open(usage_file) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            d = json.loads(line)
            ts = d.get("ts", "")
            month = ts[:7]
            if month < cutoff:
                continue
            status = d.get("status", "done")
            monthly[month][status] = monthly[month].get(status, 0) + 1
            by_agent[d.get("agent_id", "unknown")] += 1
except Exception:
    pass

print(json.dumps({
    "monthly": dict(monthly),
    "by_agent": dict(by_agent),
    "total": sum(v.get("done", 0) for v in monthly.values()),
}, ensure_ascii=False))
PY
}

# ── Stripe metered billing ────────────────────────────────────────────────────

_billing_stripe_report() {
  local stripe_key="${STRIPE_SECRET_KEY:-}"
  local sub_item="${STRIPE_SUBSCRIPTION_ITEM_ID:-}"
  local current_month
  current_month=$(date +%Y-%m)

  if [[ -z "$stripe_key" ]]; then
    log_warn "STRIPE_SECRET_KEY not set — skipping Stripe report"
    return 0
  fi
  if [[ -z "$sub_item" ]]; then
    log_warn "STRIPE_SUBSCRIPTION_ITEM_ID not set — skipping Stripe report"
    return 0
  fi

  # Count this month's executions
  local count=0
  [[ -f "$USAGE_FILE" ]] && count=$(python3 - "$USAGE_FILE" "$current_month" <<'PY'
import json, sys
usage_file, month = sys.argv[1:3]
count = 0
try:
    with open(usage_file) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            d = json.loads(line)
            if d.get("ts","").startswith(month) and d.get("status") == "done":
                count += 1
except Exception:
    pass
print(count)
PY
)

  if [[ "$count" -eq 0 ]]; then
    log_info "No executions to report for $current_month"
    return 0
  fi

  log_info "Reporting $count executions to Stripe for $current_month..."

  local response http_code
  response=$(curl -s -w "\n%{http_code}" \
    -X POST "https://api.stripe.com/v1/subscription_items/${sub_item}/usage_records" \
    -u "${stripe_key}:" \
    -d "quantity=${count}" \
    -d "action=set" \
    -d "timestamp=$(date +%s)" \
    2>/dev/null)

  http_code=$(echo "$response" | tail -1)
  local body
  body=$(echo "$response" | head -n -1)

  if [[ "$http_code" == "200" ]]; then
    log_ok "Stripe usage reported: $count executions"
    # Record the report to avoid double-reporting
    python3 - "$BILLING_DIR/stripe-reports.jsonl" "$current_month" "$count" <<'PY'
import json, sys
from datetime import datetime, timezone
report_file, month, count = sys.argv[1:4]
with open(report_file, "a") as f:
    f.write(json.dumps({
        "reported_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "month": month,
        "count": int(count),
    }) + "\n")
PY
  else
    log_warn "Stripe report failed (HTTP $http_code): $(echo "$body" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("error",{}).get("message","unknown"))' 2>/dev/null || echo "$body")"
  fi
}

# ── Public interface ──────────────────────────────────────────────────────────

cmd_billing() {
  local subcmd="${1:-usage}"
  shift || true

  # Load config
  larc_load_runtime_config

  mkdir -p "$BILLING_DIR"

  case "$subcmd" in
    usage)
      local months=3
      [[ "${1:-}" =~ ^[0-9]+$ ]] && { months="$1"; shift; }

      local usage_json
      usage_json=$(_billing_compute_usage "$months")

      python3 - "$usage_json" "${LARC_TENANT_ID:-default}" "${LARC_MONTHLY_QUOTA:-}" <<'PY'
import json, sys

usage = json.loads(sys.argv[1])
tenant = sys.argv[2]
quota  = sys.argv[3]

BOLD = '\033[1m'; CYAN = '\033[0;36m'; GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'; RESET = '\033[0m'

print()
print(f"{BOLD}{CYAN}▶ LARC Billing — tenant: {tenant}{RESET}")
print("──────────────────────────────────────")

monthly = usage.get("monthly", {})
if monthly:
    print(f"\n  Monthly executions:")
    for month in sorted(monthly.keys(), reverse=True):
        d = monthly[month]
        done   = d.get("done", 0)
        failed = d.get("failed", 0)
        quota_str = f" / {quota}" if quota else ""
        bar = "▓" * min(done, 20) + "░" * max(0, 20 - done)
        print(f"    {month}  [{bar}] {done} done, {failed} failed{quota_str}")
else:
    print("\n  No usage data yet.")

total = usage.get("total", 0)
print(f"\n  Total this period: {total} executions")

if quota:
    from datetime import datetime
    current_month = datetime.now().strftime("%Y-%m")
    this_month_done = monthly.get(current_month, {}).get("done", 0)
    pct = round(this_month_done / int(quota) * 100) if int(quota) > 0 else 0
    color = GREEN if pct < 80 else YELLOW if pct < 100 else '\033[0;31m'
    print(f"  Quota:             {color}{this_month_done}/{quota} ({pct}%){RESET}")

by_agent = usage.get("by_agent", {})
if by_agent:
    print(f"\n  By agent:")
    for aid, cnt in sorted(by_agent.items(), key=lambda x: -x[1]):
        print(f"    {aid:<20} {cnt}")

print()
PY
      ;;

    check)
      local agent_id="${1:-main}"
      if billing_check_quota "$agent_id"; then
        log_ok "Quota OK"
        exit 0
      else
        log_error "Quota exceeded — execution blocked"
        exit 1
      fi
      ;;

    report)
      _billing_stripe_report
      ;;

    record)
      # Internal: called by worker
      local agent_id="${1:-main}"
      local queue_id="${2:-}"
      local status="${3:-done}"
      billing_record_execution "$agent_id" "$queue_id" "$status"
      ;;

    help|*)
      echo ""
      echo -e "${_BOLD}larc billing${_RESET} — Usage tracking and Stripe metered billing"
      echo ""
      echo "  larc billing usage [N]     Show last N months of execution counts (default: 3)"
      echo "  larc billing check         Exit 0 if under quota, 1 if exceeded"
      echo "  larc billing report        Push this month's usage to Stripe"
      echo ""
      echo "  Environment variables:"
      echo "    LARC_MONTHLY_QUOTA          Max executions per month (unset = unlimited)"
      echo "    STRIPE_SECRET_KEY           Stripe secret key (sk_live_... or sk_test_...)"
      echo "    STRIPE_SUBSCRIPTION_ITEM_ID Stripe subscription item for metered billing"
      echo ""
      ;;
  esac
}
