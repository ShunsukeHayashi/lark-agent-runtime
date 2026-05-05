#!/usr/bin/env bash
# lib/base2pdf.sh — larc base2pdf: Lark Base レコードをテンプレートに差し込んで PDF 生成
#
# Pipeline: Lark Base → Markdown 中間 → Lark Doc → PDF Export → Drive 保存 → 元レコードへ link 書戻し
#
# Usage:
#   larc base2pdf list-templates [--industry <name>]
#   larc base2pdf describe-template --name <name>
#   larc base2pdf generate --base-token <token> --table-id <id> --record-id <id> \
#                          --template <name> --output drive-folder://<folder-id>
#   larc base2pdf batch --base-token <token> --table-id <id> --filter "<filter>" \
#                       --template <name> --output drive-folder://<folder-id>

# Resolved by bin/larc before sourcing this file.
: "${LIB_DIR:?LIB_DIR not set}"
: "${LARC_HOME:?LARC_HOME not set}"

# Template root: ship-with-larc + user-customizable
B2P_BUILTIN_TEMPLATE_DIR="$(cd "$LIB_DIR/../templates/base2pdf" && pwd)"
B2P_USER_TEMPLATE_DIR="$LARC_HOME/templates/base2pdf"
B2P_RENDER_SCRIPT="$(cd "$LIB_DIR/../scripts" && pwd)/base2pdf-render.py"

cmd_base2pdf() {
  local subcmd="${1:-}"
  if [[ -z "$subcmd" ]]; then
    _b2p_usage
    exit 1
  fi
  shift

  case "$subcmd" in
    list-templates)     _b2p_list_templates "$@" ;;
    describe-template)  _b2p_describe_template "$@" ;;
    install-template)   _b2p_install_template "$@" ;;
    generate)           _b2p_generate "$@" ;;
    batch)              _b2p_batch "$@" ;;
    -h|--help|help)     _b2p_usage ;;
    *)
      log_error "Unknown base2pdf subcommand: $subcmd"
      _b2p_usage
      exit 1
      ;;
  esac
}

_b2p_usage() {
  cat <<'EOF'
larc base2pdf — Lark Base から PDF を生成

Subcommands:
  list-templates [--industry <name>]
      利用可能なテンプレ一覧を表示

  describe-template --name <name>
      テンプレの詳細（必須フィールド・計算式）を表示

  install-template --name <name> --industry <industry> --file <path>
      ローカルテンプレを ~/.larc/templates/base2pdf/<industry>/ に追加

  generate --base-token <token> --table-id <id> --record-id <id>
           --template <name> --output drive-folder://<folder-id>
           [--writeback-field <field>] [--writeback-link]
      単一レコードから PDF 1 ファイルを生成

  batch --base-token <token> --table-id <id> --filter "<filter>"
        --template <name> --output drive-folder://<folder-id>
        [--concurrency <N>] [--writeback-field <field>] [--writeback-link]
      フィルタに一致するレコードから一括 PDF 生成

Examples:
  larc base2pdf list-templates --industry manufacturing
  larc base2pdf generate --base-token bascn... --table-id tbl... \
       --record-id rec... --template invoice-standard \
       --output drive-folder://fldcn...

EOF
}

# ---------------------------------------------------------------------------
# list-templates
# ---------------------------------------------------------------------------
_b2p_list_templates() {
  local industry=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --industry) industry="$2"; shift 2 ;;
      *) log_warn "Unknown option: $1"; shift ;;
    esac
  done

  log_head "Built-in templates"
  if [[ -d "$B2P_BUILTIN_TEMPLATE_DIR" ]]; then
    if [[ -n "$industry" ]]; then
      _b2p_list_dir "$B2P_BUILTIN_TEMPLATE_DIR/$industry" "$industry"
    else
      for d in "$B2P_BUILTIN_TEMPLATE_DIR"/*/; do
        [[ -d "$d" ]] || continue
        _b2p_list_dir "$d" "$(basename "$d")"
      done
    fi
  fi

  log_head "User templates ($B2P_USER_TEMPLATE_DIR)"
  if [[ -d "$B2P_USER_TEMPLATE_DIR" ]]; then
    if [[ -n "$industry" ]]; then
      _b2p_list_dir "$B2P_USER_TEMPLATE_DIR/$industry" "$industry"
    else
      for d in "$B2P_USER_TEMPLATE_DIR"/*/; do
        [[ -d "$d" ]] || continue
        _b2p_list_dir "$d" "$(basename "$d")"
      done
    fi
  else
    log_info "(empty — install with: larc base2pdf install-template ...)"
  fi
}

