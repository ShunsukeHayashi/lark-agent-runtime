# Lark Harness Onboarding Online Course

This course turns the Lark Harness onboarding flow into a self-paced path that a learner can finish without live hand-holding.

Use it with:

- [Instructor Runbook](instructor-runbook.md) for demos and facilitation
- [Learner Checklist](learner-checklist.md) for completion evidence
- [Troubleshooting Guide](troubleshooting.md) for common setup failures

No live secrets, tenant tokens, app IDs, Base tokens, chat IDs, auth URLs, or QR contents belong in these materials.

---

## Audience

This course is for developers, operators, and technical testers who need to set up Lark Harness with OpenClaw and Lark safely.

Learners should already be comfortable with:

- running shell commands
- creating or using a Lark Developer Console app
- distinguishing local machine setup from tenant-level app configuration

---

## Course Outcomes

By the end, the learner can:

1. Explain the roles of OpenClaw, the OpenClaw Feishu/Lark channel, the official `openclaw-lark` plugin, `lark-cli`, and `larc`.
2. Install Lark Harness on macOS/Linux or Windows-supported paths.
3. Configure `lark-cli` without exposing App Secret values in chat, docs, or GitHub.
4. Run `larc quickstart` and understand what it creates.
5. Verify `larc status`, auth scope inference, queue inspection, and OpenClaw handoff.
6. Diagnose common auth and setup blockers without leaking sensitive values.

---

## Course Map

| Module | Lesson | Outcome | Lab |
|---|---|---|---|
| 0. Safety and vocabulary | Permission-first model | Learner can explain scope, authority, app secret, user token, and bot/app authority | Identify which setup values are safe to share |
| 1. Architecture | OpenClaw + Lark Harness roles | Learner can draw the supported runtime path | Label each component in a workflow |
| 2. Install | Runtime installation | Learner can install `lark-cli` and `larc` | Run version checks |
| 3. Lark app setup | App creation or operator-provisioned config | Learner can choose a safe auth mode | Select self-owned vs operator-provisioned setup |
| 4. Auth | `lark-cli config init` and `auth login` | Learner can complete device/browser auth and verify status | Run `lark-cli auth status` |
| 5. Quickstart | Automated workspace setup | Learner can preview and execute `larc quickstart` | Run dry-run, then live quickstart |
| 6. Verification | Read-only smoke checks | Learner can collect completion evidence | Run `larc status`, `auth suggest`, and queue list |
| 7. Windows / AAI | Git Bash, WSL, PowerShell launcher | Learner can select a supported Windows path | Run Windows read-only smoke |
| 8. Troubleshooting | Recovery patterns | Learner can handle QR expiry and app/config mismatches | Resolve a simulated blocker |

---

## Module Details

### Module 0: Safety and Vocabulary

Core ideas:

- `scope` is what the Lark app is allowed to request.
- `authority` is who the action runs as: user, bot/app, or mixed.
- App Secret, tokens, auth URLs, QR codes, Base tokens, folder tokens, table IDs, and chat IDs are sensitive operational values.
- Course evidence should prove the setup completed without revealing those values.

Lab:

1. Read [docs/permission-model.md](../docs/permission-model.md).
2. Classify these as safe or unsafe to paste into GitHub:
   - command names
   - redacted status output
   - raw App Secret
   - QR login URL
   - screenshot with tokens visible
   - `larc status` result with sensitive IDs redacted

Completion check:

- Learner can state that raw auth URLs and QR contents must not be shared.

### Module 1: Architecture

Supported runtime path:

```text
User request
  -> OpenClaw Feishu/Lark channel
  -> official openclaw-lark plugin for atomic Lark operations
  -> LARC for auth explanation, approval gates, queue, memory, and audit
  -> Lark tenant surfaces
```

Lab:

1. Read [docs/quickstart-ja.md](../docs/quickstart-ja.md) through Step 0.
2. Explain why `larc daemon start` is not the first onboarding path.

Completion check:

- Learner can say which component owns the chat entry point.

### Module 2: Install

Reference:

- macOS/Linux: [README.md](../README.md) and [docs/quickstart-ja.md](../docs/quickstart-ja.md)
- Windows: [docs/install-windows.md](../docs/install-windows.md)

Lab:

```bash
node --version
python3 --version
lark-cli --version
larc version
```

Completion check:

- Learner records tool versions without adding secrets.

### Module 3: Lark App Setup

Recommended auth modes:

| Mode | Use when | Secret handling |
|---|---|---|
| Self-owned dev app | Developer can create their own app | Secret stays with the learner |
| Operator-provisioned machine | Admin can touch the target machine | Admin enters secret directly on the machine |
| Shared secret fallback | Short-lived controlled test only | Avoid as a normal process |

Lab:

1. Read [docs/lark-dev-app-create-plan.md](../docs/lark-dev-app-create-plan.md).
2. Pick the safest auth mode for the learner's environment.

Completion check:

- Learner can explain why App Secret should not be pasted into chat or GitHub.

### Module 4: Auth

The expected command shape is:

```bash
lark-cli config init \
  --app-id <APP_ID> \
  --app-secret-stdin \
  --brand lark

lark-cli auth login
lark-cli auth status
```

Important cases:

- QR or browser auth expired: restart `lark-cli auth login`; do not reuse stale auth URLs.
- App created but CLI not configured: run `lark-cli config show`; if no app is configured, run `lark-cli config init`.
- App scopes missing: update the app in Lark Developer Console, publish if required, then run auth again.

Lab:

1. Run `lark-cli config show`.
2. Run `lark-cli auth status`.
3. Redact sensitive identifiers before sharing evidence.

Completion check:

- `tokenStatus` is valid or the remaining blocker is documented without secrets.

### Module 5: Quickstart

Commands:

```bash
larc quickstart --dry-run
larc quickstart
```

What quickstart creates:

- `larc-workspace/`
- `larc-workdir/`
- `LARC-memory` Base
- SOUL / USER / MEMORY / HEARTBEAT docs
- local `~/.larc/config.env`

Lab:

1. Run dry-run first.
2. Run live quickstart only after auth is ready.
3. Save completion evidence with tokens redacted.

Completion check:

- Learner can explain that quickstart creates LARC-owned resources and should not mutate existing user projects.

### Module 6: Verification

Read-only smoke commands:

```bash
larc status
larc auth suggest "create an expense report and request approval"
larc ingress list --agent main --status pending --limit 5
larc ingress stats --agent main
```

Lab:

1. Run all read-only smoke commands.
2. Capture the outcome in the [Learner Checklist](learner-checklist.md).

Completion check:

- `larc status` reaches the Lark connection block, or the exact non-secret blocker is recorded.

### Module 7: Windows / AAI

Supported paths:

- Git Bash for most users
- WSL2 for Linux-style users
- PowerShell launcher when `larc.ps1` delegates to bash

Lab:

1. Read [docs/install-windows.md](../docs/install-windows.md).
2. Pick one runtime path and do not mix Windows-side and WSL-side `~/.larc` unless deliberately linked.
3. Run the read-only smoke commands.

Completion check:

- Learner can state which shell was used and where `~/.larc/config.env` lives.

### Module 8: Troubleshooting

Use [Troubleshooting Guide](troubleshooting.md) as the first response path.

Lab:

1. Diagnose one simulated blocker:
   - expired QR
   - app exists but CLI not configured
   - auth status invalid
   - Windows path mismatch
2. Write a non-secret resolution note.

Completion check:

- Learner can produce a concise blocker report that contains commands and error categories, not credentials.

---

## Completion Evidence

A learner has completed the course when the checklist includes:

- environment and shell
- install/version checks
- auth status category
- quickstart result
- read-only smoke results
- troubleshooting notes, if any
- explicit confirmation that no secrets were pasted into the report

Use [Learner Checklist](learner-checklist.md) as the evidence template.
