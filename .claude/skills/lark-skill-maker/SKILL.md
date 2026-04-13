---
name: lark-skill-maker
version: 1.0.0
description: "Create custom Skills for lark-cli. Use when the user wants to wrap Lark API operations into reusable Skills (wrapping atomic APIs or orchestrating multi-step flows)."
metadata:
  requires:
    bins: ["lark-cli"]
---

# Skill Maker

Create new Skills based on lark-cli. A Skill = a `SKILL.md` that teaches the AI to complete a task using CLI commands.

## Core CLI Capabilities

```bash
lark-cli <service> <resource> <method>          # Registered APIs
lark-cli <service> +<verb>                      # Shortcuts (high-level wrappers)
lark-cli api <METHOD> <path> [--data/--params]  # Any Lark OpenAPI raw call
lark-cli schema <service.resource.method>       # Check parameter definitions
```

Priority: Shortcuts > Registered APIs > `api` raw call.

## Researching APIs

```bash
# 1. Check existing API resources and Shortcuts
lark-cli <service> --help

# 2. Check parameter definitions
lark-cli schema <service.resource.method>

# 3. For unregistered APIs, use api to call directly
lark-cli api GET /open-apis/vc/v1/rooms --params '{"page_size":"50"}'
lark-cli api POST /open-apis/vc/v1/rooms/search --data '{"query":"5F"}'
```

If the above commands cannot cover the requirement (no corresponding registered API or Shortcut in the CLI), use [lark-openapi-explorer](../lark-openapi-explorer/SKILL.md) to dig native OpenAPI endpoints from the official Lark documentation, get the complete method/path/params/permissions, then complete the task via `lark-cli api` raw calls.

Determine which APIs, parameters, and scopes are needed through the above process.

## SKILL.md Template

Place the file at `skills/lark-<name>/SKILL.md`:

```markdown
---
name: lark-<name>
version: 1.0.0
description: "<Feature description>. Use when the user needs <trigger scenario>."
metadata:
  requires:
    bins: ["lark-cli"]
---


# <Title>

> **Prerequisites:** First read [`../lark-shared/SKILL.md`](../lark-shared/SKILL.md).

## Commands

\```bash
# Single-step operation
lark-cli api POST /open-apis/xxx --data '{...}'

# Multi-step orchestration: describe data flow between steps
# Step 1: ...（record the returned xxx_id）
# Step 2: use the xxx_id from Step 1
\```

## Permissions

| Operation | Required Scope |
|-----------|---------------|
| xxx | `scope:name` |
```

## Key Principles

- **Description drives triggering** — Include feature keywords + "Use when the user needs..."
- **Authentication** — Specify required scopes; use `lark-cli auth login --domain <name>` for login
- **Security** — Confirm user intent before write operations; suggest `--dry-run` for previews
- **Orchestration** — Describe data flow between steps, failure rollback, and steps that can be parallelized
