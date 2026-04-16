<#
.SYNOPSIS
    LARC PowerShell launcher — dispatches to bin/larc via a bash interpreter.

.DESCRIPTION
    LARC is implemented as a set of bash scripts. On Windows, bash is available
    via Git Bash (recommended) or WSL2. This launcher lets users run
    `larc status`, `larc send "msg"`, etc. directly from PowerShell without
    having to remember to prefix commands with `bash.exe`.

    Priority order for bash discovery:
      1. $env:LARC_BASH                  (explicit override)
      2. C:\Program Files\Git\bin\bash.exe  (Git for Windows, 64-bit)
      3. C:\Program Files (x86)\Git\bin\bash.exe  (Git for Windows, 32-bit)
      4. bash.exe found on PATH          (could be WSL or Git Bash)
      5. wsl.exe                         (last resort — runs inside WSL distro)

.EXAMPLE
    PS> larc status
    PS> larc send "deploy complete"
    PS> larc ingress list --status pending

.NOTES
    Part of the Windows Support milestone.
    See docs/install-windows.md for setup.
#>

[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

$ErrorActionPreference = 'Stop'

function Resolve-BashExe {
    if ($env:LARC_BASH -and (Test-Path $env:LARC_BASH)) {
        return $env:LARC_BASH
    }
    $candidates = @(
        "$env:ProgramFiles\Git\bin\bash.exe",
        "${env:ProgramFiles(x86)}\Git\bin\bash.exe"
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path $c)) { return $c }
    }
    $onPath = Get-Command bash.exe -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }
    $wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
    if ($wsl) { return $wsl.Source }
    return $null
}

function Resolve-LarcScript {
    # Look for the larc shell script next to this .ps1 first (dev install),
    # then in the install runtime directory used by scripts/install.sh.
    $here = Split-Path -Parent $PSCommandPath
    $localLarc = Join-Path $here 'larc'
    if (Test-Path $localLarc) { return $localLarc }
    $runtimeLarc = Join-Path $env:USERPROFILE '.larc\runtime\bin\larc'
    if (Test-Path $runtimeLarc) { return $runtimeLarc }
    return $null
}

$bash = Resolve-BashExe
if (-not $bash) {
    Write-Error @"
Cannot find a bash interpreter.
Install one of:
  - Git for Windows: https://git-scm.com/download/win  (recommended)
  - WSL2:            wsl --install

Or set \$env:LARC_BASH to an absolute path to bash.exe.
"@
    exit 127
}

$larcScript = Resolve-LarcScript
if (-not $larcScript) {
    Write-Error @"
Cannot find the larc script.
Expected one of:
  - $(Split-Path -Parent $PSCommandPath)\larc
  - $env:USERPROFILE\.larc\runtime\bin\larc

Run scripts/install.sh from Git Bash to set up the runtime directory.
"@
    exit 127
}

# When calling bash.exe from PowerShell, paths need to be converted to
# POSIX form. Git Bash's bash.exe accepts both, but WSL's does not.
# Use a conservative approach: if bash is wsl.exe, translate via wslpath.
if ($bash -ieq 'wsl.exe' -or $bash -like '*\wsl.exe') {
    $translated = & wsl.exe wslpath -u $larcScript 2>$null
    if ($LASTEXITCODE -eq 0 -and $translated) {
        $larcScript = $translated.Trim()
    }
}

# Exec bash <larc-script> <remaining args>.
# We pass $Args as separate elements so bash sees distinct arguments.
& $bash $larcScript @Args
exit $LASTEXITCODE
