---
name: lark-minutes
version: 1.0.0
description: "Lark Minutes (Miaoji): basic minutes features. 1. Search minutes list (by keyword/owner/participant/time range); 2. Get minutes metadata (title, cover, duration, etc.); 3. Download minutes audio/video files; 4. Get minutes AI artifacts (summary, todos, chapters). Lark Minutes URL format: http(s)://<host>/minutes/<minute-token>"
metadata:
  requires:
    bins: ["lark-cli"]
  cliHelp: "lark-cli minutes --help"
---

# minutes (v1)

**CRITICAL — Before starting, MUST use the Read tool to read [`../lark-shared/SKILL.md`](../lark-shared/SKILL.md). It contains authentication and permission handling.**

## Core Concepts

- **Minutes**: A recording artifact from a Lark video conference or a user-uploaded audio/video file, identified by `minute_token`.
- **Minute Token (`minute_token`)**: The unique identifier for a minutes record, extractable from the URL (e.g., `https://*.feishu.cn/minutes/obcnq3b9jl72l83w4f14xxxx` → `obcnq3b9jl72l83w4f14xxxx`). If the URL contains extra parameters (e.g., `?xxx`), take the last segment of the path.

## Core Scenarios

### 1. Search Minutes

1. When the user describes "my minutes," "minutes containing a keyword," or "minutes within a time range," prefer `minutes +search`.
2. Only keyword, time range, participant, and owner filters are supported. For unsupported filter conditions, notify the user.
3. When there are multiple results, handle pagination carefully — do not miss any records.
4. If the minutes are from a meeting, prefer using [vc +search](../lark-vc/references/lark-vc-search.md) to locate the meeting first, then retrieve the `minute_token` via [vc +recording](../lark-vc/references/lark-vc-recording.md).

### 2. View Minutes Metadata

1. When the user only needs to confirm basic info — title, cover, duration, owner, URL — use `minutes minutes get`.
2. If the user provides a minutes URL, extract the `minute_token` from the end of the URL first, then call `minutes minutes get`.
3. When the user's intent is unclear, default to providing basic metadata first to help confirm whether the correct minutes record was found.

> Use `lark-cli schema minutes.minutes.get` to see the full response structure. Core fields: `title` (title), `cover` (cover URL), `duration` (duration in ms), `owner_id` (owner ID), `url` (minutes link).

### 3. Download Minutes Audio/Video

1. Download the minutes audio/video to local, or get a 1-day download link. See [minutes +download](references/lark-minutes-download.md).
2. `minutes +download` only handles audio/video media files.
3. Use `--url-only` when the user only wants a shareable download link; download directly when the user wants the file locally.

> **Note**: `+download` only handles audio/video media files. If the user needs transcript, summary, todos, chapters, or other notes content, use [vc +notes --minute-tokens](../lark-vc/references/lark-vc-notes.md).

### 4. Get Minutes Transcript, Summary, Todos, Chapters

1. When the user says "transcript of this minutes," "summary," "todos," or "chapters," **this is NOT in scope for this skill**.
2. Use [vc +notes --minute-tokens](../lark-vc/references/lark-vc-notes.md) to get the corresponding notes artifacts.
3. If `minute_token` is already in context, pass it directly to `vc +notes`; if you only have the minutes URL, extract the `minute_token` first.

```bash
# Get notes artifacts (transcript, summary, todos, chapters) via minute_token
lark-cli vc +notes --minute-tokens <minute_token>
```

> **Cross-skill routing**: Transcript, AI summary, todos, chapters, and other notes content are provided by the `+notes` command in [lark-vc](../lark-vc/SKILL.md).

## Resource Relationships

```text
Minutes ← identified by minute_token
├── Metadata (title, cover, duration, owner, url) → minutes minutes get
└── MediaFile (audio/video file) → minutes +download
```

> **Capability boundaries**: `minutes` handles **searching minutes, viewing basic metadata, and downloading audio/video files**.
>
> **Routing rules**:
> - "minutes list / search minutes / minutes with a keyword" → `minutes +search`
> - "my minutes / minutes within a time range / minutes list" (no meeting context) → use this skill directly; do NOT go through [lark-vc](../lark-vc/SKILL.md) first
> - If the user mentions "meeting / conference / session" along with "minutes," prefer [lark-vc](../lark-vc/SKILL.md) to locate the meeting first, then get `minute_token` via [vc +recording](../lark-vc/references/lark-vc-recording.md)
> - "my minutes / minutes I own / minutes I participated in" → map to `me` filter; `me` means the current user
> - When results span multiple pages, use `page_token` to paginate until no more results
> - `minutes +search` returns at most `200` records per call; no fixed total limit
> - "title / duration / cover / link of this minutes" → `minutes minutes get`
> - "download video / audio / media file of this minutes" → `minutes +download`
> - "transcript / summary / todos / chapters of this minutes" → use [vc +notes --minute-tokens](../lark-vc/references/lark-vc-notes.md)

## Shortcuts (Prefer Using These First)

Shortcuts are high-level wrappers for common operations (`lark-cli minutes +<verb> [flags]`). Prefer Shortcuts when available.

| Shortcut | Description |
|----------|-------------|
| [`+search`](references/lark-minutes-search.md) | Search minutes by keyword, owners, participants, and time range |
| [`+download`](references/lark-minutes-download.md) | Download audio/video media file of a minute |

- Before using `+search`, read [references/lark-minutes-search.md](references/lark-minutes-search.md) to understand search parameters and response structure.
- Before using `+download`, read [references/lark-minutes-download.md](references/lark-minutes-download.md) to understand download parameters and response structure.

## API Resources

```bash
lark-cli schema minutes.<resource>.<method>   # Check parameter structure before calling any API
lark-cli minutes <resource> <method> [flags]  # Call the API
```

> **Important**: When using native APIs, always run `schema` first to inspect `--data` / `--params` structure. Do not guess field formats.

### minutes

- `get` — Get minutes info

## Permissions Table

| Method | Required Scope |
|--------|---------------|
| `+search` | `minutes:minutes.search:read` |
| `minutes.get` | `minutes:minutes:readonly` |
| `+download` | `minutes:minutes.media:export` |
