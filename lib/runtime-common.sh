#!/usr/bin/env bash
# runtime-common.sh — shared helpers for subprocess-oriented runtime modules

_LARC_LOG_BLUE='\033[0;34m'
_LARC_LOG_GREEN='\033[0;32m'
_LARC_LOG_YELLOW='\033[1;33m'
_LARC_LOG_RED='\033[0;31m'
_LARC_LOG_CYAN='\033[0;36m'
_LARC_LOG_BOLD='\033[1m'
_LARC_LOG_RESET='\033[0m'

larc_init_fallback_logs() {
  type log_head &>/dev/null || {
    log_head() { echo -e "\n${_LARC_LOG_BOLD}${_LARC_LOG_CYAN}▶ $*${_LARC_LOG_RESET}"; }
  }
  type log_info &>/dev/null || {
    log_info() { echo -e "${_LARC_LOG_BLUE}[larc]${_LARC_LOG_RESET} $*"; }
  }
  type log_ok &>/dev/null || {
    log_ok() { echo -e "${_LARC_LOG_GREEN}[larc]${_LARC_LOG_RESET} $*"; }
  }
  type log_warn &>/dev/null || {
    log_warn() { echo -e "${_LARC_LOG_YELLOW}[larc]${_LARC_LOG_RESET} $*"; }
  }
  type log_error &>/dev/null || {
    log_error() { echo -e "${_LARC_LOG_RED}[larc]${_LARC_LOG_RESET} $*" >&2; }
  }
}

larc_load_runtime_config() {
  local cfg_path="${1:-${LARC_CONFIG:-${LARC_HOME:-$HOME/.larc}/config.env}}"
  [[ -f "$cfg_path" ]] && { set -a; source "$cfg_path"; set +a; }
}

larc_detect_openclaw_cmd() {
  if command -v openclaw &>/dev/null; then
    echo "openclaw"
  elif command -v open-claw &>/dev/null; then
    echo "open-claw"
  fi
}

# ── Portable Unix utility shims ─────────────────────────────────────────────
# These helpers let LARC behave identically under macOS (BSD userland),
# Linux (GNU coreutils), Git Bash on Windows, and WSL2, without every call
# site having to branch on platform. See GitHub issues #11-14 for context.

# Resolve a path to its canonical absolute form.
# Prefers `realpath` (GNU / modern macOS via coreutils) and falls back through
# `readlink -f` (GNU) → `python3 os.path.realpath` → no-op. Safe on all shells.
larc_realpath() {
  local target="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$target" 2>/dev/null && return 0
  fi
  if readlink -f "$target" >/dev/null 2>&1; then
    readlink -f "$target"
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$target" 2>/dev/null && return 0
  fi
  # Last resort: return as-is; caller should tolerate a non-canonical path.
  echo "$target"
}

# Epoch mtime of a file. BSD `stat -f '%m'` vs GNU `stat -c '%Y'`.
larc_stat_mtime() {
  local target="$1"
  [[ -e "$target" ]] || { echo 0; return 1; }
  stat -f '%m' "$target" 2>/dev/null \
    || stat -c '%Y' "$target" 2>/dev/null \
    || echo 0
}

# Human-readable mtime. BSD `stat -f '%Sm' -t FORMAT` vs GNU `stat -c '%y'`.
# Returns ISO-ish `YYYY-MM-DD HH:MM` on both platforms.
larc_stat_mtime_human() {
  local target="$1"
  [[ -e "$target" ]] || return 1
  # BSD: supports -t format directly
  stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$target" 2>/dev/null && return 0
  # GNU: %y gives "YYYY-MM-DD HH:MM:SS.fffffffff +0000" — trim to minute
  local g; g=$(stat -c '%y' "$target" 2>/dev/null) || return 1
  echo "${g:0:16}"
}

# Portable in-place sed edit. BSD requires `-i ''`, GNU requires bare `-i`.
# Usage: larc_sed_inplace 's/foo/bar/g' <file>
larc_sed_inplace() {
  local expr="$1"
  local file="$2"
  # Detect by a harmless probe: BSD sed errors out on `sed -i` without a backup arg.
  if sed --version >/dev/null 2>&1; then
    # GNU sed
    sed -i "$expr" "$file"
  else
    # BSD sed (macOS)
    sed -i '' "$expr" "$file"
  fi
}

# Yesterday's date in YYYY-MM-DD. Tries GNU then BSD then Python fallback.
larc_date_yesterday() {
  date -d '-1 day' +%Y-%m-%d 2>/dev/null \
    || date -v-1d +%Y-%m-%d 2>/dev/null \
    || python3 -c "import datetime; print((datetime.date.today()-datetime.timedelta(days=1)).isoformat())" 2>/dev/null
}
