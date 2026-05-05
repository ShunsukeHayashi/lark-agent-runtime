#!/usr/bin/env bash
# scripts/quickstart-preflight-check.sh — local regression checks for larc quickstart scope preflight

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

FAKE_BIN="$TMP_ROOT/bin"
mkdir -p "$FAKE_BIN"

cat > "$FAKE_BIN/lark-cli" <<'FAKE_LARK_CLI'
#!/usr/bin/env bash
set -euo pipefail

printf 'lark-cli' >> "${LARC_FAKE_LOG:?}"
for arg in "$@"; do
  printf ' %s' "$arg" >> "$LARC_FAKE_LOG"
done
printf '\n' >> "$LARC_FAKE_LOG"

if [[ "${1:-}" == "config" && "${2:-}" == "show" ]]; then
  printf '{"appId":"cli_test","brand":"lark"}\n'
  exit 0
fi

if [[ "${1:-}" == "auth" && "${2:-}" == "scopes" ]]; then
  echo "Querying app scopes..."
  if [[ "${LARC_FAKE_SCOPE_MODE:-full}" == "missing" ]]; then
    printf '{"appId":"cli_test","userScopes":["offline_access"]}\n'
  else
    printf '{"appId":"cli_test","userScopes":["drive:drive","docs:permission.member:create","base:app:create","base:table:create","base:field:create","docx:document:create"]}\n'
  fi
  exit 0
fi

if [[ "${1:-}" == "auth" && "${2:-}" == "status" ]]; then
  printf '{"tokenStatus":"valid","userName":"Test User","userOpenId":"ou_test"}\n'
  exit 0
fi

has_yes=false
for arg in "$@"; do
  [[ "$arg" == "--yes" ]] && has_yes=true
done

if [[ "${1:-}" == "drive" && "${2:-}" == "files" && "${3:-}" == "create_folder" ]]; then
  if [[ "$has_yes" != "true" ]]; then
    echo "drive.files.create_folder requires confirmation, add --yes" >&2
    exit 77
  fi
  case "$*" in
    *larc-workspace*) printf '{"data":{"token":"fld_workspace"}}\n' ;;
    *larc-workdir*)   printf '{"data":{"token":"fld_workdir"}}\n' ;;
    *)                printf '{"data":{"token":"fld_unknown"}}\n' ;;
  esac
  exit 0
fi

if [[ "${1:-}" == "drive" && "${2:-}" == "permission.members" && "${3:-}" == "create" ]]; then
  if [[ "$has_yes" != "true" ]]; then
    echo "drive.permission.members.create requires confirmation, add --yes" >&2
    exit 78
  fi
  printf '{"data":{"member":{"member_id":"ou_test"}}}\n'
  exit 0
fi

if [[ "${1:-}" == "drive" && "${2:-}" == "files" && "${3:-}" == "list" ]]; then
  printf '{"data":{"files":[]}}\n'
  exit 0
fi

if [[ "${1:-}" == "api" && "${2:-}" == "POST" && "${3:-}" == "/open-apis/bitable/v1/apps" ]]; then
  printf '{"data":{"app":{"app_token":"basc_memory"}}}\n'
  exit 0
fi

if [[ "${1:-}" == "api" && "${2:-}" == "POST" && "${3:-}" == *"/tables/"*"/fields" ]]; then
  printf '{"data":{"field_id":"fld_field"}}\n'
  exit 0
fi

if [[ "${1:-}" == "api" && "${2:-}" == "POST" && "${3:-}" == *"/tables" ]]; then
  printf '{"data":{"table_id":"tbl_test"}}\n'
  exit 0
fi

if [[ "${1:-}" == "docs" && "${2:-}" == "+create" ]]; then
  printf '{"data":{"doc_id":"doc_test"}}\n'
  exit 0
fi

echo "unexpected fake lark-cli command: $*" >&2
exit 64
FAKE_LARK_CLI

cat > "$FAKE_BIN/larc" <<'FAKE_LARC'
#!/usr/bin/env bash
set -euo pipefail

printf 'larc' >> "${LARC_FAKE_LOG:?}"
for arg in "$@"; do
  printf ' %s' "$arg" >> "$LARC_FAKE_LOG"
done
printf '\n' >> "$LARC_FAKE_LOG"

if [[ "${1:-}" == "agent" && "${2:-}" == "list" ]]; then
  exit 0
fi
if [[ "${1:-}" == "agent" && "${2:-}" == "register" ]]; then
  exit 0
fi
if [[ "${1:-}" == "bootstrap" ]]; then
  echo "Done: fake bootstrap"
  exit 0
fi

echo "unexpected fake larc command: $*" >&2
exit 64
FAKE_LARC

chmod +x "$FAKE_BIN/lark-cli" "$FAKE_BIN/larc"

assert_contains() {
  local file="$1" needle="$2"
  if ! grep -Fq -- "$needle" "$file"; then
    echo "[quickstart-preflight-check] missing expected text: $needle" >&2
    echo "--- output ---" >&2
    cat "$file" >&2
    exit 1
  fi
}

run_missing_scope_check() {
  local out="$TMP_ROOT/missing.out"
  local log="$TMP_ROOT/missing.log"
  : > "$log"

  if PATH="$FAKE_BIN:$PATH" \
      LARC_HOME="$TMP_ROOT/home-missing" \
      LARC_FAKE_LOG="$log" \
      LARC_FAKE_SCOPE_MODE=missing \
      "$ROOT_DIR/bin/larc" quickstart >"$out" 2>&1; then
    echo "[quickstart-preflight-check] expected missing-scope quickstart to fail" >&2
    exit 1
  fi

  assert_contains "$out" "Bot App に必要な scope が不足しています"
  assert_contains "$out" "drive:drive"
  assert_contains "$out" "https://open.larksuite.com/app/cli_test/permissions"

  if grep -Fq "drive files create_folder" "$log"; then
    echo "[quickstart-preflight-check] quickstart should fail before Drive writes" >&2
    cat "$log" >&2
    exit 1
  fi

  echo "  PASS missing scopes fail before writes"
}

run_yes_propagation_check() {
  local out="$TMP_ROOT/full.out"
  local log="$TMP_ROOT/full.log"
  : > "$log"

  if ! PATH="$FAKE_BIN:$PATH" \
      LARC_HOME="$TMP_ROOT/home-full" \
      LARC_FAKE_LOG="$log" \
      LARC_FAKE_SCOPE_MODE=full \
      "$ROOT_DIR/bin/larc" quickstart >"$out" 2>&1; then
    echo "[quickstart-preflight-check] expected full-scope quickstart to succeed" >&2
    echo "--- output ---" >&2
    cat "$out" >&2
    echo "--- commands ---" >&2
    cat "$log" >&2
    exit 1
  fi

  assert_contains "$out" "セットアップ完了"

  if ! grep -F "drive files create_folder" "$log" | grep -Fq -- "--yes"; then
    echo "[quickstart-preflight-check] create_folder command did not receive --yes" >&2
    cat "$log" >&2
    exit 1
  fi

  if ! grep -F "drive permission.members create" "$log" | grep -Fq -- "--yes"; then
    echo "[quickstart-preflight-check] permission.members create command did not receive --yes" >&2
    cat "$log" >&2
    exit 1
  fi

  echo "  PASS --yes propagates to quickstart write commands"
}

echo "[quickstart-preflight-check] start"
run_missing_scope_check
run_yes_propagation_check
echo "[quickstart-preflight-check] done"
