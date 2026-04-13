# LARC Release Readiness Assessment

> Snapshot assessment for initial open-source release readiness as of 2026-04-14.
> Updated after Phases A–E completion and release hygiene sweep.

---

## Overall Verdict

Previous verdict: `HOLD` → Updated verdict: `CLOSE`

All five implementation phases are complete and live-verified against a real Lark tenant.
The remaining blocker is a single commit to freeze the 0.1.0 file set.

---

## Summary Table

| Area | Status | Notes |
|---|---|---|
| Product story | `GO` | Trilingual README updated to reflect Phases A–E; distinguishes proven vs. experimental |
| Naming and brand hygiene | `GO` | `crm-assets/ppal-*` and `miyabi-*` excluded via `.gitignore`; no external brand naming in public docs |
| License presence | `GO` | `LICENSE` exists and matches the MIT label in README |
| Secret and tenant hygiene | `HOLD` | Grep sweep clean; `oc_1234567890abcdef` in lark-doc is a placeholder. Re-run sweep on final commit. |
| Trilingual documentation | `GO` | README, CONTRIBUTING, glossary in English, Chinese, and Japanese — all updated to Phase E state |
| Permission credibility | `GO` | 8 regression cases passing; authority explanation in CLI output; gate policy in `config/gate-policy.json` |
| Implementation completeness | `GO` | Phases A–E complete: runtime / permission intelligence / agents / approval gates / knowledge graph |
| Repo cleanliness | `HOLD` | New files untracked (gate-policy.json, knowledge-graph.sh, agents.yaml). One commit needed to freeze 0.1.0. |
| Public release packaging | `HOLD` | File set is now determined; commit + tag is the remaining action. |

---

## What Is Already Good Enough

### 1. The public story exists

The repo now has:

- `README.md`
- `README.zh-CN.md`
- `README.ja.md`
- `CONTRIBUTING.md`
- `CONTRIBUTING.zh-CN.md`
- `CONTRIBUTING.ja.md`
- trilingual terminology glossaries
- open-source planning docs
- a release checklist

This is enough to open the door conceptually.

### 2. The technical wedge is legible

The permission-first angle is now visible through:

- `docs/permission-model.md`
- `docs/auth-suggest-cases.md`
- `scripts/auth-suggest-check.sh`

Representative checks passed during review:

- Case 3: CRM record + follow-up message
- Case 7: CRM lead + follow-up meeting

### 3. The project is no longer narratively ambiguous

The repo now clearly says:

- what is proven
- what is in incubation
- what the China-facing story is

---

## Blocking Issues

### 1. Working tree is still mixed

The repository still contains:

- staged concept changes mixed with implementation changes
- parallel work artifacts
- renamed legacy files not yet bundled into a clean initial release slice

This means the current tree is not yet a clean public release candidate.

### 2. The release boundary is still fuzzy

There is not yet a clearly frozen answer to:

- which docs are in the public initial cut
- which legacy assets remain included
- which implementation changes belong to `0.1.0`
- which files should stay private for a later wave

### 3. Final hygiene sweep still needs to be run as a release action

The release checklist exists, but it has not yet been executed as a formal pre-release pass with the final file set frozen.

---

## Recommended Next Steps

### Step 1

Create a public-release candidate slice.

Goal:

- decide which files are part of the initial public opening
- separate them from ongoing internal or parallel work

### Step 2

Run the release checklist against that frozen slice.

Goal:

- mark each section as `GO`, `HOLD`, or `NOT READY`
- remove ambiguity before changing visibility

### Step 3

Prepare a minimal release note for the initial opening.

Goal:

- explain what LARC is
- explain what is already working
- explain what is still experimental

---

## Recommendation

Do not change repository visibility yet.

Instead:

1. freeze the initial public file set
2. run the release checklist one more time
3. then re-evaluate the repo as a true release candidate

At the current pace, this looks close rather than far.

For a docs-first opening assessment, see:

- [bundle-a-readiness-2026-04-14.md](bundle-a-readiness-2026-04-14.md)
