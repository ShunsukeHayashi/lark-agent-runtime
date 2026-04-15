---
name: addness
version: 1.0.0
description: "Addness goal management: start work, record progress, report completion, create goals, check summary. Use when an OpenClaw/AI agent needs to link coding work with goal tracking. Frontend UI for viewing; CLI for writing."
metadata:
  requires:
    bins: ["addness-cli", "addness"]
  cliHelp: "addness-cli help"
---

# Addness Goal Management

## Core Design

**Frontend UI = view & review**
**addness-cli = AI agent / terminal writes**

Addness is a goal management OS built for working alongside AI. Goals are managed as a tree. OpenClaw agents use this CLI to record progress in real time.

## Two orgs

| Alias | Org name | Purpose |
|-------|----------|---------|
| `personal` | ハヤシシュンスケ | Personal projects (online course generator, etc.) |
| `banana` | バナナ | Team projects (AI marketing team, external dev, etc.) |

> **⚠️ ABSOLUTE RULE: Never write to `banana` org**
> The banana org is a shared team org managed by other members.
> AI agents must NOT create, update, complete, or delete goals in `banana` org.
> Read-only access (`summary --org banana`, etc.) is allowed.

## Shortcuts

- [`+work-start`](./references/addness-work-start.md) — Start work: detect goal → IN_PROGRESS → show context
- [`+work-done`](./references/addness-work-done.md) — Complete work: COMPLETED + progress log + PR record
- [`+progress`](./references/addness-progress.md) — Record a progress comment
- [`+pr`](./references/addness-pr.md) — Record PR URL on a goal (API bug workaround)
- [`+goal-create`](./references/addness-goal-create.md) — Create a new goal
- [`+summary`](./references/addness-summary.md) — Check progress summary
- [`+context`](./references/addness-context.md) — Get full context of current goal

## Standard AI Agent Workflow

### 1. On work start (required)

```bash
# Auto-detect from git branch (branch naming: goal/<UUID>/description)
addness-cli work start

# Direct goal ID
addness-cli work start --goal <GOAL_ID>

# JSON context for programmatic use
addness-cli context --goal <GOAL_ID>
```

`work start` does all of:
1. Extract GOAL_ID from git branch
2. Set goal status to `IN_PROGRESS`
3. Display full context: goal + deliverables + comments + siblings

### 2. During work (as needed)

```bash
addness-cli progress --message "Design done, starting implementation"
addness-cli progress --message "API tests passing" --status IN_PROGRESS
```

### 3. On work completion (required)

```bash
# Message only
addness-cli work done --message "Implementation complete"

# With PR link
addness-cli work done --message "Implementation complete" --pr https://github.com/org/repo/pull/42
```

`work done` does all of:
1. `link progress --status COMPLETED` — post completion comment
2. `goal update --status COMPLETED` — finalize status
3. If `--pr` given: record PR URL as comment (workaround for link pr bug)

## Full Command Reference

### work start
```bash
addness-cli work start                        # Auto-detect from branch
addness-cli work start --goal <ID>            # Direct ID
addness-cli work start --org personal         # Specify org
```

### work done
```bash
addness-cli work done --message "<summary>"
addness-cli work done --message "<summary>" --pr <PR_URL>
addness-cli work done --message "<summary>" --goal <ID>  # No-branch environment
```

### progress (intermediate record)
```bash
addness-cli progress --message "<progress>"
addness-cli progress --message "<progress>" --status IN_PROGRESS
addness-cli progress --message "<progress>" --goal <ID>
```

### pr (PR record / link pr bug workaround)
```bash
addness-cli pr --url <PR_URL>
addness-cli pr --url <PR_URL> --message "<description>"
addness-cli pr --url <PR_URL> --goal <ID>
# Positional argument also works
addness-cli pr https://github.com/org/repo/pull/42
```

### context (full context for AI agent)
```bash
addness-cli context                   # Auto-detect from branch
addness-cli context --goal <ID>       # Direct ID
addness-cli context --goal <ID> --json
```
Output: `{goal: {goal, children, comments, deliverables}, siblings: [...]}`

### summary
```bash
addness-cli summary                   # Current org summary
addness-cli summary --all             # Both orgs (personal + banana)
addness-cli summary --org personal
addness-cli summary --org banana
addness-cli summary --all --json      # JSON output
```
Note: `completed_actual` field is the accurate count (fixes addness bug).

### search (with status filter)
```bash
addness-cli search "course"
addness-cli search "marketing" --status IN_PROGRESS
addness-cli search "dev" --org banana --json
```

### org management
```bash
addness-cli org list              # List orgs
addness-cli org current           # Current org
addness-cli org personal          # Switch to ハヤシシュンスケ org
addness-cli org banana            # Switch to バナナ org
addness-cli org switch <UUID>     # Switch by UUID
```

### pass-through (raw addness commands)
```bash
addness-cli -- goal list --depth 5 --json
addness-cli -- goal create --title "New goal" --parent <ID>
addness-cli -- goal get <ID> --with-deliverable --with-comment --json
addness-cli -- comment create --goal <ID> --body "Comment"
```

## Goal Operations (via pass-through)

### Create goal
```bash
# Always use --parent (only one root goal per org)
addness-cli -- goal create --title "Title" --parent <PARENT_ID>
addness-cli -- goal create --title "Title" --parent <PARENT_ID> --description "Done condition"
```

### Search / browse goals
```bash
addness-cli -- goal list --depth 5 --json
addness-cli -- goal list --status IN_PROGRESS --json
addness-cli -- goal list --assigned-to me --json
addness-cli -- goal get <ID> --with-deliverable --with-comment --json
addness-cli -- goal tree <ID> --json
addness-cli -- goal children <ID> --json
addness-cli -- goal siblings <ID> --json
```

## Status values

| Value | Meaning |
|-------|---------|
| `NOT_STARTED` | Not started |
| `IN_PROGRESS` | In progress |
| `COMPLETED` | Completed |
| `CANCELLED` | Cancelled |

Note: Internally `COMPLETED` is managed as `isCompleted: true` with `status: NONE`.
`addness-cli work done` handles this correctly.

## Branch naming convention

```
goal/<GOAL_ID>/description
Example: goal/26ff19d1-5e3c-461b-b175-b54f36aef3c4/implement-login
```

- Requires at least one commit in the repository
- `addness-cli work start` auto-extracts GOAL_ID

## Known bugs (handled by addness-cli)

| Bug | Symptom | Fix |
|-----|---------|-----|
| `addness link pr` | Always 400 error | `addness-cli pr` records as comment instead |
| `addness summary` completed count | Does not count `isCompleted=true` | `addness-cli summary` corrects with jq |
| `addness detect-goal` | Fails on empty repos | `addness-cli` custom implementation |

## OpenClaw Agent Instructions

1. **Always call `addness-cli work start` when beginning work** (context load + status update)
2. **If goal detection fails, use `--goal <ID>` directly**
3. **Always call `addness-cli work done --message "..."` when work completes**
4. **When creating a PR, pass `--pr <URL>` to `work done` or call `addness-cli pr --url <URL>` separately**
5. If goal ID unknown: `addness-cli -- goal list --assigned-to me --json`
6. Check full summary: `addness-cli summary --all`
