---
name: lark-vc
version: 1.0.0
description: "Lark Video Conferencing: query meeting records, get meeting notes artifacts (summary, todos, chapters, transcript). 1. Use this skill when querying completed meetings (e.g., yesterday / last week / meetings held earlier today); for future meeting schedules use the lark-calendar skill. 2. Supports searching meeting records by keyword, time range, organizer, participant, meeting room, and other filters. 3. Use this skill when obtaining or organizing meeting notes."
metadata:
  requires:
    bins: ["lark-cli"]
  cliHelp: "lark-cli vc --help"
---

# vc (v1)

**CRITICAL — Before starting, MUST use the Read tool to read [`../lark-shared/SKILL.md`](../lark-shared/SKILL.md). It contains authentication and permission handling.**

## Core Concepts

- **Video Meeting**: A Lark video conference instance, identified by `meeting_id`.
- **Meeting Record**: A record generated after a video conference ends. Supports searching by keyword, time range, attendee, organizer, meeting room, and other filters.
- **Meeting Notes (Note)**: A structured document generated after a video conference ends, containing the notes document (with summary, todos, chapters) and a verbatim transcript document.
- **Minutes (Miaoji)**: A recording artifact from a Lark video conference or user-uploaded audio/video file; supports video/audio transcription and meeting notes, identified by `minute_token`.
- **Notes Document (MainDoc)**: The main document for AI-generated meeting notes, containing AI-generated summaries and todos, corresponding to `note_doc_token`.
- **User Meeting Notes (MeetingNotes)**: A notes document the user has manually linked to a meeting, corresponding to `meeting_notes`. Only returned via the `--calendar-event-ids` path.
- **Verbatim Transcript (VerbatimDoc)**: A word-for-word record of the meeting, including speaker and timestamp.

## Core Scenarios

### 1. Search Meeting Records
1. Only completed meetings can be searched; for future meetings, use the lark-calendar skill.
2. Only keyword, time range, attendee, organizer, meeting room, and similar filters are supported. For unsupported filter conditions, notify the user.
3. When there are multiple results, handle pagination carefully — do not miss any meeting records.

### 2. Organize Meeting Notes
1. When organizing notes, default to providing the notes document link and verbatim transcript link — no need to read the document content.
2. Only read the document content when the user explicitly needs summaries, todos, or chapters from the notes document.
3. When reading AI-generated notes (`note_doc_token`) content, the **first `<whiteboard>`** tag in the notes document is the cover image (AI-generated summary visualization); download and display it for the user:
```bash
# 1. Read the notes content
lark-cli docs +fetch --doc <note_doc_token>
# 2. Extract the token from the first <whiteboard token="xxx"/> in the returned markdown
# 3. Download the cover image to the artifact directory (same directory as the verbatim transcript)
#    Not all notes have a cover whiteboard; skip if there is no <whiteboard> tag
lark-cli docs +media-download --type whiteboard --token <whiteboard_token> --output ./artifact-<title>/cover
```
> **Artifact directory convention**: All downloaded artifacts for the same meeting (cover image, verbatim transcript, etc.) go in `artifact-<title>/` — do not scatter them in the current working directory.

> **Notes-related documents — choose based on user intent:**
> - `note_doc_token` → **AI-generated meeting notes** (AI summary + todos + chapters)
> - `meeting_notes` → **User-linked meeting notes** (document user manually linked to the meeting; only returned via `--calendar-event-ids` path)
> - `verbatim_doc_token` → **Verbatim transcript** (complete word-by-word record with speakers and timestamps) — use when user says "transcript," "full record," "who said what"
> - When user says "notes," "summary," "notes content," return both `note_doc_token` and `meeting_notes` (if available)
> - When user intent is unclear, show all document links and let the user choose — do not decide for them

### 3. Notes Document and Verbatim Transcript Links
1. Notes documents, verbatim transcript documents, and linked shared documents are returned using document tokens by default.
2. When only basic info like document name and URL is needed, use `lark-cli drive metas batch_query`:
```bash
# Learn how to use the command
lark-cli schema drive.metas.batch_query

# Batch get document basic info: maximum 10 documents per query
lark-cli drive metas batch_query --data '{"request_docs": [{"doc_type": "docx", "doc_token": "<doc_token>"}], "with_url": true}'
```
3. When document content is needed, use `lark-cli docs +fetch`:
```bash
# Get document content
lark-cli docs +fetch --doc <doc_token>
```

