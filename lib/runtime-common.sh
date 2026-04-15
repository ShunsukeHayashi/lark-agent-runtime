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
