# LARC v0.2.0 Operational Playbook

> Ground-truth reference for operating, extending, and launching LARC.  
> Last updated: 2026-04-17 | Version: 2.0.0

---

## Section 1 — Orientation

> Full product overview: [README.md](README.md) · [README.zh-CN.md](README.zh-CN.md) · [README.ja.md](README.ja.md)

LARC sits between OpenClaw/Claude Code (the reasoning agent) and Lark (the enterprise platform): it enforces execution gates, infers minimum scopes, manages the task queue, and records every action back into Base.

### Core message (3 languages)

**English**: "Permission-first runtime for Lark-native office-work agents."

**中文**: "飞书 Agent 权限管理 runtime — 让 AI 只做它被允许做的事。"

**日本語**: "AIに与える権限を設計する。Lark対応エージェントのランタイム基盤。"

---

## Section 2 — Current Truth (2026-04-17)

### Version & repository

| Field | Value |
|-------|-------|
| Version | v0.2.0 |
| Repo | `ShunsukeHayashi/lark-agent-runtime` |
| Visibility | PUBLIC (since 2026-04-14) |
| License | MIT |
| Commits | 97 |
| Install path | `~/study/larc/` (symlink: `~/bin/larc`) |

### Live metrics

- Active queue items seen in production: 11+ (including CRM/SFA tasks)
- Registered agents: 4 (main, expense-processor, crm-agent, doc-agent)
- Scope-map task types: 32
- Gate-policy entries: 32
- Claude Code skills: 24 (`.claude/skills/lark-*/`)

### Implementation status

| Feature | Status | Notes |
|---------|--------|-------|
| `larc init` | ✅ stable | Keychain + config setup |
| `larc bootstrap` | ✅ stable | SOUL/USER/MEMORY/HEARTBEAT load from Drive |
| `larc memory pull/push` | ✅ stable | Base ↔ local sync |
| `larc send` | ✅ stable | IM message to any chat |
| `larc task list/create/done` | ✅ stable | Lark Project ops |
| `larc agent list/register` | ✅ stable | YAML batch registration |
| `larc auth suggest` | ✅ stable | 32 task types, tested 8 real cases |
| `larc auth router` | ✅ stable | user/bot/blocked routing |
| `larc auth check/login` | ✅ stable | Profile-based scope check |
| `larc approve gate/create` | ✅ stable | Gate check + Approval flow creation |
| `larc ingress enqueue/list/run-once/done/prune/retry/stats` | ✅ stable | Full queue lifecycle |
| `larc ingress delegate` | ✅ stable | main → specialist agent routing |
| `larc ingress context/openclaw` | ✅ stable | OpenClaw-first bundle output |
| `larc kg build/query/show/status` | ✅ stable | Lark Wiki knowledge graph |
| `larc quickstart` | ✅ stable | 7-step idempotent onboarding |
| `larc status` | ✅ stable | Keychain + token + daemon state |
| Base table provisioning | ✅ stable | Internal to `larc quickstart` |
| IM daemon (`lib/daemon.sh`) | ⚠️ experimental | PID management not hardened |
| Windows support | ✅ implemented | Git Bash / WSL / PS1 launcher |
| `lib/mergegate.sh` | 🔴 stub | Phase 3, not integrated |

---

## Section 3 — Architecture

### Execution modes

```
Mode 1: Supervised (STABLE)
  Human CLI → larc ingress enqueue → run-once → done
  Gate = preview/approval → human confirms → resume

Mode 2: OpenClaw-assisted (PARTIALLY VERIFIED)
  OpenClaw agent → larc ingress openclaw → next-action bundle → agent executes → done

Mode 3: IM Daemon (EXPERIMENTAL)
  Lark IM message → lib/daemon.sh → auto-enqueue → run-once loop
  Risk: PID management / restart reliability not verified
```

### Storage topology

```
~/.larc/
  config.env            ← LARC_BASE_APP_TOKEN, LARC_DRIVE_FOLDER_TOKEN, etc.
  runtime/              ← bin/larc symlink target
  cache/
    workspace/<agent_id>/
      SOUL.md / USER.md / MEMORY.md / RULES.md / HEARTBEAT.md
      AGENT_CONTEXT.md  ← consolidated context

Lark Drive (LARC_DRIVE_FOLDER_TOKEN)
  SOUL.md / USER.md / MEMORY.md / RULES.md / HEARTBEAT.md
  memory/YYYY-MM-DD.md

Lark Base (LARC_BASE_APP_TOKEN)
  agents_registry   ← agent metadata + declared scopes
  agent_memory      ← daily memory records
  agent_heartbeat   ← system state log
  agent_logs        ← audit trail
  agent_queue       ← queue ledger (mirror of local queue)
```

