# addness +goal-create

Create a new goal. Always use `--parent` since only one root goal per org is allowed.

## Commands

```bash
# Create as sub-goal (--parent required)
addness-cli -- goal create \
  --title "New goal title" \
  --parent <PARENT_GOAL_ID>

# With description
addness-cli -- goal create \
  --title "Title" \
  --parent <PARENT_GOAL_ID> \
  --description "Done condition / details"

# JSON output
addness-cli -- goal create \
  --title "Title" \
  --parent <PARENT_GOAL_ID> \
  --json
```

## Root goal IDs per org

| Org | Root goal | Root goal ID |
|-----|-----------|-------------|
| personal | AIエージェントと共に、みやびAIを持続可能な事業として確立する | `dc2b48cd-65ab-48df-a19f-79a8d1efa619` |
| banana | （バナナ org root） | `4ed90c9f-c5bd-4659-a0c4-b6b0922c2626` |

## Creation flow

1. Check parent goal: `addness-cli -- goal list --depth 3 --json`
2. Create goal: `addness-cli -- goal create --title "..." --parent <ID>`
3. Start work on new goal: `addness-cli work start --goal <new ID>`

## Notes

- Only one root goal per org (API constraint)
- Sub-goals can be created at any depth
- Recommended to immediately `work start` after creating a goal

## References

- [addness SKILL.md](../SKILL.md)
- [+work-start](./addness-work-start.md)
