---
name: lark-approval
version: 1.0.0
description: "Lark Approval API: manage approval instances and approval tasks."
metadata:
  requires:
    bins: ["lark-cli"]
  cliHelp: "lark-cli approval --help"
---

# approval (v4)

**CRITICAL — Before starting, MUST read [`../lark-shared/SKILL.md`](../lark-shared/SKILL.md) using the Read tool. It contains authentication and permission handling.**

## API Resources

```bash
lark-cli schema approval.<resource>.<method>   # Always check parameter structure before calling an API
lark-cli approval <resource> <method> [flags]  # Call the API
```

> **Important**: When using native APIs, always run `schema` first to inspect `--data` / `--params` structure. Do not guess field formats.

### instances

  - `get` — Get details of a single approval instance
  - `cancel` — Withdraw an approval instance
  - `cc` — CC an approval instance

### tasks

  - `approve` — Approve an approval task
  - `reject` — Reject an approval task
  - `transfer` — Transfer an approval task
  - `query` — Query the task list for a user

## Permissions

| Method | Required scope |
|--------|---------------|
| `instances.get` | `approval:instance:read` |
| `instances.cancel` | `approval:instance:write` |
| `instances.cc` | `approval:instance:write` |
| `tasks.approve` | `approval:task:write` |
| `tasks.reject` | `approval:task:write` |
| `tasks.transfer` | `approval:task:write` |
| `tasks.query` | `approval:task:read` |
