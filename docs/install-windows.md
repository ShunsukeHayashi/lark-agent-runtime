# Installing LARC on Windows

LARC is a bash-based runtime. On Windows, you have three supported paths:

| Path | Recommended for | Effort | Notes |
|---|---|---|---|
| **Git Bash** | Most users | Low | Closest to macOS/Linux behavior |
| **WSL2** | Heavy Linux users | Low | `$HOME` differs from Windows home |
| **PowerShell launcher** | Users who live in `pwsh` | Low | Uses `bin\larc.ps1` to delegate to bash |

A native PowerShell rewrite is **not** planned. The launcher is the supported way to use LARC from PowerShell.

> These instructions assume Windows 10 / 11 (build 19041+). They were validated against Windows 11 build 26200.

---

## 1. Install prerequisites

### Common to every path

| Tool | Recommended source | Why |
|---|---|---|
| Git for Windows | https://git-scm.com/download/win | Ships Git Bash + GNU coreutils |
| Node.js (LTS) | https://nodejs.org | `lark-cli` is published as `@larksuite/cli` on npm |
| Python 3.10+ | https://www.python.org/downloads/windows/ | LARC runs several inline Python helpers |
| jq | `choco install jq` or `scoop install jq` | 40+ call sites in LARC |

After installing: open a fresh shell and verify each is on `PATH`:

```bash
git --version
node --version
python --version
jq --version
```

If you manage packages with **Chocolatey**, the one-liner is:

```powershell
choco install -y git nodejs-lts python jq
```

With **Scoop**:

```powershell
scoop install git nodejs-lts python jq
```

### Install lark-cli

```bash
npm install -g @larksuite/cli
lark-cli --version
```

---

## 2. Install LARC

Clone the repo and run the installer from Git Bash:

```bash
# From Git Bash or WSL
git clone https://github.com/ShunsukeHayashi/lark-agent-runtime.git
cd lark-agent-runtime
bash scripts/install.sh
```

The installer will:

1. Place the runtime at `%USERPROFILE%\.larc\runtime\` (equivalent to `~/.larc/runtime`)
2. Prepare `~/.larc/config.env` on first run (you will fill this in step 3)
3. Print the path you should add to `PATH`

If you are not in a git clone, the one-line network install also works under Git Bash:

```bash
curl -fsSL https://raw.githubusercontent.com/ShunsukeHayashi/lark-agent-runtime/main/scripts/install.sh | bash
```

---

## 3. Configure

Create `~/.larc/config.env` (path under Git Bash = `%USERPROFILE%\.larc\config.env`):

```bash
# lark-cli auth is driven by lark-cli itself; these are LARC's pointers.
LARC_DRIVE_FOLDER_TOKEN="<folder-token>"
LARC_BASE_APP_TOKEN="<base-app-token>"
LARC_IM_CHAT_ID="<oc_xxx>"
LARC_QUEUE_TABLE_ID="<tbl_xxx>"
LARC_LOG_TABLE_ID="<tbl_xxx>"
```

Then authenticate `lark-cli`:

```bash
lark-cli auth login
# follow the browser flow
```

Verify end-to-end:

```bash
larc status
```

Expected output block:

```
Lark connection:
  User: <your-name>
  Drive folder: configured (...)
  Base:         connected (...)
  OpenClaw:     installed (openclaw)
