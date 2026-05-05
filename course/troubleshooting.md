# Troubleshooting Guide

This guide covers the setup failures learners are most likely to hit during the online course.

Do not paste live auth URLs, QR contents, App Secrets, tokens, Base tokens, folder tokens, table IDs, chat IDs, or tenant-private URLs into issue comments or course reports.

---

## Triage Pattern

For any failure, capture only:

```text
OS:
Shell:
Command:
Error category:
Redacted stderr:
What was already tried:
```

Do not capture:

- raw URLs from auth login
- QR screenshots
- token values
- config file contents
- tenant-specific private links

---

## QR or Browser Auth Expired

Symptoms:

- browser page says the request expired
- QR code no longer works
- login command times out

Resolution:

```bash
lark-cli auth login
```

Use the new login flow. Do not reuse or share the old auth URL.

If this repeats:

1. Keep the terminal visible while logging in.
2. Complete the browser or QR step immediately.
3. Record only that the login expired; do not paste the URL.

---

## App Created but CLI Not Configured

Symptoms:

- `lark-cli auth status` reports not configured
- `larc quickstart` cannot detect a configured app
- the learner has created a Developer Console app but never ran local CLI setup

Diagnosis:

```bash
lark-cli config show
```

Resolution:

```bash
lark-cli config init \
  --app-id <APP_ID> \
  --app-secret-stdin \
  --brand lark
```

Then:

```bash
lark-cli auth login
lark-cli auth status
```

Safety note:

- Enter the secret only at the secret prompt.
- Do not put the secret directly into the shell command.

---

## Auth Status Invalid

Symptoms:

- `tokenStatus` is invalid
- `larc status` cannot read Lark connection state
- read-only Lark commands fail because auth is stale

Resolution:

```bash
lark-cli auth login
lark-cli auth status
```

If the app was recently changed:

1. Confirm required scopes in Lark Developer Console.
2. Publish or apply changes if the console requires it.
3. Run auth login again.

---

## Missing App Scope During Quickstart

Symptoms:

- quickstart fails before creating Drive/Base resources
- message says the Bot App is missing required scopes
- Drive, Base, permission member, or doc creation is blocked

Resolution:

1. Open the Developer Console permissions page for the app.
2. Add the listed scopes.
3. Publish or apply the app version if required.
4. Re-run:

```bash
larc quickstart
```

Do not attempt to work around missing app scopes by copying tokens from another environment.

---

## Quickstart Stops at Folder Creation

Symptoms:

- Drive folder creation fails
- the CLI asks for confirmation
- Lark returns a permission error

Resolution:

1. Update LARC to a version that passes confirmation flags for intentional quickstart writes.
2. Verify app scopes:

```bash
lark-cli auth scopes
```

3. Re-run:

```bash
larc quickstart --dry-run
larc quickstart
```

If it still fails, record only the error category and redacted stderr.

---

## Windows: `larc` Not Found

Symptoms:

- `larc` works in one shell but not another
- PowerShell cannot find `larc`
- Git Bash can run it but `pwsh` cannot

Resolution:

1. Use the supported Windows path from [docs/install-windows.md](../docs/install-windows.md).
2. Confirm runtime bin is on `PATH`.
3. If using PowerShell, confirm the launcher is available:

```powershell
larc version
```

If needed, set the bash interpreter explicitly:

```powershell
$env:LARC_BASH = "C:\Program Files\Git\bin\bash.exe"
```

---

## Windows: WSL and Git Bash Config Mismatch

Symptoms:

- auth works in Git Bash but not WSL
- WSL says config is missing
- `~/.larc` appears to contain different files in each shell

Cause:

- Git Bash and WSL use different home directories unless deliberately linked.

Resolution:

Pick one runtime path for the course. If linking is intentional, document the linked path without revealing config values.

---

## Keychain or Credential Store Blocked

Symptoms:

- auth works interactively but fails in a scheduled task or service
- Lark connection fails under a different user account

Resolution:

- Run LARC under the same interactive user that completed `lark-cli auth login`.
- For Windows Task Scheduler, prefer "Run only when user is logged on".
- For macOS or Linux remote sessions, re-check whether the keychain is available to that session.

---

## What to Include in a Blocker Report

Good:

```text
OS: Windows 11
Shell: Git Bash
Command: larc status
Error category: auth status invalid
Redacted stderr: token status invalid; no secrets included
Tried: lark-cli auth login once; QR expired
```

Bad:

```text
Here is the full auth URL: ...
Here is my config.env: ...
Here is a screenshot with the QR code and app secret visible.
```
