# addness +work-start

Start work. Detect goal, set to `IN_PROGRESS`, and display full context.

## Commands

```bash
# Auto-detect from git branch (recommended)
addness-cli work start

# Direct goal ID
addness-cli work start --goal <GOAL_ID>

# With org specified
addness-cli work start --goal <GOAL_ID> --org personal
addness-cli work start --goal <GOAL_ID> --org banana
```

## What it does

1. Extracts GOAL_ID from branch name (`goal/<UUID>/description`)
2. `addness goal update --status IN_PROGRESS`
3. Displays full context via `addness goal get --with-deliverable --with-comment`

## Output (JSON)

```json
{
  "children": [],
  "comments": [...],
  "deliverables": [...],
  "goal": {
    "id": "...",
    "title": "Goal title",
    "status": "IN_PROGRESS",
    "description": "Done condition",
    "parentId": "..."
  }
}
```

## If goal detection fails

```bash
# List your goals
addness-cli -- goal list --assigned-to me --json

# Then specify directly
addness-cli work start --goal <GOAL_ID>
```

## Branch naming convention

```bash
git checkout -b "goal/<GOAL_ID>/description"
# Example: git checkout -b "goal/26ff19d1-.../implement-login"
```

> Requires at least one commit. Does not work on empty repos.

## References

- [addness SKILL.md](../SKILL.md)
- [+work-done](./addness-work-done.md) — Complete work
