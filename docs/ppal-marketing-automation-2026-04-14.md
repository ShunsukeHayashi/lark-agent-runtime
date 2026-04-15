# PPAL Marketing Automation Mapping — 2026-04-14

This note fixes the current truth for supervised PPAL marketing tasks in LARC.

The purpose is not to make Notion, Slack, or a third-party SFA/MA system first-class execution targets.
The purpose is to normalize those user-facing words into the governed Lark runtime that already exists.

## Canonical Mapping

- `SFA` -> `PPAL Base`
- `MA` -> `PPAL Base`
- `Notion` -> `Lark Docs / Wiki`
- `Slack` -> `Lark IM`

## PPAL Base Defaults

- `base_token`: `REPLACE_BASE_TOKEN`
- `user_table_id`: `REPLACE_USER_TABLE_ID`
- `cv_table_id`: `REPLACE_CV_TABLE_ID`
- `metrics_table_id`: `REPLACE_METRICS_TABLE_ID`
- `source_table_id`: `REPLACE_SOURCE_TABLE_ID`
- `default_hotlist_view_id`: `REPLACE_PRIORITY_VIEW_ID`
- `default_all_users_view_id`: `REPLACE_DEFAULT_VIEW_ID`
- `ssot_doc_url`: `https://example.com/replace-with-ssot-doc-url`
- `output_folder_token`: `LARC_DRIVE_FOLDER_TOKEN` (auto-injected from runtime config)

## What LARC Does

When the user says something like:

`Use SFA and MA data for PPAL marketing, organize the campaign brief in Notion, and notify the sales team in Slack`

LARC should normalize it into:

- read PPAL lead/CV/funnel data from Base
- draft or update the campaign brief in Lark Docs/Wiki
- notify the sales team through Lark IM

## Required Business Input

LARC should block execution until at least this field is present:

- `campaign_goal`

Examples:

- `target hot leads who reached buyer intent but did not purchase`
- `prepare a reactivation follow-up for stalled nurture users`
- `draft a campaign brief for Teachable buyers eligible for upsell`

## Useful Optional Inputs

- `segment_hint`
  - `lead`
  - `buyer`
  - `nurture`
  - `prospect`
  - `hotlist`
  - `upsell`
- `destination_target`
  - `sales_team`
  - a specific Lark chat or operator

If these are missing, LARC should stay in a supervised `partial` or `ask-user` mode rather than guessing.

## Expected Runtime Shape

The supervised path should look like this:

1. `larc ingress enqueue`
2. `larc ingress openclaw`
3. OpenClaw reads the governed bundle
4. OpenClaw uses official `openclaw-lark` tools
5. `larc ingress done` / `fail` / `followup`

## Current Rule

For PPAL marketing automation, the business SSOT remains:

- `Lark Base`
- `Lark Docs / Wiki`
- `Lark IM`

Local OpenClaw or local runtime state is execution substrate only.

## Live Verification Result

The current OpenClaw-first path has been verified up to the official plugin boundary.

- `larc ingress enqueue` normalizes PPAL marketing intent into:
  - `read_base`
  - `read_document`
  - `create_document`
  - `send_message`
- `larc ingress openclaw` now passes:
  - the PPAL Base token
  - default table IDs
  - the SSOT doc URL
  - the default Drive output folder token from runtime config
  - the `SFA/MA/Notion/Slack -> Base/Docs/IM` normalization
- `larc ingress execute-apply --dry-run` now raises all four PPAL steps into executable adapters:
  - `read_base`
  - `read_document`
  - `create_document`
  - `send_message`

### Current Pilot Status

The former `application:application:self_manage` plugin permission blocker is resolved.

The supervised pilot path is now live-verified through:

- queue creation
- OpenClaw dispatch
- official `openclaw-lark` plugin reads and outbound IM send
- `partial -> followup -> done`
- Base mirror write-back to `agent_queue`

This means PPAL marketing automation is now usable as a supervised pilot, with the default Drive output folder injected automatically from runtime config.
