#!/usr/bin/env bash
# scripts/auth-login-guard-check.sh — regression checks for larc auth login scope guard

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

CALL_LOG="$TMP_DIR/calls.log"
SCOPE_LOG="$TMP_DIR/scopes.log"
STATUS_MODE="$TMP_DIR/status-mode"
mkdir -p "$TMP_DIR/bin"
printf 'broad\n' >"$STATUS_MODE"

cat >"$TMP_DIR/bin/lark-cli" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "$*" >>"${CALL_LOG:?}"

if [[ "${1:-}" == "auth" && "${2:-}" == "status" ]]; then
  case "$(cat "${STATUS_MODE:?}")" in
    broad)
      printf '{"scope":"auth:user.id:read offline_access drive:drive bitable:app docs:document:readonly"}\n'
      ;;
    none)
      exit 1
      ;;
    *)
      printf '{"scope":""}\n'
      ;;
  esac
  exit 0
fi

if [[ "${1:-}" == "auth" && "${2:-}" == "login" ]]; then
  shift 2
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --scope)
        printf '%s\n' "$2" >"${SCOPE_LOG:?}"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done
  exit 0
fi

echo "unexpected lark-cli invocation: $*" >&2
exit 1
EOF
chmod +x "$TMP_DIR/bin/lark-cli"

export PATH="$TMP_DIR/bin:$PATH"
export CALL_LOG SCOPE_LOG STATUS_MODE

assert_scope_contains() {
  local scope="$1"
  if ! tr ' ' '\n' <"$SCOPE_LOG" | grep -Fxq -- "$scope"; then
    echo "[auth-login-guard-check] expected scope missing: $scope" >&2
    echo "actual: $(cat "$SCOPE_LOG" 2>/dev/null || true)" >&2
    return 1
  fi
}

assert_scope_not_contains() {
  local scope="$1"
  if tr ' ' '\n' <"$SCOPE_LOG" | grep -Fxq -- "$scope"; then
    echo "[auth-login-guard-check] unexpected scope present: $scope" >&2
    echo "actual: $(cat "$SCOPE_LOG" 2>/dev/null || true)" >&2
    return 1
  fi
}

echo "[auth-login-guard-check] preserves current scopes by default"
bin/larc auth login --scope "im:chat:create_by_user" >/tmp/larc-auth-login-guard-default.log
assert_scope_contains "im:chat:create_by_user"
assert_scope_contains "drive:drive"
assert_scope_contains "bitable:app"

echo "[auth-login-guard-check] --add-scope is additive alias"
bin/larc auth login --add-scope "calendar:calendar.event:create" >/tmp/larc-auth-login-guard-add.log
assert_scope_contains "calendar:calendar.event:create"
assert_scope_contains "docs:document:readonly"

echo "[auth-login-guard-check] --replace keeps requested scopes only"
bin/larc auth login --replace --scope "im:chat:create_by_user" >/tmp/larc-auth-login-guard-replace.log
assert_scope_contains "im:chat:create_by_user"
assert_scope_not_contains "drive:drive"
assert_scope_not_contains "bitable:app"

echo "[auth-login-guard-check] status failure falls back to requested scopes"
printf 'none\n' >"$STATUS_MODE"
bin/larc auth login --scope "wiki:node:create" >/tmp/larc-auth-login-guard-no-status.log
assert_scope_contains "wiki:node:create"
assert_scope_not_contains "drive:drive"

echo "[auth-login-guard-check] OK"