## Resource Relationships

```
Meeting (Video Conference)
├── Note (Meeting Notes)
│   ├── MainDoc (AI-generated notes document, note_doc_token)
│   ├── MeetingNotes (user-linked meeting notes document, meeting_notes)
│   ├── VerbatimDoc (verbatim transcript, verbatim_doc_token)
│   └── SharedDoc (shared document from meeting)
└── Minutes ← identified by minute_token; +recording gets from meeting_id
    ├── Transcript
    ├── Summary
    ├── Todos
    └── Chapters
```

> **Note**: `+search` can only query completed historical meetings. For future schedules, use [lark-calendar](../lark-calendar/SKILL.md).
>
> **Priority**: When searching historical meetings, prefer `vc +search` over `calendar events search`. Calendar search is for schedules; vc search is for completed meeting records, supporting filters by attendee, organizer, meeting room, etc.
>
> **Routing rules**: If the user asks about "past meetings," "what meetings were held today," "recently attended meetings," "completed meetings," or "historical meeting records," prefer `vc +search`. Only use [lark-calendar](../lark-calendar/SKILL.md) for querying future schedules, upcoming meetings, or agendas.
>
> **Special case**: When the user asks "what meetings are today," use `vc +search` to query meetings already held today, AND use lark-calendar to query meetings not yet started, then combine and present both.

## Shortcuts (Prefer Using These First)

Shortcuts are high-level wrappers for common operations (`lark-cli vc +<verb> [flags]`). Prefer Shortcuts when available.

| Shortcut | Description |
|----------|-------------|
| [`+search`](references/lark-vc-search.md) | Search meeting records (requires at least one filter) |
| [`+notes`](references/lark-vc-notes.md) | Query meeting notes (via meeting-ids, minute-tokens, or calendar-event-ids) |
| [`+recording`](references/lark-vc-recording.md) | Query minute_token from meeting-ids or calendar-event-ids |

- Before using `+search`, read [references/lark-vc-search.md](references/lark-vc-search.md) to understand search parameters and response structure.
- Before using `+notes`, read [references/lark-vc-notes.md](references/lark-vc-notes.md) to understand query parameters, artifact types, and response structure.
- Before using `+recording`, read [references/lark-vc-recording.md](references/lark-vc-recording.md) to understand query parameters and response structure.

## API Resources

```bash
lark-cli schema vc.<resource>.<method>   # Check parameter structure before calling any API
lark-cli vc <resource> <method> [flags]  # Call the API
```

> **Important**: When using native APIs, always run `schema` first to inspect `--data` / `--params` structure. Do not guess field formats.

### meeting

  - `get` — Get meeting details (topic, time, attendees, note_id)

```bash
# Get meeting basic info: without attendee list
lark-cli vc meeting get --params '{"meeting_id": "<meeting_id>"}'

# Get meeting basic info: with attendee list
lark-cli vc meeting get --params '{"meeting_id": "<meeting_id>", "with_participants": true}'
```

### minutes (cross-domain, see [lark-minutes](../lark-minutes/SKILL.md))

  - `get` — Get minutes basic info (title, duration, cover); to query notes **content** use `+notes --minute-tokens <minute-token>`

## Permissions Table

| Method | Required Scope |
|--------|---------------|
| `+notes --meeting-ids` | `vc:meeting.meetingevent:read`, `vc:note:read` |
| `+notes --minute-tokens` | `vc:note:read`, `minutes:minutes:readonly`, `minutes:minutes.artifacts:read`, `minutes:minutes.transcript:export` |
| `+notes --calendar-event-ids` | `calendar:calendar:read`, `calendar:calendar.event:read`, `vc:meeting.meetingevent:read`, `vc:note:read` |
| `+recording --meeting-ids` | `vc:record:readonly` |
| `+recording --calendar-event-ids` | `vc:record:readonly`, `calendar:calendar:read`, `calendar:calendar.event:read` |
| `+search` | `vc:meeting.search:read` |
| `meeting.get` | `vc:meeting.meetingevent:read` |