```

If `Base:` is `unreachable`, the error reason is surfaced on the line below (this is thanks to the UX improvements in #10 — see Troubleshooting below).

---

## 4. Choose a runtime path

### Path A — Git Bash (recommended)

This is the "most Unix-like" path.

```bash
# Open Git Bash
larc status
larc ingress list --agent main --status pending --limit 5
```

Make sure `C:\Program Files\Git\bin` is on your `PATH` so `larc` resolves.

### Path B — WSL2

Inside your WSL distro, LARC runs as regular Linux. The gotcha is the **home directory is WSL-side**, not Windows-side:

```bash
# From Ubuntu under WSL
echo $HOME
# /home/<you>  — NOT C:\Users\<you>
```

This means `~/.larc/config.env` from Git Bash and from WSL are two different files. Pick one side and stick with it, or symlink them:

```bash
# Inside WSL, point .larc at the Windows-side config
ln -s /mnt/c/Users/<you>/.larc ~/.larc
```

### Path C — PowerShell launcher

Once PR #21 has landed, `bin/larc.ps1` will be in the repo. Add `bin` to `$env:PATH` (PowerShell profile):

```powershell
$env:PATH += ";$env:USERPROFILE\.larc\runtime\bin"
```

Or copy `larc.ps1` to a directory already on `PATH`.

Then:

```powershell
PS> larc status
PS> larc send "deploy complete"
```

The `.ps1` file is a thin shim that locates `bash.exe` (Git Bash preferred, then WSL) and execs the real `larc` script. You can override the bash interpreter with:

```powershell
$env:LARC_BASH = "C:\Program Files\Git\bin\bash.exe"
```

---

## 5. Daemon support stance

`larc daemon` is experimental on every platform and has extra constraints on Windows. The supported Windows stance is documented in [Windows Daemon Support Stance](windows-daemon.md).

Use the daemon only after the read-only smoke test passes. For most users, keep it in a dedicated Git Bash session:

```bash
larc daemon start --agent main --interval 30
larc daemon status
```

Windows caveat: LARC's daemon uses PID files and `kill -0` for process control. On Git Bash this works, but background processes are tied to the terminal session. There is no built-in Windows Service integration.

Supported patterns:

1. Keep a dedicated Git Bash window open for validation and pilot runs.
2. Use Task Scheduler with Git Bash, under the same Windows user that completed `lark-cli auth login`.
3. Use NSSM only as an advanced manual supervisor.

Not supported:

- native PowerShell daemon
- automatic Windows Service installation
- service-account daemon runs unless that same account completed `lark-cli auth login`

See [docs/windows-daemon.md](windows-daemon.md) for Task Scheduler and NSSM wrapper patterns.

---

## 6. Smoke test

Run these read-only commands to confirm the install:

```bash
larc --help
larc status
larc auth suggest "経費精算と承認申請を作成"
larc ingress list --status pending --limit 5
larc ingress stats --agent main
```

If any of these fail, see Troubleshooting below.

---

## Troubleshooting

### `Base: unreachable` with `keychain access blocked`

You are running from a context that cannot read the OS keychain. Most common cause: SSH session on macOS. On Windows this usually means you are running under a service account that does not own the credentials. Solutions:

- Run from an interactive Git Bash / PowerShell owned by the user who ran `lark-cli auth login`
- On Windows Task Scheduler, check "Run only when user is logged on"

### `UnicodeEncodeError: 'charmap' codec can't encode...`

Windows Python defaults to `cp1252`. Fixed in #23 by exporting `PYTHONIOENCODING=utf-8` and `PYTHONUTF8=1` at the top of `bin/larc`. If you hit this on a custom script, export both before running.

### `command not found: larc`

The installer placed the runtime at `%USERPROFILE%\.larc\runtime\bin\larc`. Either add that directory to `PATH` or symlink the file into a directory already on `PATH`:

```bash
ln -sf "$HOME/.larc/runtime/bin/larc" "$HOME/.local/bin/larc"
```

### `jq: command not found`

Install via Chocolatey or Scoop (see step 1). LARC uses `jq` heavily; every subcommand depends on it.

### `fcntl` error in `larc billing check`

Fixed in #25. Pull the latest `main`.

### `readlink: invalid option -- 'f'`

Fixed in #19. Pull the latest `main`.

---

## What is NOT supported on Windows (yet)

- Native PowerShell LARC (the `.ps1` is a launcher, not a rewrite)
- Running the daemon as a Windows Service out of the box. See [Windows Daemon Support Stance](windows-daemon.md) for the manual Task Scheduler / NSSM posture.
- Symlinks created on Git Bash may appear as junction points under PowerShell — rare issue, but worth knowing

See issue #9 for the live tracking of Windows-specific work.

---

## Feedback

If you hit a Windows-specific bug, file an issue linked from [#9](https://github.com/ShunsukeHayashi/lark-harness/issues/9) with:

1. Windows version + shell (PowerShell version / Git Bash version / WSL distro)
2. `larc --version` and `lark-cli --version`
3. Full command + output
4. Whether the same command works under WSL (this helps triage quickly)
