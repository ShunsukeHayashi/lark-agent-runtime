#!/usr/bin/env bash
# runtime-common.sh — shared helpers for subprocess-oriented runtime modules

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
