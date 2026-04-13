---
name: lark-whiteboard
version: 1.0.0
description: >
  Lark Whiteboard: query and edit whiteboards in Lark cloud documents. Supports exporting whiteboards as preview images, exporting raw node structures, and updating whiteboard content using PlantUML/Mermaid code or native OpenAPI format.
  Use this skill when the user needs to view whiteboard content, export whiteboard images, or edit a whiteboard, or when visually expressing architecture, flows, org structures, timelines, cause-and-effect, comparisons, or other structured information — regardless of whether "whiteboard" is explicitly mentioned.
metadata:
  requires:
    bins: [ "lark-cli" ]
  cliHelp: "lark-cli whiteboard --help"
---

# whiteboard (v1)

**CRITICAL — Before starting, MUST use the Read tool to read [`../lark-shared/SKILL.md`](../lark-shared/SKILL.md). It contains authentication and permission handling.**

## Core Concepts

### Whiteboard Token

The whiteboard token is the unique identifier for a whiteboard. Lark whiteboards are embedded in cloud documents; the token can be obtained from the `docs +fetch` result (`<whiteboard token="xxx"/>` tag) or from the `data.board_tokens` field after creating a whiteboard with `docs +update`.

## Quick Decision Guide

When inserting a diagram:

1. Can a Lark whiteboard be used?
    - Yes → take the whiteboard path (recommended — editable, collaborative)
    - No → take the image path

| User Need | Recommended Shortcut |
|-----------|---------------------|
| "View the content of this whiteboard" | [`+query --output_as image`](references/lark-whiteboard-query.md) |
| "Export whiteboard as an image" | [`+query --output_as image`](references/lark-whiteboard-query.md) |
| "Get the PlantUML/Mermaid code of this whiteboard" | [`+query --output_as code`](references/lark-whiteboard-query.md) |
| "Check if the whiteboard is composed of PlantUML/Mermaid code blocks" | [`+query --output_as code`](references/lark-whiteboard-query.md) |
| "Modify the color or text of a node in the whiteboard" | [`+query --output_as raw`](references/lark-whiteboard-query.md) then [`+update`](references/lark-whiteboard-update.md) |
| "Draw the whiteboard with PlantUML" | [`+update --input_format plantuml`](references/lark-whiteboard-update.md) |
| "Draw the whiteboard with Mermaid" | [`+update --input_format mermaid`](references/lark-whiteboard-update.md) |
| "Draw a complex diagram on the whiteboard" | [`+update --input_format raw`](references/lark-whiteboard-update.md), needs whiteboard-cli tool — see [lark-whiteboard-cli](../lark-whiteboard-cli/SKILL.md) |

## Shortcuts

| Shortcut | Description |
|----------|-------------|
| [`+query`](references/lark-whiteboard-query.md) | Query a whiteboard; export as preview image, code, or raw node structure |
| [`+update`](references/lark-whiteboard-update.md) | Update whiteboard content; supports PlantUML, Mermaid, or native OpenAPI format input |

## Workflow

### Scenario 1: Create a Whiteboard

1. Determine the whiteboard token (from user request or associated document) and the content to create
2. Refer to [lark-whiteboard-cli](../lark-whiteboard-cli/SKILL.md) to generate whiteboard content
3. Use [`+update`](references/lark-whiteboard-update.md) to update the whiteboard content

### Scenario 2: Modify or Optimize a Whiteboard

1. Determine the token of the whiteboard to modify (from user request or associated document)
2. Use [`+query --output_as code`](references/lark-whiteboard-query.md) to export the whiteboard code; check if the whiteboard was drawn with Mermaid or PlantUML
    1. If `+query --output_as code` returns a Mermaid / PlantUML code block, optimize and modify based on that code
    2. If no code block is returned, use [`+query --output_as image`](references/lark-whiteboard-query.md) to get the whiteboard preview image; redraw and optimize based on the image content, referring to [lark-whiteboard-cli](../lark-whiteboard-cli/SKILL.md)
    3. If the user only needs simple text content/color changes on a node, use [`+query --output_as raw`](references/lark-whiteboard-query.md) to export the native OpenAPI format and modify from there
    4. If the user has explicit requirements, user requirements take priority
