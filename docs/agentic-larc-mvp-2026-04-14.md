# Agentic LARC MVP — 2026-04-14

## Summary

LARC is already a working runtime surface for Lark-backed agent work:

- disclosure loading from Drive
- memory round-trip with Base
- IM send
- task operations
- governed scope inference
- approval gate checks
- wiki-backed knowledge graph

What it does **not** yet do is operate as a self-running agent loop. Today, Claude Code or another upper-layer agent decides which `larc` command to run next.

## Current execution model

```text
Upper-layer agent (Claude Code / OpenClaw-like controller)
  -> LARC CLI/runtime
  -> Lark APIs and tenant data surfaces
```

This is already useful, but it is still a supervised runtime rather than a resident agent.

The most natural primary path is:

```text
OpenClaw Agent
  -> official openclaw-lark plugin (atomic Feishu tools)
  -> LARC (permission / gate / queue / delegation / memory)
  -> Lark tenant surfaces
```

In this model, LARC does not need to become a standalone IM bot first. It works as the governed runtime layer used by OpenClaw.

## Gap to true agentic behavior

### 1. OpenClaw-first ingress

Missing:
- a stable OpenClaw-facing handoff bundle for queue items
- explicit runtime guidance about what the next safe action should be

Why it matters:
- this is the simplest route to practical agent operation without introducing another resident bot runtime

Optional later:
- IM/webhook receiver that turns Lark messages into executable tasks
- intent extraction and task normalization from native Lark events

### 2. Queue and continuation

Missing:
- queue ledger for task lifecycle
- `blocked` state after approval gate
- automatic resume after approval completion

Why it matters:
- gated work currently stops at the decision point and needs a human or outer agent to continue

### 3. Delegation

Missing:
- main-to-specialist agent routing
- registry-aware assignment using scopes and workspace ownership

Why it matters:
- registered agents exist, but they are not yet used as an execution fabric

### 4. Searchable memory

Missing:
- retrieval across historical Base-backed memory
- context restoration before execution

Why it matters:
- current memory flow is good for daily pull/push, but weak for longitudinal office-work context

## Recommended next implementation order

1. OpenClaw-first ingress and handoff
2. Queue / continuation ledger
3. Delegation to registered agents
4. Searchable memory retrieval
5. Optional IM/webhook ingress
6. MergeGate integration as a higher-order review layer

## Why MergeGate is not first

MergeGate is strategically valuable, but it improves review and controlled execution. The more foundational gap is still the lack of an autonomous runtime loop.

In short:

- MergeGate strengthens governance
- OpenClaw-first ingress + queue creates the simplest real agentic operation

For that reason, the next product-defining milestone should be the OpenClaw-first agentic loop, not review orchestration.

## Milestone definition

LARC reaches its first true agentic milestone when:

- an OpenClaw agent can pull the next governed queue action from LARC
- `auth suggest` and `approve gate` run automatically before execution
- blocked approval tasks resume after approval completion
- work can be delegated to a registered specialist agent
- the result is written back to Lark and stored in memory automatically
