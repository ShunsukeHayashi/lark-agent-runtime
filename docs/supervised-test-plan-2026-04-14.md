# Supervised Test Plan — 2026-04-14

This document freezes the shortest path to a real supervised test.

The goal is not feature expansion.
The goal is to make three office-work scenarios reliable enough to run under human supervision with:

- `larc ingress openclaw`
- the official `openclaw-lark` plugin
- `larc ingress done|fail|followup`

## Test Target

Only these three scenarios are in scope:

1. CRM follow-up
2. Expense approval
3. Document update

Anything else stays out of scope until these are live-verified.

## Definition of Testable

A scenario is testable when:

1. A queue item can be enqueued and routed.
2. `larc ingress openclaw` returns the correct next-step bundle.
3. The bundle names the preferred official `openclaw-lark` tools.
4. Missing required input results in `blocked`, `partial`, or explicit ask-user behavior.
5. The operator can close the lifecycle with `done`, `fail`, or `followup`.

## Scenario Matrix

### CRM follow-up

- Queue signature:
  - `create_crm_record`
  - `read_base`
  - `send_crm_followup`
  - `send_message`
- Preferred official tools:
  - `feishu_bitable_app_table_record`
  - `feishu_search_doc_wiki`
  - `feishu_im_user_message`
- Required input:
  - target lead/customer identity
  - enough message context to write a follow-up
- Success condition:
  - CRM/Base row is created or updated
  - outbound message is sent
  - queue item closes as `done` or `partial`
- Blocked condition:
  - target customer/lead cannot be identified
  - required Base/table target is missing

### Expense approval

- Queue signature:
  - `create_expense`
  - optionally `submit_approval`
- Preferred official tools:
  - `feishu_bitable_app_table_record`
  - `feishu_drive_file`
- Required input:
  - amount
  - expense type
  - date
  - business purpose
  - optionally receipt/supporting file
- Success condition:
  - expense payload is normalized
  - approval path is correctly blocked/resumed
  - queue item moves through `blocked_approval -> approved -> pending/in_progress`
- Blocked condition:
  - amount/type/date/purpose missing
  - approval metadata cannot be constructed

### Document update

- Queue signature:
  - `update_document`
  - or `write_wiki`
- Preferred official tools:
  - `feishu_fetch_doc`
  - `feishu_update_doc`
  - `feishu_search_doc_wiki`
- Required input:
  - target document/page identity
  - edit instruction or replacement content
- Success condition:
  - target doc/page is identified
  - requested update is applied
  - queue item closes with clear execution note
- Blocked condition:
  - target document is ambiguous
  - content instruction is too incomplete to apply safely

## Implementation Order

### Step 1

Freeze the adapter schema for the 3 scenarios.

### Step 2

Make CRM follow-up the first end-to-end supervised test.

Why first:

- already has the richest queue signature
- already exercises Base + IM
- already has useful tool hints

### Step 3

Make expense approval the second test.

Why second:

- validates approval gating
- validates blocked/resume flow

### Step 4

Make document update the third test.

Why third:

- validates fetch/update behavior against an existing business artifact

## Current Truth

As of this document:

- queue lifecycle exists
- OpenClaw bridge exists
- official tool hints exist
- safe adapter execution is still partial
- one supervised pilot is already closed end-to-end for the PPAL marketing case
- the PPAL case has been proven through `enqueue -> openclaw -> in_progress -> execute-apply -> partial -> followup -> done`
- the `agent_queue` Base mirror now records the final lifecycle state again

This means:

- supervised tests can start now
- at least one real office-work scenario is already usable under operator supervision
- fully reliable scenario closure for broader task types still depends on scenario-specific adapter work