3. Use [`+update`](references/lark-whiteboard-update.md) to create new whiteboard content. Depending on user needs, you may need to use [`docs +update`](../lark-doc/references/lark-doc-update.md) to create a new whiteboard, or use [`+update --overwrite`](references/lark-whiteboard-update.md) to overwrite-update the existing whiteboard

## Working with lark-doc

### Scenario 1: Get Whiteboard Token from a Document

1. Use `lark-doc`'s [`+fetch`](../lark-doc/references/lark-doc-fetch.md) to get document content
2. Parse the `<whiteboard token="xxx"/>` tag from the returned markdown and record the whiteboard token
3. Use this skill's `+query` or `+update` to read or edit the whiteboard

### Scenario 2: Create a New Whiteboard and Edit It (Full Flow)

This is the most common use case. **You MUST follow these steps completely**:

1. Use `lark-doc`'s [`+update`](../lark-doc/references/lark-doc-update.md) to create a blank whiteboard
    - Pass `<whiteboard type="blank"></whiteboard>` in the markdown
    - **Note: do not escape this XML tag**
    - When multiple whiteboards are needed, repeat multiple whiteboard tags

2. Get the token list of the newly created whiteboards from `data.board_tokens` in the response
    - Record the diagram type and position each token corresponds to

3. Design appropriate content for each whiteboard based on the document topic
    - Refer to the "Common Diagram Templates and Reference Guides" below to choose appropriate syntax
    - Use Mermaid (recommended), PlantUML, or [lark-whiteboard-cli](../lark-whiteboard-cli/SKILL.md) to generate content

4. **Update each whiteboard one by one**: Use this skill's `+update` shortcut to edit each whiteboard's content
    - Do not skip any whiteboard token
    - Ensure every whiteboard has actual content — none should be left blank

### Common Diagram Templates and Reference Guides

| Diagram Type | Recommended Syntax | Detailed Reference Guide |
|-------------|-------------------|------------------------|
| Architecture diagram | whiteboard-cli DSL | [lark-whiteboard-cli/scenes/architecture.md](../lark-whiteboard-cli/scenes/architecture.md) |
| Flowchart | whiteboard-cli DSL | [lark-whiteboard-cli/scenes/flowchart.md](../lark-whiteboard-cli/scenes/flowchart.md) |
| Org chart | whiteboard-cli DSL | [lark-whiteboard-cli/scenes/organization.md](../lark-whiteboard-cli/scenes/organization.md) |
| Milestone / timeline | whiteboard-cli DSL | [lark-whiteboard-cli/scenes/milestone.md](../lark-whiteboard-cli/scenes/milestone.md) |
| Fishbone diagram | whiteboard-cli DSL | [lark-whiteboard-cli/scenes/fishbone.md](../lark-whiteboard-cli/scenes/fishbone.md) |
| Comparison diagram | whiteboard-cli DSL | [lark-whiteboard-cli/scenes/comparison.md](../lark-whiteboard-cli/scenes/comparison.md) |
| Flywheel diagram | whiteboard-cli DSL | [lark-whiteboard-cli/scenes/flywheel.md](../lark-whiteboard-cli/scenes/flywheel.md) |
| Pyramid diagram | whiteboard-cli DSL | [lark-whiteboard-cli/scenes/pyramid.md](../lark-whiteboard-cli/scenes/pyramid.md) |
| Mind map / pie chart / sequence diagram / class diagram | Mermaid | [lark-whiteboard-cli/scenes/mermaid.md](../lark-whiteboard-cli/scenes/mermaid.md) |
| Bar chart | whiteboard-cli DSL | [lark-whiteboard-cli/scenes/bar-chart.md](../lark-whiteboard-cli/scenes/bar-chart.md) |
| Line chart | whiteboard-cli DSL | [lark-whiteboard-cli/scenes/line-chart.md](../lark-whiteboard-cli/scenes/line-chart.md) |
| Treemap | whiteboard-cli DSL | [lark-whiteboard-cli/scenes/treemap.md](../lark-whiteboard-cli/scenes/treemap.md) |
| Funnel chart | whiteboard-cli DSL | [lark-whiteboard-cli/scenes/funnel.md](../lark-whiteboard-cli/scenes/funnel.md) |
| Swimlane diagram | whiteboard-cli DSL | [lark-whiteboard-cli/scenes/swimlane.md](../lark-whiteboard-cli/scenes/swimlane.md) |
