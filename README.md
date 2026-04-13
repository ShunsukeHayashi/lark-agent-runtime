# LARC — Lark Agent Runtime CLI

> **OpenClaw-compatible agent runtime for Lark (Feishu) — permission-first design**

[![version](https://img.shields.io/badge/version-0.1.0-blue)](bin/larc)
[![license](https://img.shields.io/badge/license-MIT-green)](#license)
[![lark-cli](https://img.shields.io/badge/requires-lark--cli-orange)](https://github.com/larksuite/cli)

---

## What is LARC?

**LARC** bridges [OpenClaw](https://github.com/BerriAI/OpenClaw)-style coding agents with Lark (Feishu) — the enterprise super-app — so that AI agents can work on **back-office and white-collar tasks**, not just code.

### The Problem

AI agents are exploding in developer workflows (GitHub Copilot, Cursor, Claude Code), but they haven't crossed into general white-collar work. The key blocker: **permission control is unsolved for non-developer tasks.**

- "What can this agent access in my company's Lark?"
- "Which approvals can it trigger? On whose authority?"
- "How do I give it memory without it touching production data?"

OpenClaw already solved this for coding tasks via a local filesystem + disclosure-chain loading pattern. LARC reproduces that pattern on **Lark Drive** — turning Lark's unified API surface into a pseudo-filesystem and permission substrate for office-work agents.

### The Solution

```
Local agent runtime (larc CLI)
       │
       ├── bootstrap  → Load SOUL/USER/MEMORY from Lark Drive (OpenClaw disclosure chain)
       ├── memory     → Sync daily memory ↔ Lark Base tables
       ├── send       → Send messages to Lark IM (≈ openclaw agent --agent main -m)
       ├── task       → Manage Lark Project tasks
       ├── approve    → Approval raw API helpers (definition/scaffold/preview/create/upload)
       ├── agent      → Register / manage agents in Lark Drive + Base registry
       └── auth       → Infer required scopes, issue authorization URLs
```

---

## Key Features

| Feature | Description |
|---------|-------------|
| **Disclosure chain** | Reads `SOUL.md → USER.md → MEMORY.md → HEARTBEAT.md` from Lark Drive at agent startup — equivalent to Claude Code's `CLAUDE.md` loading |
| **Scope inference** | `larc auth suggest "create an expense report"` → instantly returns the exact Lark scopes needed |
| **Permission profiles** | 4 built-in profiles: `readonly`, `writer`, `admin`, `backoffice_agent` |
| **Lark Drive as FS** | Use Lark Drive for agent workspaces instead of local filesystem — all file ops work without local disk |
| **Lark Base as memory** | Structured daily memory in Lark Base — queryable, auditable, shareable across agents |
| **Approval helpers** | Approval definition fetch, scaffold generation, preview, create, and file upload via raw API helpers |
| **24 Claude Code skills** | Full lark-cli skill set pre-loaded for Claude Code agents |

---

## Quick Start

### Prerequisites

```bash
npm install -g @larksuite/cli   # lark-cli
```

### Install

```bash
git clone https://github.com/ShunsukeHayashi/larc-openclaw-coding-agent
cd larc-openclaw-coding-agent
chmod +x bin/larc
export PATH="$PWD/bin:$PATH"
```

### Initialize

```bash
larc init          # configure Drive folder token, Base app token, IM chat ID
larc bootstrap     # load SOUL/USER/MEMORY from Lark Drive into ~/.larc/workspace/
larc status        # verify connection
```

### Core Commands

```bash
# Send a message to Lark IM (equivalent to: openclaw agent --agent main -m "...")
larc send "Please draft an expense report for last month"

# Sync memory to/from Lark Base
larc memory pull
larc memory push

# Permission management — the key differentiator
larc auth suggest "create expense report and route to approval flow"
# → Outputs: recommended scopes for the task description

larc auth check                        # check current scope status
larc auth login --profile writer       # issue authorization URL for writer profile

# Task management
larc task list
larc task create --title "Q2 budget review" --due 2026-04-20
larc task done <task_id>

# Agent management
larc agent list
larc agent register --id finance-bot --name "Finance Agent" --workspace "Finance ops"
scripts/register-agents.sh --file agents.yaml --dry-run

# Approval task utilities
larc approve list
larc approve definition APPROVAL_CODE
larc approve scaffold-form --definition-file approval-definition.json --output form.json
larc approve scaffold-payload --definition-file approval-definition.json --output extra.json
larc approve scaffold-package --definition-file approval-definition.json --output-dir ./approval-work
larc approve preview --approval-code APPROVAL_CODE --user-id USER_ID --form-file form.json --dry-run
larc approve create --approval-code APPROVAL_CODE --user-id USER_ID --form-file form.json --payload-file extra.json --dry-run
larc approve upload-file --path ./receipt.pdf --type attachment --dry-run
scripts/approval-check.sh --approval-code APPROVAL_CODE --user-id USER_ID
cat docs/approval-spike.md
cat docs/approval-template-quickstart.md
ls examples/approval/minimal
ls examples/approval/purchase-request
```

承認テンプレート自体がまだない場合は、先に [docs/approval-template-quickstart.md](docs/approval-template-quickstart.md) を見ると最短です。
入力イメージが欲しいときは [examples/approval/minimal/README.md](examples/approval/minimal/README.md) と [form.json](examples/approval/minimal/form.json) を見ると早いです。
別事例として [examples/approval/purchase-request/README.md](examples/approval/purchase-request/README.md) も使えます。

### Live Check

ローカルの `scripts/smoke-check.sh` が通ったあと、実トークンで一本道の確認をするときは `scripts/live-check.sh` を使います。

```bash
scripts/live-check.sh
scripts/live-check.sh --chat oc_xxx
scripts/live-check.sh --register-agent --chat oc_xxx
```

確認対象:

- `status`
- `auth check`
- `bootstrap --force`
- `memory push/pull/list`
- `task create`
- `send` (`--chat` 指定時)
- `agent register` (`--register-agent` 指定時)

前提:

- `~/.larc/config.env` に `LARC_DRIVE_FOLDER_TOKEN` と `LARC_BASE_APP_TOKEN` があること
- `send` や `agent register` を含める場合は `--chat <chat_id>` か `LARC_IM_CHAT_ID` を指定すること

---

## Architecture

### OpenClaw Disclosure Chain on Lark Drive

LARC reproduces OpenClaw's `BOOTSTRAP.md` pattern using Lark as the backend:

| OpenClaw (local FS) | LARC (Lark Drive) |
|--------------------|--------------------|
| `SOUL.md` | `Lark Drive / SOUL.md` |
| `USER.md` | `Lark Drive / USER.md` |
| `memory/YYYY-MM-DD.md` | `Lark Base agent_memory table` |
| `MEMORY.md` | `Lark Drive / MEMORY.md` |
| `HEARTBEAT.md` | `Lark Base agent_heartbeat table` |
| Local file edits | `lark-cli drive +upload` / `+download` |

### Permission Model

```
config/scope-map.json
  ├── 26 task types → required scopes
  ├── 4 profiles (readonly / writer / admin / backoffice_agent)
  └── error hints (131006, 99991663, 99991668)

larc auth suggest "<task description>"
  └── keyword matching → recommended scopes + identity (bot/user)

larc auth check
  └── compare current scopes → gap analysis → issue auth URL if needed
```

### Claude Code Skills

24 lark-cli skills pre-installed in `.claude/skills/` for Claude Code agents:

`lark-base` · `lark-calendar` · `lark-doc` · `lark-drive` · `lark-event` · `lark-im` · `lark-mail` · `lark-minutes` · `lark-sheets` · `lark-slides` · `lark-task` · `lark-vc` · `lark-whiteboard` · `lark-wiki` · `lark-approval` · `lark-attendance` · `lark-contact` · `lark-openapi-explorer` · `lark-skill-maker` · `lark-workflow-meeting-summary` · `lark-workflow-standup-report` · `lark-shared` · `lark-whiteboard-cli` · `lark-project`

---

## Repository Structure

```
bin/
  larc                       # Main CLI entrypoint
lib/
  bootstrap.sh               # Disclosure chain loading from Lark Drive
  memory.sh                  # Daily memory sync ↔ Lark Base
  send.sh                    # IM message sending
  agent.sh                   # Agent registration & management
  task.sh                    # Lark Project task ops
  approve.sh                 # Approval raw API helpers
  heartbeat.sh               # System state logging
  auth.sh                    # Scope inference & authorization
config/
  scope-map.json             # 26 task types × required scopes × 4 profiles
scripts/
  setup-workspace.sh         # One-shot workspace provisioning
  live-check.sh              # Ordered live verification for MVP
  register-agents.sh         # Batch agent registration from YAML
.claude/skills/
  lark-*/                    # 24 Claude Code skills
miyabi-lark-assets/          # Reference implementations (token manager, tool policies)
crm-assets/                  # CRM templates and agent prompts
PLAYBOOK.md                  # Implementation roadmap
```

---

## Configuration

`~/.larc/config.env`:

```bash
LARC_DRIVE_FOLDER_TOKEN=fldcnXXXXXX   # Lark Drive folder for agent workspace
LARC_BASE_APP_TOKEN=bascXXXXXX        # Lark Base app for memory/registry
LARC_IM_CHAT_ID=oc_XXXXXX             # Default IM chat for agent messages
LARC_WIKI_SPACE_ID=XXXXXXXX           # Optional: Wiki space for knowledge base
LARC_CACHE_TTL=300                    # Cache TTL in seconds (default: 5 min)
```

---

## Global Context

Similar patterns exist and confirm this direction is sound:

| Repository | Approach |
|-----------|---------|
| [`larksuite/openclaw-lark`](https://github.com/larksuite/openclaw-lark) | Official Lark × OpenClaw integration |
| `EriiiirE/OpenClaw-Lark-Knowledge-Agent` | RAG on Lark Drive docs |
| `shyrock/openclaw-lark-plus` | Multi-bot orchestration |
| `xiaomochn/openclaw-feishu-swarm` | Feishu swarm agents |

LARC's differentiator: **permission-first design** — `larc auth suggest` + scope profiles + user_access_token delegation for audit trails.

---

## Roadmap (PLAYBOOK.md)

- [x] Phase 1A: Core CLI dispatch (`larc init/bootstrap/memory/send/task/approve/agent/status`)
- [x] Phase 1B: Drive workspace setup + Base table provisioning (`scripts/setup-workspace.sh`)
- [x] Phase 1C: Permission scope map + `larc auth suggest/check/login`
- [x] Phase 2A: 24 Claude Code skills (all translated to English)
- [x] Phase 2B: Fix lark-cli command alignment (`drive files list`, `base +record-*`, etc.)
- [x] Phase 2C: Multi-agent YAML batch registration
- [x] Phase 2D: Approval raw API spike (`docs/approval-spike.md`)
- [ ] Phase 3: MergeGate integration (`lib/mergegate.sh`)
- [ ] Phase 4: Knowledge graph via Lark Wiki `@mention` / `[[link]]` structure

---

## License

MIT

---

---

## 日本語

**LARC** は [OpenClaw](https://github.com/BerriAI/OpenClaw) スタイルのコーディングエージェントを Lark（飛書）に橋渡しするランタイム CLI です。

### なぜ LARC か？

AI エージェントは開発業務での普及が先行していますが、ホワイトカラーの一般業務（経費申請・承認フロー・会議調整など）にはまだ広がっていません。最大の壁は **権限制御** です。

LARC は OpenClaw の「ローカル FS ＋ディスクロージャーチェーン」パターンを Lark Drive 上に再現し、バックオフィスエージェントが安全に動ける権限サブストレートを提供します。

### クイックスタート

```bash
npm install -g @larksuite/cli
git clone https://github.com/ShunsukeHayashi/larc-openclaw-coding-agent
cd larc-openclaw-coding-agent && chmod +x bin/larc
export PATH="$PWD/bin:$PATH"
larc init && larc bootstrap
```

---

## 中文

**LARC** 是将 [OpenClaw](https://github.com/BerriAI/OpenClaw) 风格的编码智能体与飞书（Lark）连接的运行时 CLI 工具。

### 为什么选择 LARC？

AI 智能体在开发工作流中已大规模普及，但在白领通用业务（费用申请、审批流程、会议协调等）中尚未广泛落地。核心障碍是**权限管控**的缺失。

LARC 将 OpenClaw 的「本地文件系统 + 披露链加载」模式复现于飞书 Drive 之上，为后台业务智能体提供安全可控的权限基础层。

### 快速开始

```bash
npm install -g @larksuite/cli
git clone https://github.com/ShunsukeHayashi/larc-openclaw-coding-agent
cd larc-openclaw-coding-agent && chmod +x bin/larc
export PATH="$PWD/bin:$PATH"
larc init && larc bootstrap
```

### 核心功能

| 功能 | 说明 |
|------|------|
| **披露链加载** | 从飞书 Drive 读取 `SOUL.md → USER.md → MEMORY.md → HEARTBEAT.md`，等同于 Claude Code 的 `CLAUDE.md` |
| **权限推断** | `larc auth suggest "创建费用报销单"` → 即时返回所需 Lark scope 列表 |
| **权限配置文件** | 4 种内置配置：`readonly` / `writer` / `admin` / `backoffice_agent` |
| **飞书 Drive 作为文件系统** | 用飞书 Drive 替代本地磁盘，所有文件操作无需本地存储 |
| **飞书 Base 作为记忆** | 结构化日常记忆存入飞书多维表格——可查询、可审计、多 Agent 共享 |
| **审批流作为合并门控** | 飞书审批流 = 业务任务输出的代码审查门控 |
| **24 个 Claude Code 技能** | 完整 lark-cli 技能集，预装至 `.claude/skills/` |
