---
name: lark-slides
version: 1.0.0
description: "Lark Slides (Presentations): read and manage PPT pages in XML format. Prefer `+create` for creating presentations; the XML API is mainly used to read full PPT content and create/delete slide pages. Use when the user needs to create a PPT, read PPT content, or manage slide pages."
metadata:
  requires:
    bins: ["lark-cli"]
  cliHelp: "lark-cli slides --help"
---

# slides (v1)

**CRITICAL — Before starting, MUST use the Read tool to read [`../lark-shared/SKILL.md`](../lark-shared/SKILL.md). It contains authentication and permission handling.**

**CRITICAL — Before generating any XML, MUST use the Read tool to read [xml-schema-quick-ref.md](references/xml-schema-quick-ref.md). Never guess XML structure from memory.**

## Identity Selection

Lark Slides are typically the user's own content resources. **Default to explicitly using `--as user` (user identity) for slides operations**, always specifying identity explicitly.

- **`--as user` (recommended)**: Create, read, and manage presentations as the currently logged-in user. Complete user authorization first:

```bash
lark-cli auth login --domain slides
```

- **`--as bot`**: Only use when the user explicitly requests bot identity operations, or when the workflow specifically requires the bot to hold/create resources. When using bot identity, also confirm whether the bot actually has access to the target presentation.

**Execution rules**:

1. Creating, reading, adding/deleting slides, or continuing to edit an existing PPT from a user-provided link — default to `--as user`.
2. If a permission error occurs, first check whether bot identity was mistakenly used; do not default to falling back to bot.
3. Only switch to `--as bot` when the user explicitly requests "use bot/app identity," or when the current workflow specifically requires the bot to create resources for subsequent collaborative access.

## Quick Start

Create a PPT with page content in one command (recommended):

```bash
lark-cli slides +create --title "Presentation Title" --slides '[
  "<slide xmlns=\"http://www.larkoffice.com/sml/2.0\"><style><fill><fillColor color=\"rgb(245,245,245)\"/></fill></style><data><shape type=\"text\" topLeftX=\"80\" topLeftY=\"80\" width=\"800\" height=\"100\"><content textType=\"title\"><p>Page Title</p></content></shape><shape type=\"text\" topLeftX=\"80\" topLeftY=\"200\" width=\"800\" height=\"200\"><content textType=\"body\"><p>Body content</p><ul><li><p>Point 1</p></li><li><p>Point 2</p></li></ul></content></shape></data></slide>"
]'
```

Two-step approach also works (create an empty PPT first, then add pages one by one). See [+create reference](references/lark-slides-create.md).

> The above is a minimal working example. For richer page effects (gradient backgrounds, cards, charts, tables, etc.), refer to the Workflow and XML templates below.

## Required Pre-Steps

> **Important**: `references/slides_xml_schema_definition.xml` is the only authoritative XML protocol source for this skill; other `.md` files are only summaries of it and the CLI schema.

### Must-Read (Before Each Creation)

| Document | Description |
|---------|-------------|
| [xml-schema-quick-ref.md](references/xml-schema-quick-ref.md) | **XML elements and attributes quick reference — required reading** |

### Optional (Consult When Needed)

| Scenario | Document |
|----------|---------|
| Need detailed XML structure | [xml-format-guide.md](references/xml-format-guide.md) |
| Need CLI call examples | [examples.md](references/examples.md) |
| Need a real PPT XML sample | [slides_demo.xml](references/slides_demo.xml) |
| Need complex elements (table/chart, etc.) | [slides_xml_schema_definition.xml](references/slides_xml_schema_definition.xml) (full schema) |
| Need detailed parameter info for a command | Corresponding command reference document (see below) |

## Workflow

> **This is a presentation, not a document.** Each slide is an independent visual canvas — information density should be low, with visual breathing room.

