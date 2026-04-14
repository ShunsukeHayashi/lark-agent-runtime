# LARC — Lark Agent Runtime

> Permission-first runtime for AI agents that work inside Lark

[![version](https://img.shields.io/badge/version-0.1.0-blue)](bin/larc)
[![license](https://img.shields.io/badge/license-MIT-green)](#license)
[![lark-cli](https://img.shields.io/badge/requires-lark--cli-orange)](https://github.com/larksuite/cli)

English | [简体中文](README.zh-CN.md) | [日本語](README.ja.md)

Official name: `Lark Agent Runtime`
Short name: `LARC`

---

## What is LARC?

**LARC** is a permission-managed runtime for AI agents that work inside Lark.

If Claude Code is part of the execution environment for coding agents, LARC is the execution environment for office-work agents inside Lark.

The goal is not just "a CLI that talks to Lark." The goal is to treat Lark itself as the operating surface for agents:

- Drive as disclosure-chain storage
- Base as memory and registry
- IM as the action and coordination layer
- Approval as execution control
- Wiki as a knowledge and graph surface

---

## Why this project exists

AI agents are already strong in coding workflows, but they are still weak in ordinary white-collar work. The blocker is often not model quality. It is:

- unclear minimum permissions
- unclear execution authority
- an overreliance on local filesystems instead of enterprise-native surfaces

LARC takes a `permission-first` approach:

1. explain the likely scopes
2. explain the authority model
3. route the action through Lark-native surfaces

In practical terms:

1. a task arrives
2. `larc auth suggest` explains what permissions are needed and whose authority should be used
3. `larc approve gate` decides whether the action can run directly, needs preview, or must go through approval
4. execution happens through Lark IM / Base / Drive / Wiki / Approval
5. `larc memory` records what happened back into Lark

---

## Key capabilities

| Capability | What it does |
|---|---|
| `larc bootstrap` | Loads `SOUL.md → USER.md → MEMORY.md → HEARTBEAT.md` from Lark Drive |
| `larc auth suggest` | Infers minimum scopes and authority type from a natural-language task description |
| `larc approve gate` | Checks execution gate policy (none / preview / approval) before running a task |
| `larc agent register` | Registers an agent in Lark Base with declared scopes; supports YAML batch registration |
| `larc kg build` / `larc kg query` | Indexes Lark Wiki node graph and answers concept queries with neighbor context |
| `larc memory` | Syncs daily memory with Lark Base |
| `larc send` / `larc task` | Provides basic execution paths for IM and task operations |
| `larc ingress` | Runs the queue loop surface: enqueue, OpenClaw bundle, approve/resume, delegate, next, run-once, execute, followup |
| Claude Code skills | Ships Lark-oriented skills in `.claude/skills/` |

---

## Quick Start

```bash
npm install -g @larksuite/cli
git clone https://github.com/ShunsukeHayashi/lark-agent-runtime
cd lark-agent-runtime
chmod +x bin/larc
export PATH="$PWD/bin:$PATH"
larc init
larc bootstrap
```

---

## Current status

The five foundational phases are complete and live-verified against a real Lark tenant:

| Phase | What was proven |
|---|---|
| A — Runtime | `bootstrap`, `memory`, `send`, `task`, `agent` all working against live Lark APIs |
| B — Permission Intelligence | `auth suggest` infers minimum scopes for 8 compound office tasks; authority explanation included |
| C — Agent Operating Model | 4-agent registry in Lark Base; YAML batch registration; scopes stored per agent |
| D — Approval & Execution Control | Gate policy (32 task types × none/preview/approval); `larc approve gate` command |
| E — Knowledge Graph | Wiki BFS traversal; 37-node graph indexed; keyword query returns matches with neighbor context |

What is now live in the Agentic LARC MVP surface:
- queue ingestion: `enqueue`, `list`
- continuation: `approve`, `resume`
- delegation: `delegate`
- retrieval and handoff: `context`, `handoff`, `memory search`
- worker loop: `next`, `run-once`, `execute-stub`, `execute-apply`
- outcome states: `done`, `failed`, `partial`, `followup`
- supervised pilot: PPAL marketing flow has been exercised through queueing, OpenClaw dispatch, Base read, IM send, `partial`, `followup`, `done`, and Base mirror write-back
- operator runbook: [PPAL marketing supervised runbook](docs/ppal-marketing-supervised-runbook-2026-04-14.md)

What is still experimental or future:
- IM webhook / bot-triggered ingress from inside Lark itself (optional path, not the primary architecture)
- MergeGate integration for controlled execution review
- Full OpenClaw CLI compatibility layer
- Knowledge graph link extraction from document content (currently hierarchy-based)
- China-market go-to-market narrative refinement

Important nuance:

- LARC is already a working runtime surface for Lark-backed agent work
- today, it is best used as a supervised runtime under an upper-layer agent such as OpenClaw or Claude Code
- the primary path is `OpenClaw Agent -> official openclaw-lark plugin + LARC`
- supervised usage is now real, not conceptual: the PPAL marketing case has already been run end-to-end under operator supervision
- IM/webhook bot ingress is an optional future entrypoint, not the required core path

Key docs:

- [PLAYBOOK.md](PLAYBOOK.md)
- [docs/agentic-larc-mvp-2026-04-14.md](docs/agentic-larc-mvp-2026-04-14.md)
- [docs/larc-vs-lark-cli-and-openclaw.md](docs/larc-vs-lark-cli-and-openclaw.md)
- [docs/goal-aligned-playbook.md](docs/goal-aligned-playbook.md)
- [docs/permission-model.md](docs/permission-model.md)
- [docs/auth-suggest-cases.md](docs/auth-suggest-cases.md)
- [docs/terminology-glossary.md](docs/terminology-glossary.md)
- [CONTRIBUTING.md](CONTRIBUTING.md)

---

## Repo structure

```text
bin/
  larc                         # Main CLI entrypoint
lib/
  bootstrap.sh                 # Disclosure-chain loading from Lark Drive
  memory.sh                    # Daily memory sync ↔ Lark Base
  send.sh                      # IM message sending
  agent.sh                     # Agent registration and management
  task.sh                      # Lark Project task operations
  approve.sh                   # Approval flow + execution gate check
  heartbeat.sh                 # System state logging
  auth.sh                      # Scope inference and authorization
  knowledge-graph.sh           # Wiki node graph build and query
  ingress.sh                   # Queue, OpenClaw bundle, delegation, worker loop, partial follow-up
config/
  scope-map.json               # 32 task types × required scopes × authority type
  gate-policy.json             # 32 task types × risk level × execution gate
agents.yaml                    # Example multi-agent batch registration
docs/
  goal-aligned-playbook.md
  permission-model.md
  auth-suggest-cases.md        # 8 verified regression cases
  terminology-glossary.md      # (also .zh-CN.md, .ja.md)
scripts/
  setup-workspace.sh
  register-agents.sh           # YAML batch agent registration
  auth-suggest-check.sh        # Regression check for all 8 scope inference cases
.claude/skills/
  lark-*/                      # 24 Claude Code skills (Lark-oriented)
```

---

## Roadmap focus

- MergeGate integration for controlled execution review gates
- Full OpenClaw CLI compatibility layer
- Knowledge graph link extraction from document content
- Trilingual open-source release (English / Chinese / Japanese)

---

## License

MIT
