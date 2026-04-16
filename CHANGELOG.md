# Changelog

All notable changes to LARC will be documented in this file.

The format is intentionally lightweight while the project is still in incubation.

---

## 2026-04-15 — Portable Unix utilities

### Preparation for Windows Support milestone

Added cross-platform shims in `lib/runtime-common.sh` so the same code path works on macOS (BSD userland), Linux (GNU coreutils), Git Bash on Windows, and WSL2:

- `larc_realpath` — `realpath` → `readlink -f` → Python fallback
- `larc_stat_mtime` — BSD `stat -f %m` ↔ GNU `stat -c %Y`
- `larc_stat_mtime_human` — BSD `stat -f %Sm` ↔ GNU `stat -c %y`
- `larc_sed_inplace` — GNU `sed -i` ↔ BSD `sed -i `
- `larc_date_yesterday` — GNU `date -d` → BSD `date -v-1d` → Python fallback

Replaced the BSD-specific call sites in `bin/larc` (path resolution, cache mtime) and `lib/bootstrap.sh` (cache age, yesterday date, sed-inplace template substitution). macOS behavior is unchanged; Linux / Git Bash / WSL now go down working code paths instead of silently failing.

- Prep for #11 (stat -f), #12 (sed -i), #13 (date -v), #14 (readlink -f)
- Part of the Windows Support milestone

## 2026-04-15 — Improved error surfacing for lark-cli failures

Previously, `lark-cli` errors (typically `keychain Get failed: keychain access blocked` when running over SSH or from a sandboxed session) were swallowed by `2>/dev/null`, causing two misleading UX outcomes:

- `larc status` displayed `Base: unreachable` and `User: null` with no reason
- `larc ingress context` / agent registration printed a generic `Table creation failed`

Now both paths capture the structured `error.message` and `error.hint` from `lark-cli` and surface them to the user. `larc status` additionally falls back to the cached `LARC_LARK_USER_NAME` from `config.env` when the live check fails, marking it as cached.

- Fixes #6 (bug: larc status masks keychain errors as "unreachable")
- Fixes #7 (bug: ingress context misreports keychain failure as "Table creation failed")

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
