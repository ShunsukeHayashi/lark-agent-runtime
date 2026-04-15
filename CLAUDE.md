# LARC — Lark Agent Runtime CLI

> Claude Code context file for this project.

## Project Summary

**LARC** bridges OpenClaw-style coding agents with Lark (Feishu) — enabling AI agents to operate on back-office and white-collar tasks, not just code.

- **Core pattern**: Reproduces OpenClaw's disclosure chain (`SOUL.md → USER.md → MEMORY.md → HEARTBEAT.md`) using Lark Drive as the backend filesystem
- **Permission-first**: `larc auth suggest "<task>"` → keyword matching against `config/scope-map.json` → required scopes + identity type
- **Target market**: Feishu (飞书) enterprise developers in China; secondary: Japanese and English-speaking Lark markets

## Repository Structure

```
bin/larc                    # Main CLI entrypoint (bash)
lib/
  bootstrap.sh              # Disclosure chain loading from Lark Drive
  memory.sh                 # Daily memory sync ↔ Lark Base
  send.sh                   # IM message sending
  agent.sh                  # Agent registration & management
  task.sh                   # Lark Project task ops
  approve.sh                # Lark Approval flow
  heartbeat.sh              # System state logging
  auth.sh                   # Scope inference & authorization
config/
  scope-map.json            # 26 task types × required scopes × 4 profiles
scripts/
  setup-workspace.sh        # One-shot workspace provisioning
.claude/skills/
  lark-*/SKILL.md           # 24 Claude Code skills (all in English)
```

## Key Architecture Decisions

### lark-cli Command Alignment (PHASE 0)

The current `lib/*.sh` files must use **actual lark-cli shortcut commands**, not fictional ones. Verified mappings:

| Old (wrong) | Correct lark-cli command |
|---|---|
| `drive list --folder-token` | `drive files list --params '{"folder_token":"..."}'` |
| `drive download --file-token` | `drive +download --file-token` |
| `drive folder create` | `drive files create_folder --data '{"folder_token":"...","name":"..."}'` |
| `base tables list` | `base +table-list --base-token` |
| `base records list` | `base +record-list --base-token` |
| `base records create/update` | `base +record-upsert --base-token` |
| `task tasks create` | `task +create` |
| `task tasks patch` | `task +complete` |

### Scope Map (`config/scope-map.json`)

**32 task types** (v0.2.0). Structure:
```json
{
  "tasks": {
    "read_document": { "scopes": ["..."], "identity": "user_access_token", "description": "..." },
    ...
  },
  "profiles": {
    "readonly": { "scopes": [...], "description": "..." },
    "writer": { "scopes": [...], "description": "..." },
    "admin": { "scopes": [...], "description": "..." },
    "backoffice_agent": { "scopes": [...], "description": "..." }
  }
}
```

### Disclosure Chain Loading Order

```
Lark Drive folder (LARC_DRIVE_FOLDER_TOKEN)
  └── SOUL.md         → agent identity & principles
  └── USER.md         → user profile
  └── MEMORY.md       → long-term memory
  └── RULES.md        → operating rules
  └── HEARTBEAT.md    → system state
  └── memory/
        └── YYYY-MM-DD.md  → daily context

All downloaded to: ~/.larc/cache/workspace/<agent_id>/
Consolidated into: ~/.larc/cache/workspace/<agent_id>/AGENT_CONTEXT.md
```

## Config (`~/.larc/config.env`)

```bash
LARC_DRIVE_FOLDER_TOKEN=fldcnXXXXXX   # Lark Drive folder for agent workspace
LARC_BASE_APP_TOKEN=bascXXXXXX        # Lark Base app for memory/registry
LARC_IM_CHAT_ID=oc_XXXXXX             # Default IM chat for agent messages
LARC_WIKI_SPACE_ID=XXXXXXXX           # Optional: Wiki space for knowledge base
LARC_CACHE_TTL=300                    # Cache TTL in seconds (default: 5 min)
LARC_APPROVAL_CODE=XXXXXXXX           # Optional: Lark Approval flow code
```

