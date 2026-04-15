# addness +work-done

Record work completion. Update goal to `COMPLETED`, log progress comment, optionally record PR.

## Commands

```bash
# Basic
addness-cli work done --message "Implementation complete. Tests passing."

# With PR
addness-cli work done --message "Implementation complete" --pr https://github.com/org/repo/pull/42

# Direct goal ID (no-branch environment)
addness-cli work done --message "Done" --goal <GOAL_ID>

# JSON output
addness-cli work done --message "Done" --json
```

## What it does

1. `addness link progress --status COMPLETED --message "..."` — post completion comment
2. `addness goal update --status COMPLETED` — set isCompleted=true
3. If `--pr` given: record PR URL as comment (workaround for `addness link pr` API bug)

## Message guidelines

Good completion messages include:
- Summary of what was done
- Test results (pass/skip/etc.)
- Remaining items if any

Example:
```bash
addness-cli work done \
  --message "Login feature complete. All unit tests passing. Refresh token deferred to next task." \
  --pr https://github.com/miyabi/app/pull/15
```

## Notes

- `addness link pr` has an API bug and cannot be used. This wrapper records as a comment instead.
- `summary`'s `completed_actual` reflects the count once `isCompleted=true` is set.
- Completed goals appear as done in the frontend UI.

## References

- [addness SKILL.md](../SKILL.md)
- [+work-start](./addness-work-start.md) — Start work
- [+pr](./addness-pr.md) — Record PR separately
