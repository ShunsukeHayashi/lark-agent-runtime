#!/usr/bin/env bash
# lib/knowledge-graph.sh — Lark Wiki knowledge graph
#
# Commands:
#   larc kg build [--space-id <id>] [--depth <n>]
#       Traverse Lark Wiki space tree and store node graph in Lark Base.
#
#   larc kg query <concept> [--space-id <id>]
#       Keyword search over the graph; return matching nodes and their neighbors.
#
#   larc kg show <node_token>
#       Show node details and direct neighbors from local graph cache.
#
#   larc kg status
#       Show graph stats (node count, spaces indexed, last build time).

KG_TABLE_NAME="knowledge_graph"
KG_CACHE_FILE="${LARC_CACHE}/knowledge-graph.json"

cmd_kg() {
  local action="${1:-help}"; shift || true
  case "$action" in
    build)    _kg_build "$@" ;;
    query)    _kg_query "$@" ;;
    show)     _kg_show "$@" ;;
    status)   _kg_status "$@" ;;
    help|--help|-h) _kg_help ;;
    *)
      log_error "Unknown kg action: $action"
      _kg_help
      return 1
      ;;
  esac
}

_kg_help() {
  cat <<EOF

${BOLD}larc kg${RESET} — Lark Wiki knowledge graph

${BOLD}Commands:${RESET}
  ${CYAN}build${RESET} [--space-id <id>] [--depth <n>]
                        Traverse Wiki space and index node graph into Lark Base
  ${CYAN}query${RESET} <concept>    Keyword search over indexed graph; show matching nodes + neighbors
  ${CYAN}show${RESET} <node_token>  Show node details and neighbors from local cache
  ${CYAN}status${RESET}             Show graph stats (node count, last build, spaces indexed)

${BOLD}Examples:${RESET}
  larc kg build
  larc kg build --space-id 7627820424876838426 --depth 3
  larc kg query "expense"
  larc kg query "approval"
  larc kg show HW3Fw4kApiUNVPkZotPjqc8npXf
  larc kg status

${BOLD}Storage:${RESET}
  Graph nodes → Lark Base table '${KG_TABLE_NAME}'
  Local cache → ${KG_CACHE_FILE}

EOF
}

# ── Build ───────────────────────────────────────────────────────────────────

