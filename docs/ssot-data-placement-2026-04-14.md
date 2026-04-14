# SSOT Data Placement — 2026-04-14

This document fixes where data should live in the LARC runtime.

Its purpose is to prevent drift between:

- cloud SSOT
- operational ledger
- local runtime cache

## Topology

```text
OpenClaw / LARC runtime
  -> local execution + cache
  -> Lark Drive / Docs
  -> Lark Base
  -> Lark IM / Approval / Task / Wiki
```

## 1. Lark Drive / Docs

This is the document SSOT layer.

Place here:

- `SOUL`
- `USER`
- `MEMORY`
- `HEARTBEAT`
- agent workspace folders
- briefs
- shared working documents
- human-readable deliverables

Examples:

- disclosure-chain documents
- campaign briefs
- operator-facing reference documents
- final output documents that should be shared in the workspace

Do not treat this as the queue ledger.

## 2. Lark Base

This is the structured operations SSOT layer.

Place here:

- `agent_memory`
- `agent_queue`
- `agents_registry`
- CRM / SFA / MA records
- state transitions
- execution notes
- structured retrieval context

Examples:

- queue status
- assigned agent
- worker state
- completion timestamps
- memory rows
- lead and funnel records

Do not use this as the final narrative document layer.

## 3. Lark IM

This is the notification and coordination layer.

Place here:

- outbound status updates
- operator notifications
- sales-team notifications
- supervised follow-up messages

This is not the long-term memory ledger.

## 4. Lark Approval / Task / Wiki

These are business execution surfaces.

Approval:

- approval-gated operations
- controlled execution transitions

Task:

- human task tracking
- visible work ownership

Wiki:

- knowledge space
- graph surface
- discoverable documentation nodes

## 5. Local Runtime Cache

This is execution substrate, not SSOT.

Place here:

- `~/.larc/cache/workspace/...`
- `AGENT_CONTEXT.md`
- local queue ledger copy
- handoff bundles
- temporary execution state

Design rule:

- local state may accelerate execution
- local state must not become the only truth
- cloud state should be recoverable even if local cache is discarded

## Decision Table

| Data type | Canonical home | Reason |
|---|---|---|
| Disclosure chain | Drive / Docs | Human-readable shared context |
| Campaign brief / working document | Drive / Docs | Final artifact and collaboration surface |
| Queue lifecycle | Base | Structured state machine |
| Agent registry | Base | Structured lookup and declared scopes |
| Daily memory rows | Base | Queryable retrieval surface |
| Notifications | IM | Human coordination surface |
| Approval state | Approval | Formal control surface |
| Temporary bundle / session context | Local cache | Runtime-only operational state |

## PPAL Marketing Example

For the PPAL marketing scenario:

- SFA / MA data -> `PPAL Base`
- SSOT reference doc -> `Lark Docs`
- new campaign brief -> `Drive / Docs`
- sales-team notification -> `Lark IM`
- queue / lifecycle / completion note -> `Base`
- runtime bundle / execution state -> `local cache`

## Design Rule

Use this rule whenever a new adapter or scenario is added:

1. If it is a shared human-readable artifact, put it in `Drive / Docs`
2. If it is a structured lifecycle or record, put it in `Base`
3. If it is a notification, put it in `IM`
4. If it is temporary execution state, keep it in `local cache`

This is the default SSOT split for LARC.
