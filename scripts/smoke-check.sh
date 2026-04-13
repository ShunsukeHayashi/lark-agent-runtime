#!/usr/bin/env bash
# scripts/smoke-check.sh — minimal checkpoint verification for current MVP slice

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "[smoke] syntax"
bash -n bin/larc
bash -n lib/*.sh
bash -n scripts/setup-workspace.sh

echo "[smoke] setup-workspace dry-run"
scripts/setup-workspace.sh --agent smoke --drive-folder fld_smoke --base-token bas_smoke --dry-run >/tmp/larc-smoke-setup.log
tail -n 5 /tmp/larc-smoke-setup.log

echo "[smoke] auth check"
bin/larc auth check >/tmp/larc-smoke-auth.log
head -n 8 /tmp/larc-smoke-auth.log

echo "[smoke] approve list help path"
bin/larc approve help >/tmp/larc-smoke-approve.log
cat /tmp/larc-smoke-approve.log

echo "[smoke] OK"
