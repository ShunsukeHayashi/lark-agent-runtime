---
name: lark-drive
version: 1.0.0
description: "Lark Drive: Manage files and folders in Drive. Upload and download files, create folders, copy/move/delete files, view file metadata, manage document comments, manage document permissions, subscribe to user comment change events; also handles importing local Word/Markdown/Excel/CSV files as Lark online cloud documents (docx, sheet, bitable). Use when the user needs to upload or download files, organize Drive directories, view file details, manage comments, manage document permissions, subscribe to user comment change events, or import local files as new-generation documents, spreadsheets, or multi-dimensional tables/Base."
metadata:
  requires:
    bins: ["lark-cli"]
  cliHelp: "lark-cli drive --help"
---

# drive (v1)

**CRITICAL — Before starting, MUST use the Read tool to read [`../lark-shared/SKILL.md`](../lark-shared/SKILL.md), which covers authentication and permission handling**

> **Import routing rule:** If the user wants to import a local Excel / CSV as a Base / multi-dimensional table / bitable, you must first use `lark-cli drive +import --type bitable`. Do not switch to `lark-base` first; `lark-base` only handles internal table operations after the import is complete.

## Quick Decision Guide

- If the user wants to import a local `.xlsx` / `.csv` as Base / multi-dimensional table / bitable, the first step must use `lark-cli drive +import --type bitable`.
- If the user wants to import a local `.md` / `.docx` / `.doc` / `.txt` / `.html` as an online document, use `lark-cli drive +import --type docx`.
- If the user wants to import a local `.xlsx` / `.xls` / `.csv` as a spreadsheet, use `lark-cli drive +import --type sheet`.
- `lark-base` only handles internal Base operations (tables, fields, records, views) after import — do not switch to `lark-base` prematurely at the "local file -> Base" step.

## Core Concepts

### Document Types and Tokens

In the Lark Open Platform, different document types have different URL formats and token handling. When performing document operations (such as adding comments or downloading files), you must first obtain the correct `file_token`.

### Document URL Formats and Token Handling

| URL Format | Example                                                      | Token Type | Handling |
|------------|--------------------------------------------------------------|-----------|----------|
| `/docx/` | `https://example.larksuite.com/docx/doxcnxxxxxxxxx`    | `file_token` | The token in the URL path is used directly as `file_token` |
| `/doc/` | `https://example.larksuite.com/doc/doccnxxxxxxxxx`     | `file_token` | The token in the URL path is used directly as `file_token` |
| `/wiki/` | `https://example.larksuite.com/wiki/wikcnxxxxxxxxx`    | `wiki_token` | ⚠️ **Cannot be used directly** — must query to obtain the actual `obj_token` |
| `/sheets/` | `https://example.larksuite.com/sheets/shtcnxxxxxxxxx`  | `file_token` | The token in the URL path is used directly as `file_token` |
| `/drive/folder/` | `https://example.larksuite.com/drive/folder/fldcnxxxx` | `folder_token` | The token in the URL path is used as the folder token |

### Special Handling for Wiki Links (Important!)

Wiki links (`/wiki/TOKEN`) may point to different document types — cloud documents, spreadsheets, multi-dimensional tables, etc. **Do not assume the token in the URL is the file_token directly.** You must first query the actual type and real token.

#### Processing Flow

1. **Use `wiki.spaces.get_node` to query node information**
   ```bash
   lark-cli wiki spaces get_node --params '{"token":"wiki_token"}'
   ```

2. **Extract key information from the result**
   - `node.obj_type`: Document type (docx/doc/sheet/bitable/slides/file/mindnote)
   - `node.obj_token`: **The real document token** (used for subsequent operations)
   - `node.title`: Document title

3. **Use the corresponding API based on `obj_type`**

   | obj_type | Description | API to Use |
   |----------|-------------|-----------|
   | `docx` | New-generation cloud document | `drive file.comments.*`, `docx.*` |
   | `doc` | Legacy cloud document | `drive file.comments.*` |
   | `sheet` | Spreadsheet | `sheets.*` |
   | `bitable` | Multi-dimensional table | `bitable.*` |
   | `slides` | Slides | `drive.*` |
   | `file` | File | `drive.*` |
   | `mindnote` | Mind map | `drive.*` |

#### Query Example

```bash
# Query a wiki node
lark-cli wiki spaces get_node --params '{"token":"wiki_token"}'
```

Example response:
```json
{
  "node": {
    "obj_type": "docx",
    "obj_token": "xxxx",
    "title": "Title",
    "node_type": "origin",
    "space_id": "12345678910"
  }
}
```

### Resource Relationships

```
Wiki Space
└── Wiki Node
    ├── obj_type: docx (new-generation document)
    │   └── obj_token (real document token)
    ├── obj_type: doc (legacy document)
    │   └── obj_token (real document token)
    ├── obj_type: sheet (spreadsheet)
    │   └── obj_token (real document token)
    ├── obj_type: bitable (multi-dimensional table)
    │   └── obj_token (real document token)
    └── obj_type: file/slides/mindnote
        └── obj_token (real document token)

Drive Folder
└── File
    └── file_token (used directly)
```

