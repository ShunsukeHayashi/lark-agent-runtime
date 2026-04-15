# Changelog

All notable changes to LARC will be documented in this file.

The format is intentionally lightweight while the project is still in incubation.

---

## 2026-04-15

### Autonomous loop — Bridge mode fully operational

Complete end-to-end autonomous loop confirmed working without the OpenClaw Lark plugin:

- **IM poller echo loop fix**: daemon now fetches bot's own `open_id` at startup and skips outbound messages, preventing infinite re-enqueue
- **openclaw reply path fix**: the prompt sent to `openclaw agent` now explicitly instructs `larc send` + `larc ingress done` as the mandatory reply step, removing dependency on the broken `extensions/lark/` plugin
- **`larc ingress recover`**: new command resets stale `in_progress` items back to `pending`; worker auto-runs it at startup
- **`larc status`**: now shows Base connectivity, OpenClaw install state, daemon process status, and queue stats in one command
- **`memory search` pagination**: handles `has_more` correctly across large tables
- **`runtime-common.sh`**: extracted shared `larc_load_runtime_config()` and `larc_detect_openclaw_cmd()` used by daemon, worker, billing

### Onboarding docs updated

- `docs/quickstart-ja.md`: rewritten to reflect Bridge mode (no Lark plugin required), autonomous loop steps, and new troubleshooting entries
- `docs/openclaw-integration.md`: clarified that `extensions/lark/` is not used; LARC uses `larc send` (lark-cli) for Lark IM replies

---

## 2026-04-14

### Initial docs-first public opening

Opened the repository publicly with a docs-first slice centered on:

- trilingual README entry points
- trilingual CONTRIBUTING guides
- trilingual terminology glossaries
- permission model and `auth suggest` case documentation
- release checklist, readiness assessment, and launch messaging docs

This opening is intentionally **not** presented as a fully frozen runtime release.
It is the public opening of the project story, contribution surface, and permission-first design direction.

### Public metadata

- official name fixed as `Lark Agent Runtime`
- short name fixed as `LARC`
- repository description aligned to `Permission-first runtime for Lark-native office-work agents.`

### Notes

- runtime implementation work continues outside the initial docs-first opening slice
- legacy reference assets remain under separate review for later public packaging
