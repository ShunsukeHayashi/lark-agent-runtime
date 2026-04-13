# LARC Public Release Bundle Plan

> Proposed bundling strategy for the first public opening, based on the repository state on 2026-04-14.

---

## Decision

Use a **two-bundle release strategy** instead of treating the whole working tree as one public release candidate.

This reduces risk and makes the first opening easier to audit.

---

## Bundle A: Public Opening Core

This bundle is the recommended minimum for opening the repository.

### Include

#### Root entry points

- `README.md`
- `README.zh-CN.md`
- `README.ja.md`
- `CONTRIBUTING.md`
- `CONTRIBUTING.zh-CN.md`
- `CONTRIBUTING.ja.md`
- `LICENSE`

#### Public planning and truth docs

- `PLAYBOOK.md`
- `docs/goal-aligned-playbook.md`
- `docs/permission-model.md`
- `docs/auth-suggest-cases.md`
- `docs/open-source-trilingual-plan.md`
- `docs/release-checklist.md`
- `docs/release-readiness-2026-04-14.md`
- `docs/public-release-candidate-scope.md`
- `docs/terminology-glossary.md`
- `docs/terminology-glossary.zh-CN.md`
- `docs/terminology-glossary.ja.md`

#### Safe helper scripts

- `scripts/auth-suggest-check.sh`

### Why Bundle A first

- it explains the project clearly
- it shows the permission-first wedge
- it gives contributors safe places to start
- it avoids overcommitting unstable runtime details on day one

---

## Bundle B: Runtime Surface Freeze

This bundle should come only after the runtime slice is frozen as a coherent public story.

### Candidate files

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
- `scripts/setup-workspace.sh`

### Current status

`HOLD`

Reason:

- the working tree still mixes public-facing changes with ongoing implementation changes
- some runtime-related files are being changed in parallel
- the initial public narrative is already strong enough without forcing an unstable runtime freeze immediately

---

## Bundle C: Legacy Reference Assets

These are potentially useful, but should be treated as secondary.

### Candidate files

- `crm-assets/legacy-backoffice-CLAUDE.md`
- `crm-assets/legacy-backoffice-SPEC.md`
- `crm-assets/legacy-lark-approval.ts`
- `crm-assets/legacy-lark-auth.ts`
- `docs/asset-intake-plan.md`

### Current status

`HOLD`

Reason:

- these files are valuable as reference material
- but they still need one more pass to confirm they are framed as legacy/internal reference assets rather than core product surface

---

## What this means

If the goal is to open the project door as soon as possible, **Bundle A** is enough to justify an initial public opening.

If the goal is to open with a stronger technical implementation story, wait until **Bundle B** is frozen cleanly.

---

## Recommendation

Recommended order:

1. Freeze Bundle A.
2. Re-run the release checklist.
3. Decide whether the initial public opening should be docs-first.
4. Only then decide whether to add Bundle B in the same release or shortly after.

---

## Practical Interpretation

Right now, the repository appears closer to:

- `GO` for a docs-first public opening
- `HOLD` for a full runtime-first public opening

That distinction should guide the next packaging step.