### Common Operation Token Requirements

| Operation | Required Token | Notes |
|-----------|---------------|-------|
| Read document content | `file_token` / handled automatically via `docs +fetch` | `docs +fetch` supports passing a URL directly |
| Add a local comment (text selection comment) | `file_token` | When `--selection-with-ellipsis` or `--block-id` is passed, `drive +add-comment` creates a local comment; only supported for `docx` and wiki URLs that resolve to `docx` |
| Add a full-document comment | `file_token` | When `--selection-with-ellipsis` / `--block-id` is not passed, `drive +add-comment` creates a full-document comment by default; supports `docx`, legacy `doc` URLs, and wiki URLs that resolve to `doc`/`docx` |
| Download a file | `file_token` | Extracted directly from the file URL |
| Upload a file | `folder_token` / `wiki_node_token` | Token of the target location |
| List document comments | `file_token` | Same as adding comments |

### Comment Capability Boundaries (Important!)

- `drive +add-comment` supports two modes.
- Full-document comment: Enabled by default when `--selection-with-ellipsis` / `--block-id` is not passed; can also be explicitly set with `--full-comment`. Supports `docx`, legacy `doc` URLs, and wiki URLs that resolve to `doc`/`docx`.
- Local comment: Enabled when `--selection-with-ellipsis` or `--block-id` is passed. Only supports `docx` and wiki URLs that resolve to `docx`.
- The `--content` for `drive +add-comment` requires a `reply_elements` JSON array string, e.g. `--content '[{"type":"text","text":"body text"}]'`.
- If the wiki resolves to something other than `doc`/`docx`, do not use `+add-comment`.
- To call the comment V2 protocol directly at a lower level, use the native API: first run `lark-cli schema drive.file.comments.create_v2`, then run `lark-cli drive file.comments create_v2 ...`. Omit `anchor` for full-document comments; pass `anchor.block_id` for local comments.

### Comment Query and Counting Conventions (Important!)

- To query document comments, use `drive file.comments list`.
- The `items` returned by `drive file.comments list` should be understood as a list of "comment cards" — each `item` corresponds to one comment card visible in the UI, not a flat list of interaction messages.
- Semantically on the server side, when the first comment is created, the first reply within that card is also created; therefore, the actual content is carried in `item.reply_list.replies`, where the first reply represents the "comment itself" from the user's perspective.
- When the user wants to count "number of comments" or "number of comment cards", count the length of `items`. For a full count, sum the `items` lengths across all paginated responses.
- When the user wants to count "number of replies", exclude the first reply in each comment card from the user's perspective; the formula is: total length of all `item.reply_list.replies` minus the length of `items`.
- When the user wants to count "total interactions", sum the length of all `item.reply_list.replies`; this includes the first reply in each comment card.
- If `item.has_more=true` for an item, there are more replies under that comment card not included in the current response; call `drive file.comment.replys list` to retrieve all replies before computing full reply counts / total interaction counts.

### Comment Business Features and Guidance (Important!)

#### Comment Sorting Guidance
- A document typically has multiple comments sorted by `create_time` (creation time).
- **Important**: Only sort by `create_time` when the user explicitly mentions "latest comment", "last comment", or "earliest comment":
  - **Must first fetch all comments (handle pagination to retrieve all data)** — do not sort after fetching only one page
  - "Latest comment" / "Last comment": Sort by `create_time` descending, take the first
  - "Earliest comment": Sort by `create_time` ascending, take the first
- If the user only says "first comment", use the first item returned by `drive file.comments list` directly without additional sorting.

#### Comment Reply Restrictions
- **Check for the following restrictions before adding a reply to a comment**
- **Full-document comments do not support replies**: Comments where `is_whole=true` cannot have replies added. When encountering such a comment, inform the user "full-document comments do not support replies".
- **Resolved comments do not support replies**: Comments where `is_solved=true` cannot have replies added. When encountering such a comment, inform the user "this comment has been resolved and cannot be replied to".
- **Note**: When the user wants to reply to a comment but the comment cannot be replied to due to the above restrictions, only inform them — **do not automatically find another comment they can reply to**, as this may not match the user's expectations.

#### Choosing Between Batch Query and List Query
- `drive file.comments batch_query` is for **bulk querying when comment IDs are already known** — requires passing a specific list of comment IDs.
- `drive file.comments list` is for paginated retrieval of the comment list, suitable for counting total comments, iterating through all comments, or getting "latest/last N comments".

#### Reaction Scenarios
- When encountering questions about reactions on comments / replies (emoji, counts per emoji, who reacted, adding/removing reactions), **read [lark-drive-reactions.md](../../skills/lark-drive/references/lark-drive-reactions.md) first to understand how to use them**.

### Typical Errors and Solutions