_b2p_list_dir() {
  local dir="$1" industry="$2"
  [[ -d "$dir" ]] || return 0
  for f in "$dir"/*.md; do
    [[ -f "$f" ]] || continue
    local name; name="$(basename "$f" .md)"
    local desc; desc="$(_b2p_extract_frontmatter_field "$f" description)"
    printf "  %-30s [%s] %s\n" "$name" "$industry" "$desc"
  done
}

_b2p_extract_frontmatter_field() {
  local file="$1" field="$2"
  awk -v f="$field" '
    /^---$/ { in_fm = !in_fm; next }
    in_fm && $1 == f":" { sub(/^[^:]+:[ \t]*/, ""); print; exit }
  ' "$file"
}

# ---------------------------------------------------------------------------
# describe-template
# ---------------------------------------------------------------------------
_b2p_describe_template() {
  local name=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name) name="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$name" ]] && { log_error "--name required"; exit 1; }

  local path; path="$(_b2p_resolve_template_path "$name")"
  [[ -z "$path" ]] && { log_error "Template not found: $name"; exit 1; }

  log_info "Template: $name"
  log_info "Path: $path"
  echo ""
  awk '/^---$/ { c++; if (c >= 2) exit; next } { print }' "$path"
}

_b2p_resolve_template_path() {
  local name="$1"
  # Search user dir first (override), then builtin
  for root in "$B2P_USER_TEMPLATE_DIR" "$B2P_BUILTIN_TEMPLATE_DIR"; do
    [[ -d "$root" ]] || continue
    local match
    match="$(find "$root" -type f -name "${name}.md" 2>/dev/null | head -1)"
    [[ -n "$match" ]] && { echo "$match"; return 0; }
  done
  return 1
}

# ---------------------------------------------------------------------------
# install-template
# ---------------------------------------------------------------------------
_b2p_install_template() {
  # Three modes:
  #   --file <path>           Install from local .md file
  #   --from-doc <url|token>  Fetch a Lark Doc and convert to template
  #   --from-stdin            Read template body from stdin (for AI-generated content)
  local name="" industry="" src="" from_doc="" from_stdin=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name) name="$2"; shift 2 ;;
      --industry) industry="$2"; shift 2 ;;
      --file) src="$2"; shift 2 ;;
      --from-doc) from_doc="$2"; shift 2 ;;
      --from-stdin) from_stdin=true; shift ;;
      *) shift ;;
    esac
  done
  [[ -z "$name" || -z "$industry" ]] && {
    log_error "install-template requires --name and --industry"
    exit 1
  }

  local dest="$B2P_USER_TEMPLATE_DIR/$industry"
  mkdir -p "$dest"
  local out="$dest/${name}.md"

  if [[ -n "$src" ]]; then
    [[ -f "$src" ]] || { log_error "File not found: $src"; exit 1; }
    cp "$src" "$out"

  elif [[ -n "$from_doc" ]]; then
    # Accept Lark Doc URL or raw doc token. Auto-detect.
    local doc_token="$from_doc"
    if [[ "$from_doc" == http* ]]; then
      doc_token="$(echo "$from_doc" | sed -E 's#.*/(docx|doc)/([A-Za-z0-9]+).*#\2#')"
    fi
    log_info "Fetching Lark Doc: $doc_token"
    local md
    md="$(lark-cli docs +fetch --doc "$doc_token" 2>/dev/null \
      | python3 -c '
import sys, json
try:
    d = json.loads(sys.stdin.read())
except Exception:
    sys.exit(1)
