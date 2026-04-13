# LARC Public Release Candidate Scope

> Proposed file scope for the initial public opening of this repository.

---

## Goal

Define the smallest credible public first cut.

This document exists so the first open-source release is:

- understandable
- safe
- technically honest
- easy to review before changing repository visibility

---

## Include In The Initial Public Opening

### Root documents

- `README.md`
- `README.zh-CN.md`
- `README.ja.md`
- `CONTRIBUTING.md`
- `CONTRIBUTING.zh-CN.md`
- `CONTRIBUTING.ja.md`
- `LICENSE`

### Core planning and model docs

- `PLAYBOOK.md`
- `docs/goal-aligned-playbook.md`
- `docs/permission-model.md`
- `docs/auth-suggest-cases.md`
- `docs/open-source-trilingual-plan.md`
- `docs/release-checklist.md`
- `docs/release-readiness-2026-04-14.md`
- `docs/terminology-glossary.md`
- `docs/terminology-glossary.zh-CN.md`
- `docs/terminology-glossary.ja.md`

### Core runtime surface

- `bin/larc`
- `lib/bootstrap.sh`
- `lib/memory.sh`
- `lib/send.sh`
- `lib/task.sh`
- `lib/approve.sh`
- `lib/auth.sh`
- `lib/heartbeat.sh`
- `lib/agent.sh`
- `config/scope-map.json`

### Verification helpers

- `scripts/auth-suggest-check.sh`
- `scripts/setup-workspace.sh`

### Legacy reference assets that are now neutralized

- `crm-assets/legacy-backoffice-SPEC.md`
- `crm-assets/legacy-backoffice-CLAUDE.md`
- `crm-assets/legacy-lark-approval.ts`
- `crm-assets/legacy-lark-auth.ts`

Only include these if the naming cleanup is already complete and they are clearly marked as legacy references, not the main product surface.

---

## Keep Private For Now

### Assets that are still incubation-heavy

- exploratory notes that assume internal context only
- unsanitized tenant-specific examples
- any file that still mixes personal operational detail with product messaging

### Parallel or unstable work

- files whose public meaning depends on changes still being made in parallel
- implementation slices that do not yet match the docs

---

## Release Candidate Criteria

The initial public cut should satisfy all of the following:

- a new reader can understand the project from the README set
- the permission-first wedge is visible within minutes
- representative regression checks still pass
- no obvious naming or secret hygiene risks remain
- the legacy assets, if included, are clearly secondary

---

## Recommended Packaging Order

1. Freeze docs and README set.
2. Freeze permission docs and regression helper.
3. Freeze only the runtime files that match the public story.
4. Re-check naming and secret hygiene.
5. Re-run the release checklist.

---

## Current Recommendation

Use this document to decide what belongs in the first public commit range.

Do not treat the whole working tree as the release candidate.
Instead, carve out a minimal and coherent public slice first.
