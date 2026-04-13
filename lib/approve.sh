#!/usr/bin/env bash
# lib/approve.sh — Approval task helpers

cmd_approve() {
  local action="${1:-help}"; shift || true
  case "$action" in
    list|inbox) _approve_list "$@" ;;
    definition|get|show) _approve_definition "$@" ;;
    scaffold-form|scaffold) _approve_scaffold_form "$@" ;;
    scaffold-payload) _approve_scaffold_payload "$@" ;;
    scaffold-package|init) _approve_scaffold_package "$@" ;;
    preview) _approve_preview "$@" ;;
    create|start|submit) _approve_create "$@" ;;
    upload-file|upload) _approve_upload_file "$@" ;;
    help|--help|-h) _approve_help ;;
    *)
      # Keep backward compatibility with old `larc approve <doc_url>` calls.
      if [[ -n "$action" ]]; then
        log_warn "Unknown approve action: $action"
      fi
      _approve_help
      return 1
      ;;
  esac
}

_approve_help() {
  cat <<EOF

${BOLD}larc approve${RESET} — 承認タスク操作

${BOLD}コマンド:${RESET}
  ${CYAN}list${RESET} / ${CYAN}inbox${RESET}     現在の承認待ちタスクを一覧表示
  ${CYAN}definition${RESET} <approval_code>      承認定義と form / node_list を確認
  ${CYAN}scaffold-form${RESET}                   承認定義から form.json の雛形を生成
  ${CYAN}scaffold-payload${RESET}                承認定義から extra.json の雛形を生成
  ${CYAN}scaffold-package${RESET}                承認セット一式をディレクトリへ生成
  ${CYAN}preview${RESET}                         起票前の承認フローを raw API で preview
  ${CYAN}create${RESET}                          新規承認起票を raw API で実行
  ${CYAN}upload-file${RESET}                     添付 / 画像を approval file API へ upload

${BOLD}例:${RESET}
  larc approve list
  larc approve definition APPROVAL_CODE
  larc approve scaffold-form --definition-file approval-definition.json --output form.json
  larc approve scaffold-payload --definition-file approval-definition.json --output extra.json
  larc approve scaffold-package --definition-file approval-definition.json --output-dir ./approval-work
  larc approve preview --approval-code APPROVAL_CODE --user-id USER_ID --form-file form.json --dry-run
  larc approve create --approval-code APPROVAL_CODE --user-id USER_ID --form-file form.json --payload-file extra.json --dry-run
  larc approve upload-file --path ./receipt.pdf --type attachment --dry-run
  cat docs/approval-spike.md

EOF
}

_approve_list() {
  log_head "承認待ちタスク一覧"
  lark-cli approval tasks query \
    --params '{"topic":"1","locale":"ja-JP","page_size":20}' \
    --jq '.data.task_list // .task_list // .items // .' \
    2>/dev/null || log_warn "承認タスクの取得に失敗しました"
}

_approve_definition() {
  local approval_code="${1:-}"
  local locale="ja-JP"
  local user_id_type="user_id"
  local dry_run=false
  local output_path=""

  shift || true
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --locale) locale="$2"; shift 2 ;;
      --user-id-type) user_id_type="$2"; shift 2 ;;
      --output) output_path="$2"; shift 2 ;;
      --dry-run) dry_run=true; shift ;;
      *)
        log_warn "Unknown option: $1"
        shift
        ;;
    esac
  done

  [[ -z "$approval_code" ]] && {
    log_error "Usage: larc approve definition <approval_code> [--locale ja-JP] [--user-id-type user_id] [--output file] [--dry-run]"
    return 1
  }

  log_head "承認定義の取得: $approval_code"
  local cmd=(
    lark-cli api GET "/open-apis/approval/v4/approvals/${approval_code}"
    --params "{\"locale\":\"${locale}\",\"user_id_type\":\"${user_id_type}\"}"
  )
  [[ "$dry_run" == "true" ]] && cmd+=(--dry-run)
  local output
  output=$("${cmd[@]}")

  if [[ -n "$output_path" && "$dry_run" != "true" ]]; then
    printf '%s\n' "$output" > "$output_path"
    log_ok "Saved: $output_path"
  else
    printf '%s\n' "$output"
  fi
}

