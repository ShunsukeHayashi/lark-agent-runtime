---
name: lark-base
version: 1.3.0
description: "Use when operating Lark Base (multi-dimensional tables) with lark-cli: create tables, manage fields, read/write records, configure views, query history, and manage roles/forms/dashboards/workflows. Also use to migrate from legacy +table/+field/+record syntax to current command style. Required for field design, formula fields, lookup references, cross-table calculations, row-level derived metrics, and data analysis. Includes API-verified SFA/CRM design conventions."
metadata:
  requires:
    bins: ["lark-cli"]
  cliHelp: "lark-cli base --help"
---

# base

> **Prerequisite:** Read [`../lark-shared/SKILL.md`](../lark-shared/SKILL.md) first.
> **Before executing:** Always read the reference doc for the target command before running it.
> **Naming convention:** Use only `lark-cli base +...` shortcut form for Base operations. To resolve Wiki links, call `lark-cli wiki ...` first.
> **Routing rule:** If the user wants to "import a local file into Base/bitable", the first step is NOT `base` — use `lark-cli drive +import --type bitable` first; then return to `lark-cli base +...` for table operations after import.

## 1. When to Use This Skill

### 1.1 Trigger Conditions

Use this skill when:

- The user explicitly wants to operate Lark Base / multi-dimensional tables.
- The user wants to create, modify, query, or delete tables, fields, records, or views.
- The user wants formula fields, lookup fields, derived metrics, or cross-table calculations.
- The user wants ad-hoc aggregation, grouping, sorting, or min/max analysis.
- The user wants to manage workflows, dashboards, forms, or role permissions.
- The user provides a `/base/{token}` link.
- The user provides a `/wiki/{token}` link that resolves to `bitable`.
- The user wants to migrate old-style Base aggregate commands to current atomic commands (e.g. `+table / +field / +record / +view / +history / +workspace`).

Do NOT use this skill when:

- The user only needs authentication, config init, `--as user/bot` switching, or scope management — read `../lark-shared/SKILL.md` instead.
- The user is discussing "data analysis / field design" generically without a Base context.

### 1.2 Prerequisites

1. Read [`../lark-shared/SKILL.md`](../lark-shared/SKILL.md).
2. Use only `lark-cli base +...` shortcut commands. If the input is a Wiki link, resolve it with `lark-cli wiki spaces get_node` first.
3. After identifying the command, read its reference doc before executing.
4. If the user wants to import local Excel/CSV into Base, the first step is `lark-cli drive +import --type bitable`; resume `lark-cli base +...` after import.
5. Do not switch to `lark-cli api /open-apis/bitable/v1/...` in Base contexts.

## 2. Module and Command Navigation

Select the module first, then the command. Determine which module the user's goal belongs to, enter it, read the reference, then execute.

### 2.1 Module Map

| Module | What it handles | Sub-modules / capabilities |
|--------|----------------|---------------------------|
| Base module | Manage the Base itself, or enter Base context from a link | `base-create / base-get / base-copy`, Base/Wiki link resolution |
| Tables & Data module | Manage internal structure and daily data operations | `table / field / record / view` |
| Formula / Lookup module | Derived fields, conditionals, cross-table calculations, fixed lookup references | `formula / lookup` field creation and update |
| Data Analysis module | One-time filtering, grouping, aggregation | `data-query` |
| Workflow module | Manage automation flows | `workflow-list / get / create / update / enable / disable` |
| Dashboard module | Manage dashboards and chart blocks | `dashboard-* / dashboard-block-*` |
| Form module | Manage forms and form questions | `form-* / form-questions-*` |
| Permissions & Roles module | Manage advanced permissions and custom roles | `advperm-* / role-*` |

### 2.2 Base Module

For managing the Base itself, or entering Base operations from a user-provided link.
Module index: [`references/lark-base-workspace.md`](references/lark-base-workspace.md)

| Command | Purpose / When to use | Required reference | Notes |
|---------|----------------------|--------------------|-------|
| `+base-create` | Create a new Base | [`lark-base-base-create.md`](references/lark-base-base-create.md), [`lark-base-workspace.md`](references/lark-base-workspace.md) | Write op; read reference first; `--folder-token` and `--time-zone` are optional |
| `+base-get` | Get Base metadata | [`lark-base-base-get.md`](references/lark-base-base-get.md), [`lark-base-workspace.md`](references/lark-base-workspace.md) | Good for confirming Base identity; does not replace table/field structure reads |
| `+base-copy` | Copy an existing Base | [`lark-base-base-copy.md`](references/lark-base-base-copy.md), [`lark-base-workspace.md`](references/lark-base-workspace.md) | Write op; read reference first; return new Base identifiers on success |