_kg_build() {
  local space_id="${LARC_WIKI_SPACE_ID:-}"
  local max_depth=4
  local dry_run=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --space-id)   space_id="$2";   shift 2 ;;
      --depth)      max_depth="$2";  shift 2 ;;
      --dry-run)    dry_run=true;    shift ;;
      *) log_warn "Unknown option: $1"; shift ;;
    esac
  done

  # Discover spaces if no space_id given
  if [[ -z "$space_id" ]]; then
    log_info "No --space-id given. Discovering wiki spaces..."
    local spaces_json
    spaces_json=$(lark-cli wiki spaces list \
      --jq '.data.items // []' 2>/dev/null || echo "[]")
    local n_spaces
    n_spaces=$(echo "$spaces_json" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
    if [[ "$n_spaces" -eq 0 ]]; then
      log_error "No wiki spaces found. Set LARC_WIKI_SPACE_ID in config or pass --space-id."
      return 1
    fi
    if [[ "$n_spaces" -eq 1 ]]; then
      space_id=$(echo "$spaces_json" | python3 -c "import json,sys; print(json.load(sys.stdin)[0]['space_id'])" 2>/dev/null)
      local space_name
      space_name=$(echo "$spaces_json" | python3 -c "import json,sys; print(json.load(sys.stdin)[0].get('name',''))" 2>/dev/null)
      log_info "Using space: $space_name ($space_id)"
    else
      echo "$spaces_json" | python3 -c "
import json, sys
spaces = json.load(sys.stdin)
print('Available spaces:')
for i, s in enumerate(spaces):
    print(f'  [{i}] {s.get(\"name\",\"?\")} — {s.get(\"space_id\",\"?\")}')
"
      log_error "Multiple spaces found. Pass --space-id to select one."
      return 1
    fi
  fi

  log_head "Knowledge graph build: space $space_id (max depth $max_depth)"

  # Traverse the wiki tree and collect nodes
  local all_nodes_json
  all_nodes_json=$(python3 - "$space_id" "$max_depth" <<'PY'
import sys, json, subprocess

space_id = sys.argv[1]
max_depth = int(sys.argv[2])

nodes = []

def traverse(parent_token, depth):
    if depth > max_depth:
        return
    params = {"space_id": space_id, "page_size": 50}
    if parent_token:
        params["parent_node_token"] = parent_token

    result = subprocess.run(
        ["lark-cli", "wiki", "nodes", "list",
         "--params", json.dumps(params),
         "--page-all"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        return

    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError:
        return

    items = data.get("data", {}).get("items") or []
    for item in items:
        token = item.get("node_token", "")
        node = {
            "node_token":    token,
            "space_id":      space_id,
            "title":         item.get("title", ""),
            "obj_type":      item.get("obj_type", ""),
            "parent_token":  parent_token or "",
            "depth":         str(depth),
            "has_child":     str(item.get("has_child", False)).lower(),
        }
        nodes.append(node)
        if item.get("has_child"):
            traverse(token, depth + 1)

traverse("", 1)
print(json.dumps(nodes))
PY
)

  local n_nodes
  n_nodes=$(echo "$all_nodes_json" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
  log_ok "Traversed $n_nodes nodes"

  if [[ "$n_nodes" -eq 0 ]]; then
    log_warn "No nodes found — check space_id or permissions"
    return 1
  fi

  # Save to local cache
  mkdir -p "$(dirname "$KG_CACHE_FILE")"
  echo "$all_nodes_json" | python3 -c "
import json, sys
nodes = json.load(sys.stdin)
cache = {
    'space_id': '${space_id}',
    'built_at': __import__('datetime').datetime.now(__import__('datetime').timezone.utc).isoformat(),
    'node_count': len(nodes),
    'nodes': nodes
}
print(json.dumps(cache, ensure_ascii=False, indent=2))
" > "$KG_CACHE_FILE"
  log_ok "Local cache saved: $KG_CACHE_FILE"

  if [[ "$dry_run" == "true" ]]; then
    log_info "Dry run — skipping Lark Base write"
    return 0
  fi

  # Write to Lark Base
  if [[ -n "$LARC_BASE_APP_TOKEN" ]]; then
    _kg_ensure_table
    local table_id
    table_id=$(_kg_get_table_id)
    [[ -z "$table_id" ]] && { log_error "Failed to get knowledge_graph table_id"; return 1; }

    log_info "Writing $n_nodes nodes to Lark Base table '$KG_TABLE_NAME'..."
    local written=0
    echo "$all_nodes_json" | python3 -c "
import json, sys, subprocess

nodes = json.load(sys.stdin)
table_id = '${table_id}'
base_token = '${LARC_BASE_APP_TOKEN}'

for node in nodes:
    record_json = json.dumps({
        'node_token':   node['node_token'],
        'space_id':     node['space_id'],
        'title':        node['title'],
        'obj_type':     node['obj_type'],
        'parent_token': node['parent_token'],
        'depth':        node['depth'],
        'has_child':    node['has_child'],
    }, ensure_ascii=False)
    subprocess.run(
        ['lark-cli', 'base', '+record-upsert',
         '--base-token', base_token,
         '--table-id', table_id,
         '--json', record_json],
        capture_output=True
    )

print(f'Wrote {len(nodes)} nodes')
" 2>/dev/null
    log_ok "Knowledge graph stored in Lark Base"
  else
    log_warn "LARC_BASE_APP_TOKEN not set — graph stored in local cache only"
  fi

  log_ok "Build complete. Run: larc kg query <concept>"
}

_kg_get_table_id() {
  lark-cli base +table-list \
    --base-token "$LARC_BASE_APP_TOKEN" \
    --jq ".data.tables[] | select(.name == \"${KG_TABLE_NAME}\") | .id" \
    2>/dev/null | head -1 || echo ""
}

_kg_ensure_table() {
  local table_id
  table_id=$(_kg_get_table_id)

  if [[ -z "$table_id" ]]; then
    log_info "Creating ${KG_TABLE_NAME} table in Lark Base..."
    table_id=$(lark-cli base +table-create \
      --base-token "$LARC_BASE_APP_TOKEN" \
      --name "$KG_TABLE_NAME" \
      --jq '.data.table.id // .data.table_id // .table_id' 2>/dev/null || echo "")
    [[ -z "$table_id" ]] && { log_error "Failed to create table"; return 1; }
    log_ok "Table created: $table_id"
  fi

  # Ensure fields (idempotent)
  for field_name in node_token space_id title obj_type parent_token depth has_child; do
    lark-cli base +field-create \
      --base-token "$LARC_BASE_APP_TOKEN" \
      --table-id "$table_id" \
      --json "{\"name\":\"$field_name\",\"type\":\"text\"}" \
      >/dev/null 2>&1 || true
  done
}

# ── Query ────────────────────────────────────────────────────────────────────

_kg_query() {
  local concept="${1:-}"
  shift || true
  local space_id="${LARC_WIKI_SPACE_ID:-}"
  local limit=10

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --space-id) space_id="$2"; shift 2 ;;
      --limit)    limit="$2";    shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -z "$concept" ]]; then
    log_error "Usage: larc kg query <concept>"
    return 1
  fi

  log_head "Knowledge graph query: \"$concept\""

  if [[ ! -f "$KG_CACHE_FILE" ]]; then
    log_error "No graph cache found. Run: larc kg build"
    return 1
  fi

  python3 - "$KG_CACHE_FILE" "$concept" "$limit" <<'PY'
