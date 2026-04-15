# addness +pr

Record a PR URL on a goal. Workaround for `addness link pr` API bug — records as comment instead.

## Commands

```bash
# URL only
addness-cli pr --url https://github.com/org/repo/pull/42

# With description
addness-cli pr --url https://github.com/org/repo/pull/42 --message "Login feature PR"

# Direct goal ID
addness-cli pr --url <URL> --goal <GOAL_ID>

# Positional argument also works
addness-cli pr https://github.com/org/repo/pull/42

# JSON output
addness-cli pr --url <URL> --json
```

## How it works internally

`addness link pr` always returns `400 Bad Request: invalid character '-' in numeric literal`.
This command uses `addness comment create` to record as a comment instead:

```
PR: https://github.com/org/repo/pull/42

<message if provided>
```

Appears as a comment in the frontend UI.

## When to use

- Recording a PR separately from `work done`
- Linking multiple PRs to one goal
- Retroactively recording a PR after creation

## References

- [addness SKILL.md](../SKILL.md)
- [+work-done](./addness-work-done.md) — Can also record PR via `--pr` option
