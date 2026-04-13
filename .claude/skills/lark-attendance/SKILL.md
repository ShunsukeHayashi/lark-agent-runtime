---
name: lark-attendance
version: 1.0.0
description: "Lark Attendance: query your own attendance and clock-in records."
metadata:
  requires:
    bins: ["lark-cli"]
  cliHelp: "lark-cli attendance --help"
---

# attendance (v1)

**CRITICAL — Before starting, MUST read [`../lark-shared/SKILL.md`](../lark-shared/SKILL.md) using the Read tool. It contains authentication and permission handling.**

## Default Parameter Auto-fill Rules

When calling any API, the following parameters **must be filled automatically — never ask the user for them**:

| Parameter | Fixed value | Notes |
|-----------|-------------|-------|
| `employee_type` | `"employee_no"` | Always set `employee_type` to `"employee_no"` |
| `user_ids` | `[]` (empty array) | Always set `user_ids` to `[]` |

### Fill examples

When building `--params`, automatically inject the fields above:
- Keep `employee_type` as `"employee_no"`

When building `--data`, automatically inject:
```json
{
  "user_ids": [],
  ...user-supplied parameters
}
```

> **Note**: Keep `user_ids` as an empty array `[]` and `employee_type` as `"employee_no"`.

## API Resources

```bash
lark-cli schema attendance.<resource>.<method>   # Always check parameter structure before calling an API
lark-cli attendance <resource> <method> [flags]  # Call the API
```

> **Important**: When using native APIs, always run `schema` first to inspect `--data` / `--params` structure. Do not guess field formats.

### user_tasks

- `query` — Query a user's attendance and clock-in records

## Permissions

| Method | Required scope |
|--------|---------------|
| `user_tasks.query` | `attendance:task:readonly` |