### Permission model

```
larc auth suggest "<task>"
  → keyword match against config/scope-map.json (32 types)
  → minimum required scopes
  → identity type: user_access_token | tenant_access_token | bot_token
  → gate level: none | preview | approval
  → authority explanation (why user/bot/blocked)

larc auth router
  → per-operation routing: user_token | bot_token | blocked
  → blocked = Lark enforces User OAuth only (cannot be automated)

config/gate-policy.json
  → 32 task types × risk level × gate
  → none:  agent executes immediately
  → preview: human reviews, then `larc ingress approve <id>`
  → approval: Lark Approval flow created, human approves in UI, then `larc ingress resume <id>`
```

### HITL constraints (permanent — Lark API enforces User OAuth)

These operations **cannot** be automated. Human must act in Lark UI:

- `approval.tasks.approve` — approve a pending approval
- `approval.tasks.reject` — reject an approval
- `approval.tasks.transfer` — transfer approver
- `approval.instances.cancel` — cancel an approval instance

`lib/approve.sh` intentionally does NOT implement these.

---

## Section 4 — Setup Runbook

### Prerequisites

```bash
# Required
brew install jq python3
npm install -g @larksuite/cli

# Verify
lark-cli --version
jq --version
```

### Install

```bash
git clone https://github.com/ShunsukeHayashi/lark-agent-runtime ~/study/larc
ln -sf ~/study/larc/bin/larc ~/bin/larc
export PATH="$PATH:$HOME/bin"

# Verify
larc --version   # → v0.2.0
```

### Configuration (`~/.larc/config.env`)

```bash
LARC_DRIVE_FOLDER_TOKEN=fldcnXXXXXX   # Lark Drive folder for agent workspace
LARC_BASE_APP_TOKEN=bascXXXXXX        # Lark Base app for memory/registry
LARC_IM_CHAT_ID=oc_XXXXXX             # Default IM chat for agent messages
LARC_WIKI_SPACE_ID=XXXXXXXX           # Optional: Wiki space for knowledge base
LARC_CACHE_TTL=300                    # Cache TTL seconds (default: 5 min)
LARC_APPROVAL_CODE=XXXXXXXX           # Optional: Lark Approval flow code
```

### Quickstart (7 steps, idempotent)

```bash
larc quickstart
```

Internally runs:
1. `larc init` — config.env check + keychain setup
2. Base table provisioning (internal — 5 tables: agent_queue, agent_logs, agent_memory, agents_registry, wiki_knowledge_graph)
3. `larc bootstrap --agent main` — load disclosure chain
4. `larc agent register` — register agents from agents.yaml
5. `larc memory pull --agent main` — sync memory from Base
6. `larc ingress enqueue --text "quickstart test" --source claude-code`
7. `larc ingress run-once` → `larc ingress done --queue-id <id>`

---

## Section 5 — Daily Operations

### Morning startup

```bash
larc status                          # verify keychain + tokens
larc memory pull --agent main        # sync overnight memory
larc ingress list --status pending   # see what's queued
larc ingress list --status failed    # any failures to triage
```

### Task processing loop

```bash
# Standard supervised flow
larc ingress enqueue --text "CRM顧客フォローアップリストを更新" --agent main --source claude-code
larc ingress run-once
# → if gate=preview: human reviews, then:
larc ingress approve <queue-id>
# → if gate=approval: Lark Approval flow created, human approves in UI, then:
larc ingress resume <queue-id>
# → mark done
larc ingress done --queue-id <id>
```

### Delegation flow

```bash
# main delegates to specialist
larc ingress delegate --queue-id <id> --agent crm-agent
# specialist picks up
larc ingress run-once --agent crm-agent
```

### End of day

```bash
larc memory push --agent main        # persist memory to Base
larc ingress stats                   # daily queue summary
larc heartbeat --agent main          # log system state
```

---

## Section 6 — Permission Model Deep Dive

### `larc auth suggest`

