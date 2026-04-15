# Changelog

All notable changes to LARC will be documented in this file.

The format is intentionally lightweight while the project is still in incubation.

---

## 2026-04-15

### OpenClaw-first positioning clarified

The public guidance now consistently treats LARC as:

- a governed runtime layer under OpenClaw
- used together with the official `openclaw-lark` plugin for atomic Lark operations
- not yet positioned as a standalone fully autonomous IM bot runtime

### Runtime and queue work

- **`larc ingress recover`**: new command resets stale `in_progress` items back to `pending`; worker auto-runs it at startup
- **`larc status`**: now shows Base connectivity, OpenClaw install state, daemon process status, and queue stats in one command
- **`memory search` pagination**: handles `has_more` correctly across large tables
- **`runtime-common.sh`**: extracted shared `larc_load_runtime_config()` and `larc_detect_openclaw_cmd()` used by daemon, worker, billing

### Onboarding and integration docs corrected

- `README.md`, `README.ja.md`, `README.zh-CN.md`: repositioned the main path as `OpenClaw Agent -> official openclaw-lark plugin + LARC`
- `docs/quickstart-ja.md`: rewritten around OpenClaw-assisted onboarding; daemon-driven IM loop is now documented as experimental
- `docs/openclaw-integration.md`: rewritten to describe the plugin-first execution model and LARC's governance role

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