### 2.3 Tables & Data Module

The most commonly used module, covering `table / field / record / view`.
Supplemental examples: [`references/examples.md`](references/examples.md) — read when you need a full table/record/view operation chain.

#### 2.3.1 Table Sub-module

Sub-module index: [`references/lark-base-table.md`](references/lark-base-table.md)

| Command | Purpose / When to use | Required reference | Notes |
|---------|----------------------|--------------------|-------|
| `+table-list / +table-get` | List tables or get details of a single table | [`lark-base-table-list.md`](references/lark-base-table-list.md), [`lark-base-table-get.md`](references/lark-base-table-get.md) | `+table-list` must run serially; `+table-get` is good before delete/update |
| `+table-create / +table-update / +table-delete` | Create, update, or delete a table | [`lark-base-table-create.md`](references/lark-base-table-create.md), [`lark-base-table-update.md`](references/lark-base-table-update.md), [`lark-base-table-delete.md`](references/lark-base-table-delete.md) | For creation, use when building a table in one shot; confirm target before update; use `--yes` when user has clearly confirmed deletion |

#### 2.3.2 Field Sub-module

For regular field management. If the field type is `formula` or `lookup`, go to the Formula/Lookup module below.
Sub-module index: [`references/lark-base-field.md`](references/lark-base-field.md)

| Command | Purpose / When to use | Required reference | Notes |
|---------|----------------------|--------------------|-------|
| `+field-list / +field-get` | List fields or get details of a single field | [`lark-base-field-list.md`](references/lark-base-field-list.md), [`lark-base-field-get.md`](references/lark-base-field-get.md) | Run `+field-list` before writing records/fields or doing analysis; must run serially; `+field-get` is good before delete/update |
| `+field-create / +field-update / +field-delete` | Create, update, or delete a regular field | [`lark-base-field-create.md`](references/lark-base-field-create.md), [`lark-base-field-update.md`](references/lark-base-field-update.md), [`lark-base-field-delete.md`](references/lark-base-field-delete.md), [`lark-base-shortcut-field-properties.md`](references/lark-base-shortcut-field-properties.md) | Read field property spec before writing; if type is `formula/lookup`, go to the guide first; use `--yes` when user has clearly confirmed deletion |
| `+field-search-options` | Query selectable options for a field | [`lark-base-field-search-options.md`](references/lark-base-field-search-options.md) | For single-select / multi-select fields |

#### 2.3.3 Record Sub-module

Sub-module index: [`references/lark-base-record.md`](references/lark-base-record.md), [`references/lark-base-history.md`](references/lark-base-history.md)

| Command | Purpose / When to use | Required reference | Notes |
|---------|----------------------|--------------------|-------|
| `+record-search / +record-list / +record-get` | Search records by keyword, list/export records with pagination, or get a single record | [`lark-base-record-search.md`](references/lark-base-record-search.md), [`lark-base-record-list.md`](references/lark-base-record-list.md), [`lark-base-record-get.md`](references/lark-base-record-get.md) | Default to `+record-list`; use `+record-search` only when user provides explicit keywords; do not use for aggregation; max `--limit` is `200`; paginate only when user explicitly requests more; `+record-list` must run serially |
| `+record-upsert / +record-batch-create / +record-batch-update` | Create, update, or batch-write records | [`lark-base-record-upsert.md`](references/lark-base-record-upsert.md), [`lark-base-record-batch-create.md`](references/lark-base-record-batch-create.md), [`lark-base-record-batch-update.md`](references/lark-base-record-batch-update.md), [`lark-base-shortcut-record-value.md`](references/lark-base-shortcut-record-value.md) | Run `+field-list` first; write only storage fields; max 500 records per batch; do not use for attachments |
| `+record-upload-attachment` | Upload an attachment to an existing record | [`lark-base-record-upload-attachment.md`](references/lark-base-record-upload-attachment.md) | Dedicated attachment upload path; do not fake attachment values in `+record-upsert` / `+record-batch-*` |
| `lark-cli docs +media-download` | Download a Base attachment to local disk | [`../lark-doc/references/lark-doc-media-download.md`](../lark-doc/references/lark-doc-media-download.md) | Get `file_token` from the attachment array returned by `+record-get`; **do not use `lark-cli drive +download`** (returns 403 for Base attachments) |
| `+record-delete / +record-history-list` | Delete a record, or query change history for a record | [`lark-base-record-delete.md`](references/lark-base-record-delete.md), [`lark-base-record-history-list.md`](references/lark-base-record-history-list.md) | Use `--yes` when target is clear; history query uses `table-id + record-id`; full-table scan not supported; `+record-history-list` must run serially |

