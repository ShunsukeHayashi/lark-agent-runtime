---
name: lark-workflow-standup-report
version: 1.0.0
description: "Schedule and to-do summary: orchestrates calendar +agenda and task +get-my-tasks to generate a schedule and incomplete task summary for a specified date. Suitable for understanding today's/tomorrow's/this week's plans."
metadata:
  requires:
    bins: ["lark-cli"]
---

# Schedule and To-Do Summary Workflow

**CRITICAL — Before starting, MUST use the Read tool to read [`../lark-shared/SKILL.md`](../lark-shared/SKILL.md). It contains authentication and permission handling.**

## Applicable Scenarios

- "What's on my schedule today" / "Today's schedule and to-dos"
- "What meetings do I have tomorrow" / "Tomorrow's schedule and incomplete tasks"
- "What do I need to do today" / "Morning briefing summary"
- "Start-of-day summary" / "standup report"
- "What's left on my schedule this week"

## Prerequisites

Supports **user identity only**. Ensure authorization before running:

```bash
lark-cli auth login --domain calendar,task
```

## Workflow

```
{date} ─┬─► calendar +agenda [--start/--end] ──► schedule list (meetings/events)
        └─► task +get-my-tasks [--due-end]    ──► incomplete to-do list
                    │
                    ▼
              AI summary (time conversion + conflict detection + sorting) ──► summary
```

### Step 1: Get Schedule

```bash
# Today (default — no extra params needed)
lark-cli calendar +agenda

# Specified date range (MUST use ISO 8601 format; "tomorrow" and other natural language not supported)
lark-cli calendar +agenda --start "2026-03-26T00:00:00+08:00" --end "2026-03-26T23:59:59+08:00"
```

> **Note**: `--start` / `--end` only support ISO 8601 format (e.g., `2026-01-01` or `2026-01-01T15:04:05+08:00`) and Unix timestamps — `"tomorrow"`, `"next monday"`, and other natural language are **not supported**. The AI must calculate the target date from the current date.

Output includes: event_id, summary, start_time (with timestamp + timezone), end_time, free_busy_status, self_rsvp_status.

### Step 2: Get Incomplete To-Dos

```bash
# Default: return incomplete tasks assigned to the current user (up to 20)
lark-cli task +get-my-tasks

# Only tasks due before a specified date (recommended for summary scenarios to reduce data volume)
lark-cli task +get-my-tasks --due-end "2026-03-27T23:59:59+08:00"

# Get all (when more than 20 tasks)
lark-cli task +get-my-tasks --page-all
```

> **Note**: Without filter conditions, a large number of historical to-dos may be returned (tested at 30+, 100KB+), potentially exceeding context limits. For summary scenarios, recommended approach:
> - Use `--due-end` to filter tasks due before the target date
> - If tasks without due dates are also needed, omit the filter — but in the AI summary, only show **tasks created within the past 30 days** and fold the rest as "N other historical to-dos"

### Step 3: AI Summary

Integrate results from Steps 1 and 2 and output in the following structure:

```
## {Date} Summary ({YYYY-MM-DD Day of week})

### Schedule
| Time | Event | Organizer | Status |
|------|-------|-----------|--------|
| 09:00-10:00 | Product Requirements Review | Zhang San | Accepted |
| 14:00-15:00 | Technical Design Discussion | Li Si | Pending confirmation |

### To-Do Items
- [ ] {task_summary} (due: {due_date})
- [ ] {task_summary}

### Summary
- Total {n} meetings, {m} to-do items
- Conflict alerts: {list overlapping events}
- Free slots: {free_slots} (inferred from schedule)
```

**Data processing rules:**

1. **Time conversion**: API returns Unix timestamps; convert to `HH:mm` format based on the `timezone` field (usually `Asia/Shanghai`)
2. **RSVP status mapping**:
   | API Value | Display Text |
   |-----------|-------------|
   | `accept` | Accepted |
   | `decline` | Declined |
   | `needs_action` | Pending confirmation |
   | `tentative` | Tentative |
3. **Schedule sorting**: Sort by start time ascending
4. **Conflict detection**: After sorting by time, check if adjacent events overlap (previous `end_time` > next `start_time`); if so, list conflicting pairs in the summary
5. **Declined events**: Mark as "Declined" but do not count toward busy time or conflict detection
6. **To-do sorting**: Sort by due time ascending; mark overdue items; items without due dates go last

## Permissions Table

| Command | Required Scope |
|---------|---------------|
| `calendar +agenda` | `calendar:calendar.event:read` |
| `task +get-my-tasks` | `task:task:read` |

## References

- [lark-shared](../lark-shared/SKILL.md) — Authentication, permissions (required reading)
- [lark-calendar](../lark-calendar/SKILL.md) — Detailed usage of `+agenda`
- [lark-task](../lark-task/SKILL.md) — Detailed usage of `+get-my-tasks`
