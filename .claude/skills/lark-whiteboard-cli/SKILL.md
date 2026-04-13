---
name: lark-whiteboard-cli
description: >
  Use this skill when the user requests or needs to draw architecture diagrams, flowcharts, mind maps, sequence diagrams, or other visual charts on Lark Whiteboards. Acts as a guide for designing diagram layouts using whiteboard-cli.
compatibility: Requires Node.js 18+
metadata:
  requires:
    bins: ["lark-cli"]
---

> [!NOTE]
> **Environment dependency**: Drawing whiteboards requires `@larksuite/whiteboard-cli` (whiteboard Node.js CLI tool) and `lark-cli` (LarkSuite CLI tool).
> If execution fails, manually install and retry: `npm install -g @larksuite/whiteboard-cli@^0.2.0`

> [!IMPORTANT]
> Always obtain user consent before running `npm install` to install new dependencies!


## Workflow

> **This is a whiteboard, not a webpage.** A whiteboard is an infinite canvas where elements are placed freely; flex layout is an optional enhancement.

```
Step 1: Route & load knowledge
  - Determine the rendering path (see routing table): Mermaid or DSL?
  - Read the corresponding scene guide — understand structural characteristics and layout strategy
  - Determine layout strategy (see quick decision below) and construction approach
  - Read references/ core modules — syntax, layout, colors, typography, connectors

Step 2: Generate complete DSL (with colors)
  - Plan information volume and groupings per content.md
  - Select layout mode and spacing per layout.md
  - Consider using icons to make diagrams more intuitive; run `npx -y @larksuite/whiteboard-cli@^0.2.0 --icons` to see available icons; choose appropriate icons without overusing them — select based on diagram type and content
  - Apply colors per style.md (use the default classic palette when the user hasn't specified)
  - Output complete JSON per schema.md syntax
  - Connectors per connectors.md; typography per typography.md

  Note: Some shapes (fishbone/flywheel/bar-chart/line-chart, etc.) require writing a .js script per the scene guide's script template to generate JSON:
    1. Create artifact directory ./diagrams/YYYY-MM-DDTHHMMSS/
    2. Save the script as diagram.gen.js, run node diagram.gen.js to produce diagram.json
    3. Use the produced diagram.json to enter Step 3

Step 3: Render & review → deliver
  - Pre-render self-check (see checklist below)
  - Render PNG; check:
    · Is information complete? Is the layout reasonable? Is the color scheme harmonious?
    · Is any text truncated? Are any connectors crossing?
  - If issues found → fix per the symptom table → re-render (max 2 rounds)
  - If still seriously problematic after 2 rounds → consider falling back to Mermaid path
  - If no issues → deliver:
    · User requests upload to Lark → see "Upload to Lark Whiteboard" section below
    · User hasn't specified → display PNG image to the user
```

**Layout strategy quick decision** (see `references/layout.md` for details):

Determine the **primary layout** first, then sub-layouts: **structured information** preferably uses Flex, **relational chains** preferably use Dagre, **free positioning** uses absolute layout.

For specific boundaries between Dagre / Flex, dangerous patterns, and mixed layout principles, `references/layout.md` is the authoritative source; scene files only describe scenario differences and do not duplicate general layout rules.

> **Construction approach is a hard constraint**: When the scene guide requires "script generation," you MUST write a script (.js) and execute it with `node` to produce the JSON file. Absolute positioning scenarios (fishbone, flywheel, bar chart, line chart, etc.) require mathematical coordinate calculation; hand-writing JSON directly is extremely error-prone and will likely cause overlapping nodes or connector issues.

---

## Rendering Path Selection (DSL or Mermaid)

| Diagram Type | Path | Reason |
|-------------|------|--------|
| Mind map | **Mermaid** | Radial structure with auto-layout |
| Sequence diagram | **Mermaid** | Participants + messages auto-arranged |
| Class diagram | **Mermaid** | Class relationships auto-layout |
| Pie chart | **Mermaid** | Native Mermaid support |
| All other types | **DSL** | Precise style and layout control |

**Routing rules**:
1. **Auto Mermaid**: mind maps, sequence diagrams, class diagrams, pie charts → default to Mermaid
2. **Explicit Mermaid**: user input contains Mermaid syntax → use Mermaid
3. **DSL path**: all other types → read core modules first, then read the corresponding scene guide

**Mermaid path**: Refer to `scenes/mermaid.md` to write a `.mmd` file; skip DSL modules.
**DSL path**: Execute the 3-step Workflow.

---

## Module Index