#### 2.3.4 View Sub-module

Sub-module index: [`references/lark-base-view.md`](references/lark-base-view.md)

| Command | Purpose / When to use | Required reference | Notes |
|---------|----------------------|--------------------|-------|
| `+view-list / +view-get` | List views or get details of a single view | [`lark-base-view-list.md`](references/lark-base-view-list.md), [`lark-base-view-get.md`](references/lark-base-view-get.md) | `+view-list` must run serially; `+view-get` is good for inspecting view config |
| `+view-create / +view-delete / +view-rename` | Create, delete, or rename a view | [`lark-base-view-create.md`](references/lark-base-view-create.md), [`lark-base-view-delete.md`](references/lark-base-view-delete.md), [`lark-base-view-rename.md`](references/lark-base-view-rename.md) | Confirm table and view type before creation; confirm target before deletion; rename directly when user has provided the new name |
| `+view-get-filter / +view-set-filter` | Read or configure filter conditions | [`lark-base-view-get-filter.md`](references/lark-base-view-get-filter.md), [`lark-base-view-set-filter.md`](references/lark-base-view-set-filter.md), [`lark-base-record-list.md`](references/lark-base-record-list.md) | Often combined with `+record-list` to filter records by view |
| `+view-get-sort / +view-set-sort` | Read or configure sort order | [`lark-base-view-get-sort.md`](references/lark-base-view-get-sort.md), [`lark-base-view-set-sort.md`](references/lark-base-view-set-sort.md) | Field names must come from actual table structure |
| `+view-get-group / +view-set-group` | Read or configure grouping | [`lark-base-view-get-group.md`](references/lark-base-view-get-group.md), [`lark-base-view-set-group.md`](references/lark-base-view-set-group.md) | Field names must come from actual table structure |
| `+view-get-visible-fields / +view-set-visible-fields` | Read or configure visible fields | [`lark-base-view-get-visible-fields.md`](references/lark-base-view-get-visible-fields.md), [`lark-base-view-set-visible-fields.md`](references/lark-base-view-set-visible-fields.md) | Controls field order and visibility in the view |
| `+view-get-card / +view-set-card` | Read or configure card view | [`lark-base-view-get-card.md`](references/lark-base-view-get-card.md), [`lark-base-view-set-card.md`](references/lark-base-view-set-card.md) | For card layout scenarios |
| `+view-get-timebar / +view-set-timebar` | Read or configure timeline view | [`lark-base-view-get-timebar.md`](references/lark-base-view-get-timebar.md), [`lark-base-view-set-timebar.md`](references/lark-base-view-set-timebar.md) | For timeline display scenarios |

### 2.4 Formula / Lookup Module

Enter this module whenever the user's request involves derived metrics, conditionals, text processing, date differences, cross-table calculations, or fixed lookup references.

Default to `formula`: suitable for regular calculations, conditionals, text processing, date differences, cross-table aggregation, and any derived result that should persist in the table.
Use `lookup` only when the user explicitly requests it, or the scenario naturally fits the `from / select / where / aggregate` fixed-lookup model.

| Command | Purpose / When to use | Required reference | Notes |
|---------|----------------------|--------------------|-------|
| `+field-create` (`type=formula`) | Create a formula field | [`formula-field-guide.md`](references/formula-field-guide.md), [`lark-base-field-create.md`](references/lark-base-field-create.md), [`lark-base-shortcut-field-properties.md`](references/lark-base-shortcut-field-properties.md) | Do not create without reading the guide first |
| `+field-update` (`type=formula`) | Update a formula field | [`formula-field-guide.md`](references/formula-field-guide.md), [`lark-base-field-update.md`](references/lark-base-field-update.md), [`lark-base-shortcut-field-properties.md`](references/lark-base-shortcut-field-properties.md) | Fetch current table structure first |
| `+field-create` (`type=lookup`) | Create a lookup field | [`lookup-field-guide.md`](references/lookup-field-guide.md), [`lark-base-field-create.md`](references/lark-base-field-create.md), [`lark-base-shortcut-field-properties.md`](references/lark-base-shortcut-field-properties.md) | Do not create without reading the guide first |
| `+field-update` (`type=lookup`) | Update a lookup field | [`lookup-field-guide.md`](references/lookup-field-guide.md), [`lark-base-field-update.md`](references/lark-base-field-update.md), [`lark-base-shortcut-field-properties.md`](references/lark-base-shortcut-field-properties.md) | Also fetch target table structure for cross-table lookups |

### 2.5 Data Analysis Module

For one-time analysis and ad-hoc aggregation. Use when the user wants "the calculated result now" rather than persisting it as a field.

