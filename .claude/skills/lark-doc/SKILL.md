---
name: lark-doc
version: 1.0.0
description: "Lark Cloud Documents: Create and edit Lark documents. Create documents from Markdown, fetch document content, update documents (append/overwrite/replace/insert/delete), upload and download images and files within documents, search Drive documents. Use when the user needs to create or edit Lark documents, read document content, insert images into documents, or search Drive documents. If the user wants to first locate spreadsheets, reports, or other Drive objects by name or keyword, also start here with docs +search for resource discovery."
metadata:
  requires:
    bins: ["lark-cli"]
  cliHelp: "lark-cli docs --help"
---

# docs (v1)

**CRITICAL — Before starting, MUST use the Read tool to read [`../lark-shared/SKILL.md`](../lark-shared/SKILL.md), which covers authentication and permission handling**

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

## Important Note: Whiteboard Editing
> **⚠️ The lark-doc skill cannot directly edit existing whiteboard content, but `docs +update` can create a new blank whiteboard**
### Scenario 1: Document content and whiteboard token already obtained via docs +fetch
If the user has already fetched document content using `docs +fetch` and the document contains a whiteboard (the returned Markdown includes a `<whiteboard token="xxx"/>` tag), guide the user to:
1. Record the whiteboard token
2. See [`../lark-whiteboard/SKILL.md`](../lark-whiteboard/SKILL.md) to learn how to edit whiteboard content
### Scenario 2: Whiteboard just created and needs editing
If the user just created a blank whiteboard via `docs +update` and wants to edit it:
**Step 1: Create using blank whiteboard syntax**
- Pass `<whiteboard type="blank"></whiteboard>` directly in `--markdown`
- When multiple blank whiteboards are needed, repeat multiple whiteboard tags within the same `--markdown`
  **Step 2: Record the token from the response**
- After `docs +update` succeeds, read the `data.board_tokens` field from the response
- `data.board_tokens` is the list of tokens for the newly created whiteboards; use these tokens for subsequent edits
  **Step 3: Guide editing**
- Record the whiteboard token(s) to edit
- See [`../lark-whiteboard/SKILL.md`](../lark-whiteboard/SKILL.md) to learn how to edit whiteboard content
### Notes
- Existing whiteboard content cannot be edited directly via `docs +update` in lark-doc
- Editing a whiteboard requires using the dedicated [`../lark-whiteboard/SKILL.md`](../lark-whiteboard/SKILL.md)

## Document Visualization Recommendations
> **💡 When writing documents that involve complex sequences, architectural layers, logical relationships, data flows, etc., it is recommended to use whiteboards to create visual diagrams to significantly improve document readability.**
> 
> Refer to [`../lark-whiteboard/SKILL.md`](../lark-whiteboard/SKILL.md) to learn how to draw whiteboard content.

## Quick Decision Guide
- If the user says "look at the images/attachments/assets in the document" or "preview assets", prefer `lark-cli docs +media-preview`.
- If the user explicitly says "download assets", use `lark-cli docs +media-download`.
- If the target is specifically a whiteboard / whiteboard thumbnail, you must use `lark-cli docs +media-download --type whiteboard` — do not use `+media-preview`.
- If the user says "find a spreadsheet", "search by name for a spreadsheet", "find a report", "recently opened spreadsheet", use `lark-cli docs +search` for resource discovery first.
- `docs +search` is not limited to searching documents / Wiki; results will also return Drive objects such as `SHEET`.
- After obtaining a spreadsheet URL / token, switch to `lark-sheets` for internal operations like reading, filtering, and writing.
- If the user says "add a comment to a document", "view comments", "reply to a comment", "add a reaction to a comment", or "delete a reaction from a comment", **do not stay in `lark-doc`** — switch directly to `lark-drive`.

## Proactive Whiteboard Identification

> **Users rarely proactively mention "whiteboard". When creating a document, proactively identify content suitable for visualization and present it using a whiteboard.**

### 🔴 Critical Requirement (Must Follow)

**Creating a blank whiteboard ≠ completing the task**. After creating a blank whiteboard, **you must continue using the lark-whiteboard skill to fill in actual content**.

### Semantic to Whiteboard Type Mapping

When creating/editing documents, if the document topic involves the following semantics, **proactively** create a whiteboard without waiting for the user to specify:

| Semantic            | Whiteboard Type  | Reference Guide                                                                                        |
|---------------------|------------------|------------------------------------------------------------------------------------------------------|
| Architecture/layers/technical design | Architecture diagram | [lark-whiteboard-cli/scenes/architecture.md](../lark-whiteboard-cli/scenes/architecture.md) |
| Process/approval/deployment/business flow | Flowchart | [lark-whiteboard-cli/scenes/flowchart.md](../lark-whiteboard-cli/scenes/flowchart.md) |
| Organization/hierarchy/reporting structure | Org chart | [lark-whiteboard-cli/scenes/organization.md](../lark-whiteboard-cli/scenes/organization.md) |
| Timeline/milestones/version roadmap | Milestone chart | [lark-whiteboard-cli/scenes/milestone.md](../lark-whiteboard-cli/scenes/milestone.md) |
| Cause-and-effect/retrospective/root cause analysis | Fishbone diagram | [lark-whiteboard-cli/scenes/fishbone.md](../lark-whiteboard-cli/scenes/fishbone.md) |
| Solution comparison/technology selection | Comparison diagram | [lark-whiteboard-cli/scenes/comparison.md](../lark-whiteboard-cli/scenes/comparison.md) |
| Cycle/flywheel/closed loop | Flywheel diagram | [lark-whiteboard-cli/scenes/flywheel.md](../lark-whiteboard-cli/scenes/flywheel.md) |
| Hierarchy/proportion/capability model | Pyramid diagram | [lark-whiteboard-cli/scenes/pyramid.md](../lark-whiteboard-cli/scenes/pyramid.md) |
| Module dependencies/call relationships | Architecture diagram | [lark-whiteboard-cli/scenes/architecture.md](../lark-whiteboard-cli/scenes/architecture.md) |
| Classification/knowledge taxonomy | Mind map | [lark-whiteboard-cli/scenes/mermaid.md](../lark-whiteboard-cli/scenes/mermaid.md) |
| Data distribution/proportion | Pie chart | [lark-whiteboard-cli/scenes/mermaid.md](../lark-whiteboard-cli/scenes/mermaid.md) |

Before creating a whiteboard, be sure to read both [`lark-whiteboard-cli`](../lark-whiteboard-cli/SKILL.md) and [`lark-whiteboard`](../lark-whiteboard/SKILL.md) to understand the whiteboard creation workflow.

### Complete Execution Flow (Must Be Fully Followed)

1. **Create a blank whiteboard placeholder**: Use `docs +create` for creation scenarios, `docs +update` for editing scenarios to insert a blank whiteboard
2. **Obtain the whiteboard token**: Get the whiteboard token list from `data.board_tokens` in the `docs +update` response
3. **Fill in whiteboard content**: Switch to [`lark-whiteboard-cli`](../lark-whiteboard-cli/SKILL.md) to create whiteboard content and populate the whiteboard
4. **Verify completion**: Confirm all whiteboards have actual content, not blank

**Not applicable**: Pure text records (logs/notes), data-intensive content (use tables), user explicitly wants text only.

> ⚠️ **Warning**: If you only create blank whiteboards without filling in content, the task will be considered incomplete!

## Additional Notes
`docs +search` serves not only as a search entry for documents / Wiki, but also as a resource discovery entry for "first locating Drive objects, then switching to the corresponding business skill for operations". When the user verbally mentions "spreadsheet / report", start here first.

## Shortcuts (Prefer Using These First)

Shortcuts are high-level wrappers for common operations (`lark-cli docs +<verb> [flags]`). Prefer using Shortcuts when available.

| Shortcut | Description |
|----------|-------------|
| [`+search`](references/lark-doc-search.md) | Search Lark docs, Wiki, and spreadsheet files (Search v2: doc_wiki/search) |
| [`+create`](references/lark-doc-create.md) | Create a Lark document |
| [`+fetch`](references/lark-doc-fetch.md) | Fetch Lark document content |
| [`+update`](references/lark-doc-update.md) | Update a Lark document |
| [`+media-insert`](references/lark-doc-media-insert.md) | Insert a local image or file at the end of a Lark document (4-step orchestration + auto-rollback) |
| [`+media-download`](references/lark-doc-media-download.md) | Download document media or whiteboard thumbnail (auto-detects extension) |
| [`+whiteboard-update`](references/lark-doc-whiteboard-update.md) | Update an existing whiteboard in lark document with whiteboard dsl. Such DSL input from stdin. refer to lark-whiteboard skill for more details. |
