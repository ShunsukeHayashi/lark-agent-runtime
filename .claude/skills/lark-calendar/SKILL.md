---
name: lark-calendar
version: 1.0.0
description: "Lark Calendar: comprehensive management of calendars and events (meetings). Core scenarios: view/search events, create/update events, manage attendees, query free/busy status and suggest available time slots, query/search/book meeting rooms. IMPORTANT: for scheduling meetings or finding/booking rooms, you MUST first read references/lark-calendar-schedule-meeting.md. Prefer Shortcuts: +agenda (today's schedule overview), +create (create event, invite attendees, optionally book room), +freebusy (query primary calendar free/busy and RSVP status), +rsvp (reply to event invitations)."
metadata:
  requires:
    bins: ["lark-cli"]
  cliHelp: "lark-cli calendar --help"
---

# calendar (v4)

**CRITICAL — Before starting, MUST use the Read tool to read [`../lark-shared/SKILL.md`](../lark-shared/SKILL.md). It contains authentication and permission handling.**
**CRITICAL — Before executing any Shortcut, you MUST first use the Read tool to read its corresponding reference document. Do not blindly invoke commands.**
**CRITICAL — Whenever the user's intent involves scheduling a meeting/event or finding/searching meeting rooms, the FIRST step MUST be to read [`references/lark-calendar-schedule-meeting.md`](references/lark-calendar-schedule-meeting.md). Do not call any API or Shortcut before reading this file.**
**CRITICAL — Terminology note: When users casually say things like "set up a calendar" or "check today's calendar," they usually mean creating or querying Events, not the Calendar container itself. Automatically map colloquial "calendar" intent to event operations (e.g., `+create`, `+agenda`).**

**Date and time inference rules:**
- **Week definition**: Monday is the first day of the week, Sunday is the last. When calculating relative dates like "next Monday," always calculate based on the current real date.
- **Day range**: When the user says "tomorrow" or "today," the time range should default to cover the entire day. Do NOT narrow the query range arbitrarily.
- **Historical time constraint**: Cannot book a time that has completely passed. The only exception is events that span the current moment (started in the past but end in the future).

## Core Scenarios

### 1. Schedule a Meeting / Search for Available Rooms

**BLOCKING REQUIREMENT: Whenever the user's intent includes "schedule a meeting" or "find/search for available meeting rooms," you MUST immediately stop all other reasoning and use the Read tool to fully read [`references/lark-calendar-schedule-meeting.md`](references/lark-calendar-schedule-meeting.md). Absolutely no event creation or room query operations are permitted before reading that file.**

**CRITICAL: You MUST strictly follow the workflow defined in that document. When handling this scenario, act as a "smart assistant," not a "form filler." Fill in sensible defaults first; only ask the user when there is a time conflict, ambiguous time semantics, or the result cannot be uniquely determined.**

**CRITICAL: Execution order is fixed: fill defaults → check whether time is explicit → branch to "explicit time" or "ambiguous/no time." Do not skip steps.**

**CRITICAL: For explicit time with room needed, run `+room-find` before `+freebusy`. For ambiguous or no time, run `+suggestion` first; then `+room-find` with the suggested time blocks if rooms are needed.**

**CRITICAL: When the user says "find a room," "look for a room," or "recommend a common room," the default intent is to check room availability — not to list room resources, and certainly not to analyze historical events for statistics. Full rules are in [lark-calendar-schedule-meeting.md](references/lark-calendar-schedule-meeting.md).**

**BLOCKING REQUIREMENT: Even if the user's core request is "find a room," if no explicit start/end time is provided, calling `+room-find` directly is absolutely prohibited. You MUST enter the [ambiguous/no time] branch, call `+suggestion` to get candidate time blocks, and then pass those blocks to `+room-find`.**

**BLOCKING REQUIREMENT: Whenever choosing between time slots or room options (ambiguous time, no time, or room needed), you MUST present candidate options to the user and wait for explicit confirmation before calling `+create`. Never make decisions on behalf of the user.**

## Core Concepts