_approve_scaffold_form() {
  local approval_code=""
  local definition_file=""
  local output_path=""
  local locale="ja-JP"
  local user_id_type="user_id"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --approval-code) approval_code="$2"; shift 2 ;;
      --definition-file) definition_file="$2"; shift 2 ;;
      --output) output_path="$2"; shift 2 ;;
      --locale) locale="$2"; shift 2 ;;
      --user-id-type) user_id_type="$2"; shift 2 ;;
      *)
        log_warn "Unknown option: $1"
        shift
        ;;
    esac
  done

  [[ -z "$approval_code" && -z "$definition_file" ]] && {
    log_error "Specify either --approval-code or --definition-file"
    return 1
  }
  [[ -n "$approval_code" && -n "$definition_file" ]] && {
    log_error "Use only one of --approval-code or --definition-file"
    return 1
  }

  local definition_json=""
  if [[ -n "$approval_code" ]]; then
    log_head "承認 form 雛形の生成: $approval_code"
    definition_json=$(lark-cli api GET "/open-apis/approval/v4/approvals/${approval_code}" \
      --params "{\"locale\":\"${locale}\",\"user_id_type\":\"${user_id_type}\"}")
  else
    [[ ! -f "$definition_file" ]] && {
      log_error "Definition file not found: $definition_file"
      return 1
    }
    log_head "承認 form 雛形の生成: $(basename "$definition_file")"
    definition_json=$(cat "$definition_file")
  fi

  local scaffold
  scaffold=$(python3 - "$definition_json" <<'PY'
import json
import sys

raw = sys.argv[1]
doc = json.loads(raw)
if isinstance(doc, dict) and "data" in doc and isinstance(doc["data"], dict):
    doc = doc["data"]

form = doc.get("form", [])
if isinstance(form, str):
    form = json.loads(form)

def placeholder(widget):
    widget_type = widget.get("type", "")
    options = widget.get("options") or widget.get("widget_options") or []
    first_option = None
    if isinstance(options, list) and options:
        item = options[0]
        if isinstance(item, dict):
            first_option = item.get("value") or item.get("key") or item.get("name")
        else:
            first_option = item

    if widget_type in {"input", "textarea", "telephone", "address", "location", "account", "document"}:
        return ""
    if widget_type in {"number", "amount"}:
        return "0"
    if widget_type in {"radioV2"}:
        return first_option or ""
    if widget_type in {"checkboxV2", "department", "contact", "image", "imageV2", "attachment", "attachmentV2"}:
        return []
    if widget_type == "date":
        return {"date": ""}
    if widget_type == "dateInterval":
        return {"start": "", "end": ""}
    return "__FILL_MANUALLY__"

skip_types = {"text", "formula", "serialNumber"}
result = []
for widget in form:
    if not isinstance(widget, dict):
        continue
    widget_type = widget.get("type", "")
    if widget_type in skip_types:
        continue
    item = {
        "id": widget.get("id", ""),
        "type": widget_type,
        "value": placeholder(widget),
        "_name": widget.get("name", ""),
        "_custom_id": widget.get("custom_id", ""),
        "_required": bool(widget.get("required", False)),
    }
    result.append(item)

print(json.dumps(result, ensure_ascii=False, indent=2))
PY
)

  if [[ -n "$output_path" ]]; then
    printf '%s\n' "$scaffold" > "$output_path"
    log_ok "Saved: $output_path"
  else
    printf '%s\n' "$scaffold"
  fi
}

_approve_scaffold_payload() {
  local approval_code=""
  local definition_file=""
  local output_path=""
  local locale="ja-JP"
  local user_id_type="user_id"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --approval-code) approval_code="$2"; shift 2 ;;
      --definition-file) definition_file="$2"; shift 2 ;;
      --output) output_path="$2"; shift 2 ;;
      --locale) locale="$2"; shift 2 ;;
      --user-id-type) user_id_type="$2"; shift 2 ;;
      *)
        log_warn "Unknown option: $1"
        shift
        ;;
    esac
  done

  [[ -z "$approval_code" && -z "$definition_file" ]] && {
    log_error "Specify either --approval-code or --definition-file"
    return 1
  }
  [[ -n "$approval_code" && -n "$definition_file" ]] && {
    log_error "Use only one of --approval-code or --definition-file"
    return 1
  }

  local definition_json=""
  if [[ -n "$approval_code" ]]; then
    log_head "承認 payload 雛形の生成: $approval_code"
    definition_json=$(lark-cli api GET "/open-apis/approval/v4/approvals/${approval_code}" \
      --params "{\"locale\":\"${locale}\",\"user_id_type\":\"${user_id_type}\"}")
  else
    [[ ! -f "$definition_file" ]] && {
      log_error "Definition file not found: $definition_file"
      return 1
    }
    log_head "承認 payload 雛形の生成: $(basename "$definition_file")"
    definition_json=$(cat "$definition_file")
  fi

  local scaffold
  scaffold=$(python3 - "$definition_json" <<'PY'
import json
import sys

raw = sys.argv[1]
doc = json.loads(raw)
if isinstance(doc, dict) and "data" in doc and isinstance(doc["data"], dict):
    doc = doc["data"]

nodes = doc.get("node_list") or []

approver_nodes = []
cc_nodes = []
for node in nodes:
    if not isinstance(node, dict):
        continue
    node_type = node.get("node_type", "")
    node_id = node.get("custom_node_id") or node.get("node_id") or ""
    name = node.get("name", "")
    if not node_id:
        continue
    if node.get("need_approver"):
        approver_nodes.append({
            "key": node_id,
            "value": [],
            "_node_name": name,
        })
    if node_type == "CC_NODE" or node.get("has_cc_type_free"):
        cc_nodes.append({
            "key": node_id,
            "value": [],
            "_node_name": name,
        })

payload = {
    "title": "",
    "allow_resubmit": False,
    "allow_submit_again": False,
}

if approver_nodes:
    payload["node_approver_user_id_list"] = approver_nodes
if cc_nodes:
    payload["node_cc_user_id_list"] = cc_nodes

print(json.dumps(payload, ensure_ascii=False, indent=2))
PY
)

  if [[ -n "$output_path" ]]; then
    printf '%s\n' "$scaffold" > "$output_path"
    log_ok "Saved: $output_path"
  else
    printf '%s\n' "$scaffold"
  fi
}

