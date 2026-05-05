# Learner Checklist

Use this checklist as the completion record for the Lark Harness onboarding course.

Do not paste raw secrets, tokens, auth URLs, QR codes, app IDs, Base tokens, folder tokens, table IDs, chat IDs, or tenant-private URLs. Use redacted placeholders.

---

## 1. Environment

| Item | Answer |
|---|---|
| OS | |
| Shell | |
| Runtime path | macOS/Linux / Git Bash / WSL2 / PowerShell launcher |
| Lark tenant type | test / dev / production |
| OpenClaw available | yes / no |

Evidence:

```text
<redacted notes>
```

---

## 2. Tool Versions

Run:

```bash
node --version
python3 --version
lark-cli --version
larc version
```

Windows learners also run:

```bash
git --version
jq --version
```

Record:

| Tool | Version |
|---|---|
| node | |
| python | |
| lark-cli | |
| larc | |
| git, if Windows | |
| jq, if Windows | |

---

## 3. App Setup Mode

Choose one:

- [ ] Self-owned dev app
- [ ] Operator-provisioned machine
- [ ] Short controlled shared-secret fallback

Confirm:

- [ ] App Secret was entered only through an interactive secret prompt or operator-controlled setup.
- [ ] App Secret was not pasted into chat, docs, issue comments, screenshots, or shell history.
- [ ] Any screenshots are redacted.

Notes:

```text
<redacted notes>
```

---

## 4. lark-cli Config and Auth

Run:

```bash
lark-cli config show
lark-cli auth status
```

Record:

| Check | Result |
|---|---|
| CLI app configured | pass / blocked |
| Auth status valid | pass / blocked |
| Blocker category, if any | |

If QR or browser auth expired:

- [ ] Restarted `lark-cli auth login`.
- [ ] Did not paste the expired URL or QR content anywhere.

If app exists but CLI is not configured:

- [ ] Ran `lark-cli config show`.
- [ ] Ran or requested `lark-cli config init`.

---

## 5. Quickstart

Run:

```bash
larc quickstart --dry-run
larc quickstart
```

Record:

| Check | Result |
|---|---|
| Dry-run completed | pass / blocked |
| Live quickstart completed | pass / blocked |
| Existing user projects untouched | confirmed / not checked |
| `~/.larc/config.env` created | yes / no |

Do not record raw token values from generated resources.

---

## 6. Read-only Smoke

Run:

```bash
larc status
larc auth suggest "create an expense report and request approval"
larc ingress list --agent main --status pending --limit 5
larc ingress stats --agent main
```

Record:

| Command | Result | Non-secret notes |
|---|---|---|
| `larc status` | pass / blocked | |
| `larc auth suggest ...` | pass / blocked | |
| `larc ingress list ...` | pass / blocked | |
| `larc ingress stats ...` | pass / blocked | |

---

## 7. Windows / AAI Addendum

Complete this section only for Windows learners.

| Item | Answer |
|---|---|
| Shell used | Git Bash / WSL2 / PowerShell launcher |
| Config location | Windows home / WSL home / linked |
| `larc.ps1` used | yes / no |
| `jq` available | yes / no |

Confirm:

- [ ] Did not mix WSL-side `~/.larc` with Windows-side `~/.larc` accidentally.
- [ ] If using Task Scheduler or NSSM, credentials belong to the same interactive user that completed auth.

---

## 8. Completion Statement

Fill in:

```text
I completed the Lark Harness onboarding course on <date>.
No raw secrets, tokens, auth URLs, QR contents, app IDs, Base tokens, folder tokens, table IDs, chat IDs, or tenant-private URLs are included in this report.
Remaining blocker, if any: <non-secret description>
```