Before entering this module, confirm:
- `+data-query` performs aggregation only (grouping, filtering, sorting, aggregation functions); it does not list raw records or row-by-row detail.
- The caller must be a Base admin with FA (Full Access) on the target Base, otherwise a permission error is returned.
- `+data-query` only supports whitelisted field types; `formula`, `lookup`, attachments, system fields, and linked fields cannot be used in `dimensions / measures / filters / sort`.

| Command | Purpose / When to use | Required reference | Notes |
|---------|----------------------|--------------------|-------|
| `+data-query` | Grouped statistics, SUM/AVG/COUNT/MAX/MIN, filtered aggregation | [`lark-base-data-query.md`](references/lark-base-data-query.md) | Field names must exactly match actual names; do not use `+record-list/+record-search` to pull all rows and calculate manually; `+data-query` does not return raw records; verify permissions and supported field types before use |

### 2.6 Workflow Module

High-constraint module. Always read the corresponding command doc and schema before running any workflow command.
Module index: [`references/lark-base-workflow.md`](references/lark-base-workflow.md)

| Command | Purpose / When to use | Required reference | Notes |
|---------|----------------------|--------------------|-------|
| `+workflow-list / +workflow-get` | List workflows or get full workflow structure | [`lark-base-workflow-list.md`](references/lark-base-workflow-list.md), [`lark-base-workflow-get.md`](references/lark-base-workflow-get.md), [`lark-base-workflow-schema.md`](references/lark-base-workflow-schema.md) | `+workflow-list` returns summaries only and must run serially; use `+workflow-get` for full structure |
| `+workflow-create / +workflow-update` | Create or update a workflow | [`lark-base-workflow-create.md`](references/lark-base-workflow-create.md), [`lark-base-workflow-update.md`](references/lark-base-workflow-update.md), [`lark-base-workflow-schema.md`](references/lark-base-workflow-schema.md) | Read schema first; do not guess `type` from natural language; confirm actual table and field names |
| `+workflow-enable / +workflow-disable` | Enable or disable a workflow | [`lark-base-workflow-enable.md`](references/lark-base-workflow-enable.md), [`lark-base-workflow-disable.md`](references/lark-base-workflow-disable.md), [`lark-base-workflow-schema.md`](references/lark-base-workflow-schema.md) | Confirm target workflow before enabling/disabling; distinguish `workflow_id` from `table_id` by prefix |

### 2.7 Dashboard Module

Enter this module when the user mentions: dashboard, data board, chart, visualization, block, component, add block, create chart.
Read [`lark-base-dashboard.md`](references/lark-base-dashboard.md) first.

| Command | Purpose / When to use | Required reference | Notes |
|---------|----------------------|--------------------|-------|
| `+dashboard-list / +dashboard-get` | List dashboards or get dashboard details | [`lark-base-dashboard-list.md`](references/lark-base-dashboard-list.md), [`lark-base-dashboard-get.md`](references/lark-base-dashboard-get.md), [`lark-base-dashboard.md`](references/lark-base-dashboard.md) | Read guide before entering dashboard context; `+dashboard-list` must run serially |
| `+dashboard-create / +dashboard-update / +dashboard-delete` | Create, update, or delete a dashboard | [`lark-base-dashboard-create.md`](references/lark-base-dashboard-create.md), [`lark-base-dashboard-update.md`](references/lark-base-dashboard-update.md), [`lark-base-dashboard-delete.md`](references/lark-base-dashboard-delete.md), [`lark-base-dashboard.md`](references/lark-base-dashboard.md) | Clarify board purpose and display scenario before creation; read current config before update; confirm target before deletion |
| `+dashboard-block-list / +dashboard-block-get` | List chart blocks or get single block details | [`lark-base-dashboard-block-list.md`](references/lark-base-dashboard-block-list.md), [`lark-base-dashboard-block-get.md`](references/lark-base-dashboard-block-get.md), [`lark-base-dashboard.md`](references/lark-base-dashboard.md), [`dashboard-block-data-config.md`](references/dashboard-block-data-config.md) | `+dashboard-block-list` must run serially; read block config doc for configuration details |
| `+dashboard-block-create / +dashboard-block-update / +dashboard-block-delete` | Create, update, or delete a chart block | [`lark-base-dashboard-block-create.md`](references/lark-base-dashboard-block-create.md), [`lark-base-dashboard-block-update.md`](references/lark-base-dashboard-block-update.md), [`lark-base-dashboard-block-delete.md`](references/lark-base-dashboard-block-delete.md), [`lark-base-dashboard.md`](references/lark-base-dashboard.md), [`dashboard-block-data-config.md`](references/dashboard-block-data-config.md) | Read block config doc for `data_config`, chart type, and filter; confirm target before deletion |