```text
Step 1: Clarify requirements & load knowledge
  - Clarify user requirements: topic, audience, page count, style preference
  - If no explicit style, recommend based on topic (see style quick-reference table below)
  - Read XML schema references:
    · xml-schema-quick-ref.md — elements and attributes quick reference
    · xml-format-guide.md — detailed structure and examples
    · slides_demo.xml — real XML samples

Step 2: Generate outline → confirm with user → create
  - Generate a structured outline (page title + key points + layout description) and confirm with user
  - 10 pages or fewer: use slides +create --slides '[...]' to create the PPT and add all pages in one step
  - More than 10 pages: create an empty PPT with slides +create first, then add pages one by one with xml_presentation.slide.create
  - Each slide needs complete XML: background, text, shapes, color scheme
  - Complex elements (table, chart) require referencing the XSD source

Step 3: Review & deliver
  - After creation, read the full XML with xml_presentations.get and verify:
    · Is the page count correct? Is each page's content complete?
    · Is the color scheme consistent? Are font size levels reasonable?
  - If issues found → delete problem pages with xml_presentation.slide.delete, recreate
  - If no issues → deliver: inform the user of the presentation ID and how to access it
```

### jq Command Template (When Editing an Existing PPT)

New PPTs should use `+create --slides`. The following jq template is for appending pages to an existing presentation to avoid manual double-quote escaping:

```bash
lark-cli slides xml_presentation.slide create \
  --as user \
  --params '{"xml_presentation_id":"YOUR_ID"}' \
  --data "$(jq -n --arg content '<slide xmlns="http://www.larkoffice.com/sml/2.0">
  <style><fill><fillColor color="BACKGROUND_COLOR"/></fill></style>
  <data>
    Place shape, line, table, chart, and other elements here
  </data>
</slide>' '{slide:{content:$content}}')"
```

### Style Quick-Reference Table

> **Note**: Gradient colors MUST use `rgba()` format with percentage stop points, e.g., `linear-gradient(135deg,rgba(15,23,42,1) 0%,rgba(56,97,140,1) 100%)`. Using `rgb()` or omitting stop points will cause the server to fall back to white.

| Scenario/Topic | Recommended Style | Background | Primary Color | Text Color |
|---------------|------------------|-----------|--------------|-----------|
| Tech/AI/Product | Dark tech | Deep blue gradient `linear-gradient(135deg,rgba(15,23,42,1) 0%,rgba(56,97,140,1) 100%)` | Blue `rgb(59,130,246)` | White |
| Business report/quarterly summary | Light business | Light gray `rgb(248,250,252)` | Dark blue `rgb(30,60,114)` | Dark gray `rgb(30,41,59)` |
| Education/training | Fresh bright | White `rgb(255,255,255)` | Green `rgb(34,197,94)` | Dark gray `rgb(51,65,85)` |
| Creative/design | Gradient vibrant | Purple-pink gradient `linear-gradient(135deg,rgba(88,28,135,1) 0%,rgba(190,24,93,1) 100%)` | Pink-purple | White |
| Weekly report/daily updates | Clean professional | Light gray `rgb(248,250,252)` + top color gradient strip | Blue `rgb(59,130,246)` | Dark `rgb(15,23,42)` |
| User unspecified | Default clean professional | Same as above | Same as above | Same as above |

### Page Layout Guide

| Page Type | Layout Key Points |
|-----------|------------------|
| Cover page | Centered large title + subtitle + bottom info; use gradient or dark background |
| Data overview | Metric cards in a row (rect background + large numbers + small description), chart or list below |
| Content page | Left vertical line decoration + title, columns or list below |
| Comparison/table | table element or side-by-side cards; header with dark background and white text |
| Chart page | chart element (column/line/pie) with text annotation |
| End page | Centered thank-you text + decorative line; style echoes the cover |

### Outline Template

Use this format to generate and confirm an outline with the user:

```text
[PPT Title] — [positioning description], targeting [audience]

Page structure (N pages):
1. Cover: [title text]
2. [Page topic]: [point 1], [point 2], [point 3]
3. [Page topic]: [point description]
...
N. End page: [closing text]

Style: [color scheme], [layout style]
```

### Common Slide XML Templates

Ready-to-use templates (cover page, content page, data card page, end page): [slide-templates.md](references/slide-templates.md)

---

## Core Concepts

### URL Formats and Tokens

