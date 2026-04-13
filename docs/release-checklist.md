# LARC Release Checklist

> Private-to-public release checklist for turning this repository into a safe, credible, China-facing open-source project.

---

## 1. Release Decision

Before changing repository visibility, confirm all of the following:

- the project story is clear in `README.md`
- the Chinese and Japanese mirrors do not materially drift from the English meaning
- no private tenant information is exposed
- the repo can explain what is proven, what is partial, and what is still aspirational

If any of these are false, keep the repository private.

---

## 2. Naming And Brand Hygiene

Verify:

- no third-party product naming remains in public-facing docs unless strictly necessary for comparison
- historical internal asset names are neutralized or clearly marked as legacy
- no misleading claims imply endorsement, partnership, or official status

Suggested checks:

```bash
rg -n "bakuraku|爆落|バクラク" README* docs crm-assets
rg -n "official integration|official partner|certified" README* docs
```

Pass when:

- grep returns no unintended naming hits
- remaining references, if any, are deliberate and contextual

---

## 3. Secrets And Tenant Hygiene

Verify:

- no `.env` contents are committed
- no tenant tokens, app secrets, webhook URLs, or chat IDs are present in docs or tracked files
- no real tenant identifiers are exposed in examples

Suggested checks:

```bash
rg -n "app_secret|tenant_access_token|user_access_token|webhook|chat_id|oc_" .
git ls-files | rg "\\.env$"
```

Pass when:

- no live credentials are found
- examples use placeholders only

---

## 4. Documentation Entry Points

Verify:

- `README.md` exists and reads as the canonical public entry
- `README.zh-CN.md` exists and is first-class, not an afterthought
- `README.ja.md` exists and remains aligned
- `CONTRIBUTING.md`, `CONTRIBUTING.zh-CN.md`, and `CONTRIBUTING.ja.md` exist
- terminology glossary exists in all three languages

Pass when:

- a new contributor can understand the project in under 5 minutes from any supported language

---

## 5. Current Truth And Scope

Verify:

- README does not overclaim current implementation status
- `PLAYBOOK.md` and `docs/goal-aligned-playbook.md` reflect the actual current phase
- known limitations are documented
- speculative roadmap items are clearly separated from proven behavior

Pass when:

- the repo accurately distinguishes shipped, partial, and planned work

---

## 6. Permission Credibility

Verify:

- `docs/permission-model.md` is present and current
- `docs/auth-suggest-cases.md` is present and current
- `scripts/auth-suggest-check.sh` still matches the documented cases
- `auth suggest` explanation output still matches the documented authority model

Suggested checks:

```bash
bash scripts/auth-suggest-check.sh --list
bash scripts/auth-suggest-check.sh --case 3 --verify
bash scripts/auth-suggest-check.sh --case 7 --verify
```

Pass when:

- docs, CLI output, and regression script agree with each other

---

## 7. Command Alignment

Verify:

- wrapper scripts still reflect actual `lark-cli` behavior
- examples in docs do not use fictional commands
- known raw-API paths are documented as such

Pass when:

- command examples are believable and runnable with expected setup

---

## 8. Public Contribution Safety

Verify:

- contribution boundaries are documented
- community-safe areas are identifiable
- destructive or tenant-specific paths are not presented as casual contributions

Pass when:

- an external contributor can tell what is safe to improve without risking private operations

---

## 9. China-Facing Readiness

Verify:

- the Chinese README communicates the project’s value clearly
- Feishu/Lark terminology is consistent
- examples and wording feel native to the China market rather than loosely translated

Pass when:

- the Chinese docs can stand on their own as the primary public market narrative

---

## 10. Final Go / No-Go

Mark each item:

- `GO`
- `HOLD`
- `NOT READY`

Only switch visibility when:

- no `NOT READY` items remain in sections 2 through 6
- any `HOLD` item has an explicit reason and acceptable risk

---

## 11. Recommended Release Sequence

1. Run the naming and secret hygiene checks.
2. Re-read README and mirrors for drift.
3. Re-run permission regression checks.
4. Confirm playbook and current-truth docs are aligned.
5. Review contribution boundaries one last time.
6. Only then consider changing repository visibility.