- **Calendar**: A container for events. Each user has one primary calendar and can create or subscribe to shared calendars.
- **Event**: A single item in a calendar with start/end times, location, title, attendees, etc. Supports one-time and recurring events, following the RFC 5545 iCalendar standard.
- **All-day Event**: An event that occupies a date without a specific start/end time. The end date is inclusive.
- **Event Instance**: A concrete time instance of an event. Regular and exception events correspond to 1 instance; recurring events correspond to N instances. When querying by time range, the instance view can expand recurring events into individual instances for accurate timeline display and management.
- **Recurrence Rule (Rrule)**: Defines the repetition pattern, e.g., `FREQ=DAILY;UNTIL=20230307T155959Z;INTERVAL=14` means repeat every 14 days.
- **Exception Event**: An occurrence in a recurring series that differs from the original pattern.
- **Attendee**: A participant in an event — can be a user, group, meeting room resource, or external email. Each attendee has an independent RSVP status.
- **RSVP Status**: An attendee's reply to an event invitation (accept/decline/tentative).
- **FreeBusy**: Query a user's busy/free status for a given time range, used for scheduling coordination.
- **Meeting Room (Room)**: "Room" means "meeting room." Map "room" to meeting room and related operations when interpreting user intent.
- **Time Block / Time Slot**: A specific, continuous time span (e.g., `14:00–15:00`). Distinct from a broad time range like "this afternoon" or "next week." Booking and room-finding operations require a definite time block, not a vague time range.

## Resource Relationships

```
Calendar
└── Event
    ├── Attendee
    └── Reminder
```

## Shortcuts (Prefer Using These First)

Shortcuts are high-level wrappers for common operations (`lark-cli calendar +<verb> [flags]`). Prefer Shortcuts when available.

| Shortcut | Description |
|----------|-------------|
| [`+agenda`](references/lark-calendar-agenda.md) | View schedule (default: today) |
| [`+create`](references/lark-calendar-create.md) | Create an event and invite attendees (ISO 8601 times) |
| [`+freebusy`](references/lark-calendar-freebusy.md) | Query primary calendar free/busy and RSVP status |
| [`+room-find`](references/lark-calendar-room-find.md) | Find available rooms for one or more **explicit** time blocks (**never call directly without explicit time — use `+suggestion` first**) |
| [`+rsvp`](references/lark-calendar-rsvp.md) | Reply to an event invitation (accept/decline/tentative) |
| [`+suggestion`](references/lark-calendar-suggestion.md) | Suggest multiple available time-block options based on a vague or ranged time input |

## Meeting Room Rules

- **Meeting rooms are a type of attendee (resource attendee) in an event — they cannot exist or be booked independently of an event.**
- **Any user intent to "book/find/search for available meeting rooms" MUST go through the `references/lark-calendar-schedule-meeting.md` workflow.**
- `+room-find` input must be a **definite time block** — not a time range search.
- **Hard constraint: If the user only requests "find a room" but provides no explicit time, you MUST call `+suggestion` first to get available time blocks, then pass those blocks to `+room-find`. Never guess a time and blindly call `+room-find`.**

## API Resources

```bash
lark-cli schema calendar.<resource>.<method>   # Check parameter structure before calling any API
lark-cli calendar <resource> <method> [flags]  # Call the API
```

> **Important**: When using native APIs, always run `schema` first to inspect `--data` / `--params` structure. Do not guess field formats.

### calendars

  - `create` — Create a shared calendar
  - `delete` — Delete a shared calendar
  - `get` — Get calendar info
  - `list` — List calendars
  - `patch` — Update calendar info
  - `primary` — Get the user's primary calendar
  - `search` — Search calendars

### event.attendees

  - `batch_delete` — Remove event attendees
  - `create` — Add event attendees
  - `list` — Get event attendee list

### events

  - `create` — Create an event
  - `delete` — Delete an event
  - `get` — Get an event
  - `instance_view` — Query event instances view
  - `patch` — Update an event
  - `search` — Search events

### freebusys

  - `list` — Query primary calendar free/busy info

## Permissions Table

| Method | Required Scope |
|--------|---------------|
| `calendars.create` | `calendar:calendar:create` |
| `calendars.delete` | `calendar:calendar:delete` |
| `calendars.get` | `calendar:calendar:read` |
| `calendars.list` | `calendar:calendar:read` |
| `calendars.patch` | `calendar:calendar:update` |
| `calendars.primary` | `calendar:calendar:read` |
| `calendars.search` | `calendar:calendar:read` |
| `event.attendees.batch_delete` | `calendar:calendar.event:update` |
| `event.attendees.create` | `calendar:calendar.event:update` |
| `event.attendees.list` | `calendar:calendar.event:read` |
| `events.create` | `calendar:calendar.event:create` |
| `events.delete` | `calendar:calendar.event:delete` |
| `events.get` | `calendar:calendar.event:read` |
| `events.instance_view` | `calendar:calendar.event:read` |
| `events.patch` | `calendar:calendar.event:update` |
| `events.search` | `calendar:calendar.event:read` |
| `freebusys.list` | `calendar:calendar.free_busy:read` |

**Note (mandatory):** When converting between date/time strings and Unix timestamps, always call a system command or script (e.g., `date`) for the conversion. Never compute this mentally — incorrect timestamps will cause serious logic errors.
