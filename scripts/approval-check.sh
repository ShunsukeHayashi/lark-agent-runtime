#!/usr/bin/env bash
# scripts/approval-check.sh — ordered verification for approval flow

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APPROVAL_CODE=""
USER_ID=""
OPEN_ID=""
DEFINITION_FILE=""
FORM_FILE=""
PAYLOAD_FILE=""
UPLOAD_PATH=""
UPLOAD_TYPE="attachment"
UPLOAD_NAME=""
LOCALE="ja-JP"
USER_ID_TYPE=""
WORK_DIR="/tmp/larc-approval-check"
LIVE_MODE=false

usage() {
  cat <<EOF
Usage: scripts/approval-check.sh [options]

Required:
  --approval-code <code>
  --user-id <id> | --open-id <id>

Optional:
  --definition-file <path>  Reuse an existing approval definition JSON
  --form-file <path>        Reuse an existing form.json
  --payload-file <path>     Reuse an existing extra.json
  --upload-path <path>      Also verify approve upload-file
  --upload-type <type>      attachment | image (default: attachment)
  --upload-name <name>      Override upload file name
  --locale <locale>         Default: ja-JP
  --user-id-type <type>     Default inferred from --user-id / --open-id
  --work-dir <path>         Scratch directory (default: /tmp/larc-approval-check)
  --live                    Execute live API calls instead of --dry-run
  --help                    Show this help

Examples:
  scripts/approval-check.sh --approval-code CODE --user-id USER_ID
  scripts/approval-check.sh --approval-code CODE --user-id USER_ID --upload-path ./receipt.pdf
  scripts/approval-check.sh --approval-code CODE --user-id USER_ID --live
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --approval-code) APPROVAL_CODE="$2"; shift 2 ;;
    --user-id) USER_ID="$2"; USER_ID_TYPE="${USER_ID_TYPE:-user_id}"; shift 2 ;;
    --open-id) OPEN_ID="$2"; USER_ID_TYPE="${USER_ID_TYPE:-open_id}"; shift 2 ;;
    --definition-file) DEFINITION_FILE="$2"; shift 2 ;;
    --form-file) FORM_FILE="$2"; shift 2 ;;
    --payload-file) PAYLOAD_FILE="$2"; shift 2 ;;
    --upload-path) UPLOAD_PATH="$2"; shift 2 ;;
    --upload-type) UPLOAD_TYPE="$2"; shift 2 ;;
    --upload-name) UPLOAD_NAME="$2"; shift 2 ;;
    --locale) LOCALE="$2"; shift 2 ;;
    --user-id-type) USER_ID_TYPE="$2"; shift 2 ;;
    --work-dir) WORK_DIR="$2"; shift 2 ;;
    --live) LIVE_MODE=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *)
      echo "[approval-check] unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

[[ -z "$APPROVAL_CODE" ]] && { echo "[approval-check] --approval-code is required" >&2; exit 1; }
[[ -z "$USER_ID" && -z "$OPEN_ID" ]] && { echo "[approval-check] specify --user-id or --open-id" >&2; exit 1; }
[[ -n "$USER_ID" && -n "$OPEN_ID" ]] && { echo "[approval-check] use only one of --user-id or --open-id" >&2; exit 1; }
USER_ID_TYPE="${USER_ID_TYPE:-user_id}"

mkdir -p "$WORK_DIR"
DEFINITION_FILE="${DEFINITION_FILE:-$WORK_DIR/approval-definition.json}"
FORM_FILE="${FORM_FILE:-$WORK_DIR/form.json}"
PAYLOAD_FILE="${PAYLOAD_FILE:-$WORK_DIR/extra.json}"

run_step() {
  local label="$1"
  shift
  echo ""
  echo "[approval-check] $label"
  "$@"
}

dry_flag() {
  if [[ "$LIVE_MODE" == "true" ]]; then
    return 1
  fi
  printf '%s' '--dry-run'
}

run_step "syntax" bash -n lib/approve.sh

if [[ ! -f "$DEFINITION_FILE" ]]; then
  if [[ "$LIVE_MODE" == "true" ]]; then
    run_step "definition" \
      bin/larc approve definition "$APPROVAL_CODE" \
        --locale "$LOCALE" \
        --user-id-type "$USER_ID_TYPE" \
        --output "$DEFINITION_FILE"
  else
    run_step "definition dry-run" \
      bin/larc approve definition "$APPROVAL_CODE" \
        --locale "$LOCALE" \
        --user-id-type "$USER_ID_TYPE" \
        --dry-run
    echo "[approval-check] note: dry-run では definition file を保存できないので、live で再実行するか --definition-file を渡してください"
  fi
fi

if [[ -f "$DEFINITION_FILE" ]]; then
  [[ ! -f "$FORM_FILE" ]] && run_step "scaffold form" \
    bin/larc approve scaffold-form --definition-file "$DEFINITION_FILE" --output "$FORM_FILE"
  [[ ! -f "$PAYLOAD_FILE" ]] && run_step "scaffold payload" \
    bin/larc approve scaffold-payload --definition-file "$DEFINITION_FILE" --output "$PAYLOAD_FILE"
fi

if [[ -n "$UPLOAD_PATH" ]]; then
  if [[ "$LIVE_MODE" == "true" ]]; then
    run_step "upload file" \
      bin/larc approve upload-file --path "$UPLOAD_PATH" --type "$UPLOAD_TYPE" ${UPLOAD_NAME:+--name "$UPLOAD_NAME"}
  else
    run_step "upload file dry-run" \
      bin/larc approve upload-file --path "$UPLOAD_PATH" --type "$UPLOAD_TYPE" ${UPLOAD_NAME:+--name "$UPLOAD_NAME"} --dry-run
  fi
fi

preview_cmd=(
  bin/larc approve preview
  --approval-code "$APPROVAL_CODE"
  --locale "$LOCALE"
  --user-id-type "$USER_ID_TYPE"
)
if [[ -n "$USER_ID" ]]; then
  preview_cmd+=(--user-id "$USER_ID")
else
  preview_cmd+=(--open-id "$OPEN_ID")
fi
preview_cmd+=(--form-file "$FORM_FILE")
[[ "$LIVE_MODE" != "true" ]] && preview_cmd+=(--dry-run)
run_step "preview" "${preview_cmd[@]}"

create_cmd=(
  bin/larc approve create
  --approval-code "$APPROVAL_CODE"
  --locale "$LOCALE"
  --user-id-type "$USER_ID_TYPE"
)
if [[ -n "$USER_ID" ]]; then
  create_cmd+=(--user-id "$USER_ID")
else
  create_cmd+=(--open-id "$OPEN_ID")
fi
create_cmd+=(--form-file "$FORM_FILE" --payload-file "$PAYLOAD_FILE")
[[ "$LIVE_MODE" != "true" ]] && create_cmd+=(--dry-run)
run_step "create" "${create_cmd[@]}"

echo ""
echo "[approval-check] OK"
echo "[approval-check] work dir: $WORK_DIR"
echo "[approval-check] mode: $([[ "$LIVE_MODE" == "true" ]] && echo live || echo dry-run)"
