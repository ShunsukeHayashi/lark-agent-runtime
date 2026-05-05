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
LOGIN_DONE="$TMP_DIR/login-done"
POLL_COUNT="$TMP_DIR/poll-count"
mkdir -p "$TMP_DIR/bin"
printf 'grant\n' >"$STATUS_MODE"

cat >"$TMP_DIR/bin/lark-cli" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "$*" >>"${CALL_LOG:?}"

if [[ "${1:-}" == "auth" && "${2:-}" == "login" && "${3:-}" == "--help" ]]; then
  cat <<'HELP'
Usage:
  lark-cli auth login [flags]

Flags:
      --device-code string
      --json
      --no-wait
      --scope string
HELP
  exit 0
fi

if [[ "${1:-}" == "auth" && "${2:-}" == "status" ]]; then
  base_scopes="auth:user.id:read offline_access drive:drive bitable:app docs:document:readonly"
  case "$(cat "${STATUS_MODE:?}")" in
    grant|retry)
      if [[ -f "${LOGIN_DONE:?}" && -s "${SCOPE_LOG:?}" ]]; then
        printf '{"scope":"%s"}\n' "$(cat "${SCOPE_LOG:?}")"
      else
        printf '{"scope":"%s"}\n' "$base_scopes"
      fi
      ;;
    missing)
      printf '{"scope":"%s"}\n' "$base_scopes"
      ;;
    partial)
      if [[ -f "${LOGIN_DONE:?}" && -s "${SCOPE_LOG:?}" ]]; then
        first_extra=""
        for scope in $(cat "${SCOPE_LOG:?}"); do
          case " $base_scopes " in
            *" $scope "*) ;;
            *)
              first_extra="$scope"
              break
              ;;
          esac
        done
        printf '{"scope":"%s %s"}\n' "$base_scopes" "$first_extra"
      else
        printf '{"scope":"%s"}\n' "$base_scopes"
      fi
      ;;
    none)
      exit 1
      ;;
    pre-none-post-grant)
      if [[ -f "${LOGIN_DONE:?}" && -s "${SCOPE_LOG:?}" ]]; then
        printf '{"scope":"%s"}\n' "$(cat "${SCOPE_LOG:?}")"
      else
        exit 1
      fi
      ;;
    *)
      printf '{"scope":""}\n'
      ;;
  esac
  exit 0
fi

if [[ "${1:-}" == "auth" && "${2:-}" == "login" ]]; then
  shift 2
  device_code=""
  no_wait=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --scope)
        printf '%s\n' "$2" >"${SCOPE_LOG:?}"
        shift 2
        ;;
      --device-code)
        device_code="$2"
        shift 2
        ;;
      --no-wait)
        no_wait=true
        shift
        ;;
      --json)
        shift
        ;;
      *)
        shift
        ;;
    esac
  done

  if [[ "$no_wait" == "true" ]]; then
    printf '{"device_code":"device-test","user_code":"USER-123","verification_uri_complete":"https://example.test/device","expires_in":600,"interval":1}\n'
    exit 0
  fi

  if [[ -n "$device_code" ]]; then
    if [[ "$(cat "${STATUS_MODE:?}")" == "retry" ]]; then
      count=0
      [[ -f "${POLL_COUNT:?}" ]] && count="$(cat "${POLL_COUNT:?}")"
      count=$(( count + 1 ))
      printf '%s\n' "$count" >"${POLL_COUNT:?}"
      if [[ "$count" -eq 1 ]]; then
        printf '{"error":{"type":"auth","message":"authorization failed: Authorization timed out, please try again"}}\n' >&2
        exit 1
      fi
    fi
    touch "${LOGIN_DONE:?}"
    printf '{"ok":true}\n'
    exit 0
  fi

  touch "${LOGIN_DONE:?}"
  exit 0
fi

echo "unexpected lark-cli invocation: $*" >&2
exit 1
EOF
chmod +x "$TMP_DIR/bin/lark-cli"

