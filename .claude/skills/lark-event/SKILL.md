---
name: lark-event
version: 1.0.0
description: "Lark Event Subscriptions: listen to Lark events in real time via WebSocket long connections (messages, contact changes, calendar changes, etc.), output NDJSON to stdout, supports compact agent-friendly format, regex routing, file output. Use when you need to listen to Lark events in real time or build event-driven pipelines."
metadata:
  requires:
    bins: ["lark-cli"]
  cliHelp: "lark-cli event --help"
---

# event (v1)

> **Prerequisites:** First read [`../lark-shared/SKILL.md`](../lark-shared/SKILL.md) to understand authentication, permission handling, and security rules.

## Shortcuts (Prefer Using These First)

Shortcuts are high-level wrappers for common operations (`lark-cli event +<verb> [flags]`). Prefer Shortcuts when available.

| Shortcut | Description |
|----------|-------------|
| [`+subscribe`](references/lark-event-subscribe.md) | Subscribe to Lark events via WebSocket long connection (read-only, NDJSON output); bot-only; supports compact agent-friendly format, regex routing, file output |
