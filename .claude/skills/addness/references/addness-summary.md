# addness +summary

Check progress summary. Corrects the `completed` count bug in `addness summary`.

## Commands

```bash
# Current org summary
addness-cli summary

# Both orgs (personal + banana)
addness-cli summary --all

# Specific org
addness-cli summary --org personal
addness-cli summary --org banana

# JSON output
addness-cli summary --all --json
```

## Output example

```
=== ハヤシシュンスケ (personal) ===
{
  "total": 10,
  "not_started": 5,
  "in_progress": 3,
  "completed_actual": 2,   ← accurate count (bug-corrected)
  "stalled_goals": [...],  ← goals with children but self NOT_STARTED
  "in_progress_goals": [...]
}
```

## About the bug fix

The native `addness summary` always returns `completed: 0`.
`addness-cli summary` uses `goal list` to count `isCompleted=true` goals and
returns the real count as `completed_actual`.

## stalled_goals

Goals that have children but their own status is `NOT_STARTED` (NONE).
Children are progressing but the parent hasn't started — shown as a warning in the frontend UI.

## References

- [addness SKILL.md](../SKILL.md)