### Core References (Required for DSL Path)

| Module | File | Description |
|--------|------|-------------|
| DSL syntax | `references/schema.md` | Node types, attributes, dimension values |
| Content planning | `references/content.md` | Information extraction, density decisions, connector pre-planning |
| Layout system | `references/layout.md` | Grid methodology, Flex mapping, spacing rules |
| Typography rules | `references/typography.md` | Font size levels, alignment, line spacing |
| Connector system | `references/connectors.md` | Topology planning, anchor selection |
| Color system | `references/style.md` | Multiple palettes, visual hierarchy |

### Scene Guides (Select One by Type)

| Diagram Type | File | Applicable Scenarios |
|-------------|------|---------------------|
| Architecture diagram | `scenes/architecture.md` | Layered architecture, microservices architecture |
| Org chart | `scenes/organization.md` | Company org, tree hierarchy |
| Swimlane diagram | `scenes/swimlane.md` | Cross-role flows, cross-system interaction flows, end-to-end chains |
| Comparison diagram | `scenes/comparison.md` | Solution comparison, feature matrix |
| Fishbone diagram | `scenes/fishbone.md` | Cause-effect analysis, root cause analysis |
| Bar chart | `scenes/bar-chart.md` | Bar charts, column charts |
| Line chart | `scenes/line-chart.md` | Line charts, trend charts |
| Treemap | `scenes/treemap.md` | Rectangular treemap, hierarchical proportions |
| Funnel chart | `scenes/funnel.md` | Conversion funnel, sales funnel |
| Pyramid diagram | `scenes/pyramid.md` | Hierarchical structure, needs hierarchy |
| Flywheel / cycle diagram | `scenes/flywheel.md` | Growth flywheel, closed-loop chain |
| Milestone | `scenes/milestone.md` | Timeline, version evolution |
| Flowchart | `scenes/flowchart.md` | Business flow, state machine, conditional chain |
| Mermaid | `scenes/mermaid.md` | Mind map, sequence diagram, class diagram, pie chart |

---

## Artifact File Conventions

Each drawing creates a subdirectory under `./diagrams/` named by current time (`YYYY-MM-DDTHHMMSS`); filenames within the directory are fixed. If the user specifies a save path, use the user's path.

```
./diagrams/
  2026-03-27T143000/      ← automatically created by timestamp; no naming needed
    diagram.json          ← DSL (CLI input)
    diagram.gen.js        ← coordinate calculation script (script construction only)
    diagram.png           ← final image
    diagram.mmd           ← Mermaid source (Mermaid path only)
```

## CLI Commands

**View available icons**:
```bash
npx -y @larksuite/whiteboard-cli@^0.2.0 --icons
```

**Render**:
```bash
npx -y @larksuite/whiteboard-cli@^0.2.0 -i ./diagrams/2026-03-27T143000/diagram.json -o ./diagrams/2026-03-27T143000/diagram.png    # DSL
npx -y @larksuite/whiteboard-cli@^0.2.0 -i ./diagrams/2026-03-27T143000/diagram.mmd -o ./diagrams/2026-03-27T143000/diagram.png     # Mermaid
```

**Upload to Lark Whiteboard**:

> Uploading requires Lark authentication. When encountering authentication or permission errors, read [`../lark-shared/SKILL.md`](../lark-shared/SKILL.md) for login and permission handling.

**Step 1: Get Whiteboard Token**

| What the user provides | How to get the token |
|----------------------|---------------------|
| Whiteboard token (`XXX`) | Use directly |
| Document URL or doc_id; document already has a whiteboard | `lark-cli docs +fetch --doc <URL> --as user`, extract token from the returned `<whiteboard token="XXX"/>` |
| Document URL or doc_id; need to create a new whiteboard | `lark-cli docs +update --doc <doc_id> --mode append --markdown '<whiteboard type="blank"></whiteboard>' --as user`, get token from `data.board_tokens[0]` in the response |

For more operations on creating and reading Lark documents, refer to the lark-doc skill [`../lark-doc/SKILL.md`](../lark-doc/SKILL.md).

**Step 2: Upload**

