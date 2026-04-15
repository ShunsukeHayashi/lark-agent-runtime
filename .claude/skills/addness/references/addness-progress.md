# addness +progress

Record a progress comment mid-work. Optionally update status at the same time.

## Commands

```bash
# Progress comment only
addness-cli progress --message "Design done, starting implementation"

# With status update
addness-cli progress --message "50% complete" --status IN_PROGRESS

# Direct goal ID
addness-cli progress --message "Progress report" --goal <GOAL_ID>

# JSON output
addness-cli progress --message "..." --json
```

## When to use

- Leaving a mid-task checkpoint during long work
- Recording a decision change or problem discovery
- AI agent logging steps while working through a multi-step task

## Status values

| Value | Meaning |
|-------|---------|
| `NOT_STARTED` | Not started |
| `IN_PROGRESS` | In progress (default) |
| `COMPLETED` | Completed (use `work done` for final completion) |
| `CANCELLED` | Cancelled |

## References

- [addness SKILL.md](../SKILL.md)
- [+work-done](./addness-work-done.md) — Final completion record