```bash
larc auth suggest "経費申請書を作成して承認フローを起動"
# Output:
# Task type: expense_approval
# Required scopes: base:record:created, approval:approval:write, im:message:send_as_bot
# Identity: user_access_token
# Gate: approval
# Authority: User OAuth required for approval flow creation
# Minimum profile: writer
```

### `larc auth router`

```bash
larc auth router --operation "drive:download"     # → user_access_token
larc auth router --operation "im:message:send"    # → bot_token
larc auth router --operation "approval:tasks:approve"  # → BLOCKED (User OAuth only, cannot automate)
```

### `larc auth check`

```bash
larc auth check --profile writer       # verify current token has writer profile scopes
larc auth check --profile backoffice_agent
```

### `larc auth login`

```bash
larc auth login --profile backoffice_agent  # opens browser OAuth flow for required scopes
```

### Gate policy reference

| Gate | When | Human action |
|------|------|-------------|
| `none` | Safe read / notification ops | None required |
| `preview` | Write ops, data changes | Review content → `larc ingress approve <id>` |
| `approval` | Financial, HR, legal ops | Lark UI approval → `larc ingress resume <id>` |

---

## Section 7 — Queue Lifecycle

### States

```
pending → in_progress → done
                      → failed   → retry with: larc ingress retry <id>
                      → blocked  → resume with: larc ingress resume <id>
                      → partial  → followup with: larc ingress followup <id>
```

Additional states:
- `pending_preview` — awaiting human preview confirmation
- `blocked_approval` — awaiting Lark Approval flow completion
- `delegated` — transferred to specialist agent

### Enqueue options

```bash
larc ingress enqueue \
  --text "<task description>" \
  --agent main \
  --source <claude-code|lark_im|github|voice|manual> \
  --priority <high|normal|low>
```

### Triage commands

```bash
larc ingress prune --days 7 --status failed    # remove old failed items
larc ingress retry --queue-id <id>             # retry a failed item
larc ingress retry --status failed --limit 5   # bulk retry
larc ingress stats                             # queue health summary
```

### Stale queue recovery

```bash
# Reset all stale in_progress items (stuck > timeout minutes, default 120)
larc ingress recover

# Dry-run first to see what would be reset
larc ingress recover --dry-run

# Custom timeout threshold
larc ingress recover --timeout 60
```

---

## Section 8 — Agent Management

### Register from YAML

```bash
larc agent register   # reads agents.yaml in current dir or ~/.larc/agents.yaml
```

### `agents.yaml` format

```yaml
agents:
  - id: main
    name: Main Orchestrator
    model: claude-sonnet-4-6
    scopes:
      - docs:doc:readonly
      - im:message:send_as_bot
      - base:record:readonly
    workspace: general

  - id: expense-processor
    name: 経費処理エージェント
    model: claude-haiku-4-5
    scopes:
      - base:record:created
      - approval:approval:write
    workspace: finance

  - id: crm-agent
    name: CRMエージェント
    model: claude-sonnet-4-6
    scopes:
      - base:record:created
      - base:record:readonly
    workspace: sales

  - id: doc-agent
    name: ドキュメントエージェント
    model: claude-sonnet-4-6
    scopes:
      - docs:doc:readonly
      - docs:doc:created
      - drive:drive:readonly
    workspace: knowledge
```

### List / show agents

```bash
larc agent list                    # all registered agents
larc agent show --agent crm-agent  # detail for one agent
```

---

## Section 9 — Memory Management

### Sync cycle

```
Daily:
  larc memory pull --agent main   → Lark Base → ~/.larc/cache/workspace/main/
  [agent work happens]
  larc memory push --agent main   → ~/.larc/cache/workspace/main/ → Lark Base

Bootstrap (on session start):
  larc bootstrap --agent main
  → downloads SOUL.md / USER.md / MEMORY.md / RULES.md / HEARTBEAT.md from Drive
  → consolidates into AGENT_CONTEXT.md
```

### Memory search

```bash
larc memory search --query "CRM顧客フォローアップ" --days 30
larc memory search --query "expense" --agent expense-processor --days 7
```

### Memory file structure

```
~/.larc/cache/workspace/main/
  SOUL.md          ← agent identity & principles (from Drive)
  USER.md          ← user profile (from Drive)
  MEMORY.md        ← long-term memory index (from Drive)
  RULES.md         ← operating rules (from Drive)
  HEARTBEAT.md     ← system state (from Drive)
  memory/
    2026-04-14.md  ← daily context files
    2026-04-15.md
    ...
  AGENT_CONTEXT.md ← consolidated, used by agent at runtime
```

