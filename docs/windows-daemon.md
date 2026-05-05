# Windows Daemon Support Stance

This document defines the supported posture for `larc daemon` on Windows.

Short version: `larc daemon` is still experimental. On Windows, use it only from a controlled Git Bash or WSL environment, and keep the same interactive user that completed `lark-cli auth login`.

---

## Support Matrix

| Runtime | Supported for daemon? | Recommended use | Notes |
|---|---:|---|---|
| Git Bash | Conditional | Local validation and supervised pilot runs | Keep a dedicated shell or supervisor alive |
| PowerShell launcher | No native daemon | Invoke `larc` commands through `larc.ps1`; do not treat it as a service runtime | The launcher delegates to bash; it is not a PowerShell port |
| WSL2 | Conditional | Linux-style daemon runs inside WSL only | WSL home and Windows home are separate unless deliberately linked |
| Windows Service | Not built in | Use Task Scheduler or NSSM manually if needed | Must run as the same user that owns `lark-cli` credentials |

---

## Recommended Path: Dedicated Git Bash Session

Use this when validating daemon behavior on a Windows workstation.

```bash
larc status
larc daemon start --agent main --interval 30
larc daemon status
larc daemon logs
```

Stop it before closing the shell:

```bash
larc daemon stop
```

Why this is recommended:

- Git Bash provides the POSIX tools that the bash runtime expects.
- The daemon PID files and `kill -0` checks behave closest to macOS/Linux.
- The credential store is more likely to match the interactive user who ran `lark-cli auth login`.

Known limitation:

- Background processes can be tied to the terminal session. Closing the shell can terminate or orphan daemon children.

---

## Task Scheduler Pattern

Use Task Scheduler only after the interactive Git Bash path has passed.

Constraints:

- Run as the same Windows user that completed `lark-cli auth login`.
- Prefer "Run only when user is logged on" so the credential store is available.
- Do not run under a generic service account unless that account completed auth itself.
- Keep all secrets in the normal `lark-cli` credential store and `~/.larc/config.env`; do not embed them in Task Scheduler arguments.

Suggested wrapper script:

```bash
#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.larc/runtime/bin:$PATH"

larc daemon start --agent main --interval 30

while true; do
  larc daemon health >/dev/null 2>&1 || true
  sleep 60
done
```

Task Scheduler configuration:

| Field | Value |
|---|---|
| Program/script | `C:\Program Files\Git\bin\bash.exe` |
| Arguments | `-lc "/c/Users/<you>/.larc/scripts/larc-daemon-task.sh"` |
| User | The same user that ran `lark-cli auth login` |

The wrapper intentionally keeps the parent shell alive. This avoids treating a short-lived `larc daemon start` command as if it were a native Windows service.

---

## NSSM Pattern

NSSM is acceptable for advanced users who already operate Windows services.

Example shape:

```powershell
nssm install larc-daemon "C:\Program Files\Git\bin\bash.exe" "-lc '/c/Users/<you>/.larc/scripts/larc-daemon-task.sh'"
```

Service account rules:

- Use the same Windows user that completed `lark-cli auth login`.
- If using a different service account, run the full `lark-cli config init` and `lark-cli auth login` flow for that account.
- Never copy credential files or secrets from another profile without explicit approval.

Operational checks:

```bash
larc daemon status
larc daemon health
larc daemon logs
```

---

## WSL2 Pattern

WSL2 can run `larc daemon` as a Linux process, but it is a separate runtime from Windows.

Use WSL2 when:

- the learner intentionally chose WSL as their LARC home
- `~/.larc/config.env` and `lark-cli` auth were set up inside WSL
- the daemon should be supervised by Linux-style tooling

Avoid:

- starting a WSL daemon that points at Windows-side `~/.larc` unless the link is deliberate and documented
- mixing Git Bash `lark-cli auth login` with WSL daemon execution

---

## Not Supported

The following are not supported by LARC itself:

- a native PowerShell daemon implementation
- automatic Windows Service installation
- daemon runs under a Windows account that has not completed `lark-cli auth login`
- copying secrets or credential store files from another machine or user profile
- using `larc daemon` as the primary production onboarding path

For production-like usage, prefer supervised or OpenClaw-assisted workflows until the daemon graduates from experimental status.

---

## Evidence for Issue #9

When reporting Windows daemon results, include:

```text
OS:
Shell/runtime:
Supervisor: dedicated Git Bash / Task Scheduler / NSSM / WSL
Command:
Result:
Redacted stderr:
Same user as lark-cli auth login: yes/no
```

Do not include:

- App Secret
- auth URLs
- QR screenshots
- token values
- `~/.larc/config.env` contents
- tenant-private URLs
