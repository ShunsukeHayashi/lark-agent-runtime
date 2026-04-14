# PPAL Marketing Supervised Runbook — 2026-04-14

This is the shortest reproducible operator runbook for the PPAL marketing scenario.

It assumes:

- `larc` is configured locally
- the `larc-runtime` skill is installed in OpenClaw
- the official `openclaw-lark` plugin is enabled and diagnosed
- `LARC_DRIVE_FOLDER_TOKEN` is present in runtime config

## Scope

This runbook is only for the PPAL marketing scenario:

- `SFA -> PPAL Base`
- `MA -> PPAL Base`
- `Notion -> Lark Docs/Wiki`
- `Slack -> Lark IM`

## Canonical Input Shape

Use a concrete request such as:

`In the PPAL context, use SFA and MA data to identify hotlist leads, draft a campaign brief in Notion, and notify the sales team in Slack`

## Operator Flow

1. Enqueue the request.

```bash
bin/larc ingress enqueue \
  --text "In the PPAL context, use SFA and MA data to identify hotlist leads, draft a campaign brief in Notion, and notify the sales team in Slack" \
  --sender ou_operator
```

2. Capture the latest `queue_id`.

```bash
tail -n 1 ~/.larc/cache/queue/main.jsonl
```

3. Inspect the OpenClaw runtime bundle.

```bash
bin/larc ingress openclaw --queue-id <queue-id> --days 30
```

Expected normalized context:

- `base_token`
- `default_view_id`
- `ssot_doc_url`
- `output_folder_token`
- `normalization`

4. Claim the item for supervised execution.

```bash
bin/larc ingress run-once --queue-id <queue-id> --agent main
```

5. Review the execution plan before actual execution.

```bash
bin/larc ingress execute-apply --queue-id <queue-id> --dry-run
```

Expected runnable steps:

- `read_base`
- `read_document`
- `create_document`
- `send_message`

6. Execute under operator supervision.

```bash
bin/larc ingress execute-apply --queue-id <queue-id>
```

7. If the queue item becomes `partial`, inspect follow-up work.

```bash
bin/larc ingress followup --queue-id <queue-id> --days 30
```

8. Close the lifecycle explicitly.

Success:

```bash
bin/larc ingress done --queue-id <queue-id> --note "Manual follow-up completed in supervised pilot"
```

Failure:

```bash
bin/larc ingress fail --queue-id <queue-id> --note "Supervised pilot stopped after operator review"
```

## Current Truth

As of this runbook:

- `read_base` dispatches through OpenClaw
- `read_document` dispatches through OpenClaw
- `create_document` dispatches through OpenClaw with auto-resolved `output_folder_token`
- `send_message` runs through LARC IM send

This means the PPAL marketing scenario is usable now as a supervised operator flow.
