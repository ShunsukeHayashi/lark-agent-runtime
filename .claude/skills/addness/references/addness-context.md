# addness +context

Get full context of current working goal. For AI agents to understand the situation before starting.

## Commands

```bash
# Auto-detect from branch
addness-cli context

# Direct goal ID
addness-cli context --goal <GOAL_ID>

# JSON output (for AI processing)
addness-cli context --goal <GOAL_ID> --json
```

## Output structure

```json
{
  "goal": {
    "goal": {
      "id": "...",
      "title": "Goal title",
      "description": "Done condition",
      "status": "IN_PROGRESS",
      "isCompleted": false,
      "parentId": "..."
    },
    "children": [...],     // child goals
    "comments": [...],     // comment history
    "deliverables": [...]  // deliverables
  },
  "siblings": [           // sibling goals (same parent)
    {
      "id": "...",
      "title": "Sibling goal name",
      "status": "NOT_STARTED",
      "deliverables": [...]
    }
  ]
}
```

## Difference from `work start`

| | `work start` | `context` |
|--|-------------|---------|
| Status update | Sets `IN_PROGRESS` | No update |
| Purpose | Beginning work | Read-only info |
| Siblings | Not shown | Shown |

## When to use

- Resuming work and need to understand current state
- Checking relationship to sibling goals
- Need context without changing status

## References

- [addness SKILL.md](../SKILL.md)
- [+work-start](./addness-work-start.md)
