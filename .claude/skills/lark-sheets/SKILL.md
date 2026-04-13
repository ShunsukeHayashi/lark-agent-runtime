---
name: lark-sheets
version: 1.1.0
description: "Lark Sheets (Spreadsheets): create and operate spreadsheets. Create spreadsheets with headers and data, read and write cells, append row data, find cells in a known spreadsheet, export spreadsheet files. Use when the user needs to create a spreadsheet, bulk read/write data, find content in a known spreadsheet, or export/download a spreadsheet. To search for spreadsheet files in Drive by name or keyword, use lark-doc's docs +search to locate the resource first."
metadata:
  requires:
    bins: ["lark-cli"]
  cliHelp: "lark-cli sheets --help"
---

# sheets (v3)

**CRITICAL — Before starting, MUST use the Read tool to read [`../lark-shared/SKILL.md`](../lark-shared/SKILL.md). It contains authentication and permission handling.**

## Quick Decision Guide

- To find a spreadsheet file in Drive by title or keyword, use `lark-cli docs +search` first.
- `docs +search` directly returns `SHEET` results — do not assume it only searches documents / Wiki.
- After obtaining a spreadsheet URL / token, use `sheets +info`, `sheets +read`, `sheets +find`, etc. for internal operations.

## Core Concepts

### Document Types and Tokens

In the Lark Open Platform, different document types have different URL formats and token handling. When performing document operations (such as adding comments or downloading files), you must first obtain the correct `file_token`.

### Document URL Formats and Token Handling

| URL Format | Example | Token Type | Handling |
|------------|---------|-----------|----------|
| `/docx/` | `https://example.larksuite.com/docx/doxcnxxxxxxxxx` | `file_token` | The token in the URL path is used directly as `file_token` |
| `/doc/` | `https://example.larksuite.com/doc/doccnxxxxxxxxx` | `file_token` | The token in the URL path is used directly as `file_token` |
| `/wiki/` | `https://example.larksuite.com/wiki/wikcnxxxxxxxxx` | `wiki_token` | ⚠️ **Cannot be used directly** — must query to obtain the actual `obj_token` |
| `/sheets/` | `https://example.larksuite.com/sheets/shtcnxxxxxxxxx` | `file_token` | The token in the URL path is used directly as `file_token` |
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

**Filter operation flow (important):**

1. **create** — Create a filter
   - Used for creating a filter for the first time
   - ⚠️ `range` must cover all columns to be filtered (e.g., B1:E200)
   - If a filter already exists, using `create` again will overwrite the entire filter

2. **update** — Update a filter
   - Used to add/update conditions for a specific column in an existing filter
   - Only specify `col` and `condition`; no `range` needed

3. **delete** — Delete a filter

4. **get** — Get filter status

**Multi-column filter example:**

Creating a dual filter for media name (column B) and sentiment analysis (column E):

```bash
# 1. Delete existing filter (if any)
lark-cli sheets spreadsheet.sheet.filters delete \
  --params '{"spreadsheet_token":"<spreadsheet_token>","sheet_id":"<sheet_id>"}'

# 2. Create the first filter; range covers all columns to filter
lark-cli sheets spreadsheet.sheet.filters create \
  --params '{"spreadsheet_token":"<spreadsheet_token>","sheet_id":"<sheet_id>"}' \
  --data '{"col":"B","condition":{"expected":["xx"],"filter_type":"multiValue"},"range":"<sheet_id>!B1:E200"}'

# 3. Add the second filter condition
lark-cli sheets spreadsheet.sheet.filters update \
  --params '{"spreadsheet_token":"<spreadsheet_token>","sheet_id":"<sheet_id>"}' \
  --data '{"col":"E","condition":{"expected":["xx"],"filter_type":"multiValue"}}'
```

**Common errors:**
- `Wrong Filter Value`: Filter already exists; delete it first then create
- `Excess Limit`: Duplicate column condition added during update

## Shortcuts (Prefer Using These First)

Shortcuts are high-level wrappers for common operations (`lark-cli sheets +<verb> [flags]`). Prefer Shortcuts when available.

| Shortcut | Description |
|----------|-------------|
| [`+info`](references/lark-sheets-info.md) | View spreadsheet and sheet information |
| [`+read`](references/lark-sheets-read.md) | Read spreadsheet cell values |
| [`+write`](references/lark-sheets-write.md) | Write to spreadsheet cells (overwrite mode) |
| [`+write-image`](references/lark-sheets-write-image.md) | Write an image into a spreadsheet cell |
| [`+append`](references/lark-sheets-append.md) | Append rows to a spreadsheet |
| [`+find`](references/lark-sheets-find.md) | Find cells in a spreadsheet |
| [`+create`](references/lark-sheets-create.md) | Create a spreadsheet (optional header row and initial data) |
| [`+export`](references/lark-sheets-export.md) | Export a spreadsheet (async task polling + optional download) |
| [`+merge-cells`](references/lark-sheets-merge-cells.md) | Merge cells in a spreadsheet |
| [`+unmerge-cells`](references/lark-sheets-unmerge-cells.md) | Unmerge (split) cells in a spreadsheet |
| [`+replace`](references/lark-sheets-replace.md) | Find and replace cell values |
| [`+set-style`](references/lark-sheets-set-style.md) | Set cell style for a range |
| [`+batch-set-style`](references/lark-sheets-batch-set-style.md) | Batch set cell styles for multiple ranges |
| [`+add-dimension`](references/lark-sheets-add-dimension.md) | Add rows or columns at the end of a sheet |
| [`+insert-dimension`](references/lark-sheets-insert-dimension.md) | Insert rows or columns at a specified position |
| [`+update-dimension`](references/lark-sheets-update-dimension.md) | Update row or column properties (visibility, size) |
| [`+move-dimension`](references/lark-sheets-move-dimension.md) | Move rows or columns to a new position |
| [`+delete-dimension`](references/lark-sheets-delete-dimension.md) | Delete rows or columns |

## API Resources

```bash
lark-cli schema sheets.<resource>.<method>   # Check parameter structure before calling any API
lark-cli sheets <resource> <method> [flags]  # Call the API
```

> **Important**: When using native APIs, always run `schema` first to inspect `--data` / `--params` structure. Do not guess field formats.

### spreadsheets

  - `create` — Create a spreadsheet
  - `get` — Get spreadsheet info
  - `patch` — Update spreadsheet properties

### spreadsheet.sheet.filters

  - `create` — Create a filter
  - `delete` — Delete a filter
  - `get` — Get a filter
  - `update` — Update a filter

### spreadsheet.sheets

  - `find` — Find cells in a spreadsheet

## Permissions Table

| Method | Required Scope |
|--------|---------------|
| `spreadsheets.create` | `sheets:spreadsheet:create` |
| `spreadsheets.get` | `sheets:spreadsheet.meta:read` |
| `spreadsheets.patch` | `sheets:spreadsheet.meta:write_only` |
| `spreadsheet.sheet.filters.create` | `sheets:spreadsheet:write_only` |
| `spreadsheet.sheet.filters.delete` | `sheets:spreadsheet:write_only` |
| `spreadsheet.sheet.filters.get` | `sheets:spreadsheet:read` |
| `spreadsheet.sheet.filters.update` | `sheets:spreadsheet:write_only` |
| `spreadsheet.sheets.find` | `sheets:spreadsheet:read` |