---

## Section 10 — Knowledge Graph

### Build and query

```bash
larc kg build    # BFS crawl of Lark Wiki space → 37+ nodes in Base
larc kg status   # index freshness + node count
larc kg query "expense approval process"   # related nodes + parent/sibling context
larc kg show --node-id <id>               # full node detail
```

### Use in agent context

```bash
# After building the KG, memory search and context bundles include KG-derived links
larc ingress context --queue-id <id> --days 14
```

---

## Section 11 — Daemon Operations (EXPERIMENTAL)

> The IM daemon is functional but restart reliability is not verified. Do not use as primary path in production.

### Start / stop

```bash
larc daemon start   # starts lib/daemon.sh as background process, writes PID
larc daemon stop    # sends SIGTERM to PID
larc daemon status  # checks PID + last heartbeat
```

### Configuration

The daemon interval is passed as a positional argument (default: 30 seconds):

```bash
larc daemon start --agent main --interval 60   # poll every 60s
```

Logs are written to `~/.larc/logs/daemon-im.log` and `~/.larc/logs/daemon-worker.log`.

### Known limitations

- No automatic restart on crash
- `nohup` equivalent on Windows (Git Bash) is weak — use Scheduled Task or NSSM for Windows
- Health check / watchdog not yet implemented (T-015)

---

## Section 12 — Error Handling

### Known Lark API error codes

| Code | Meaning | Resolution |
|------|---------|-----------|
| 230038 | Cross-tenant DM blocked | Use tenant-internal chat only |
| 232024 | Token scope insufficient | `larc auth check` → `larc auth login` |
| 232033 | Bot not in chat | Add bot to target chat in Lark UI |
| 131005 | External user API gap | External users cannot be managed via Bot API — human action required |

### Retry policy

- Failed queue items: manual `larc ingress retry <id>` or bulk `--status failed`
- Lark API 5xx: LARC does not auto-retry (by design — prevents duplicate writes)
- Token expiry: `larc status` detects → `larc auth login` refreshes

### Cross-platform notes (Windows)

- `fcntl.flock` → `msvcrt.locking` fallback implemented in `lib/billing.sh`
- `realpath / stat / sed / date` → portable shims in `lib/shims.sh`
- Git Bash and WSL2 tested; native PowerShell via `bin/larc.ps1`

---

## Section 13 — Launch Roadmap

### Milestone overview

| Milestone | Status | Description |
|-----------|--------|-------------|
| M1: Claude Code → LARC | ✅ COMPLETE | Supervised mode, full queue lifecycle |
| M2: OpenClaw → LARC | 🔄 IN PROGRESS | Partially verified; env verification needed |
| M3: Stable Daemon | 🔴 PENDING | PID mgmt + auto-restart hardening |
| M4: MergeGate | 🔴 PENDING | Bot Webhook → merge gate integration |

### Task backlog (from tasks.json)

| ID | Title | Milestone | Priority |
|----|-------|-----------|----------|
| T-008 | Real-hardware smoke test (Windows 11 / AAI) | windows-support | medium |
| T-010 | Commit 14 pending files + tag v0.2.0 | launch | HIGH |
| T-011 | Set GitHub Topics + Description | launch | HIGH |
| T-012 | Post to Feishu developer community (Chinese) | launch | HIGH |
| T-013 | Publish X thread @The_AGI_WAY (39K followers) | launch | HIGH |
| T-014 | AI Governance Diagnosis service proposal template | bizdev | medium |
| T-015 | Stabilize IM daemon (experimental → stable) | operational-resilience | medium |
| T-016 | Write Note/Zenn SFA case study article | launch | medium |
| T-017 | Expand scope-map 32 → 50 task types | core-ux | low |
| T-018 | MergeGate integration (lib/mergegate.sh) | milestone-2 | low |
| T-019 | Publish GitHub Release v0.2.0 | launch | HIGH |
| T-020 | OpenClaw-assisted autonomous mode env verification | milestone-2 | medium |

### Immediate next actions (in order)

