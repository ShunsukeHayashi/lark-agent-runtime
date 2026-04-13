---
name: lark-task
version: 1.0.0
description: "Lark Tasks: manage tasks and tasklists. Create to-do tasks, view and update task status, break down subtasks, organize tasklists, assign collaborators. Use when the user needs to create to-dos, view task lists, track task progress, manage project tasklists, or assign tasks to others."
metadata:
  requires:
    bins: ["lark-cli"]
  cliHelp: "lark-cli task --help"
---

# task (v2)

**CRITICAL — Before starting, MUST use the Read tool to read [`../lark-shared/SKILL.md`](../lark-shared/SKILL.md). It contains authentication and permission handling.**

> **Search tip**: If the user's query only specifies a task name (e.g., "finish task Lobster-1"), use `+get-my-tasks --query "Lobster-1"` to search directly (without `--complete` to search both incomplete and complete tasks simultaneously).
> **User identity resolution**: Under user identity, if the user mentions "me" (e.g., "assigned to me," "created by me"), default to fetching the current logged-in user's `open_id` as the corresponding parameter value.
> **Terminology**: If the user mentions "todo," consider whether they mean "task" and prefer using this Skill's commands.
> **Friendly output**: When outputting task (or tasklist) results to the user, extract and include the `url` field (task link) from the command response so the user can click directly to view details.

> **Create/Update notes**:
> 1. `repeat_rule` (recurrence rule) and `reminder` can only be set when `due` (due time) is set.
> 2. If both `start` (start time) and `due` (due time) are set, start time must be ≤ due time.
> 3. When using `tenant_access_token` (bot identity), task members cannot be added across tenants.

> **Query notes**:
> 1. When displaying task details, if rendering assignee, creator, or other person fields, in addition to showing the `id` (e.g., open_id), always try to fetch and display the person's real name (e.g., via the contact skill) so the user can more easily identify them.
> 2. When displaying task details, render date/time fields (creation time, due time, etc.) in the local timezone (format: 2006-01-02 15:04:05).

> **Task GUID definition**:
> The `guid` used to update/operate tasks in Task OpenAPI is the task's globally unique identifier (GUID), not the client-displayed task number (e.g., `t104121` / `suite_entity_num`).
> For Feishu task applinks (e.g., `.../client/todo/task?guid=...`), use the `guid` parameter from the URL query as the task guid.

## Shortcuts

- [`+create`](./references/lark-task-create.md) — Create a task
- [`+update`](./references/lark-task-update.md) — Update a task
- [`+comment`](./references/lark-task-comment.md) — Add a comment to a task
- [`+complete`](./references/lark-task-complete.md) — Complete a task
- [`+reopen`](./references/lark-task-reopen.md) — Reopen a task
- [`+assign`](./references/lark-task-assign.md) — Assign or remove members from a task
- [`+followers`](./references/lark-task-followers.md) — Manage task followers
- [`+reminder`](./references/lark-task-reminder.md) — Manage task reminders
- [`+get-my-tasks`](./references/lark-task-get-my-tasks.md) — List tasks assigned to me
- [`+tasklist-create`](./references/lark-task-tasklist-create.md) — Create a tasklist and batch add tasks
- [`+tasklist-task-add`](./references/lark-task-tasklist-task-add.md) — Add existing tasks to a tasklist
- [`+tasklist-members`](./references/lark-task-tasklist-members.md) — Manage tasklist members

## API Resources

```bash
lark-cli schema task.<resource>.<method>   # Check parameter structure before calling any API
lark-cli task <resource> <method> [flags]  # Call the API
```

> **Important**: When using native APIs, always run `schema` first to inspect `--data` / `--params` structure. Do not guess field formats.

### tasks

  - `create` — Create a task
  - `delete` — Delete a task
  - `get` — Get task details
  - `list` — List tasks
  - `patch` — Update a task

### tasklists

  - `add_members` — Add tasklist members
  - `create` — Create a tasklist
  - `delete` — Delete a tasklist
  - `get` — Get tasklist details
  - `list` — List tasklists
  - `patch` — Update a tasklist
  - `remove_members` — Remove tasklist members
  - `tasks` — Get tasks in a tasklist

### subtasks

  - `create` — Create a subtask
  - `list` — Get subtask list for a task

### members

  - `add` — Add task members
  - `remove` — Remove task members

### sections

  - `create` — Create a custom section
  - `delete` — Delete a custom section
  - `get` — Get custom section details
  - `list` — List custom sections
  - `patch` — Update a custom section
  - `tasks` — Get tasks in a custom section

## Permissions Table

| Method | Required Scope |
|--------|---------------|
| `tasks.create` | `task:task:write` |
| `tasks.delete` | `task:task:write` |
| `tasks.get` | `task:task:read` |
| `tasks.list` | `task:task:read` |
| `tasks.patch` | `task:task:write` |
| `tasklists.add_members` | `task:tasklist:write` |
| `tasklists.create` | `task:tasklist:write` |
| `tasklists.delete` | `task:tasklist:write` |
| `tasklists.get` | `task:tasklist:read` |
| `tasklists.list` | `task:tasklist:read` |
| `tasklists.patch` | `task:tasklist:write` |
| `tasklists.remove_members` | `task:tasklist:write` |
| `tasklists.tasks` | `task:tasklist:read` |
| `subtasks.create` | `task:task:write` |
| `subtasks.list` | `task:task:read` |
| `members.add` | `task:task:write` |
| `members.remove` | `task:task:write` |
| `sections.create` | `task:section:write` |
| `sections.delete` | `task:section:write` |
| `sections.get` | `task:section:read` |
| `sections.list` | `task:section:read` |
| `sections.patch` | `task:section:write` |
| `sections.tasks` | `task:section:read` |
