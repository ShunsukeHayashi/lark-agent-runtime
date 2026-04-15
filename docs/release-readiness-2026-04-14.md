# LARC Release Readiness Assessment

> Snapshot assessment for initial open-source release readiness as of 2026-04-15.
> Updated after OpenClaw-first guidance alignment and tenant hygiene remediation.

---

## Overall Verdict

Current verdict: `PREVIEW CANDIDATE`

The repository is now suitable for an initial preview release candidate.
Public-facing docs are aligned to the OpenClaw-first story, and the tenant hygiene sweep has been completed.
The remaining work is release packaging, not a security or narrative blocker.

---

## Summary Table

| Area | Status | Notes |
|---|---|---|
| Product story | `GO` | Trilingual README updated to reflect the OpenClaw-first runtime story and distinguish stable vs. experimental paths |
| Naming and brand hygiene | `GO` | Public docs now position LARC as the governed Lark runtime layer for OpenClaw; internal naming no longer drives the release story |
| License presence | `GO` | `LICENSE` exists and matches the MIT label in README |
| Secret and tenant hygiene | `GO` | Tenant-specific open_id, table/view IDs, doc tokens, and fixed tenant URLs were replaced with placeholders or env-driven examples |
| Trilingual documentation | `GO` | README and contribution guides in English, Chinese, and Japanese are aligned to the same OpenClaw-first meaning |
| Permission credibility | `GO` | 8 regression cases passing; authority explanation in CLI output; gate policy in `config/gate-policy.json` |
| Implementation completeness | `GO (preview)` | Runtime, permission intelligence, queue/agent flow, and OpenClaw handoff path are present; IM daemon loop and environment-specific plugin/channel setup still require stable-release hardening |
| Repo cleanliness | `GO` | Hygiene fixes are committed and the remaining work is packaging, not tree cleanup |
| Public release packaging | `HOLD` | Release note, version tag, and publish decision are still pending |

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

## Remaining Work

### 1. Release packaging is not finished

The technical and documentation blockers are cleared, but the release still needs:

- a preview-oriented version/tag decision
- a concise release note
- the final publish action

### 2. Experimental scope must stay explicit

The repository is ready for a `preview` or `beta` style release, not for a “fully stable autonomous IM bot” claim.

This must remain explicit in:

- the GitHub Release body
- any launch announcement
- future README edits

---

## Recommended Next Steps

### Step 1

Freeze the release wording and version label.

Goal:

- choose `preview` or `beta`
- decide the release tag name

### Step 2

Prepare the release note.

Goal:

- explain what LARC is
- explain what is stable
- explain what remains experimental

### Step 3

Publish the release.

Goal:

- create the tag
- publish the GitHub Release

---

## Recommendation

The repo no longer has a security- or narrative-level blocker for a preview release candidate.

Instead:

1. choose the preview release label
2. write the release note
3. publish the preview release

For a stable release, autonomous IM loop behavior still needs more production hardening.

For a docs-first opening assessment, see:

- [bundle-a-readiness-2026-04-14.md](bundle-a-readiness-2026-04-14.md)
