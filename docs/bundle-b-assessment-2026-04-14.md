# LARC Bundle B Assessment

> Runtime-freeze assessment for the next public slice, based on the repository state on 2026-04-14.

---

## Verdict

Current verdict for **Bundle B as a whole**: `HOLD`

Current verdict for the **Bundle B core subset**: `GO SOON`

This means:

- the full runtime slice should not be bundled and published as one clean public release yet
- but a narrower runtime subset already looks close enough to freeze next

---

## What Bundle B Is Trying To Cover

Bundle B is the first runtime-oriented public slice after the docs-first opening.

It is where LARC stops being only a project story and starts becoming a cleaner public implementation surface.

Candidate surfaces currently in motion:

- `bin/larc`
- `lib/auth.sh`
- `lib/approve.sh`
- `lib/agent.sh`
- `lib/memory.sh`
- `lib/send.sh`
- `scripts/register-agents.sh`
- `config/scope-map.json`
- `config/gate-policy.json`
- `lib/knowledge-graph.sh`

---

## What Looks Strong Already

### 1. Permission intelligence

`lib/auth.sh` and `config/scope-map.json` have clearly moved beyond the earlier baseline.

Evidence:

- stronger keyword mapping
- compound task handling
- authority explanation output
- gate-policy integration hooks

This is one of the strongest differentiators of the project and should likely be part of the next runtime slice.

### 2. Approval gate semantics

`lib/approve.sh` now appears to be moving toward a clearer execution-control model, including:

- `approve gate`
- explicit risk / gate descriptions
- preview vs approval separation

This aligns tightly with the public permission-first story.

### 3. Agent registry maturity

`lib/agent.sh` improvements around scopes and table fields are directionally strong.

The agent surface is becoming more compatible with the project’s story of governed multi-agent office work.

---

## What Still Looks Mixed

### 1. Register-agents workflow

`scripts/register-agents.sh` appears to be undergoing meaningful restructuring.

It may be valuable, but it is also more likely to contain transitional implementation detail that still needs one more pass before being presented as part of a frozen public runtime slice.

### 2. Knowledge graph surface

`lib/knowledge-graph.sh` is promising, but it is newly introduced and conceptually closer to a later-phase differentiator than a required early runtime freeze item.

It should probably not be forced into the next runtime release unless it is explicitly positioned as experimental.

### 3. Legacy asset migration

The `crm-assets` rename and packaging work is still in flight.

That belongs to a separate packaging concern and should not be coupled too tightly to the runtime freeze commit.

---

## Recommended Bundle B Core Subset

If the goal is to produce a smaller, cleaner next runtime commit, the best subset is likely:

- `bin/larc`
- `lib/auth.sh`
- `lib/approve.sh`
- `lib/agent.sh`
- `config/scope-map.json`
- `config/gate-policy.json`

Why this subset:

- it directly supports the permission-first story
- it improves execution control
- it matches the strongest public narrative of the project
- it avoids dragging in every runtime experiment at once

---

## Recommended Hold Items

Keep these out of the first runtime freeze unless they get another review pass:

- `scripts/register-agents.sh`
- `lib/knowledge-graph.sh`
- `crm-assets/legacy-*`
- `docs/asset-intake-plan.md`
- `lib/memory.sh`
- `lib/send.sh`

This does not mean they are bad.
It means they are less essential to the next crisp public slice.

---

## Suggested Next Step

Create a **Bundle B core manifest** for the narrow runtime subset and review only those files together.

That would make the next public runtime commit much easier to reason about than trying to freeze every remaining local change at once.

---

## Practical Interpretation

- docs-first opening: already done
- full runtime freeze: still too broad
- narrow permission-and-gates runtime freeze: likely the right next move
