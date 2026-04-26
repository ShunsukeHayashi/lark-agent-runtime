# lib/executors/

External executor modules. Loaded by the dispatcher in `lib/ingress.sh`'s
Python heredocs (lines 700 and 922) before falling back to the inline
`if/elif` scenarios.

See [docs/adr/0001-executor-architecture.md](../../docs/adr/0001-executor-architecture.md)
for the rationale.

## Convention

- One file per `scenario_id`: `lib/executors/<scenario_id>.py`
- Must define `extract_fields(text)` returning the 5-tuple:
  `(fields: dict, missing: list, blocked: list, partial: list, ask_user: str)`
- Must NOT import from `ingress.sh` heredocs. Imports must be standard library
  only (no project-specific Python modules require side-effect-free re-exec).

## Dispatcher contract

The dispatcher checks for `lib/executors/<scenario_id>.py`. If present, the
external module's `extract_fields` is called and its return value is used
directly. If not present, control flows to the inline branches.

`detect_scenario()` in `lib/ingress_scenario.py` is responsible for mapping
task-type sets to a `scenario_id`. New executors require a corresponding
branch there, or they will never be dispatched (because `scenario_id` will
remain `"generic"`).

## Index

| File | Scenario | Issue |
|---|---|---|
| `queue_triage.py` | `queue_triage` — stale in_progress + failed queue classification | #44 |
| `doc_search.py` | `doc_search` — document/invoice failure triage | #45 |
| `crm_admin.py` | `crm_admin` — CRM read/update queue triage (operator side) | #46 |
| `cross_search.py` | `cross_search` — Wiki/Drive/Base cross-source improvement-area extraction | #47 |