print((d.get("data", {}) or {}).get("markdown", "") or d.get("markdown", ""))
')"
    [[ -z "$md" ]] && { log_error "Failed to fetch Lark Doc content"; exit 1; }

    # Auto-derive required_fields from {{var}} occurrences if no frontmatter present.
    local body="$md"
    local has_fm=false
    [[ "$md" == "---"* ]] && has_fm=true

    if [[ "$has_fm" == "false" ]]; then
      local fields
      fields="$(echo "$md" | python3 -c '
import sys, re
text = sys.stdin.read()
fields = sorted({m.group(1) for m in re.finditer(r"\{\{\s*([\w\.]+)\s*\}\}", text) if "." not in m.group(1)})
for f in fields:
    print(f"  - {f}")
')"
      cat > "$out" <<EOF
---
name: $name
industry: $industry
description: Imported from Lark Doc $doc_token
required_fields:
$fields
calculations: {}
---

$body
EOF
    else
      printf "%s" "$md" > "$out"
    fi

  elif [[ "$from_stdin" == "true" ]]; then
    cat > "$out"

  else
    log_error "install-template requires one of: --file, --from-doc, --from-stdin"
    exit 1
  fi

  log_ok "Installed: $out"
  log_info "Test with: larc base2pdf describe-template --name $name"
}

# ---------------------------------------------------------------------------
# generate (single record)
# ---------------------------------------------------------------------------
_b2p_generate() {
  local base_token="" table_id="" record_id="" template_name=""
  local output="" writeback_field="" writeback_link=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --base-token) base_token="$2"; shift 2 ;;
      --table-id) table_id="$2"; shift 2 ;;
      --record-id) record_id="$2"; shift 2 ;;
      --template) template_name="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      --writeback-field) writeback_field="$2"; shift 2 ;;
      --writeback-link) writeback_link=true; shift ;;
      *) log_warn "Unknown option: $1"; shift ;;
    esac
  done

  [[ -z "$base_token" || -z "$table_id" || -z "$record_id" || -z "$template_name" || -z "$output" ]] && {
    log_error "generate requires: --base-token --table-id --record-id --template --output"
    exit 1
  }

  local template_path; template_path="$(_b2p_resolve_template_path "$template_name")"
  [[ -z "$template_path" ]] && { log_error "Template not found: $template_name"; exit 1; }

  local folder_token="${output#drive-folder://}"

  log_head "base2pdf generate"
  log_info "Template: $template_name ($template_path)"
  log_info "Base: $base_token / Table: $table_id / Record: $record_id"
  log_info "Output: $folder_token"

  # Step 1: fetch record
  local record_json; record_json="$(_b2p_fetch_record "$base_token" "$table_id" "$record_id")"
  [[ -z "$record_json" ]] && { log_error "Failed to fetch record"; exit 1; }

  # Step 2: render markdown
  local tmp_md; tmp_md="$(mktemp -t b2p_render.XXXXXX.md)"
  echo "$record_json" | python3 "$B2P_RENDER_SCRIPT" \
    --template "$template_path" \
    --output "$tmp_md" || { log_error "Render failed"; rm -f "$tmp_md"; exit 1; }

  # Step 3: create Lark Doc from markdown
  local doc_title="${template_name}_$(date +%Y%m%d_%H%M%S)"
  local doc_token; doc_token="$(_b2p_create_doc_from_md "$tmp_md" "$folder_token" "$doc_title")"
  rm -f "$tmp_md"
  [[ -z "$doc_token" ]] && { log_error "Failed to create Lark Doc"; exit 1; }
  log_ok "Doc created: $doc_token"

  # Step 4: export to PDF + upload to target folder
  local pdf_token; pdf_token="$(_b2p_export_doc_to_pdf "$doc_token" "$folder_token" "$doc_title")"
  [[ -z "$pdf_token" ]] && { log_error "Failed to export/upload PDF"; exit 1; }
  log_ok "PDF uploaded: $pdf_token"

  # Step 5: writeback (optional)
  if [[ "$writeback_link" == "true" && -n "$writeback_field" ]]; then
    if _b2p_writeback "$base_token" "$table_id" "$record_id" "$writeback_field" "$pdf_token"; then
      log_ok "Wrote back PDF link to field: $writeback_field"
    fi
  fi

  echo ""
  echo "doc_token: $doc_token"
  echo "pdf_token: $pdf_token"
}

