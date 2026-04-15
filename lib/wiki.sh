#!/usr/bin/env bash
# lib/wiki.sh — LARC Wiki helpers
#
# Commands:
#   larc wiki add-member --space-id <id> --email <email> [--role member|admin]
#       Add a user to a Lark Wiki space.  Handles the 131005 external-user
#       error gracefully and suggests the correct workaround instead of failing
#       silently.
#
#   larc wiki open-sharing --space-id <id> --level <level>
#       Set the Wiki space open_sharing level:
#         no_access       — only members can access
#         tenant_readable — anyone in the tenant can read
#         anyone_readable — public link (no Lark account required)

set -uo pipefail

_WIKI_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_WIKI_SH_DIR}/runtime-common.sh"

larc_init_fallback_logs

# ── Public interface ──────────────────────────────────────────────────────────

cmd_wiki() {
  local subcmd="${1:-help}"; shift || true
  case "$subcmd" in
    add-member)    _wiki_add_member "$@" ;;
    open-sharing)  _wiki_open_sharing "$@" ;;
    help|--help|-h) _wiki_help ;;
    *)
      log_error "Unknown wiki subcommand: $subcmd"
      _wiki_help
      return 1
      ;;
  esac
}

_wiki_help() {
  cat <<EOF

${BOLD}larc wiki${RESET} — Lark Wiki space management

${BOLD}Commands:${RESET}
  ${CYAN}add-member${RESET} --space-id <id> --email <email> [--role member|admin]
                        Add a user to a Wiki space by email or open_id.
                        Detects the 131005 external-user API gap and suggests
                        the correct workaround (admin-console invite / open_id).
  ${CYAN}open-sharing${RESET} --space-id <id> --level <level>
                        Set Wiki open_sharing level:
                          no_access       — members only
                          tenant_readable — anyone in tenant
                          anyone_readable — public link (no account required)

${BOLD}Examples:${RESET}
  larc wiki add-member --space-id 7627820424876838426 --email alice@example.com
  larc wiki add-member --space-id 7627820424876838426 --open-id ou_XXXXXX --role admin
  larc wiki open-sharing --space-id 7627820424876838426 --level anyone_readable

${BOLD}External user limitation:${RESET}
  Users from other Lark tenants cannot be found by email via the Contact API.
  add-member will detect this and print the correct workaround steps.
  See: docs/known-issues/lark-external-user-api-gap.md

EOF
}

# ── add-member ────────────────────────────────────────────────────────────────

_wiki_add_member() {
  local space_id="${LARC_WIKI_SPACE_ID:-}"
  local email="" open_id="" role="member"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --space-id) space_id="$2"; shift 2 ;;
      --email)    email="$2";    shift 2 ;;
      --open-id)  open_id="$2";  shift 2 ;;
      --role)     role="$2";     shift 2 ;;
      *) log_warn "Unknown option: $1"; shift ;;
    esac
  done

  if [[ -z "$space_id" ]]; then
    log_error "Usage: larc wiki add-member --space-id <id> (--email <addr> | --open-id <id>) [--role member|admin]"
    log_info "Set LARC_WIKI_SPACE_ID in config to avoid passing --space-id each time"
    return 1
  fi
  if [[ -z "$email" && -z "$open_id" ]]; then
    log_error "Provide --email <addr> or --open-id <ou_...>"
    return 1
  fi

  local member_type member_id
  if [[ -n "$open_id" ]]; then
    member_type="openid"
    member_id="$open_id"
  else
    # Try to resolve email → open_id via Contact API first
    log_info "Resolving email → open_id for $email ..."
    local resolve_out
    resolve_out=$(lark-cli api POST "/open-apis/contact/v3/users/batch_get_id" \
      --as bot \
      --data "{\"emails\":[\"$email\"]}" 2>/dev/null || echo "{}")
    open_id=$(python3 -c "
import json, sys
d = json.loads(sys.argv[1])
users = d.get('data', {}).get('user_list', [])
for u in users:
    oid = u.get('open_id') or u.get('user_id', '')
    if oid:
        print(oid)
        raise SystemExit(0)
" "$resolve_out" 2>/dev/null || echo "")

    if [[ -n "$open_id" ]]; then
      log_info "Resolved: $email → $open_id"
      member_type="openid"
      member_id="$open_id"
    else
      # Could not resolve — fall back to email member_type and let Lark try
      member_type="email"
      member_id="$email"
    fi
  fi

  log_head "Wiki add-member: space=$space_id member=$member_id role=$role"

  local result
  result=$(lark-cli wiki spaces members create \
    --params "{\"space_id\":\"$space_id\"}" \
    --data "{\"member_id\":\"$member_id\",\"member_type\":\"$member_type\",\"member_role\":\"$role\"}" \
    2>&1)

  # Detect external-user error (131005) and surface the workaround
  local code
  code=$(echo "$result" | python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    print(d.get('code', 0))
except Exception:
    print(0)
" 2>/dev/null || echo "0")

  if [[ "$code" == "131005" ]]; then
    log_error "Cannot add external user '$email' via email — Lark API does not expose cross-tenant users (error 131005)"
    echo ""
    echo "  Workaround options:"
    echo ""
    echo "  A) Invite as guest via admin console, then add by open_id:"
    echo "     1. Go to admin.larksuite.com → External collaborators → Invite"
    echo "     2. After invitation, ask the user for their open_id"
    echo "     3. Run: larc wiki add-member --space-id $space_id --open-id <open_id> --role $role"
    echo ""
    echo "  B) Make the space publicly readable (no Lark account required):"
    echo "     larc wiki open-sharing --space-id $space_id --level anyone_readable"
    echo ""
    echo "  Reference: docs/known-issues/lark-external-user-api-gap.md"
    return 1
  elif [[ "$code" != "0" ]]; then
    local msg
    msg=$(echo "$result" | python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    print(d.get('msg', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")
    log_error "Wiki member add failed (code $code): $msg"
    log_info "Raw response: $result"
    return 1
  fi

  log_ok "Added $member_id ($role) to Wiki space $space_id"
}

# ── open-sharing ──────────────────────────────────────────────────────────────

_wiki_open_sharing() {
  local space_id="${LARC_WIKI_SPACE_ID:-}"
  local level="anyone_readable"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --space-id) space_id="$2"; shift 2 ;;
      --level)    level="$2";    shift 2 ;;
      *) log_warn "Unknown option: $1"; shift ;;
    esac
  done

  if [[ -z "$space_id" ]]; then
    log_error "Usage: larc wiki open-sharing --space-id <id> --level <level>"
    return 1
  fi

  case "$level" in
    no_access|tenant_readable|anyone_readable) ;;
    *)
      log_error "Invalid --level '$level'. Choose: no_access | tenant_readable | anyone_readable"
      return 1
      ;;
  esac

  log_info "Setting open_sharing=$level for space $space_id ..."

  local result
  result=$(lark-cli api PUT "/open-apis/wiki/v2/spaces/${space_id}/setting" \
    --data "{\"open_sharing\":\"$level\"}" 2>&1)

  local code
  code=$(echo "$result" | python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    print(d.get('code', 0))
except Exception:
    print(0)
" 2>/dev/null || echo "0")

  if [[ "$code" == "0" ]]; then
    log_ok "Wiki space $space_id open_sharing set to '$level'"
    if [[ "$level" == "anyone_readable" ]]; then
      log_info "The space is now publicly readable via link (no Lark account required)"
    fi
  else
    local msg
    msg=$(echo "$result" | python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    print(d.get('msg', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")
    log_error "open_sharing update failed (code $code): $msg"
    return 1
  fi
}
