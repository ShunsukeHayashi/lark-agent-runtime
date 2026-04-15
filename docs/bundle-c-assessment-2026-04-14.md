# LARC Bundle C Assessment

> Assessment for the next post-`v0.1.0` runtime slice, focused on memory, send, and agent registration flows.

---

## Verdict

Current verdict for **Bundle C**: `GO SOON`

This slice is smaller and more operational than Bundle B.
It looks like a natural follow-up candidate for `0.1.1`.

---

## Proposed Scope

Bundle C should focus on:

- `lib/memory.sh`
- `lib/send.sh`
- `scripts/register-agents.sh`
- supporting docs updates only if they are needed to explain behavior changes

---

## Why This Slice Makes Sense

### 1. It follows the public runtime story cleanly

After permission inference, gates, and agent registry core, the next most natural surfaces are:

- memory round-trip
- message dispatch
- batch registration workflow

These are operationally important and easy to explain.

### 2. The changes appear mostly alignment-oriented

From the current diffs:

- `lib/memory.sh` is aligning with actual `lark-cli base +record-list` response structure
- `lib/send.sh` is aligning with the correct IM send shortcut form
- `scripts/register-agents.sh` is being simplified around YAML-driven batch registration

That is a good shape for a small public runtime follow-up.

### 3. It avoids dragging in unrelated experimental surfaces

This slice does not need:

- knowledge graph
- legacy asset packaging
- broader planning docs

That keeps the next release understandable.

---

## Risks To Watch

### 1. Register-agents may still be transitional

This file has the most restructuring in the slice.
It should be reviewed carefully before being frozen as part of a public release.

### 2. Memory parsing should be checked against real responses

The change in `lib/memory.sh` is plausible and directionally right, but it should still be tested against a live tenant or a known-good fixture before release.

### 3. Send path should be validated end-to-end

The `im +messages-send --text` form looks correct, but it should be exercised through an actual message send before being frozen publicly.

---

## Recommended Next Step

Create a **Bundle C manifest** and a small verification checklist for:

- memory pull
- send
- register-agents dry-run

If those checks pass, the slice is a strong `0.1.1` candidate.

---

## Practical Interpretation

- `v0.1.0`: docs-first opening + permission/gate runtime core
- `v0.1.1` candidate: memory/send/register-agents operational slice

That progression feels coherent and easy to explain publicly.
