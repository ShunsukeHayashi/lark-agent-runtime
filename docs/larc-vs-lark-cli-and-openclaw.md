# LARC vs lark-cli vs OpenClaw

## Summary

There is no official product called "LARC CLI."

The correct comparison is:

- `larksuite/cli` (`lark-cli`) — the official Lark API wrapper CLI
- `OpenClaw` and similar coding-agent runtimes — agent execution environments optimized for coding work
- `LARC` — a permission-first runtime layer for Lark-native office-work agents

In short:

- `lark-cli` is the API access layer
- `OpenClaw` is a coding-agent runtime model
- `LARC` adds permission intelligence, execution gates, registry, disclosure-chain loading, and office-work runtime semantics on top of Lark

## What lark-cli has that LARC does not try to replace

### API coverage

`lark-cli` aims to cover the Lark API surface broadly:

- calendar
- meetings
- attendance
- contacts
- docs
- drive
- base
- approval

LARC does not try to be a full API wrapper replacement.

### Official maintenance

`lark-cli` tracks the official Lark platform more directly. LARC intentionally depends on it as the lower-level access layer where possible.

### Auth and token handling

`lark-cli` already provides the practical auth surface:

- OAuth flows
- token management
- identity switching

LARC builds workflow semantics on top of that.

## What LARC adds on top

### 1. Permission intelligence

`larc auth suggest "<task>"` adds a capability that `lark-cli` does not have:

- infer likely minimum scopes from natural-language office tasks
- explain authority type (`user`, `bot`, `either`)
- surface execution-gate implications

This is one of the project’s main differentiators.

### 2. Execution gates

`larc approve gate <task_type>` introduces a declarative risk layer:

- `none`
- `preview`
- `approval`

This is not just API access. It is runtime governance.

### 3. Agent registry

LARC stores agent declarations in Lark Base:

- agent id
- model
- workspace
- declared scopes
- drive folder

This is closer to an operating model than a pure CLI wrapper.

### 4. Knowledge graph

LARC can treat Lark Wiki as a graph surface:

- traverse nodes
- cache graph structure
- query concepts with neighbor context

This is not part of the official CLI’s core value proposition.

### 5. Disclosure chain backed by Lark

LARC moves the disclosure-chain pattern onto Lark-native surfaces:

- `SOUL.md`
- `USER.md`
- `MEMORY.md`
- `HEARTBEAT.md`

That makes cross-device and shared-context operation more natural than a purely local-file design.

### 6. White-collar workflow focus

Most agent runtimes are still strongest in:

- coding
- git
- CI
- deployment

LARC is intentionally focused on:

- expense and approval work
- CRM and follow-up tasks
- docs and wiki updates
- office coordination
- governed execution inside a tenant surface

## What OpenClaw has that LARC does not yet have

### Autonomous loop behavior

Today, LARC is still mostly invoked by a supervising agent or a person.

It does not yet fully provide:

- bot/webhook ingress from Lark IM
- automatic queue lifecycle
- continuation after approval completion
- built-in delegation across specialist agents

This is the next major product step.

### Full runtime orchestration

OpenClaw-style systems are stronger in:

- continuous execution loops
- agent-to-agent orchestration
- coding-task recursion
- local execution automation

LARC is moving toward that shape, but for Lark-native office work.

## Honest current limit

LARC today is best described as:

**a working Lark runtime surface for agents, not yet a fully autonomous Lark-resident agent loop**

That means:

- the core runtime pieces are real
- the governance layer is real
- the office-work wedge is real
- the autonomous loop is still under construction

## Recommended positioning

Do not describe LARC as:

- a replacement for `lark-cli`
- a finished autonomous agent platform
- a general-purpose enterprise OS

Prefer:

**LARC is a permission-first runtime for Lark-native office-work agents, built on top of official Lark access layers rather than replacing them.**
