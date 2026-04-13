# LARC — Lark Agent Runtime

> Permission-first runtime for Lark-native office-work agents

[![version](https://img.shields.io/badge/version-0.1.0-blue)](bin/larc)
[![license](https://img.shields.io/badge/license-MIT-green)](#license)
[![lark-cli](https://img.shields.io/badge/requires-lark--cli-orange)](https://github.com/larksuite/cli)

English | [简体中文](README.zh-CN.md) | [日本語](README.ja.md)

Official name: `Lark Agent Runtime`
Short name: `LARC`

---

## What is LARC?

**LARC** brings OpenClaw-style agent operation into Lark-native office workflows.

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

---

## Key capabilities

| Capability | What it does |
|---|---|
| `larc bootstrap` | Loads `SOUL.md → USER.md → MEMORY.md → HEARTBEAT.md` from Lark Drive |
| `larc auth suggest` | Infers scopes and authority from a natural-language task |
| `larc memory` | Syncs daily memory with Lark Base |
| `larc send` / `larc task` | Provides basic execution paths for IM and task operations |
| Approval support | Models approval creation, approval task action, and execution gates |
| Claude Code skills | Ships Lark-oriented skills in `.claude/skills/` |

---

## Quick Start

```bash
npm install -g @larksuite/cli
git clone https://github.com/ShunsukeHayashi/larc-openclaw-coding-agent
cd larc-openclaw-coding-agent
chmod +x bin/larc
export PATH="$PWD/bin:$PATH"
larc init
larc bootstrap
```

---

## Current status

This project is still in incubation, but the following pieces are already moving:

- bootstrap / memory / send / task basics
- initial `auth suggest` implementation with regression cases
- approval model spike
- OpenClaw-style disclosure-chain reenactment on Lark surfaces

Key planning and design docs:

- [PLAYBOOK.md](PLAYBOOK.md)
- [docs/goal-aligned-playbook.md](docs/goal-aligned-playbook.md)
- [docs/permission-model.md](docs/permission-model.md)
- [docs/open-source-trilingual-plan.md](docs/open-source-trilingual-plan.md)
- [docs/auth-suggest-cases.md](docs/auth-suggest-cases.md)
- [CONTRIBUTING.md](CONTRIBUTING.md)
- [docs/terminology-glossary.md](docs/terminology-glossary.md)
- [docs/release-checklist.md](docs/release-checklist.md)
- [docs/release-readiness-2026-04-14.md](docs/release-readiness-2026-04-14.md)
- [docs/public-release-bundle-2026-04-14.md](docs/public-release-bundle-2026-04-14.md)
- [docs/bundle-a-readiness-2026-04-14.md](docs/bundle-a-readiness-2026-04-14.md)
- [docs/bundle-a-manifest-2026-04-14.md](docs/bundle-a-manifest-2026-04-14.md)
- [docs/launch-messaging.md](docs/launch-messaging.md)
- [docs/repo-publish-kit.md](docs/repo-publish-kit.md)

---

## Repo structure

```text
bin/
  larc
lib/
  bootstrap.sh
  memory.sh
  send.sh
  agent.sh
  task.sh
  approve.sh
  heartbeat.sh
  auth.sh
config/
  scope-map.json
docs/
  goal-aligned-playbook.md
  permission-model.md
  open-source-trilingual-plan.md
scripts/
  setup-workspace.sh
  auth-suggest-check.sh
.claude/skills/
  lark-*/
```

---

## Roadmap focus

- strengthen permission intelligence and minimum-scope inference
- improve Lark-native disclosure-chain realism
- connect approval to safer execution control
- prepare the repo for trilingual open-source release

---

## License

MIT