export PATH="$TMP_DIR/bin:$PATH"
export CALL_LOG SCOPE_LOG STATUS_MODE LOGIN_DONE POLL_COUNT

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
rm -f "$LOGIN_DONE" "$SCOPE_LOG" "$POLL_COUNT"
printf 'grant\n' >"$STATUS_MODE"
bin/larc auth login --scope "im:chat:create_by_user" >/tmp/larc-auth-login-guard-default.log
assert_scope_contains "im:chat:create_by_user"
assert_scope_contains "drive:drive"
assert_scope_contains "bitable:app"

echo "[auth-login-guard-check] --add-scope is additive alias"
rm -f "$LOGIN_DONE" "$SCOPE_LOG" "$POLL_COUNT"
printf 'grant\n' >"$STATUS_MODE"
bin/larc auth login --add-scope "calendar:calendar.event:create" >/tmp/larc-auth-login-guard-add.log
assert_scope_contains "calendar:calendar.event:create"
assert_scope_contains "docs:document:readonly"

echo "[auth-login-guard-check] --replace keeps requested scopes only"
rm -f "$LOGIN_DONE" "$SCOPE_LOG" "$POLL_COUNT"
printf 'grant\n' >"$STATUS_MODE"
bin/larc auth login --replace --scope "im:chat:create_by_user" >/tmp/larc-auth-login-guard-replace.log
assert_scope_contains "im:chat:create_by_user"
assert_scope_not_contains "drive:drive"
assert_scope_not_contains "bitable:app"

echo "[auth-login-guard-check] pre-login status failure falls back to requested scopes"
rm -f "$LOGIN_DONE" "$SCOPE_LOG" "$POLL_COUNT"
printf 'pre-none-post-grant\n' >"$STATUS_MODE"
bin/larc auth login --scope "wiki:node:create" >/tmp/larc-auth-login-guard-no-status.log
assert_scope_contains "wiki:node:create"
assert_scope_not_contains "drive:drive"

echo "[auth-login-guard-check] missing requested scope returns non-zero"
rm -f "$LOGIN_DONE" "$SCOPE_LOG" "$POLL_COUNT"
printf 'missing\n' >"$STATUS_MODE"
if bin/larc auth login --scope "im:chat:create_by_user" >/tmp/larc-auth-login-guard-missing.log 2>&1; then
  echo "[auth-login-guard-check] missing scope case unexpectedly succeeded" >&2
  exit 1
fi
grep -Fq "auth_error=requested_scopes_not_granted" /tmp/larc-auth-login-guard-missing.log
grep -Fq "im:chat:create_by_user" /tmp/larc-auth-login-guard-missing.log

echo "[auth-login-guard-check] partial requested scope grant returns non-zero"
rm -f "$LOGIN_DONE" "$SCOPE_LOG" "$POLL_COUNT"
printf 'partial\n' >"$STATUS_MODE"
if bin/larc auth login --scope "calendar:calendar.event:create im:chat:create_by_user" >/tmp/larc-auth-login-guard-partial.log 2>&1; then
  echo "[auth-login-guard-check] partial scope case unexpectedly succeeded" >&2
  exit 1
fi
grep -Fq "auth_error=requested_scopes_not_granted" /tmp/larc-auth-login-guard-partial.log

echo "[auth-login-guard-check] post-login status failure returns non-zero"
rm -f "$LOGIN_DONE" "$SCOPE_LOG" "$POLL_COUNT"
printf 'none\n' >"$STATUS_MODE"
if bin/larc auth login --scope "wiki:node:create" >/tmp/larc-auth-login-guard-post-status-fail.log 2>&1; then
  echo "[auth-login-guard-check] post-login status failure unexpectedly succeeded" >&2
  exit 1
fi
grep -Fq "auth_error=granted_scope_validation_unavailable" /tmp/larc-auth-login-guard-post-status-fail.log

echo "[auth-login-guard-check] device flow timeout retry keeps polling"
rm -f "$LOGIN_DONE" "$SCOPE_LOG" "$POLL_COUNT"
printf 'retry\n' >"$STATUS_MODE"
bin/larc auth login --timeout 8 --poll-interval 1 --scope "calendar:calendar.event:create" >/tmp/larc-auth-login-guard-retry.log
assert_scope_contains "calendar:calendar.event:create"
grep -Fq "Authorization is still pending" /tmp/larc-auth-login-guard-retry.log

echo "[auth-login-guard-check] OK"
