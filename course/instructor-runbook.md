# Instructor Runbook

This runbook helps an instructor deliver the Lark Harness onboarding course as a live workshop or recorded walkthrough.

The instructor must not display live App Secrets, auth URLs, QR contents, tokens, Base app tokens, folder tokens, table IDs, chat IDs, or tenant-specific private URLs.

---

## Session Shape

Recommended duration: 90 to 120 minutes.

| Segment | Time | Goal |
|---|---:|---|
| Opening and safety | 10 min | Establish secret hygiene and supported paths |
| Architecture | 10 min | Separate OpenClaw, plugin, `lark-cli`, and LARC roles |
| Install | 15 min | Verify runtime prerequisites |
| App setup and auth | 25 min | Configure `lark-cli` safely |
| Quickstart | 20 min | Run dry-run and live setup |
| Verification | 15 min | Collect read-only smoke evidence |
| Troubleshooting | 15 min | Practice common failures |

---

## Preflight for Instructor

Before recording or teaching:

```bash
larc version
lark-cli --version
node --version
python3 --version
```

Prepare:

- a demo Lark app with non-production data
- a clean terminal profile
- a redaction plan for any output that includes identifiers
- a backup path if browser auth or QR auth expires

Do not prepare:

- screenshots containing raw QR codes
- copied auth URLs
- raw App Secret values in slides
- tenant-specific tokens in examples

---

## Demo 1: Roles and Mental Model

Show the supported path:

```text
OpenClaw Feishu/Lark channel
  -> official openclaw-lark plugin
  -> LARC runtime controls
  -> Lark tenant APIs
```

Narration points:

- The user talks to the OpenClaw-connected chat app or bot.
- `lark-cli` is the local auth and API substrate.
- LARC adds permission explanation, execution gates, queue, memory, and audit.
- The experimental IM daemon is not the primary onboarding path.

Checkpoint:

- Learners can say where the chat entry point lives.

---

## Demo 2: Install Checks

Run:

```bash
node --version
python3 --version
lark-cli --version
larc version
```

Windows variant:

```bash
git --version
jq --version
larc version
```

Checkpoint:

- Learners record tool versions in the checklist.

---

## Demo 3: App Setup

Explain the three auth modes:

1. self-owned dev app
2. operator-provisioned machine
3. shared secret fallback for short controlled tests only

Show command shape only:

```bash
lark-cli config init \
  --app-id <APP_ID> \
  --app-secret-stdin \
  --brand lark
```

Teaching note:

- When the prompt asks for the secret, pause recording or switch to a prepared redacted terminal.
- Never paste the secret into a visible command line.

Checkpoint:

- `lark-cli config show` reports an app configured, with sensitive values masked or redacted.

---

## Demo 4: Auth Login

Run:

```bash
lark-cli auth login
lark-cli auth status
```

Common live teaching issue:

- If the QR or browser page expires, restart `lark-cli auth login`.
- Do not paste the expired URL into chat or issue comments.

Checkpoint:

- `lark-cli auth status` reaches a valid status or produces a non-secret blocker.

---

## Demo 5: Quickstart

Run:

```bash
larc quickstart --dry-run
larc quickstart
```

Narration points:

- Dry-run is the preview step.
- Quickstart creates LARC-owned workspace folders, a LARC-memory Base, identity docs, and local config.
- It should not mutate existing user projects.

Checkpoint:

- Learner can identify the generated resources without exposing their tokens.

---

## Demo 6: Verification

Run read-only checks:

```bash
larc status
larc auth suggest "create an expense report and request approval"
larc ingress list --agent main --status pending --limit 5
larc ingress stats --agent main
```

Checkpoint:

- The learner records pass/fail for each command in [Learner Checklist](learner-checklist.md).

---

## Demo 7: Troubleshooting Tabletop

Use these prompts:

| Scenario | Expected learner response |
|---|---|
| QR expired | Restart `lark-cli auth login`; do not reuse the old URL |
| App exists but CLI says not configured | Run `lark-cli config show`; run `config init` if missing |
| `auth status` invalid | Re-run auth login; record non-secret error category |
| Windows `larc` not found | Check Git Bash / PATH / `larc.ps1` launcher |
| WSL cannot see config | Explain WSL home vs Windows home |

Checkpoint:

- Learners produce a non-secret blocker report.

---

## Instructor Completion Gate

Before marking the cohort complete, confirm:

- every learner has a filled checklist
- screenshots are redacted
- no issue comment contains raw secrets or live auth URLs
- Windows learners record shell and config location
- unresolved blockers are filed with command, error category, and environment only
