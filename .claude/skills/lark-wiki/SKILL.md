---
name: lark-wiki
version: 1.0.0
description: "Lark Wiki (Knowledge Base): manage knowledge spaces and document nodes. Create and query knowledge spaces, manage node hierarchy, organize documents and shortcuts in the knowledge base. Use when the user needs to find or create documents in the knowledge base, browse knowledge space structure, or move/copy nodes."
metadata:
  requires:
    bins: ["lark-cli"]
  cliHelp: "lark-cli wiki --help"
---

# wiki (v2)

**CRITICAL — Before starting, MUST use the Read tool to read [`../lark-shared/SKILL.md`](../lark-shared/SKILL.md). It contains authentication and permission handling.**

## Shortcuts (Prefer Using These First)

Shortcuts are high-level wrappers for common operations (`lark-cli wiki +<verb> [flags]`). Prefer Shortcuts when available.

| Shortcut | Description |
|----------|-------------|
| [`+node-create`](references/lark-wiki-node-create.md) | Create a wiki node with automatic space resolution |

## API Resources

```bash
lark-cli schema wiki.<resource>.<method>   # Check parameter structure before calling any API
lark-cli wiki <resource> <method> [flags]  # Call the API
```

> **Important**: When using native APIs, always run `schema` first to inspect `--data` / `--params` structure. Do not guess field formats.

### spaces

- `get` — Get knowledge space info
- `get_node` — Get knowledge space node info
- `list` — List knowledge spaces

### nodes

- `copy` — Create a copy of a knowledge space node
- `create` — Create a knowledge space node
- `list` — List child nodes of a knowledge space

## Permissions Table

| Method | Required Scope |
|--------|---------------|
| `spaces.get` | `wiki:space:read` |
| `spaces.get_node` | `wiki:node:read` |
| `spaces.list` | `wiki:space:retrieve` |
| `nodes.copy` | `wiki:node:copy` |
| `nodes.create` | `wiki:node:create` |
| `nodes.list` | `wiki:node:retrieve` |