import json, sys, re

cache_file, concept, limit = sys.argv[1], sys.argv[2].lower(), int(sys.argv[3])

with open(cache_file) as f:
    cache = json.load(f)

nodes = cache.get("nodes", [])
by_token = {n["node_token"]: n for n in nodes}

# Score each node: title match strength
def score(node):
    title = node.get("title", "").lower()
    words = re.split(r"\W+", concept)
    s = 0
    for w in words:
        if w and w in title:
            s += 2
    if concept in title:
        s += 5
    return s

scored = [(score(n), n) for n in nodes]
scored.sort(key=lambda x: -x[0])
matches = [(s, n) for s, n in scored if s > 0][:limit]

if not matches:
    print(f"\n  No nodes matching '{concept}' found in the graph.")
    print(f"  Try: larc kg build  (to refresh the index)")
    sys.exit(0)

BOLD = "\033[1m"; CYAN = "\033[0;36m"; RESET = "\033[0m"; DIM = "\033[2m"

print(f"\n  {BOLD}Matching nodes ({len(matches)} of {len(nodes)} indexed):{RESET}\n")
for s, node in matches:
    token = node["node_token"]
    title = node.get("title", "?")
    depth = node.get("depth", "?")
    obj   = node.get("obj_type", "?")
    print(f"  {BOLD}{title}{RESET}  {DIM}[{obj} · depth {depth} · score {s}]{RESET}")
    print(f"    token: {token}")

    # Show parent
    p_token = node.get("parent_token", "")
    if p_token and p_token in by_token:
        p_title = by_token[p_token].get("title", "?")
        print(f"    parent: {p_title}")

    # Show children
    children = [n for n in nodes if n.get("parent_token") == token]
    if children:
        child_titles = [c.get("title", "?") for c in children[:4]]
        suffix = f" … +{len(children)-4}" if len(children) > 4 else ""
        print(f"    children: {', '.join(child_titles)}{suffix}")
    print()

