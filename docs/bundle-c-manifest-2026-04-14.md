# LARC Bundle C Manifest

> Exact file manifest for the likely `0.1.1` candidate slice after `v0.1.0`.

---

## Bundle C Files

- `lib/memory.sh`
- `lib/send.sh`
- `scripts/register-agents.sh`

---

## Purpose

This slice is meant to improve the practical operating paths after the `v0.1.0` permission-and-gates release:

- memory round-trip
- message sending
- YAML-based agent batch registration

---

## Practical Staging Command

```bash
git add \
  lib/memory.sh \
  lib/send.sh \
  scripts/register-agents.sh
```

---

## Verification Targets

Before committing this slice, check:

- `larc memory pull` on a real or known-good record set
- `larc send` against a real chat
- `scripts/register-agents.sh --dry-run` against `agents.yaml`

---

## Commit Intent

Recommended intent:

`fix: align memory send and agent batch flows`