> [!CAUTION]
> **MANDATORY PRE-FLIGHT CHECK (required interception check before upload)**
> When writing content to an **existing whiteboard token**, you are **absolutely prohibited** from running the upload command directly! You MUST strictly follow these two steps:
> **Force a Dry Run (state probe)**
> You MUST first add `--overwrite --dry-run` to the command to probe the whiteboard's current state. Example command:
> ```bash
> npx -y @larksuite/whiteboard-cli@^0.2.0 --to openapi -i <input_file> --format json | lark-cli whiteboard +update --whiteboard-token <Token> --source - --overwrite --dry-run --as user
> ```
>
> **Parse results and intercept**
> - Carefully read the Dry Run output log.
> - **If the log contains `XX whiteboard nodes will be deleted`**: The whiteboard is **non-empty**, and the current operation will overwrite and destroy the user's existing diagram!
> - **You MUST immediately stop the operation** and ask the user via `AskUserQuestion` (or direct reply): "The target whiteboard is currently non-empty. Continuing will clear the existing XX nodes. Do you confirm the overwrite?"
> - Only after the user explicitly authorizes "confirm overwrite" can you remove `--dry-run` and actually execute the upload.
> - If the user requests a non-overwrite update, remove both `--overwrite` and `--dry-run` before uploading.

```bash
npx -y @larksuite/whiteboard-cli@^0.2.0 --to openapi -i <input_file> --format json | lark-cli whiteboard +update --whiteboard-token <whiteboard_token> --source - --yes --as user
```
> Once uploaded, a whiteboard cannot be modified. To upload as bot identity, replace `--as user` with `--as bot`.
> If the whiteboard is non-empty, add `--overwrite --dry-run` first to check the number of nodes to be deleted; confirm with the user before removing `--dry-run` to execute.

You can also output the layout as native OpenAPI JSON format, then import it into a Lark whiteboard via lark-cli. For more ways to operate whiteboards with lark-cli, refer to [../lark-whiteboard/SKILL.md](../lark-whiteboard/SKILL.md).

**Symptom → Fix Table** (refer to this when visual review finds issues):

| Issue Observed | What to Change |
|---------------|---------------|
| Text is truncated | Change height to fit-content |
| Text overflows the container's right side | Increase width, or shorten the text |
| Nodes overlap or stick together | Increase gap |
| Nodes crammed together | Increase padding and gap |
| Connectors pass through nodes | Adjust fromAnchor/toAnchor or increase spacing |
| Large areas of white space | Reduce the outer frame width |
| Text and background color too similar | Adjust fillColor or textColor |
| Layout is shifted left/right overall | Adjust absolute position x-coordinates to center content |

---

## Pre-Render Checklist

After generating DSL and before rendering, quick checks:

- [ ] Different groups use different colors? Nodes within the same group have completely consistent styles?
- [ ] Outer containers use light backgrounds; inner nodes use white? (outer heavy, inner light)
- [ ] All nodes have a border (borderWidth=2)? Text is clearly readable on the background?
- [ ] Connectors use gray (#BBBFC4) — not colorful?
- [ ] All frames have a layout attribute? Are gap and padding explicitly set?
- [ ] Text-containing nodes use fit-content for height? Connectors are in the top-level nodes array?

---

## Key Constraints Quick Reference

> The most frequently violated rules — must be followed even without reading sub-module files.

1. **Text-containing nodes MUST use `'fit-content'` for height** — hardcoding a numeric value will truncate text
2. **`fill-container` only works inside a flex parent container** — under `layout: 'none'`, width degrades to 0
3. **Containers with `layout: 'none'` MUST have fixed width and height** — do not write fit-content
4. **Connectors MUST be in the top-level nodes array** — cannot be nested inside frame children
5. **Layer order** — array order = drawing order. Later-defined elements have higher z-order and will cover earlier-defined ones. Overlapping/floating/annotation elements MUST be placed at the end of the array.
6. **x/y inside flex containers are completely ignored** — use `layout: 'none'` or top-level nodes for free positioning
7. **Dagre sub-containers are opaque nodes by default** — outer connectors cannot address their inner child nodes (engine auto-redirects to the shell). To allow penetration, declare `layout: "dagre"` + `layoutOptions: { isCluster: true }`

❌ Fatal error: setting x/y inside a flex container — coordinates take no effect; nodes are arranged in order
```json
{ "type": "frame", "layout": "vertical", "children": [
  { "type": "rect", "x": 100, "y": 0, "text": "Chengdu" },
  { "type": "rect", "x": 540, "y": 0, "text": "Kangding" }
]}
```
✅ Correct: use `layout: "none"` or place nodes in the top-level nodes array with x/y for positioning.

❌ Fatal error: writing `width: "fit-content", height: "fit-content"` on a `layout: "none"` container itself, then placing absolutely-positioned child nodes inside

✅ Correct: give the absolute-positioning container fixed width/height first, then place child nodes inside with x/y.