| URL Format | Example | Token Type | Handling |
|------------|---------|-----------|----------|
| `/slides/` | `https://example.larkoffice.com/slides/xxxxxxxxxxxxx` | `xml_presentation_id` | The token in the URL path is used directly as `xml_presentation_id` |
| `/wiki/` | `https://example.larkoffice.com/wiki/wikcnxxxxxxxxx` | `wiki_token` | ⚠️ **Cannot be used directly** — must query to obtain the actual `obj_token` |

### Special Handling for Wiki Links (Important!)

Wiki links (`/wiki/TOKEN`) may point to different document types — cloud documents, spreadsheets, slides, etc. **Do not assume the token in the URL is `xml_presentation_id`.** You must first query the actual type and real token.

#### Processing Flow

1. **Use `wiki.spaces.get_node` to query node information**
   ```bash
   lark-cli wiki spaces get_node --as user --params '{"token":"wiki_token"}'
   ```

2. **Extract key information from the result**
   - `node.obj_type`: Document type; slides correspond to `slides`
   - `node.obj_token`: **The real presentation token** (used for subsequent operations)
   - `node.title`: Document title

3. **Confirm `obj_type` is `slides`, then use `obj_token` as `xml_presentation_id`**

#### Query Example

```bash
# Query a wiki node
lark-cli wiki spaces get_node --as user --params '{"token":"wikcnxxxxxxxxx"}'
```

Example response:
```json
{
   "node": {
      "obj_type": "slides",
      "obj_token": "xxxxxxxxxxxx",
      "title": "2026 Annual Product Summary",
      "node_type": "origin",
      "space_id": "1234567890"
   }
}
```

```bash
# Use obj_token to read slide content
lark-cli slides xml_presentations get --as user --params '{"xml_presentation_id":"xxxxxxxxxxxx"}'
```

### Resource Relationships

```text
Wiki Space
└── Wiki Node (obj_type: slides)
    └── obj_token → xml_presentation_id

Slides (Presentation)
├── xml_presentation_id (unique identifier)
├── revision_id (version number)
└── Slide (page)
    └── slide_id (page unique identifier)
```

## Shortcuts (Prefer Using These First)

Shortcuts are high-level wrappers for common operations (`lark-cli slides +<verb> [flags]`). Prefer Shortcuts when available.

| Shortcut | Description |
|----------|-------------|
| [`+create`](references/lark-slides-create.md) | Create a PPT (optional `--slides` to add pages in one step); bot mode auto-authorizes |

## API Resources

```bash
lark-cli schema slides.<resource>.<method>    # Check parameter structure before calling any API
lark-cli slides <resource> <method> [flags]   # Call the API
```

> **Important**: When using native APIs, always run `schema` first to inspect `--data` / `--params` structure. Do not guess field formats.

### xml_presentations

  - `get` — Read the full PPT content; returns in XML format

### xml_presentation.slide

  - `create` — Create a page in a specified XML presentation
  - `delete` — Delete a page from a specified XML presentation

## Core Rules

1. **Draft the outline first**: Generate and confirm an outline with the user before creating a PPT to avoid rework.
2. **Creation flow**: For 10 pages or fewer, use `slides +create --slides '[...]'` to create in one step; for more than 10 pages, first create an empty PPT with `slides +create`, then add pages one by one with `xml_presentation.slide.create`.
3. **`<slide>` direct children are only `<style>`, `<data>`, and `<note>`**: Text and shapes must be placed inside `<data>`.
4. **Text is expressed via `<content>`**: Must use `<content><p>...</p></content>`; never put text directly inside a shape.
5. **Save key IDs**: Subsequent operations need `xml_presentation_id`, `slide_id`, and `revision_id`.
6. **Deletion is irreversible**: At least one slide page must be retained in a presentation.

## Permissions Table

| Method | Required Scope |
|--------|---------------|
| `slides +create` | `slides:presentation:create`, `slides:presentation:write_only` |
| `xml_presentations.get` | `slides:presentation:read` |
| `xml_presentation.slide.create` | `slides:presentation:update` or `slides:presentation:write_only` |
| `xml_presentation.slide.delete` | `slides:presentation:update` or `slides:presentation:write_only` |

## Common Error Reference