### 2.8 Form Module

For managing forms and form questions.
Module index: [`references/lark-base-form.md`](references/lark-base-form.md), [`references/lark-base-form-questions.md`](references/lark-base-form-questions.md)
Form question operations require `form-id`; see `form-list` and `form-create` references for how to obtain it.

| Command | Purpose / When to use | Required reference | Notes |
|---------|----------------------|--------------------|-------|
| `+form-list / +form-get` | List forms or get a single form | [`lark-base-form-list.md`](references/lark-base-form-list.md), [`lark-base-form-get.md`](references/lark-base-form-get.md) | `+form-list` can retrieve `form-id`; `+form-get` is good for inspecting existing form config |
| `+form-create / +form-update / +form-delete` | Create, update, or delete a form | [`lark-base-form-create.md`](references/lark-base-form-create.md), [`lark-base-form-update.md`](references/lark-base-form-update.md), [`lark-base-form-delete.md`](references/lark-base-form-delete.md) | After creation, proceed to form question operations; confirm target before update or deletion |
| `+form-questions-list` | List form questions | [`lark-base-form-questions-list.md`](references/lark-base-form-questions-list.md) | Good for inspecting existing question structure |
| `+form-questions-create / +form-questions-update / +form-questions-delete` | Create, update, or delete questions | [`lark-base-form-questions-create.md`](references/lark-base-form-questions-create.md), [`lark-base-form-questions-update.md`](references/lark-base-form-questions-update.md), [`lark-base-form-questions-delete.md`](references/lark-base-form-questions-delete.md) | Confirm `form-id` first; confirm question target before update or deletion |

### 2.9 Permissions & Roles Module

For enabling advanced permissions and managing custom Base roles.
The executing user must be a Base admin for `+advperm-enable / +advperm-disable / +role-*`; otherwise a permission error is returned.

| Command | Purpose / When to use | Required reference | Notes |
|---------|----------------------|--------------------|-------|
| `+advperm-enable / +advperm-disable` | Enable or disable advanced permissions | [`lark-base-advperm-enable.md`](references/lark-base-advperm-enable.md), [`lark-base-advperm-disable.md`](references/lark-base-advperm-disable.md) | Must enable before managing roles; disabling is high-risk and invalidates existing custom roles |
| `+role-list / +role-get` | List roles or get role details | [`lark-base-role-list.md`](references/lark-base-role-list.md), [`lark-base-role-get.md`](references/lark-base-role-get.md), [`role-config.md`](references/role-config.md) | `+role-list` must run serially; `+role-get` is good for viewing full permission config |
| `+role-create / +role-update / +role-delete` | Create, update, or delete a role | [`lark-base-role-create.md`](references/lark-base-role-create.md), [`lark-base-role-update.md`](references/lark-base-role-update.md), [`lark-base-role-delete.md`](references/lark-base-role-delete.md), [`role-config.md`](references/role-config.md) | `+role-create` supports only `custom_role`; `+role-update` uses Delta Merge — pass `role_name` and `role_type` even if unchanged; `+role-delete` is irreversible |

## 3. General Base Knowledge

The English name for Lark's multi-dimensional table product is `Base` (formerly `Bitable`). The name `bitable` appearing in legacy docs, return fields, parameter names, or error messages is for backward compatibility — it does not mean you should switch to a different command set.

### 3.1 Field Classification and Writability

| Field type | Meaning | Can be written directly via `+record-upsert / +record-batch-create / +record-batch-update`? | Notes |
|------------|---------|-------------------------------------------------------------------------------------------|-------|
| Storage field | Stores user-entered data | Yes | Common types: text, number, date, single-select, multi-select, user, linked record |
| Attachment field | Stores file attachments | No (do not write as a regular field) | Upload via `+record-upload-attachment`; download via `lark-cli docs +media-download` |
| System field | Maintained automatically by the platform | No | Common types: created time, updated time, creator, modifier, auto-number |
| `formula` field | Computed via an expression | No | Read-only |
| `lookup` field | References values via cross-table rules | No | Read-only |

### 3.2 Task Routing Mental Model