# ---------------------------------------------------------------------------
# batch (multiple records)
# ---------------------------------------------------------------------------
_b2p_batch() {
  local base_token="" table_id="" filter="" template_name=""
  local output="" concurrency=5 writeback_field="" writeback_link=false
  local view_id=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --base-token) base_token="$2"; shift 2 ;;
      --table-id) table_id="$2"; shift 2 ;;
      --filter) filter="$2"; shift 2 ;;
      --view-id) view_id="$2"; shift 2 ;;
      --template) template_name="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      --concurrency) concurrency="$2"; shift 2 ;;
      --writeback-field) writeback_field="$2"; shift 2 ;;
      --writeback-link) writeback_link=true; shift ;;
      *) shift ;;
    esac
  done

  [[ -z "$base_token" || -z "$table_id" || -z "$template_name" || -z "$output" ]] && {
    log_error "batch requires: --base-token --table-id --template --output"
    exit 1
  }

  local folder_token="${output#drive-folder://}"

  log_head "base2pdf batch"
  log_info "Template: $template_name"
  log_info "Base: $base_token / Table: $table_id"
  log_info "Filter: ${filter:-(none)} View: ${view_id:-(none)}"
  log_info "Concurrency: $concurrency (sequential in MVP, parallel in v0.2)"

  # List records (paginated). MVP: single page up to 100.
  local params; params="$(python3 -c "
import json
p = {'app_token': '$base_token', 'table_id': '$table_id', 'page_size': 100}
if '$view_id': p['view_id'] = '$view_id'
if '$filter': p['filter'] = '$filter'
print(json.dumps(p))")"

  local list_resp; list_resp="$(lark-cli base record list --params "$params" --as "$B2P_AS" 2>/dev/null)"
  local record_ids; record_ids="$(echo "$list_resp" | python3 -c '
import sys, json
try:
    d = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)
items = (d.get("data", {}).get("items", []))
for it in items:
    print(it.get("record_id", ""))
')"

  local total; total="$(echo "$record_ids" | grep -c .)"
  [[ "$total" == "0" ]] && { log_warn "No records matched"; return 0; }

  log_info "$total record(s) matched"
  local i=0 ok=0 fail=0
  while IFS= read -r rid; do
    [[ -z "$rid" ]] && continue
    i=$((i+1))
    log_info "[${i}/${total}] generating record $rid"
    local args=(--base-token "$base_token" --table-id "$table_id" --record-id "$rid" \
                --template "$template_name" --output "$output")
    [[ -n "$writeback_field" ]] && args+=(--writeback-field "$writeback_field")
    [[ "$writeback_link" == "true" ]] && args+=(--writeback-link)
    if _b2p_generate "${args[@]}" >/dev/null 2>&1; then
      ok=$((ok+1))
    else
      fail=$((fail+1))
    fi
  done <<< "$record_ids"

  log_ok "Done: $ok ok / $fail failed (total $total)"
}

# ---------------------------------------------------------------------------
# Internal: lark-cli wrappers
# ---------------------------------------------------------------------------

# Identity used for Lark API calls. Default user, override via env (e.g. for bot-only tenants).
B2P_AS="${B2P_AS:-user}"

_b2p_fetch_record() {
  local base_token="$1" table_id="$2" record_id="$3"
  lark-cli base record get \
    --params "{\"app_token\":\"${base_token}\",\"table_id\":\"${table_id}\",\"record_id\":\"${record_id}\"}" \
    --as "$B2P_AS" 2>/dev/null
}