1. `T-010` — Commit all 14 modified files, push, tag `v0.2.0`
2. `T-019` — Create GitHub Release from CHANGELOG
3. `T-011` — Set repo Topics: `lark feishu agent-runtime permissions openclaw bash`
4. `T-012` — Post to open.feishu.cn + 掘金
5. `T-013` — Publish X thread on @The_AGI_WAY

---

## Section 14 — Business Playbook

### Market priority

| Market | Platform | Language | Channel |
|--------|---------|---------|---------|
| Primary | Feishu (飞书) China | 中文 | open.feishu.cn dev community, 掘金 (juejin.cn) |
| Secondary | Lark Japan | 日本語 | Zenn, Note, @The_AGI_WAY (39K) |
| Tertiary | Lark International | English | GitHub, Dev.to |

### OSS strategy

- MIT license — maximum adoption
- LARC as the governed runtime; OpenClaw as the agent engine
- GitHub discoverability depends on Topics + Description (T-011 blocks this)
- README trilingual: `README.md` (EN) / `README.zh-CN.md` (ZH) / `README.ja.md` (JA)

### AI Governance Diagnosis service (T-014)

Target: Any enterprise deploying AI agents (not Lark-dependent)

```
Service: AI業務導入 権限設計診断
Price: ¥60〜80万/社
Flow:
  1. 4-question intake (LARCの質問ベース)
  2. Task × Risk classification map
  3. 危険箇所レポート (high-risk operations without gates)
  4. Continuous improvement proposal
```

This service monetizes LARC's scope-map and gate-policy concepts directly.

### KPIs to track

| Metric | Target | Tracking |
|--------|--------|---------|
| GitHub stars | 100 in 30 days | GitHub Insights |
| Feishu community posts | 3 in first week | open.feishu.cn |
| X thread impressions | 50K in 7 days | @The_AGI_WAY analytics |
| Diagnosis service inquiries | 2 in 60 days | Lark IM / DM |
| Queue tasks processed (production) | 50/month | `larc ingress stats` |

---

## Appendix A — Lark App Required Scopes

Minimum scopes for each agent profile:

| Profile | Scopes |
|---------|--------|
| `readonly` | `drive:drive:readonly`, `docs:doc:readonly`, `base:record:readonly`, `wiki:wiki:readonly` |
| `writer` | readonly + `docs:doc:created`, `base:record:created`, `im:message:send_as_bot` |
| `admin` | writer + `approval:approval:write`, `task:task:write`, `contact:user:readonly` |
| `backoffice_agent` | admin + `calendar:calendar:write`, `attendance:sheet:write` |

---

## Appendix B — Tenant Constraints Reference

Full documentation: `docs/known-issues/lark-external-user-api-gap.md`

Key constraints:
- External users (cross-tenant): cannot be DM'd by bot (error 230038)
- External users: cannot be looked up via `contact:user:readonly` from foreign tenant
- Approval actions: User OAuth enforced, bot cannot approve/reject
- Wiki space: read requires explicit space membership — bootstrap will fail if agent not added

---

## Appendix C — Quick Command Reference

```bash
# Setup
larc init
larc quickstart

# Bootstrap
larc bootstrap --agent main
larc status

# Auth
larc auth suggest "タスク説明"
larc auth router --operation "docs:download"
larc auth check --profile writer
larc auth login --profile backoffice_agent

# Queue
larc ingress enqueue --text "..." --agent main --source claude-code
larc ingress list --status pending
larc ingress run-once
larc ingress approve <id>    # preview gate
larc ingress resume <id>     # approval gate
larc ingress done --queue-id <id>
larc ingress retry --queue-id <id>
larc ingress prune --days 7 --status failed
larc ingress stats
larc ingress recover               # reset stale in_progress items → pending
larc ingress recover --dry-run
larc ingress followup --agent crm-agent   # pick up partial items
larc ingress delegate --queue-id <id> --agent crm-agent
larc ingress context --queue-id <id> --days 14   # context bundle for agent
larc ingress openclaw --agent main --days 14     # OpenClaw-format next-action bundle

# Memory
larc memory pull --agent main
larc memory push --agent main
larc memory search --query "..." --days 30

# Agent
larc agent list
larc agent register
larc agent show --agent <id>

# Knowledge graph
larc kg build
larc kg query "concept"
larc kg status

# Daemon (experimental)
larc daemon start
larc daemon stop
larc daemon status

# Triage
larc ingress list --status failed
larc ingress retry --status failed --limit 10
larc heartbeat --agent main
```