| Error Code | Meaning | Solution |
|-----------|---------|----------|
| 400 | XML format error | Check XML syntax; ensure all tags are closed |
| 400 | Create content exceeds supported range | `xml_presentations.create` is only for creating empty PPTs; do not pass full slide content here |
| 400 | Request wrapper error | Check that `--data` passes `xml_presentation.content` or `slide.content` per the schema |
| 404 | Presentation does not exist | Check that `xml_presentation_id` is correct |
| 404 | Slide page does not exist | Check that `slide_id` is correct |
| 403 | Insufficient permissions | Check that you have the corresponding scope |
| 400 | Cannot delete the only slide | A presentation must retain at least one page |

## Pre-Creation Checklist

Quick checks before generating slide XML for each page:

- [ ] Is each page's background color/gradient set? Is it consistent with the overall style?
- [ ] Are titles in large font (28-48pt), body text in small font (13-16pt), with clear hierarchy?
- [ ] Are similar elements using consistent colors? (e.g., all metric cards in the same color family, all body text the same color)
- [ ] Are decorative elements (dividers, color blocks, vertical lines) in colors that match the primary color?
- [ ] Are text box dimensions large enough for the content? (width × height)
- [ ] Is the shape `type` correct? (text boxes use `text`, decorations use `rect`)
- [ ] Are all XML tags properly closed? Are special characters (`&`, `<`, `>`) escaped?

## Symptom → Fix Table

| Issue Observed | What to Change |
|---------------|---------------|
| Text is cut off / not fully visible | Increase the shape's `width` or `height` |
| Elements overlap | Adjust `topLeftX`/`topLeftY`; increase spacing |
| Large areas of white space | Reduce element spacing, or add more content |
| Text and background color too similar | Use light text on dark background; dark text on light background |
| Table column widths unbalanced | Adjust the `width` of `col` in `colgroup` |
| Chart not showing | Check that both `chartPlotArea` and `chartData` are present; check that `dim1`/`dim2` data counts match |
| Gradient background appears white | Gradient MUST use `rgba()` format + percentage stop points, e.g., `linear-gradient(135deg,rgba(30,60,114,1) 0%,rgba(59,130,246,1) 100%)`; using `rgb()` or omitting stop points causes fallback to white |
| Gradient direction incorrect | Adjust the angle in `linear-gradient` (`90deg` = horizontal, `180deg` = vertical, `135deg` = diagonal) |
| Overall style inconsistent | Use the same background for cover and end pages; maintain consistent color scheme and font size levels throughout content pages |
| API returns 400 | Check XML syntax: tag closure, attribute quotes, special character escaping |
| API returns 3350001 | `xml_presentation_id` was not created via `xml_presentations.create`, or the token is incorrect |

## Reference Documents

| Document | Description |
|---------|-------------|
| [lark-slides-create.md](references/lark-slides-create.md) | **+create Shortcut: create a PPT (supports `--slides` to add pages in one step)** |
| [xml-schema-quick-ref.md](references/xml-schema-quick-ref.md) | **XML Schema condensed quick reference (required reading)** |
| [slide-templates.md](references/slide-templates.md) | Ready-to-copy Slide XML templates |
| [xml-format-guide.md](references/xml-format-guide.md) | Detailed XML structure and examples |
| [examples.md](references/examples.md) | CLI call examples |
| [slides_demo.xml](references/slides_demo.xml) | Complete XML of a real PPT |
| [slides_xml_schema_definition.xml](references/slides_xml_schema_definition.xml) | **Full schema definition** (the only authoritative protocol reference) |
| [lark-slides-xml-presentations-create.md](references/lark-slides-xml-presentations-create.md) | Create empty PPT command details |
| [lark-slides-xml-presentations-get.md](references/lark-slides-xml-presentations-get.md) | Read PPT command details |
| [lark-slides-xml-presentation-slide-create.md](references/lark-slides-xml-presentation-slide-create.md) | Add slide command details |
| [lark-slides-xml-presentation-slide-delete.md](references/lark-slides-xml-presentation-slide-delete.md) | Delete slide command details |

> **Note**: If md content conflicts with `slides_xml_schema_definition.xml` or `lark-cli schema slides.<resource>.<method>` output, the latter two take precedence.