| User goal | Preferred approach | Do NOT use |
|-----------|--------------------|-----------|
| One-time analysis / ad-hoc stats | `+data-query` | Do not pull all rows with `+record-list / +record-search` and calculate manually |
| Persist result long-term in table | `formula` field | Do not provide only a one-time manual analysis result |
| User explicitly requests lookup, or scenario is naturally a fixed-lookup config | `lookup` field | Do not default to lookup; check if `formula` is more appropriate first |
| Read raw record detail / keyword search / export | `+record-search / +record-list / +record-get` | Do not use `+data-query` as a data-fetch command |
| Upload attachment to a record | `+record-upload-attachment` | Do not fake attachment values in `+record-upsert / +record-batch-*` |
| Download attachment from a record | `lark-cli docs +media-download --token <file_token> --output <path>` | Get `file_token` from attachment array in `+record-get`; see [`../lark-doc/references/lark-doc-media-download.md`](../lark-doc/references/lark-doc-media-download.md) |
| Filter-based record read using a view | `+view-set-filter` + `+record-list` | Do not skip view filter and guess conditions |
| Import local Excel/CSV into Base | `lark-cli drive +import --type bitable` | Do not use `+base-create`, `+table-create`, or `+record-upsert` |

### 3.3 Table Names, Field Names, and Expression References

1. Table names and field names must exactly match what is returned by `+table-list / +table-get / +field-list`.
2. Do not guess names from natural language; do not rewrite table/field names the user mentions verbally.
3. Names in `formula / lookup / data-query / workflow` must also exactly match; expression references, where conditions, DSL field names, and workflow configs follow the same rule.
4. For cross-table scenarios, also fetch the target table's structure — do not rely only on the current table.

### 3.4 Tokens and Links

High-priority section. If the user's input contains a link or token, or an error mentions `baseToken / wiki_token / obj_token`, check here first.

| Input type | Correct handling | Notes |
|-----------|-----------------|-------|
| Direct Base link `/base/{token}` | Extract token directly as `--base-token` | Do not pass the full URL as `--base-token` |
| Wiki link `/wiki/{token}` | Call `wiki.spaces.get_node` first, then use `node.obj_token` | Do not use `wiki_token` directly as `--base-token` |
| `?table={id}` in URL | Check object type by prefix first | `tbl` prefix = table `table-id` usable as `--table-id`; `blk` = dashboard ID; `wkf` = workflow ID; `ldx` = embedded doc — do not treat all as `--table-id` |
| `?view={id}` in URL | Extract as `--view-id` | For directly targeting a view |

| `obj_type` from `lark-cli wiki spaces get_node` | Next route | Notes |
|------------------------------------------------|-----------|-------|
| `bitable` | Prefer `lark-cli base +...` | Fall back to `lark-cli base <resource> <method>` only if shortcut doesn't cover the case; do not switch to `lark-cli api /open-apis/bitable/v1/...` |
| `docx` | Switch to doc/Drive skill | Do not continue using Base commands |
| `sheet` | Switch to Sheets skill | Do not continue using Base commands |
| `slides` | Switch to Drive skill | Do not continue using Base commands |
| `mindnote` | Switch to Drive skill | Do not continue using Base commands |

### 3.5 Execution Identity and User Fields

- User fields: note the difference between `user_id_type` and execution identity (user/bot).
- Bot identity: bot cannot see user private resources; actions execute as the application identity.
- User identity: requires user authorization and scope; better suited for operating user resources.

## 4. Execution Rules

### 4.1 Standard Execution Order

1. Determine which module the task belongs to, select the right command family.
2. If the user provided a link, resolve the token first — do not use wiki tokens, full URLs, or other object IDs as `base_token`.
3. Fetch structure first, then build the command — avoid guessing table names, field names, or expression references.
4. After identifying the command, read its reference doc before executing.
5. Execute the command and determine the next step based on the returned result.
6. Reply with key results and information about possible follow-up actions to support agent chaining.

### 4.2 Non-Negotiable Rules

1. Fetch structure first; at minimum fetch the current table structure; for cross-table operations, fetch the target table structure too.
2. Never guess table names, field names, or expression references — always use what is actually returned.
3. Use only atomic commands; never fall back to legacy aggregate commands (`+table / +field / +record / +view / +history / +workspace`).
4. Before writing records, read field structure: run `+field-list` first, then construct write values by field type.
5. Before writing fields, read the field property spec: read `lark-base-shortcut-field-properties.md` before constructing `+field-create / +field-update` JSON.
6. Write only writable fields; system fields, attachment fields, `formula`, and `lookup` are not valid write targets for record commands.
7. Route analysis and data reads correctly: stats go to `+data-query`, keyword search to `+record-search`, detail reads to `+record-list / +record-get`.
8. Filter queries use view capabilities: configure with `+view-set-filter`, then read with `+record-list`.
9. In Base contexts, do not switch to raw API calls (`lark-cli api /open-apis/bitable/v1/...`).
10. Always use `--base-token`; do not use the legacy `--app-token`.
11. For workflow scenarios, read schema first; do not guess `type` from natural language.
12. For dashboard scenarios, read guide first; enter the dashboard module whenever charts, boards, or blocks are mentioned.
13. For formula/lookup scenarios, read guide first; do not create or update without reading the guide.

