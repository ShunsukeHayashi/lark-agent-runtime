# Lark Harness

> The business operations harness for AI agents — persistent memory, reusable skills, SaaS protocols, approval gates, and full audit — built on Lark.

[![version](https://img.shields.io/badge/version-0.2.0-blue)](bin/larc)
[![CI](https://github.com/ShunsukeHayashi/lark-harness/actions/workflows/ci.yml/badge.svg)](https://github.com/ShunsukeHayashi/lark-harness/actions/workflows/ci.yml)
[![license](https://img.shields.io/badge/license-MIT-green)](#license)
[![lark-cli](https://img.shields.io/badge/requires-lark--cli-orange)](https://github.com/larksuite/cli)

English | [简体中文](README.zh-CN.md) | [日本語](README.ja.md)

---

## What is Lark Harness?

The biggest shift in AI agents had nothing to do with making models smarter. It was about making the **environment around them** smarter.

**Lark Harness** is that environment — for business operations.

```
LLM (Claude / GPT / ...)
    ↓
Lark Harness
    memory · skills · protocols · gates · audit
    ↓
SaaS APIs — freee / Shopify / HubSpot / SmartHR / ...
    ↓  lark-cli
Lark — Drive / Base / IM / Approval / Wiki
```

Same model. Completely different reliability.

---

## The three problems it solves

AI agents fail in business operations for three reasons:

| Problem | Lark Harness answer |
|---|---|
| No memory across sessions | Lark Base as persistent memory |
| No reusable domain knowledge | SKILL.md — 25 skills for Lark + SaaS operations |
| No governance | Gate policy (none / preview / approval) + full audit log |

---

## Key capabilities

| Capability | What it does |
|---|---|
| `larc bootstrap` | Loads agent context (`SOUL → USER → MEMORY → HEARTBEAT`) from Lark Drive |
| `larc auth suggest` | Infers minimum required scopes from a natural-language task description |
| `larc approve gate` | Enforces execution gate policy before any action |
| `larc ingress enqueue` | Queues a task into Lark Base with source tagging |
| `larc ingress run-once` | Picks up and executes the next queued task |
| `larc ingress done / fail` | Records outcome + notifies via Lark IM |
| `larc agent register` | Registers agents in Lark Base with declared scopes |
| `larc memory` | Syncs daily memory with Lark Base |
| `larc kg build / query` | Indexes Lark Wiki node graph; answers concept queries |
| Claude Code skills | 25 Lark-oriented skills in `.claude/skills/` |

---

## SaaS connectors

Lark Harness wraps best-in-class MCP servers, adding HITL gates and Lark routing on top:

| SaaS | MCP | Coverage |
|---|---|---|
| freee | `freee-mcp` (OSS, Apache-2.0) | 会計 / HR / 請求 / 工数 / 電子契約 |
| Shopify | `Shopify AI Toolkit` (OSS, MIT) | 注文 / 商品 / 顧客 / 在庫 |
| HubSpot | HubSpot MCP | CRM / マーケ |
| Google Workspace | Google MCP | Drive / Docs / Sheets / Calendar |
| Notion | Notion MCP | ドキュメント管理 |
| SmartHR | API wrapper | HR / 労務 |

---

## Quick Start

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/ShunsukeHayashi/lark-harness/main/scripts/install.sh | bash

# Configure
lark-cli config init --app-id <App ID> --app-secret-stdin --brand lark
lark-cli auth login

# One-command workspace setup
larc quickstart

# Verify
larc status
```

→ Full guide: [docs/quickstart-ja.md](docs/quickstart-ja.md)
→ Self-paced onboarding course: [course/README.md](course/README.md)

---

## Repo structure

```text
bin/larc                       # CLI entrypoint
lib/
  bootstrap.sh                 # Context loading from Lark Drive
  memory.sh                    # Memory sync ↔ Lark Base
  ingress.sh                   # Task queue + execution
  auth.sh                      # Scope inference + authorization
  approve.sh                   # Gate policy enforcement
  agent.sh                     # Agent registration
config/
  scope-map.json               # 50 task types × scopes × authority
  gate-policy.json             # 50 task types × risk × gate
.claude/skills/                # 25 Claude Code skills
docs/                          # Guides and references
```

---

## License

MIT
