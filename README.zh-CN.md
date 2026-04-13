# LARC — Lark Agent Runtime

> 面向 Lark（飞书）原生办公 Agent 的 permission-first runtime

[English](README.md) | 简体中文 | [日本語](README.ja.md)

正式名称: `Lark Agent Runtime`
简称: `LARC`

---

## LARC 是什么

**LARC** 不是一个“连接飞书 API 的普通 CLI”。它的目标是把 Lark 本身变成 Agent 的运行表面。

它尝试把 OpenClaw 风格的运行方式迁移到飞书原生能力上：

- Drive 作为 disclosure chain 存储面
- Base 作为 memory / registry
- IM 作为执行与协作表面
- Approval 作为执行控制
- Wiki 作为知识与上下文表面

---

## 为什么这个方向重要

AI Agent 在开发工作流里已经很强，但在一般白领工作流里还没有真正跑起来。关键问题通常不是模型能力，而是下面这些：

- 不知道一个任务最小需要哪些权限
- 不清楚动作应该以谁的身份执行
- 很多 Agent 仍然默认本地文件系统，而不是企业工具本身

LARC 的切入点是 `permission-first`：

- 先解释权限
- 再解释 authority
- 再把动作路由到飞书原生表面

---

## 核心能力

| 能力 | 说明 |
|------|------|
| `larc bootstrap` | 从 Drive 读取 `SOUL.md → USER.md → MEMORY.md → HEARTBEAT.md` |
| `larc auth suggest` | 从自然语言任务推断所需 scope 和 authority |
| `larc memory` | 将日常记忆同步到 Base |
| `larc send` / `larc task` | 提供消息发送和任务操作的基本执行路径 |
| Approval 支持 | 区分审批实例创建与审批任务执行 |
| Claude Code skills | 在 `.claude/skills/` 中提供 Lark 相关技能集 |

---

## 快速开始

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

## 当前状态

这个项目仍然处于 incubation 阶段，但已经有了清晰进展：

- bootstrap / memory / send / task 的基础链路已建立
- `auth suggest` 已有初始实现和回归案例
- approval 模型已经做过 spike
- 正在把 OpenClaw 风格 disclosure chain 迁移到飞书表面

更多背景请看：

- [PLAYBOOK.md](PLAYBOOK.md)
- [docs/goal-aligned-playbook.md](docs/goal-aligned-playbook.md)
- [docs/permission-model.md](docs/permission-model.md)
- [docs/open-source-trilingual-plan.md](docs/open-source-trilingual-plan.md)
- [CONTRIBUTING.md](CONTRIBUTING.md)
- [docs/terminology-glossary.zh-CN.md](docs/terminology-glossary.zh-CN.md)
- [docs/release-checklist.md](docs/release-checklist.md)
- [docs/release-readiness-2026-04-14.md](docs/release-readiness-2026-04-14.md)
- [docs/public-release-bundle-2026-04-14.md](docs/public-release-bundle-2026-04-14.md)
- [docs/bundle-a-readiness-2026-04-14.md](docs/bundle-a-readiness-2026-04-14.md)

---

## License

MIT
