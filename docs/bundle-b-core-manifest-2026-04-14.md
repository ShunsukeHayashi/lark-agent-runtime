# LARC Bundle B Core Manifest

> Exact file manifest for the narrow runtime slice recommended as the next public implementation-oriented commit.

---

## Purpose

This manifest defines the **Bundle B core subset**.

It exists to keep the next runtime-facing public slice:

- small enough to review
- aligned with the permission-first story
- separate from later-phase experiments

---

## Bundle B Core Files

- `bin/larc`
- `config/scope-map.json`
- `config/gate-policy.json`
- `lib/auth.sh`
- `lib/approve.sh`
- `lib/agent.sh`

---

## Why These Files

This subset directly supports the strongest public differentiators of LARC:

- permission intelligence
- authority explanation
- execution gates
- governed agent registry behavior

These files are the cleanest next step after the docs-first opening.

---

## Explicitly Not In Bundle B Core

Do not pull these into the same commit yet:

- `lib/memory.sh`
- `lib/send.sh`
- `scripts/register-agents.sh`
- `lib/knowledge-graph.sh`
- `crm-assets/legacy-*`
- `docs/asset-intake-plan.md`

Those deserve separate review or later packaging.

---

## Practical Staging Command

```bash
git add \
  bin/larc \
  config/scope-map.json \
  config/gate-policy.json \
  lib/auth.sh \
  lib/approve.sh \
  lib/agent.sh
```

Review the staged diff before committing.

---

## Commit Intent

Recommended intent:

`feat: freeze permission and gate runtime core`

This keeps the commit aligned with the actual value being shipped.

---

## Final Rule

If a runtime change does not clearly improve:

- permission inference
- authority clarity
- gate behavior
- agent registry semantics

then it likely belongs outside this core subset.
