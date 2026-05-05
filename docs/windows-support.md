# Windows Support — Reproduction Log

Live status doc tracking Windows-specific Lark Harness defects and the
sub-issues filed under [#9 — tracking: Windows support](https://github.com/ShunsukeHayashi/lark-harness/issues/9).

> Setup instructions live in [docs/install-windows.md](install-windows.md).
> Daemon posture lives in [docs/windows-daemon.md](windows-daemon.md).
> This file is for **defect reproductions** only.

## Cadence

- Reviewed monthly on the 1st of each month.
- Reproductions with no activity for **90 days** are closed.
- New reproductions: file as a sub-issue under #9 with environment shape,
  exact error, and `file:line` reference. Add a row to the open table below.
- Do **not** attempt blind fixes without a reproduction.

## Last reviewed

`2026-05-05` (daemon support stance documented)

Next scheduled review: `2026-06-01`.

## Environment shapes covered

- Windows 11 + PowerShell 7 (`pwsh`) via `bin\larc.ps1` launcher
- Windows 11 + Git Bash (MSYS2 / MinGW)
- Windows 11 + WSL2 (Ubuntu 22.04+)

## Current daemon stance

`larc daemon` remains experimental. On Windows, it is supported only as a controlled Git Bash or WSL run, with optional manual Task Scheduler / NSSM supervision. It is not a native PowerShell daemon and LARC does not install a Windows Service automatically.

Daemon reports should include the supervisor shape and whether the same Windows user completed `lark-cli auth login`. Do not include secrets, QR screenshots, auth URLs, or config contents.

## Open reproductions

| Reported | Env | Error / Symptom | File:line | Sub-issue |
|---|---|---|---|---|
| _none yet_ | — | — | — | — |

## Closed reproductions (archive)

| Closed | Env | Symptom | Resolution | Sub-issue |
|---|---|---|---|---|
| _none yet_ | — | — | — | — |

## Triage template (for new reports)

When a Windows user files a defect, ask for:

1. **Environment**: which of the three shapes above?
2. **Exact command and stderr**: `larc <subcommand> ... 2>&1`
3. **First failure point**: which `file:line` is reached before the error?
   (Use `bash -x bin/larc <subcommand>` to bisect.)
4. **Repro frequency**: deterministic vs. flaky.

Once these four items are available, the report is "reproduced" and
qualifies for a sub-issue under #9.
