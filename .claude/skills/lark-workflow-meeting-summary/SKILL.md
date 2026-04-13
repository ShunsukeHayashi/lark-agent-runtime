---
name: lark-workflow-meeting-summary
version: 1.0.0
description: "Meeting notes summary workflow: aggregate meeting notes for a specified time range and generate a structured report. Use when the user needs to organize meeting notes, generate a weekly meeting report, or review meeting content over a period of time."
metadata:
  requires:
    bins: ["lark-cli"]
---

# Meeting Notes Summary Workflow

**CRITICAL — Before starting, MUST use the Read tool to read [`../lark-shared/SKILL.md`](../lark-shared/SKILL.md). It contains authentication and permission handling.** Then read [`../lark-vc/SKILL.md`](../lark-vc/SKILL.md) to understand meeting notes operations.

## Applicable Scenarios

- "Help me organize this week's meeting notes" / "Summarize recent meetings" / "Generate a weekly meeting report"
- "What meetings were held today" / "Review what meetings happened last week"

## Prerequisites

Supports **user identity only**. Ensure authorization before running:

```bash
lark-cli auth login --domain vc        # Basic (query + notes)
lark-cli auth login --domain vc,drive  # Including reading notes document content, generating documents
```

## Workflow

```
{time range} ─► vc +search ──► meeting list (meeting_ids)
                   │
                   ▼
               vc +notes ──► notes document tokens
                   │
                   ▼
               drive metas batch_query — notes metadata
                   │
                   ▼
               Structured report
```

### Step 1: Determine Time Range

Default: **past 7 days**. Inference rules: "today" → current day, "this week" → this Monday to now, "last week" → last Monday to last Sunday, "this month" → 1st to now.

> **Note**: Date conversion MUST use system commands (e.g., `date`); never compute mentally. Time range parameters must be formatted as required by the CLI (usually `YYYY-MM-DD` or ISO 8601).

### Step 2: Query Meeting Records

```bash
# page-size maximum is 30
lark-cli vc +search --start "<YYYY-MM-DD>" --end "<YYYY-MM-DD>" --format json --page-size 30
```

- Time range splitting: maximum search range is 1 month. For longer ranges, split into multiple queries of one month each.
- `--end` is **inclusive of that day** (i.e., to query "today," set both start and end to today)
- `--format json` outputs JSON format for easier parsing
- `--page-size 30` maximum 30 records per page
- When a `page_token` is present, continue paginating to collect all `id` fields (meeting-id)

### Step 3: Get Notes Metadata

1. Query notes information associated with meetings:
```bash
lark-cli vc +notes --meeting-ids "id1,id2,...,idN"
```
- Query meeting notes based on `meeting-id` collected in the previous step
- Maximum 50 notes per single query; split into batches if more than 50
- For meetings that return `no notes available`, mark as "No notes available" in the final output
- Record each meeting's `note_doc_token` (notes document token) and `verbatim_doc_token` (verbatim transcript token)

2. Get notes document and verbatim transcript links:
```bash
# Learn how to use the command
lark-cli schema drive.metas.batch_query

# Batch get notes and verbatim transcript links: maximum 10 documents per query
lark-cli drive metas batch_query --data '{"request_docs": [{"doc_type": "docx", "doc_token": "<doc_token>"}], "with_url": true}'
```

### Step 4: Organize the Notes Report

Choose output format based on time span:

- **Single-day summary** ("today"/"yesterday"): Use "Today's Meetings Overview" as the title; list meeting time, topic, notes link, and verbatim transcript link for each meeting.
- **Multi-day/weekly report** ("this week"/"past 7 days", etc.): Use "Weekly Meeting Report" as the title; include overview statistics and per-meeting details.

### Step 5: Generate Document (Optional — When Requested by User)

Read [`../lark-doc/SKILL.md`](../lark-doc/SKILL.md) to learn the cloud document skill.

```bash
lark-cli docs +create --title "Meeting Notes Summary (<start> - <end>)" --markdown "<content>"
# Or append to an existing document
lark-cli docs +update --doc "<url_or_token>" --mode append --markdown "<content>"
```

## References

- [lark-shared](../lark-shared/SKILL.md) — Authentication, permissions (required reading)
- [lark-vc](../lark-vc/SKILL.md) — Detailed usage of `+search`, `+notes`
- [lark-doc](../lark-doc/SKILL.md) — Detailed usage of `+fetch`, `+create`, `+update`
