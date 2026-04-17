# LARC — Lark Agent Runtime CLI

> Claude Code context file for this project.

## 🚫 エージェント動作ルール（必読）

**LARC ソースコードは絶対に編集しない。**

- `~/.larc/runtime/` 以下のファイル（`bin/larc`, `lib/*.sh`, `scripts/`, `config/` など）は読み取り専用として扱う
- エージェントがタスクを実行する際、LARC ソースへの書き込み・削除・移動は一切行わない
- LARC 本体のアップデートは必ず `larc update` コマンド経由でのみ行う
- エージェントの成果物（ドキュメント・レポート・データ）は必ず **Lark Drive の `larc-workdir/`** に出力する
- ローカルへの一時ファイル出力が必要な場合は `~/.larc/cache/` または `/tmp/` を使用する

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

## Human in the Loop (HITL) 設計

エージェントが担う範囲と人間が担う範囲の定義。詳細 → [LARC Wiki: HITL 設計ガイド](https://miyabi-g-k.jp.larksuite.com/wiki/HLMMwMwcciOii8kS578johsPpBf)

### ゲートポリシー（`config/gate-policy.json`）

| gate | 意味 | 人間のアクション |
|------|------|----------------|
| `none` | エージェントが即時実行 | 不要 |
| `preview` | 内容確認後に実行 | 確認 → `larc ingress approve` |
| `approval` | Lark 承認フロー起動・待機 | Lark UI で承認/却下 → `larc ingress resume` |

### Lark API 制約による HITL（エージェントが物理的に実行不可）

以下の操作は **Lark が User OAuth を強制**しており、Bot では永久に実行できない。人間が Lark UI で直接操作する必要がある：

- `approval.tasks.approve` — 承認タスクの承認
- `approval.tasks.reject` — 承認タスクの却下
- `approval.tasks.transfer` — 承認担当者の転送
- `approval.instances.cancel` — 承認申請の取り下げ

**`lib/approve.sh` はこれらを意図的に実装していない。** エージェントは申請作成（`larc approve create`）までを担い、承認・却下は人間が担う。

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

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **larc** (9863 symbols, 10971 relationships, 30 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## When Debugging

1. `gitnexus_query({query: "<error or symptom>"})` — find execution flows related to the issue
2. `gitnexus_context({name: "<suspect function>"})` — see all callers, callees, and process participation
3. `READ gitnexus://repo/larc/process/{processName}` — trace the full execution flow step by step
4. For regressions: `gitnexus_detect_changes({scope: "compare", base_ref: "main"})` — see what your branch changed

## When Refactoring

- **Renaming**: MUST use `gitnexus_rename({symbol_name: "old", new_name: "new", dry_run: true})` first. Review the preview — graph edits are safe, text_search edits need manual review. Then run with `dry_run: false`.
- **Extracting/Splitting**: MUST run `gitnexus_context({name: "target"})` to see all incoming/outgoing refs, then `gitnexus_impact({target: "target", direction: "upstream"})` to find all external callers before moving code.
- After any refactor: run `gitnexus_detect_changes({scope: "all"})` to verify only expected files changed.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Tools Quick Reference

| Tool | When to use | Command |
|------|-------------|---------|
| `query` | Find code by concept | `gitnexus_query({query: "auth validation"})` |
| `context` | 360-degree view of one symbol | `gitnexus_context({name: "validateUser"})` |
| `impact` | Blast radius before editing | `gitnexus_impact({target: "X", direction: "upstream"})` |
| `detect_changes` | Pre-commit scope check | `gitnexus_detect_changes({scope: "staged"})` |
| `rename` | Safe multi-file rename | `gitnexus_rename({symbol_name: "old", new_name: "new", dry_run: true})` |
| `cypher` | Custom graph queries | `gitnexus_cypher({query: "MATCH ..."})` |

## Impact Risk Levels

| Depth | Meaning | Action |
|-------|---------|--------|
| d=1 | WILL BREAK — direct callers/importers | MUST update these |
| d=2 | LIKELY AFFECTED — indirect deps | Should test |
| d=3 | MAY NEED TESTING — transitive | Test if critical path |

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/larc/context` | Codebase overview, check index freshness |
| `gitnexus://repo/larc/clusters` | All functional areas |
| `gitnexus://repo/larc/processes` | All execution flows |
| `gitnexus://repo/larc/process/{name}` | Step-by-step execution trace |

## Self-Check Before Finishing

Before completing any code modification task, verify:
1. `gitnexus_impact` was run for all modified symbols
2. No HIGH/CRITICAL risk warnings were ignored
3. `gitnexus_detect_changes()` confirms changes match expected scope
4. All d=1 (WILL BREAK) dependents were updated

## Keeping the Index Fresh

After committing code changes, the GitNexus index becomes stale. Re-run analyze to update it:

```bash
npx gitnexus analyze
```

If the index previously included embeddings, preserve them by adding `--embeddings`:

```bash
npx gitnexus analyze --embeddings
```

To check whether embeddings exist, inspect `.gitnexus/meta.json` — the `stats.embeddings` field shows the count (0 means no embeddings). **Running analyze without `--embeddings` will delete any previously generated embeddings.**

> Claude Code users: A PostToolUse hook handles this automatically after `git commit` and `git merge`.

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