_approve_scaffold_package() {
  local approval_code=""
  local definition_file=""
  local output_dir=""
  local locale="ja-JP"
  local user_id_type="user_id"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --approval-code) approval_code="$2"; shift 2 ;;
      --definition-file) definition_file="$2"; shift 2 ;;
      --output-dir) output_dir="$2"; shift 2 ;;
      --locale) locale="$2"; shift 2 ;;
      --user-id-type) user_id_type="$2"; shift 2 ;;
      *)
        log_warn "Unknown option: $1"
        shift
        ;;
    esac
  done

  [[ -z "$approval_code" && -z "$definition_file" ]] && {
    log_error "Specify either --approval-code or --definition-file"
    return 1
  }
  [[ -n "$approval_code" && -n "$definition_file" ]] && {
    log_error "Use only one of --approval-code or --definition-file"
    return 1
  }
  [[ -z "$output_dir" ]] && {
    log_error "Usage: larc approve scaffold-package (--approval-code CODE | --definition-file FILE) --output-dir DIR"
    return 1
  }

  mkdir -p "$output_dir"

  local resolved_definition_file="$output_dir/approval-definition.json"
  local resolved_form_file="$output_dir/form.json"
  local resolved_payload_file="$output_dir/extra.json"

  if [[ -n "$definition_file" ]]; then
    cp "$definition_file" "$resolved_definition_file"
    log_ok "Saved: $resolved_definition_file"
  else
    _approve_definition "$approval_code" \
      --locale "$locale" \
      --user-id-type "$user_id_type" \
      --output "$resolved_definition_file"
  fi

  _approve_scaffold_form \
    --definition-file "$resolved_definition_file" \
    --output "$resolved_form_file"

  _approve_scaffold_payload \
    --definition-file "$resolved_definition_file" \
    --output "$resolved_payload_file"

  cat > "$output_dir/README.md" <<EOF
# Approval Workdir

Files:

