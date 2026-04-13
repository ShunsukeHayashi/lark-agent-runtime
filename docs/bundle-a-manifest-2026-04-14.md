# LARC Bundle A Manifest

> Exact file manifest for the docs-first public opening candidate as of 2026-04-14.

---

## Purpose

This manifest defines the exact file set for **Bundle A**.

Use it when:

- preparing the first docs-first public opening
- staging files intentionally
- reviewing whether the public opening scope is still coherent

This is not the whole repository.
It is the smallest intended public opening slice.

---

## Bundle A File Set

### Root files

- `README.md`
- `README.zh-CN.md`
- `README.ja.md`
- `CONTRIBUTING.md`
- `CONTRIBUTING.zh-CN.md`
- `CONTRIBUTING.ja.md`
- `LICENSE`
- `PLAYBOOK.md`

### Docs

- `docs/goal-aligned-playbook.md`
- `docs/permission-model.md`
- `docs/auth-suggest-cases.md`
- `docs/open-source-trilingual-plan.md`
- `docs/release-checklist.md`
- `docs/release-readiness-2026-04-14.md`
- `docs/public-release-candidate-scope.md`
- `docs/public-release-bundle-2026-04-14.md`
- `docs/bundle-a-readiness-2026-04-14.md`
- `docs/launch-messaging.md`
- `docs/repo-publish-kit.md`
- `docs/terminology-glossary.md`
- `docs/terminology-glossary.zh-CN.md`
- `docs/terminology-glossary.ja.md`

### Safe verification helper

- `scripts/auth-suggest-check.sh`

---

## Explicitly Not In Bundle A

Do not treat the following as required for the initial docs-first public opening:

- `bin/larc`
- `lib/*.sh`
- `config/scope-map.json`
- `scripts/setup-workspace.sh`
- `crm-assets/legacy-*`
- `docs/asset-intake-plan.md`

These belong to later review waves or Bundle B / Bundle C.

---

## Practical Staging Command

When you want to stage **only** Bundle A, use a command like this:

```bash
git add \
  README.md README.zh-CN.md README.ja.md \
  CONTRIBUTING.md CONTRIBUTING.zh-CN.md CONTRIBUTING.ja.md \
  LICENSE PLAYBOOK.md \
  docs/goal-aligned-playbook.md \
  docs/permission-model.md \
  docs/auth-suggest-cases.md \
  docs/open-source-trilingual-plan.md \
  docs/release-checklist.md \
  docs/release-readiness-2026-04-14.md \
  docs/public-release-candidate-scope.md \
  docs/public-release-bundle-2026-04-14.md \
  docs/bundle-a-readiness-2026-04-14.md \
  docs/launch-messaging.md \
  docs/repo-publish-kit.md \
  docs/terminology-glossary.md \
  docs/terminology-glossary.zh-CN.md \
  docs/terminology-glossary.ja.md \
  scripts/auth-suggest-check.sh
```

Review the staged set before committing.

---

## Commit Intent

Recommended intent for this bundle:

`docs: open the project with a trilingual docs-first public slice`

This keeps the message aligned with the actual release strategy.

---

## Final Rule

If a file does not clearly support:

- project understanding
- contribution onboarding
- permission credibility
- release readiness

then it probably does not belong in Bundle A.