print(f"  Run: larc kg show <node_token>  for full neighbor details")
PY
}

# ── Show ─────────────────────────────────────────────────────────────────────

_kg_show() {
  local node_token="${1:-}"
  [[ -z "$node_token" ]] && { log_error "Usage: larc kg show <node_token>"; return 1; }

  if [[ ! -f "$KG_CACHE_FILE" ]]; then
    log_error "No graph cache found. Run: larc kg build"
    return 1
  fi

  python3 - "$KG_CACHE_FILE" "$node_token" <<'PY'
import json, sys

cache_file, target = sys.argv[1], sys.argv[2]

with open(cache_file) as f:
    cache = json.load(f)

nodes = cache.get("nodes", [])
by_token = {n["node_token"]: n for n in nodes}

if target not in by_token:
    print(f"  Node not found: {target}")
    print(f"  Run: larc kg build  (to refresh index)")
    sys.exit(1)

node = by_token[target]
BOLD = "\033[1m"; CYAN = "\033[0;36m"; RESET = "\033[0m"; DIM = "\033[2m"

print(f"\n  {BOLD}{node.get('title', '?')}{RESET}")
print(f"  token:      {target}")
print(f"  type:       {node.get('obj_type','?')}")
print(f"  depth:      {node.get('depth','?')}")
print(f"  space_id:   {node.get('space_id','?')}")

p_token = node.get("parent_token", "")
if p_token and p_token in by_token:
    print(f"\n  {BOLD}Parent:{RESET} {by_token[p_token].get('title','?')}  ({p_token})")

children = [n for n in nodes if n.get("parent_token") == target]
if children:
    print(f"\n  {BOLD}Children ({len(children)}):{RESET}")
    for c in children:
        print(f"    · {c.get('title','?')}  ({c['node_token']})")

siblings = [n for n in nodes
            if n.get("parent_token") == p_token
            and n["node_token"] != target] if p_token else []
if siblings:
    print(f"\n  {BOLD}Siblings ({len(siblings)}):{RESET}")
    for s in siblings[:6]:
        print(f"    · {s.get('title','?')}")
    if len(siblings) > 6:
        print(f"    … +{len(siblings)-6} more")
PY
}

# ── Status ───────────────────────────────────────────────────────────────────

_kg_status() {
  log_head "Knowledge graph status"

  if [[ ! -f "$KG_CACHE_FILE" ]]; then
    log_warn "No graph cache found. Run: larc kg build"
    return 0
  fi

  python3 - "$KG_CACHE_FILE" <<'PY'
import json, sys

with open(sys.argv[1]) as f:
    cache = json.load(f)

nodes = cache.get("nodes", [])
BOLD = "\033[1m"; RESET = "\033[0m"; GREEN = "\033[0;32m"

print(f"\n  {BOLD}Cache file:{RESET}  {sys.argv[1]}")
print(f"  {BOLD}Space ID:{RESET}    {cache.get('space_id','?')}")
print(f"  {BOLD}Built at:{RESET}    {cache.get('built_at','?')}")
print(f"  {BOLD}Nodes:{RESET}       {GREEN}{cache.get('node_count', len(nodes))}{RESET}")

depths = {}
for n in nodes:
    d = n.get("depth", "?")
    depths[d] = depths.get(d, 0) + 1
if depths:
    print(f"\n  {BOLD}Depth distribution:{RESET}")
    for d in sorted(depths, key=lambda x: int(x) if str(x).isdigit() else 99):
        print(f"    depth {d}: {depths[d]} nodes")

types = {}
for n in nodes:
    t = n.get("obj_type", "?")
    types[t] = types.get(t, 0) + 1
if types:
    print(f"\n  {BOLD}Node types:{RESET}")
    for t, c in sorted(types.items(), key=lambda x: -x[1]):
        print(f"    {t}: {c}")
PY
}
