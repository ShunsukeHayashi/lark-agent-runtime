# LARC — Lark Agent Runtime

> The Lark execution and governance layer for OpenClaw agents

[![version](https://img.shields.io/badge/version-0.2.0-blue)](bin/larc)
[![CI](https://github.com/ShunsukeHayashi/lark-agent-runtime/actions/workflows/ci.yml/badge.svg)](https://github.com/ShunsukeHayashi/lark-agent-runtime/actions/workflows/ci.yml)
[![license](https://img.shields.io/badge/license-MIT-green)](#license)
[![lark-cli](https://img.shields.io/badge/requires-lark--cli-orange)](https://github.com/larksuite/cli)

English | [简体中文](README.zh-CN.md) | [日本語](README.ja.md)

---

## What is LARC?

**LARC** is the Lark execution and governance layer for [OpenClaw](https://openclaw.dev) agents.

OpenClaw is the agent brain and execution engine. LARC is what gives OpenClaw safe, permission-controlled access to Lark's enterprise surfaces.

```
OpenClaw agent (LLM execution)
    ↓  larc ingress openclaw
LARC (permission · queue · audit · context)
    ↓  lark-cli
Lark API — Drive / Base / IM / Approval / Wiki
```

If OpenClaw is the agent, LARC is the guard rail: it enforces execution gates, tracks authority, manages the task queue, and records everything back into Lark.

---

## Why this exists

AI agents are strong in coding workflows but still weak in ordinary white-collar work. The blocker is rarely model quality. It is:

- unclear minimum permissions
- unclear execution authority  
- an over-reliance on local filesystems instead of enterprise-native surfaces

LARC takes a `permission-first` approach — explain required scopes before touching anything, route through Lark-native surfaces, record every action back into Base.

---

## Key capabilities

| Capability | What it does |
|---|---|
| `larc bootstrap` | Loads `SOUL → USER → MEMORY → HEARTBEAT` from Lark Drive into the agent context |
| `larc auth suggest` | Infers minimum scopes and authority type from a natural-language task description |
| `larc approve gate` | Checks execution gate policy (none / preview / approval) before running a task |
| `larc ingress openclaw` | Builds and dispatches the next governed action bundle to OpenClaw |
| `larc ingress recover` | Resets stale in-progress queue items after a worker crash |
| `larc agent register` | Registers agents in Lark Base with declared scopes; supports YAML batch registration |
| `larc memory` | Syncs daily memory with Lark Base; supports full pagination and keyword search |
| `larc status` | Shows Base connectivity, OpenClaw install state, daemon status, and queue stats |
| `larc kg build` / `larc kg query` | Indexes Lark Wiki node graph and answers concept queries with neighbor context |
| Claude Code skills | Ships 24 Lark-oriented skills in `.claude/skills/` |

---

## Quick Start

### Prerequisites

```bash
which openclaw    # OpenClaw — the agent execution engine
which lark-cli    # lark-cli — npm install -g @larksuite/cli
which python3     # Python 3.8+
```

> **Start with OpenClaw.** LARC is a runtime layer for OpenClaw agents, not a standalone agent.  
> Install the LARC runtime skill in OpenClaw first: `bash scripts/install-openclaw-larc-runtime-skill.sh`

### Install LARC

```bash
# Install LARC (downloads to ~/.larc/runtime/)
curl -fsSL https://raw.githubusercontent.com/ShunsukeHayashi/lark-agent-runtime/main/scripts/install.sh | bash

# Configure lark-cli with your Lark app credentials
lark-cli config init --app-id <App ID> --app-secret-stdin --brand lark
lark-cli auth login

# One-command workspace setup
larc quickstart

# Verify everything
larc status
```

→ Full guide: [docs/quickstart-ja.md](docs/quickstart-ja.md)
→ OpenClaw integration: [docs/openclaw-integration.md](docs/openclaw-integration.md)
→ Lark app setup (for coordinators): [docs/lark-app-setup.md](docs/lark-app-setup.md)

---

## Operating modes

| Mode | What runs | Status |
|---|---|---|
| **Supervised** | OpenClaw + Claude Code manually calls `larc ingress run-once` | ✅ Stable |
| **OpenClaw-assisted autonomous** | OpenClaw calls `larc ingress openclaw --execute`; official `openclaw-lark` handles atomic Lark actions; LARC handles gate/queue/audit | ✅ Stable |
| **Experimental IM loop** | `larc daemon start` — IM poller enqueues messages, worker dispatches to OpenClaw automatically | 🧪 Experimental |

> **The IM daemon loop is experimental.** Use supervised or OpenClaw-assisted mode for production workflows. The daemon is useful for testing and low-stakes automation, not as the primary onboarding path.

---

## Current status

### Proven and stable

| Area | What is verified |
|---|---|
| Permission intelligence | `auth suggest` infers minimum scopes for 32 task types; authority model documented |
| Approval gate | `approve gate` enforces none/preview/approval policy before execution |
| Queue lifecycle | `enqueue → openclaw → done/fail/partial/followup` full cycle verified |
| Agent registry | YAML batch registration; scopes stored per agent in Lark Base |
| Memory sync | Paginated `memory pull/push/search` against live Lark Base |
| Knowledge graph | Wiki BFS traversal; keyword query with neighbor context |
| Status dashboard | `larc status` shows Base, OpenClaw, daemon, and queue state in one view |

### Experimental

- IM daemon loop (`larc daemon start`) — echo loop and restart reliability still being hardened
- `larc send` notifications via bot token — just fixed (2026-04-15)
- OpenClaw plugin/runtime combinations may still need setup verification per environment; the recommended path remains `official openclaw-lark plugin + LARC`

---

## Repo structure

```text
bin/larc                       # Main CLI entrypoint
lib/
  bootstrap.sh                 # Disclosure-chain loading from Lark Drive
  memory.sh                    # Daily memory sync ↔ Lark Base (paginated)
  send.sh                      # IM message sending (--as bot)
  ingress.sh                   # Queue, OpenClaw bundle, delegation, worker loop
  daemon.sh                    # IM poller + queue worker subprocess management
  worker.sh                    # Queue worker (OpenClaw dispatch or supervised fallback)
  runtime-common.sh            # Shared helpers for subprocess modules
  agent.sh                     # Agent registration and management
  auth.sh                      # Scope inference and authorization
  approve.sh                   # Approval flow + execution gate check
  knowledge-graph.sh           # Wiki node graph build and query
config/
  scope-map.json               # 32 task types × required scopes × authority type
  gate-policy.json             # 32 task types × risk level × execution gate
.claude/skills/lark-*/         # 24 Claude Code skills (Lark-oriented)
docs/
  quickstart-ja.md             # Full onboarding guide (Japanese)
  openclaw-integration.md      # How LARC connects to OpenClaw
  permission-model.md          # Scope and authority model
```

---

## Verification

```bash
bash -n bin/larc scripts/install.sh scripts/auth-suggest-check.sh
bash scripts/auth-suggest-check.sh --verify
```

---

## License

MIT