| Error Message | Cause | Solution |
|---------------|-------|----------|
| `not exist` | Incorrect token used | Check token type; wiki links must first be queried to obtain `obj_token` |
| `permission denied` | Missing required permissions | Guide the user to check whether the current identity has the appropriate permissions on the document/file; grant permissions if needed |
| `invalid file_type` | Incorrect file_type parameter | Pass the correct file_type (docx/doc/sheet) based on `obj_type` |

### Granting Document Access to the Current Application

When document permissions need to be granted to **the current application (bot) itself**, first obtain the app's open_id via the bot info API, then call the permissions API to grant access:

```bash
# 1. Get the current application's open_id
lark-cli api GET /open-apis/bot/v3/info --as bot
# Extract bot.open_id from the response

# 2. Grant the current application access to the document
lark-cli drive permission.members create \
  --params '{"token":"<doc_token>","type":"<resource_type>"}' \
  --data '{"member_type":"openid","member_id":"<bot_open_id>","perm":"view","type":"user"}'
```

> **Note**: This approach is only applicable when granting access to **the current application**. To grant access to other users, use their open_id directly without calling the bot info API.

`<resource_type>` valid values: `doc`, `docx`, `sheet`, `bitable`, `file`, `folder`, `wiki`.

## Shortcuts (Prefer Using These First)

Shortcuts are high-level wrappers for common operations (`lark-cli drive +<verb> [flags]`). Prefer using Shortcuts when available.

| Shortcut | Description |
|----------|-------------|
| [`+upload`](references/lark-drive-upload.md) | Upload a local file to Drive |
| [`+download`](references/lark-drive-download.md) | Download a file from Drive to local |
| [`+add-comment`](references/lark-drive-add-comment.md) | Add a full-document comment, or a local comment to selected docx text (also supports wiki URL resolving to doc/docx) |
| [`+export`](references/lark-drive-export.md) | Export a doc/docx/sheet/bitable to a local file with limited polling |
| [`+export-download`](references/lark-drive-export-download.md) | Download an exported file by file_token |
| [`+import`](references/lark-drive-import.md) | Import a local file to Drive as a cloud document (docx, sheet, bitable) |
| [`+move`](references/lark-drive-move.md) | Move a file or folder to another location in Drive |
| [`+delete`](references/lark-drive-delete.md) | Delete a Drive file or folder with limited polling for folder deletes |
| [`+task_result`](references/lark-drive-task-result.md) | Poll async task result for import, export, move, or delete operations |

## API Resources

```bash
lark-cli schema drive.<resource>.<method>   # Must check parameter structure before calling the API
lark-cli drive <resource> <method> [flags] # Call the API
```

> **Important**: When using native APIs, always run `schema` first to check the `--data` / `--params` parameter structure — do not guess field formats.

### files

  - `copy` — Copy a file
  - `create_folder` — Create a new folder
  - `list` — List contents of a folder

### file.comments

  - `batch_query` — Batch fetch comments
  - `create_v2` — Add a full-document or local (text selection) comment
  - `list` — Paginated fetch of document comments
  - `patch` — Resolve / restore a comment

### file.comment.replys

  - `create` — Add a reply
  - `delete` — Delete a reply
  - `list` — Get replies
  - `update` — Update a reply

### permission.members

  - `auth` — 
  - `create` — Add a collaborator permission
  - `transfer_owner` — 

### metas

  - `batch_query` — Batch fetch document metadata

### user

  - `remove_subscription` — Unsubscribe from user/app dimension events
  - `subscription` — Subscribe to user/app dimension events (currently supports comment added events)
  - `subscription_status` — Query subscription status of a user/app for a specified event

### file.statistics

  - `get` — Get file statistics

### file.view_records

  - `list` — Get document visitor records

### file.comment.reply.reactions

  - `update_reaction` — Add / remove a reaction

## Permissions Table

| Method | Required Scope |
|--------|---------------|
| `files.copy` | `docs:document:copy` |
| `files.create_folder` | `space:folder:create` |
| `files.list` | `space:document:retrieve` |
| `file.comments.batch_query` | `docs:document.comment:read` |
| `file.comments.create_v2` | `docs:document.comment:create` |
| `file.comments.list` | `docs:document.comment:read` |
| `file.comments.patch` | `docs:document.comment:update` |
| `file.comment.replys.create` | `docs:document.comment:create` |
| `file.comment.replys.delete` | `docs:document.comment:delete` |
| `file.comment.replys.list` | `docs:document.comment:read` |
| `file.comment.replys.update` | `docs:document.comment:update` |
| `permission.members.auth` | `docs:permission.member:auth` |
| `permission.members.create` | `docs:permission.member:create` |
| `permission.members.transfer_owner` | `docs:permission.member:transfer` |
| `metas.batch_query` | `drive:drive.metadata:readonly` |
| `user.remove_subscription` | `docs:event:subscribe` |
| `user.subscription` | `docs:event:subscribe` |
| `user.subscription_status` | `docs:event:subscribe` |
| `file.statistics.get` | `drive:drive.metadata:readonly` |
| `file.view_records.list` | `drive:file:view_record:readonly` |
| `file.comment.reply.reactions.update_reaction` | `docs:document.comment:create` |
