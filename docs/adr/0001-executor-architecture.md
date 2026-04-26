# 0001 — Executor architecture for generic-scenario adapters

- **Status:** Proposed
- **Date:** 2026-04-26
- **Driver:** post-v0.2 stabilization (playbook/post-v0.2-stabilization.yaml Phase 2)
- **Related:** #41, #44, #45, #46, #47

## Context

Four open issues call for new typed executors that today are absent — each one
auto-resolves under `scenario=generic` instead of running:

| Issue | Adapter | Target queue |
|---|---|---|
| #44 | `read_task` (queue-triage classification) | NO.545 |
| #45 | `search_content` (document/invoice) | NO.546 |
| #46 | CRM (`read_base` / `update_base_record`) | NO.547 |
| #47 | Wiki/Drive/Base cross-search | NO.548 |

Issue #41 (CRM follow-up split into `create_crm_record` + `send_followup_message`
audit rows) is also blocked on this decision: there is no place today where a
single queue item can emit step-typed audit rows, because the worker is
scenario-blind.

### Load-bearing facts about the codebase (verified 2026-04-26)

1. **Worker is generic.** `lib/worker.sh` (108 lines) polls and dispatches the
   whole queue item to either `openclaw` (when `LARC_OPENCLAW_CMD` is set) or
   `larc ingress run-once` (supervised mode). A single rc is returned. There is
   no per-step concept inside the worker.
2. **Existing scenarios are inline Python heredocs in `lib/ingress.sh`.** Four
   scenarios (`ppal_marketing_ops`, `crm_followup`, `expense_approval`,
   `document_update`) live as branches of `extract_fields(scenario_id, text)`.
3. **`extract_fields` is duplicated.** It exists at `lib/ingress.sh:700` *and*
   at `lib/ingress.sh:922`, in separate heredocs. The two copies look identical
   in structure and likely drift over time. This is pre-existing tech debt
   relevant to the decision.
4. **Scenario detection is in a separate module.** `lib/ingress_scenario.py`
   maps task-type sets to a `scenario_id`.
5. **No `lib/executors/` directory exists.** Adding one is a new pattern.
6. **`ingress.sh` is 3,277 lines.** Adding more inline branches keeps growing it.

## Decision

Adopt **Option C — Hybrid**:

- Existing four inline scenarios stay where they are. Do **not** refactor them.
- New executors land as **separate files** under `lib/executors/<scenario>.sh`,
  each exposing a known function name (e.g. `executor_read_task_extract_fields`).
- A small dispatcher in `ingress.sh` checks for an external executor file
  matching `scenario_id` before falling back to the inline branches.
- The duplicate `extract_fields` at lines 700 and 922 is **not unified** as part
  of this ADR; that is a separate pre-existing problem and should be tracked in
  its own issue. Leaving them duplicated is the lower-blast-radius choice for
  the post-v0.2 cycle.

### Why Option C over A and B

**Option A — extend inline `extract_fields` with new branches**
- ✅ Zero refactor; one PR per new scenario.
- ❌ ingress.sh keeps growing (already 3,277 lines).
- ❌ Two copies of `extract_fields` mean every new scenario must be written
  twice or risk drift.
- ❌ Per-scenario testing remains impractical — the heredocs hide behind bash
  process boundaries.

**Option B — extract all scenarios to `lib/executors/*.sh` with a dispatcher**
- ✅ Clean separation; per-scenario tests possible.
- ❌ Forces refactoring four working scenarios as part of post-v0.2 stabilization.
- ❌ The duplicate `extract_fields` problem must be solved first, expanding
  blast radius.
- ❌ Risk of regression on production scenarios outweighs the cleanup value.

**Option C — Hybrid (chosen)**
- ✅ New scenarios get the cleaner pattern from day one.
- ✅ Production scenarios stay untouched until someone has a separate reason to
  refactor them.
- ✅ Dispatcher is a tiny addition (~20 lines) that does not require touching
  the duplicate `extract_fields` blocks.
- ❌ Two patterns coexist. New contributors must read this ADR to know which
  to use. (Mitigated by a one-line note in `lib/executors/README.md`.)

## Consequences

### What becomes true

- A new file `lib/executors/<name>.sh` in the repo means: "this is a typed
  executor; the dispatcher in ingress.sh will route `scenario_id=<name>` to it
  before falling back to the inline path."
- Each executor file owns one scenario_id and exports:
  - `executor_<name>_extract_fields(text) -> JSON {fields, missing, blocked, partial, ask_user}`
  - `executor_<name>_run(claimed_json) -> rc + writes audit rows directly`
- `executor_<name>_run` may emit **multiple** audit rows for the same queue_id
  (resolves #41 mechanically — `create_crm_record` and `send_followup_message`
  become two `_ingress_write_audit_log` calls inside a single `executor_crm_run`).
- Acceptance test for new executors: `scripts/verify-post-v0.2.sh --check executors`
  (to be added once the first executor lands).

### What becomes harder

- Two patterns to navigate. The `lib/executors/README.md` index is mandatory.
- Dispatcher must be kept narrow — it only checks file existence + sources +
  dispatches. Anything more becomes its own ADR.

### Migration

- No migration of existing inline scenarios. They keep working.
- `extract_fields` duplication remains a separate ticket (file new issue:
  "refactor: unify duplicate extract_fields in lib/ingress.sh").

## Alternatives considered

See "Why Option C over A and B" above. No other patterns evaluated were
substantively different from these three.

## Approval

When approved, change Status to `Approved` and implementation may proceed under
playbook tasks `p2-read-task-adapter`, `p2-search-content-adapter`,
`p2-crm-executor`, `p2-cross-search-executor`. Issue #41's CRM split lands as
part of `p2-crm-executor` (which will own the two-audit-row emission).
