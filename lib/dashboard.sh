#!/usr/bin/env bash
# dashboard.sh — LARC operational dashboard
# T-501: Lark Base dashboard — queue stats + execution log push

set -uo pipefail

_DASHBOARD_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_DASHBOARD_SH_DIR}/runtime-common.sh"

larc_init_fallback_logs

# ── helpers ──────────────────────────────────────────────────────────────────

_dashboard_compute_stats() {
  local queue_dir="${LARC_CACHE:-${LARC_HOME:-$HOME/.larc}/cache}/queue"
  local agent_id="${1:-}"

  python3 - "$queue_dir" "$agent_id" <<'PY'
import json, os, sys
from datetime import datetime, timezone, timedelta

queue_dir = sys.argv[1]
agent_filter = sys.argv[2]

stats = {
    "total": 0, "pending": 0, "pending_preview": 0,
    "in_progress": 0, "done": 0, "failed": 0, "blocked": 0,
    "by_agent": {},
    "by_source": {},
    "last_24h_done": 0,
    "last_24h_failed": 0,
    "avg_execution_seconds": None,
}

now = datetime.now(timezone.utc)
cutoff_24h = now - timedelta(hours=24)
exec_durations = []

if not os.path.isdir(queue_dir):
    print(json.dumps(stats))
    sys.exit(0)

for fname in os.listdir(queue_dir):
    if not fname.endswith(".jsonl"):
        continue
    with open(os.path.join(queue_dir, fname)) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                item = json.loads(line)
            except Exception:
                continue

            aid = item.get("agent_id", "unknown")
            if agent_filter and aid != agent_filter:
                continue

            status = item.get("status", "unknown")
            source = item.get("source", "unknown")

            stats["total"] += 1
            if status in stats:
                stats[status] += 1
            if "blocked" in status:
                stats["blocked"] += 1

            stats["by_agent"][aid] = stats["by_agent"].get(aid, 0) + 1
            stats["by_source"][source] = stats["by_source"].get(source, 0) + 1

            # Last 24h counts
            def parse_ts(val):
                if not val:
                    return None
                for s in (val, val.replace("Z", "+00:00")):
                    try:
                        return datetime.fromisoformat(s)
                    except ValueError:
                        pass
                return None

            if status == "done":
                ts = parse_ts(item.get("completed_at") or item.get("updated_at"))
                if ts and ts >= cutoff_24h:
                    stats["last_24h_done"] += 1
                # Compute execution duration
                started = parse_ts(item.get("started_at"))
                completed = parse_ts(item.get("completed_at"))
                if started and completed:
                    exec_durations.append((completed - started).total_seconds())
            elif status == "failed":
                ts = parse_ts(item.get("updated_at"))
                if ts and ts >= cutoff_24h:
                    stats["last_24h_failed"] += 1

if exec_durations:
    stats["avg_execution_seconds"] = round(sum(exec_durations) / len(exec_durations), 1)

print(json.dumps(stats, ensure_ascii=False))
PY
}

_dashboard_push_snapshot() {
  local stats_json="$1"
  local agent_id="${2:-all}"

  [[ -z "${LARC_BASE_APP_TOKEN:-}" ]] && { log_warn "LARC_BASE_APP_TOKEN not set — skipping Base push"; return 0; }

  # Get or create dashboard_metrics table
  local table_id
  table_id=$(lark-cli base +table-list \
    --base-token "$LARC_BASE_APP_TOKEN" \
    --jq '.data.tables[] | select(.name == "dashboard_metrics") | .id' \
    2>/dev/null | head -1 || echo "")

  if [[ -z "$table_id" ]]; then
    log_info "Creating dashboard_metrics table..."
    table_id=$(lark-cli base +table-create \
      --base-token "$LARC_BASE_APP_TOKEN" \
      --name "dashboard_metrics" \
      --jq '.table.table_id // .table_id' 2>/dev/null || echo "")
    # Validate table_id looks like a real ID (non-empty, no whitespace, min length)
    table_id=$(echo "$table_id" | tr -d '[:space:]')
    if [[ -z "$table_id" ]] || [[ "${#table_id}" -lt 5 ]]; then
      log_warn "dashboard_metrics table creation failed (bad table_id: '$table_id')"
      return 0
    fi
    log_ok "dashboard_metrics table created: $table_id"
    # Create fields
    for field in snapshot_at agent_id total pending in_progress done failed last_24h_done last_24h_failed avg_exec_seconds; do
      lark-cli base +field-create --base-token "$LARC_BASE_APP_TOKEN" --table-id "$table_id" \
        --json "{\"name\":\"$field\",\"type\":\"text\"}" >/dev/null 2>&1 || true
    done
  fi

  local record_json
  record_json=$(python3 - "$stats_json" "$agent_id" <<'PY'
import json, sys
from datetime import datetime, timezone

stats = json.loads(sys.argv[1])
agent_id = sys.argv[2]

row = {
    "snapshot_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "agent_id": agent_id,
    "total": str(stats.get("total", 0)),
    "pending": str(stats.get("pending", 0) + stats.get("pending_preview", 0)),
    "in_progress": str(stats.get("in_progress", 0)),
    "done": str(stats.get("done", 0)),
    "failed": str(stats.get("failed", 0)),
    "last_24h_done": str(stats.get("last_24h_done", 0)),
    "last_24h_failed": str(stats.get("last_24h_failed", 0)),
    "avg_exec_seconds": str(stats.get("avg_execution_seconds") or ""),
}
print(json.dumps(row))
PY
)

  lark-cli base +record-upsert \
    --base-token "$LARC_BASE_APP_TOKEN" \
    --table-id "$table_id" \
    --json "$record_json" \
    >/dev/null 2>&1 && log_ok "Dashboard snapshot pushed to Lark Base" || log_warn "Dashboard Base push failed"
}