### 4.3 Concurrency, Pagination, and Batch Limits

- `+table-list / +field-list / +record-list / +view-list / +record-history-list / +role-list / +dashboard-list / +dashboard-block-list / +workflow-list` must not be called concurrently — run serially only.
- For `+record-list` pagination, max `--limit` is `200`; fetch the first batch and check `has_more`; continue paginating only when the user explicitly requests more data.
- For batch writes, recommended max is `500` records per batch.
- For sequential writes to the same table, use serial writes with a `0.5–1` second delay between batches.

### 4.4 Confirmation and Reply Rules

- For view rename: when the user has clearly specified which view to rename and the new name, execute `+view-rename` directly.
- For record/field/table deletion: if the user has clearly stated the delete intent and the target is unambiguous, execute `+record-delete / +field-delete / +table-delete` directly with `--yes`.
- If the delete target is still ambiguous, confirm first with `+record-get / +field-get / +table-get` or the corresponding list command.
- After `+base-create / +base-copy` succeeds, always return the new Base's identifier information; also return any accessible link if present.
- If the Base was created by bot identity and a user identity is available in the current CLI, proactively grant the current user `full_access`; ownership transfer requires separate confirmation and must not be executed without it.

## 5. Common Errors and Recovery

| Error / Symptom | Meaning | Recovery action |
|----------------|---------|----------------|
| `1254064` | Date format error | Use millisecond timestamp, not string or second-level |
| `1254068` | Hyperlink format error | Use `{text, link}` object |
| `1254066` | User field error | Use `[{id:"ou_xxx"}]` and confirm `user_id_type` |
| `1254045` | Field name not found | Check field name (spaces, case) |
| `1254015` | Field value type mismatch | Run `+field-list` first, then construct value by type |
| `param baseToken is invalid` / `base_token invalid` | Wiki token, workspace token, or other token was passed as `base_token` | If input came from `/wiki/...`, first run `lark-cli wiki spaces get_node` to get the actual `obj_token`; when `obj_type=bitable`, retry with `node.obj_token` as `--base-token`; do not switch to `bitable/v1` |
| `not found` with a wiki link | Often caused by using wiki token as base token | Roll back to check wiki resolution first, rather than switching to `bitable/v1` |
| formula/lookup creation failed | Guide not read or structure invalid | Read `formula-field-guide.md` / `lookup-field-guide.md` first, then rebuild the request per the guide |
| System/formula field write failed | Read-only field used as write target | Switch to writing storage fields; let formula/lookup/system fields produce their values automatically |
| `1254104` | Batch exceeds 500 records | Split into multiple calls |
| `1254291` | Concurrent write conflict | Use serial writes with delay between batches |

## 5.5 SFA/CRM Design Conventions (みやびAI標準・API検証済み)

> Full reference: [`crm-assets/lark-base-best-practices.md`](../../../crm-assets/lark-base-best-practices.md)

SFA/CRM コンテキスト（contacts / companies / deals / activities / lead_scores）でテーブルを設計・操作する際の必須ルール。

### セマンティックID（先頭フィールド）

```
{CODE}-{YYYYMM}-{NNN} | {サマリー}
例: CNT-202504-001 | 窪内優也
```

| テーブル | CODE |
|---------|------|
| contacts | `CNT` |
| companies | `ORG` |
| deals | `DEAL` |
| activities | `ACT` |
| lead_scores | `SCORE` |

先頭フィールドは **Formula 型**。`連番` フィールドは **必ず `text` 型** で実装（`auto_number` はフォーミュラ参照でバグあり）。

```bash
# 連番フィールドは text 型で作成
lark-cli base +field-create --base-token {TOKEN} --table-id {TBL} \
  --json '{"field_name":"連番","type":"text"}'

# フォーミュラ内のフィールド参照は必ずブラケット記法
# 正: [初回接触日], [名前], [連番]
# 誤: 初回接触日, 名前, 連番
```

### フィールド命名禁則

- **絵文字禁止** — API文字列マッチング不安定化
- Linkフィールド名: `{参照先}_Link`（例: `所属会社_Link`）
- フィールド名は必ず `+field-list` で確認してから指定（推測禁止）

### Selectフィールド選択肢

**必ず2桁番号プレフィックス付き**: `00.未開始` / `01.進行中` / `99.終了`

理由: Lark Base API は選択肢の表示順序を保証しないため、文字列比較でステージ比較可能にする。

### フォーミュラの制約（API検証済み）