## Claude Code Skills

24 pre-installed skills in `.claude/skills/`. Each `SKILL.md` has:
- `name`, `version`, `description` frontmatter
- Applicable scenarios
- Step-by-step workflow
- Permissions table

**All skills are in English** (translated from Chinese). Exception: `lark-project/SKILL.md` is intentionally in Japanese (internal Miyabi GK project).

Skills: `lark-base` · `lark-calendar` · `lark-doc` · `lark-drive` · `lark-event` · `lark-im` · `lark-mail` · `lark-minutes` · `lark-sheets` · `lark-slides` · `lark-task` · `lark-vc` · `lark-whiteboard` · `lark-wiki` · `lark-approval` · `lark-attendance` · `lark-contact` · `lark-openapi-explorer` · `lark-skill-maker` · `lark-workflow-meeting-summary` · `lark-workflow-standup-report` · `lark-shared` · `lark-whiteboard-cli` · `lark-project` · `addness`

**`addness` スキル**: ゴール管理OS Addness と OpenClaw を連携する。`addness-cli` 経由でゴールの開始・進捗記録・完了・作成・サマリー確認を行う。OpenClaw Agent がコーディング作業を行う際は必ず Addness ゴールと連動させること。詳細: `addness/SKILL.md` / OpenClaw 連携: `openclaw-larc-runtime/SKILL.md`

**`lark-doc` の追加スキル**: `+mention-link` — text_run URL を mention_doc に変換して被リンク（相関図）を作成する。Lark相関図にリンクを認識させるには必ずこの方法を使うこと。`lark-cli docs +update` のmarkdown変換は常にtext_runを生成するため、被リンクには使えない。詳細: `lark-doc/references/lark-doc-mention-link.md` / スクリプト: `scripts/lark-mention-link.py`

**ナレッジグラフ設計ルール**: `docs/lark-knowledge-graph-linking.md` — 4層アーキテクチャ、リンク種別（根拠/定義/順序/連動/帰還）、クリーンアップ手順、みやびGKグラフ構成（11ノード・46エッジ）

## Development Roadmap

### Milestone 1 — Claude Code → LARC ✅ COMPLETE

Claude Code controls LARC locally; no OpenClaw dependency required.

**Verified E2E flow:**
```
larc quickstart (7 steps, idempotent)
  → larc bootstrap --agent main
  → larc ingress enqueue --text "..." --source claude-code
  → larc ingress run-once (Base-first pickup)
  → larc ingress done --queue-id <id>
  → Lark IM completion notification
```

- [x] Phase 1A: Core CLI dispatch (`larc init/bootstrap/memory/send/task/approve/agent/status`)
- [x] Phase 1B: Drive workspace setup + Base table provisioning
- [x] Phase 1C: Permission scope map + `larc auth suggest/check/login`
- [x] Phase 2A: 25 Claude Code skills (all in English; lark-project in Japanese)
- [x] **Phase 0 (retroactive)**: Fix lark-cli command alignment in `lib/*.sh`
- [x] Phase 2B: Multi-agent YAML batch registration
- [x] Phase 2C: `larc agent register` from YAML
- [x] **Milestone 1**: Base-first queue pickup; `larc quickstart` 7-step automated onboarding
- [ ] Phase 3: MergeGate integration (`lib/mergegate.sh`)
- [ ] Phase 4: Knowledge graph via Lark Wiki `@mention` / `[[link]]`

### Milestone 2 — OpenClaw → LARC (next)

- Default model: Codex (OpenAI OAuth login)
- `openclaw-lark` plugin for Lark API calls
- `larc ingress openclaw` as the connection bridge

## Common Commands

```bash
# Setup
larc init
larc bootstrap --agent main

# Daily use
larc memory pull
larc send "Draft an expense report for last month"
larc task list

# Permission management
larc auth suggest "create expense report and route to approval"
larc auth check --profile writer
larc auth login --profile backoffice_agent

# Agent management
larc agent list
larc agent register
```