# ── Public interface ──────────────────────────────────────────────────────────

cmd_dashboard() {
  local subcmd="${1:-summary}"
  shift || true

  # Load config if needed
  larc_load_runtime_config

  local agent_id=""
  local push=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent)  agent_id="$2"; shift 2 ;;
      --push)   push=true; shift ;;
      *) shift ;;
    esac
  done

  case "$subcmd" in
    summary|status)
      local stats_json
      stats_json=$(_dashboard_compute_stats "$agent_id")

      python3 - "$stats_json" "$agent_id" <<'PY'
import json, sys

stats = json.loads(sys.argv[1])
agent = sys.argv[2] or "all agents"

BOLD = '\033[1m'; CYAN = '\033[0;36m'; GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'; RED = '\033[0;31m'; RESET = '\033[0m'

print()
print(f"{BOLD}{CYAN}▶ LARC Dashboard — {agent}{RESET}")
print("──────────────────────────────────────")

total   = stats["total"]
pending = stats["pending"] + stats["pending_preview"]
active  = stats["in_progress"]
done    = stats["done"]
failed  = stats["failed"]

# Status bar
bar_width = 30
if total > 0:
    done_w   = max(1, round(done   / total * bar_width)) if done   else 0
    failed_w = max(1, round(failed / total * bar_width)) if failed else 0
    pend_w   = max(0, bar_width - done_w - failed_w)
    bar = (f"{GREEN}{'█' * done_w}{RESET}"
           f"{RED}{'█' * failed_w}{RESET}"
           f"{'░' * pend_w}")
    print(f"\n  [{bar}]  {done}/{total} done")

print(f"\n  Queue:")
print(f"    pending     {pending}")
print(f"    in_progress {active}")
print(f"    done        {done}")
print(f"    failed      {failed}")
print(f"    total       {total}")

avg = stats.get("avg_execution_seconds")
if avg is not None:
    print(f"\n  Avg execution time:  {avg}s")

print(f"\n  Last 24 h:")
print(f"    completed   {stats['last_24h_done']}")
print(f"    failed      {stats['last_24h_failed']}")

if stats["by_agent"]:
    print(f"\n  By agent:")
    for aid, cnt in sorted(stats["by_agent"].items()):
        print(f"    {aid:<20} {cnt}")

if stats["by_source"]:
    print(f"\n  By source:")
    for src, cnt in sorted(stats["by_source"].items()):
        print(f"    {src:<20} {cnt}")

print()
PY

      if [[ "$push" == "true" ]]; then
        _dashboard_push_snapshot "$stats_json" "${agent_id:-all}"
      fi
      ;;

    push)
      # Push snapshot without printing summary
      local stats_json
      stats_json=$(_dashboard_compute_stats "$agent_id")
      _dashboard_push_snapshot "$stats_json" "${agent_id:-all}"
      ;;

    help|*)
      echo ""
      echo -e "${_BOLD}larc dashboard${_RESET} — Operational metrics"
      echo ""
      echo "  larc dashboard summary [--agent main]       Print queue stats"
      echo "  larc dashboard summary --push               Print + push to Lark Base"
      echo "  larc dashboard push    [--agent main]       Push snapshot to Lark Base only"
      echo ""
      ;;
  esac
}