- \`approval-definition.json\`
- \`form.json\`
- \`extra.json\`

Next steps:

\`\`\`bash
larc approve preview --approval-code ${approval_code:-APPROVAL_CODE} --user-id USER_ID --form-file $resolved_form_file --dry-run
larc approve create --approval-code ${approval_code:-APPROVAL_CODE} --user-id USER_ID --form-file $resolved_form_file --payload-file $resolved_payload_file --dry-run
\`\`\`
EOF

  log_ok "Approval package ready: $output_dir"
}

_approve_preview() {
  _approve_instances_api "/open-apis/approval/v4/instances/preview" "preview" "$@"
}

_approve_create() {
  _approve_instances_api "/open-apis/approval/v4/instances" "create" "$@"
}

_approve_upload_file() {
  local file_path=""
  local file_type="attachment"
  local file_name=""
  local dry_run=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --path) file_path="$2"; shift 2 ;;
      --type) file_type="$2"; shift 2 ;;
      --name) file_name="$2"; shift 2 ;;
      --dry-run) dry_run=true; shift ;;
      *)
        log_warn "Unknown option: $1"
        shift
        ;;
    esac
  done

  [[ -z "$file_path" ]] && {
    log_error "Usage: larc approve upload-file --path <file> [--type attachment|image] [--name upload-name] [--dry-run]"
    return 1
  }
  [[ ! -f "$file_path" ]] && {
    log_error "File not found: $file_path"
    return 1
  }
  case "$file_type" in
    attachment|image) ;;
    *)
      log_error "type must be 'attachment' or 'image'"
      return 1
      ;;
  esac

  file_name="${file_name:-$(basename "$file_path")}"

  log_head "承認ファイル upload: $file_name"
  local cmd=(
    lark-cli api POST "/approval/openapi/v2/file/upload"
    --file "content=${file_path}"
    --data "{\"name\":\"${file_name}\",\"type\":\"${file_type}\"}"
  )
  [[ "$dry_run" == "true" ]] && cmd+=(--dry-run)
  "${cmd[@]}"
}

_approve_instances_api() {
  local path="$1"
  local mode="$2"
  shift 2

  local approval_code=""
  local user_id=""
  local open_id=""
  local department_id=""
  local form_file=""
  local form_json=""
  local payload_file=""
  local uuid_value=""
  local locale="ja-JP"
  local user_id_type=""
  local dry_run=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --approval-code) approval_code="$2"; shift 2 ;;
      --user-id) user_id="$2"; user_id_type="${user_id_type:-user_id}"; shift 2 ;;
      --open-id) open_id="$2"; user_id_type="${user_id_type:-open_id}"; shift 2 ;;
      --department-id) department_id="$2"; shift 2 ;;
      --form-file) form_file="$2"; shift 2 ;;
      --form-json) form_json="$2"; shift 2 ;;
      --payload-file) payload_file="$2"; shift 2 ;;
      --uuid) uuid_value="$2"; shift 2 ;;
      --locale) locale="$2"; shift 2 ;;
      --user-id-type) user_id_type="$2"; shift 2 ;;
      --dry-run) dry_run=true; shift ;;
      *)
        log_warn "Unknown option: $1"
        shift
        ;;
    esac
  done

  [[ -z "$approval_code" ]] && {
    log_error "approval_code is required"
    return 1
  }
  [[ -z "$user_id" && -z "$open_id" ]] && {
    log_error "Specify either --user-id or --open-id"
    return 1
  }
  [[ -z "$form_file" && -z "$form_json" ]] && {
    log_error "Specify either --form-file or --form-json"
    return 1
  }
  [[ -n "$form_file" && -n "$form_json" ]] && {
    log_error "Use only one of --form-file or --form-json"
    return 1
  }
  [[ -n "$payload_file" && ! -f "$payload_file" ]] && {
    log_error "Payload file not found: $payload_file"
    return 1
  }
  user_id_type="${user_id_type:-user_id}"

  local payload
  payload=$(_approve_build_payload \
    "$approval_code" \
    "$user_id" \
    "$open_id" \
    "$department_id" \
    "$form_file" \
    "$form_json" \
    "$payload_file" \
    "$uuid_value") || return 1

  log_head "承認 ${mode}: ${approval_code}"
  local cmd=(
    lark-cli api POST "$path"
    --params "{\"user_id_type\":\"${user_id_type}\",\"locale\":\"${locale}\"}"
    --data "$payload"
  )
  [[ "$dry_run" == "true" ]] && cmd+=(--dry-run)
  "${cmd[@]}"
}

_approve_build_payload() {
  local approval_code="$1"
  local user_id="$2"
  local open_id="$3"
  local department_id="$4"
  local form_file="$5"
  local form_json="$6"
  local payload_file="$7"
  local uuid_value="$8"

  python3 - "$approval_code" "$user_id" "$open_id" "$department_id" "$form_file" "$form_json" "$payload_file" "$uuid_value" <<'PY'
import json
import pathlib
import sys

approval_code, user_id, open_id, department_id, form_file, form_json, payload_file, uuid_value = sys.argv[1:]

if form_file:
    text = pathlib.Path(form_file).read_text(encoding="utf-8")
else:
    text = form_json

try:
    form_value = json.loads(text)
except json.JSONDecodeError as exc:
    raise SystemExit(f"form JSON parse failed: {exc}")

def strip_meta(value):
    if isinstance(value, dict):
        return {
            key: strip_meta(inner)
            for key, inner in value.items()
            if not str(key).startswith("_")
        }
    if isinstance(value, list):
        return [strip_meta(item) for item in value]
    return value

form_value = strip_meta(form_value)

payload = {
    "approval_code": approval_code,
    "form": json.dumps(form_value, ensure_ascii=False, separators=(",", ":")),
}

if payload_file:
    extra = json.loads(pathlib.Path(payload_file).read_text(encoding="utf-8"))
    if not isinstance(extra, dict):
        raise SystemExit("payload file must be a JSON object")
    payload.update(extra)

if user_id:
    payload["user_id"] = user_id
if open_id:
    payload["open_id"] = open_id
if department_id:
    payload["department_id"] = department_id
if uuid_value:
    payload["uuid"] = uuid_value

payload = strip_meta(payload)

print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))
PY
}