- `CREATED_TIME()` はフォーミュラフィールドで動作しない（null になる）
  → 代替: レコード作成時に日付フィールドを必須入力とする
- ダッシュボードブロックは **直列作成** が必要（並列API呼び出し不可）

## 6. Reference Documents

- [lark-base-shortcut-field-properties.md](references/lark-base-shortcut-field-properties.md) — **Must read** before `+field-create/+field-update`; field JSON specs for each type
- [role-config.md](references/role-config.md) — Role permission configuration details
- [lark-base-shortcut-record-value.md](references/lark-base-shortcut-record-value.md) — **Must read** before `+record-upsert / +record-batch-create / +record-batch-update`; record JSON specs for each type
- [lark-base-record-batch-create.md](references/lark-base-record-batch-create.md) — `+record-batch-create` usage and `--json` structure
- [lark-base-record-batch-update.md](references/lark-base-record-batch-update.md) — `+record-batch-update` usage and `--json` structure
- [formula-field-guide.md](references/formula-field-guide.md) — Formula field syntax, function constraints, CurrentValue rules, cross-table calculation patterns
- [lookup-field-guide.md](references/lookup-field-guide.md) — Lookup field configuration rules, where/aggregate constraints, trade-offs vs formula
- [lark-base-view-set-filter.md](references/lark-base-view-set-filter.md) — View filter configuration
- [lark-base-record-list.md](references/lark-base-record-list.md) — Record list retrieval and pagination
- [lark-base-record-search.md](references/lark-base-record-search.md) — Keyword record search
- [lark-base-advperm-enable.md](references/lark-base-advperm-enable.md) — `+advperm-enable` to enable advanced permissions
- [lark-base-advperm-disable.md](references/lark-base-advperm-disable.md) — `+advperm-disable` to disable advanced permissions
- [lark-base-role-list.md](references/lark-base-role-list.md) — `+role-list`
- [lark-base-role-get.md](references/lark-base-role-get.md) — `+role-get`
- [lark-base-role-create.md](references/lark-base-role-create.md) — `+role-create`
- [lark-base-role-update.md](references/lark-base-role-update.md) — `+role-update`
- [lark-base-role-delete.md](references/lark-base-role-delete.md) — `+role-delete`
- [lark-base-dashboard.md](references/lark-base-dashboard.md) — Dashboard module workflow guide
- [dashboard-block-data-config.md](references/dashboard-block-data-config.md) — Block `data_config` structure, chart types, filter rules
- [lark-base-workflow.md](references/lark-base-workflow.md) — Workflow command index
- [lark-base-workflow-schema.md](references/lark-base-workflow-schema.md) — `+workflow-create/+workflow-update` JSON body structure
- [lark-base-data-query.md](references/lark-base-data-query.md) — `+data-query` aggregation, DSL structure, supported field types, aggregation functions
- [examples.md](references/examples.md) — Full operation examples

## 7. Command Groups

> **Before executing:** After locating a command in the table below, always read its reference doc before running it.

| Command group | Description |
|--------------|-------------|
| [`table commands`](references/lark-base-table.md) | `+table-list / +table-get / +table-create / +table-update / +table-delete` |
| [`field commands`](references/lark-base-field.md) | `+field-list / +field-get / +field-create / +field-update / +field-delete / +field-search-options` |
| [`record commands`](references/lark-base-record.md) | `+record-search / +record-list / +record-get / +record-upsert / +record-batch-create / +record-batch-update / +record-upload-attachment / +record-delete` |
| [`view commands`](references/lark-base-view.md) | `+view-list / +view-get / +view-create / +view-delete / +view-get-* / +view-set-* / +view-rename` |
| [`data-query commands`](references/lark-base-data-query.md) | `+data-query` |
| [`history commands`](references/lark-base-history.md) | `+record-history-list` |
| [`base / workspace commands`](references/lark-base-workspace.md) | `+base-create / +base-get / +base-copy` |
| [`advperm commands`](references/lark-base-advperm-enable.md) | `+advperm-enable / +advperm-disable` |
| [`role commands`](references/lark-base-role-list.md) | `+role-list / +role-get / +role-create / +role-update / +role-delete` |
| [`form commands`](references/lark-base-form-create.md) | `+form-list / +form-get / +form-create / +form-update / +form-delete` |
| [`form questions commands`](references/lark-base-form-questions-create.md) | `+form-questions-list / +form-questions-create / +form-questions-update / +form-questions-delete` |
| [`workflow commands`](references/lark-base-workflow.md) | `+workflow-list / +workflow-get / +workflow-create / +workflow-update / +workflow-enable / +workflow-disable` |