_b2p_create_doc_from_md() {
  # Returns doc_id (docx token) on stdout, empty string on failure.
  # lark-cli requires --markdown @path to be a relative path within cwd, so we cd first.
  local md_file="$1" folder_token="$2" title="$3"
  local md_dir; md_dir="$(cd "$(dirname "$md_file")" && pwd)"
  local md_base; md_base="$(basename "$md_file")"
  local resp
  resp="$(cd "$md_dir" && lark-cli docs +create \
    --markdown "@${md_base}" \
    --folder-token "$folder_token" \
    --title "$title" 2>&1)" || { log_error "docs +create failed: $resp"; return 1; }

  # Strip the leading [deprecated] notice lines if present, then parse JSON.
  echo "$resp" | python3 -c '
import sys, json, re
text = sys.stdin.read()
m = re.search(r"\{[\s\S]*\}\s*$", text)
if not m:
    sys.exit(0)
try:
    d = json.loads(m.group(0))
except Exception:
    sys.exit(0)
data = d.get("data", {})
print(
    data.get("doc_id")
    or data.get("document_id")
    or (data.get("document") or {}).get("document_id")
    or (data.get("document") or {}).get("token")
    or ""
)
'
}

_b2p_export_doc_to_pdf() {
  # Args: doc_token, target_folder_token, output_filename (without .pdf)
  # Returns: uploaded PDF file_token on stdout, empty on failure.
  local doc_token="$1" folder_token="$2" pdf_name="$3"
  local tmp_dir; tmp_dir="$(mktemp -d -t b2p_pdf.XXXXXX)"

  # Step A: export Lark Doc → local PDF (lark-cli polls internally).
  # lark-cli requires --output-dir to be relative, so we cd into tmp_dir.
  if ! ( cd "$tmp_dir" && lark-cli drive +export \
        --token "$doc_token" \
        --doc-type docx \
        --file-extension pdf \
        --file-name "$pdf_name" \
        --output-dir "." \
        --overwrite >/dev/null 2>&1 ); then
    log_error "drive +export failed for doc=$doc_token"
    rm -rf "$tmp_dir"
    return 1
  fi

  local local_pdf="$tmp_dir/${pdf_name}.pdf"
  if [[ ! -f "$local_pdf" ]]; then
    # Some lark-cli versions append the extension differently; try to find any PDF.
    local found
    found="$(find "$tmp_dir" -maxdepth 1 -type f -name '*.pdf' | head -1)"
    if [[ -n "$found" ]]; then
      local_pdf="$found"
    else
      log_error "Exported PDF not found in $tmp_dir"
      rm -rf "$tmp_dir"
      return 1
    fi
  fi

  # Step B: upload local PDF to target Drive folder, capture file_token.
  # lark-cli requires --file to be a relative path, so cd to the file's directory.
  local pdf_dir; pdf_dir="$(cd "$(dirname "$local_pdf")" && pwd)"
  local pdf_base; pdf_base="$(basename "$local_pdf")"
  local upload_resp
  upload_resp="$(cd "$pdf_dir" && lark-cli drive +upload \
    --file "./${pdf_base}" \
    --folder-token "$folder_token" \
    --name "${pdf_name}.pdf" 2>&1)" || {
    log_error "drive +upload failed: $upload_resp"
    rm -rf "$tmp_dir"
    return 1
  }

  rm -rf "$tmp_dir"

  echo "$upload_resp" | python3 -c '
import sys, json
try:
    d = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)
data = d.get("data", {})
print(data.get("file_token") or data.get("token") or "")
'
}

_b2p_writeback() {
  # Update Base record with PDF link/attachment.
  # MVP: write the file_token URL (Lark Drive deep link) to a single-line text field.
  local base_token="$1" table_id="$2" record_id="$3" field="$4" pdf_token="$5"
  local pdf_url="https://www.larksuite.com/file/${pdf_token}"

  local payload
  payload="$(python3 -c "
import json, sys
print(json.dumps({
    'app_token': '$base_token',
    'table_id': '$table_id',
    'record_id': '$record_id',
}))")"

  local data
  data="$(python3 -c "
import json
print(json.dumps({'fields': {'$field': '$pdf_url'}}, ensure_ascii=False))")"

  lark-cli base record update \
    --params "$payload" \
    --data "$data" \
    --as "$B2P_AS" >/dev/null 2>&1 || {
    log_warn "writeback failed (field may not be a text type, or field name mismatch)"
    return 1
  }
}
