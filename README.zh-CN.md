# LARC — Lark Agent Runtime

> 面向在 Lark 内工作的 AI Agent 的、以权限管理为核心的运行时环境

[English](README.md) | 简体中文 | [日本語](README.ja.md)

正式名称: `Lark Agent Runtime`
简称: `LARC`

---

## LARC 是什么

**LARC** 是一个面向在 Lark 内工作的 AI Agent 的、以权限管理为核心的运行时环境。

如果说 Claude Code 是编码 Agent 的一部分执行环境，那么 LARC 就是飞书内办公 Agent 的执行环境。

它不是一个“连接飞书 API 的普通 CLI”。它的目标是把 Lark 本身变成 Agent 的运行表面。

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

实际的执行链路是：

1. 一个任务到来
2. `larc auth suggest` 解释需要哪些权限、应该用谁的 authority
3. `larc approve gate` 判断是直接执行、需要 preview、还是必须先走 approval
4. 执行发生在飞书 IM / Base / Drive / Wiki / Approval 上
5. `larc memory` 把执行结果记录回飞书

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
git clone https://github.com/ShunsukeHayashi/lark-agent-runtime
cd lark-agent-runtime
chmod +x bin/larc
export PATH="$PWD/bin:$PATH"
larc init
larc bootstrap
```

---

## 当前状态

五个基础阶段已完成，并在真实的飞书租户中实时验证：

| 阶段 | 已验证内容 |
|---|---|
| A — 运行时 | `bootstrap`、`memory`、`send`、`task`、`agent` 全部对接真实飞书 API |
| B — 权限智能 | `auth suggest` 对 8 个复合办公任务推断最小权限，包含权限主体说明 |
| C — 智能体管理 | 4 个智能体注册至飞书多维表格；支持 YAML 批量注册；每个智能体存储权限范围 |
| D — 审批与执行控制 | 门控策略（32 种任务类型 × none/preview/approval）；`larc approve gate` 命令 |
| E — 知识图谱 | 知识空间 BFS 遍历；37 个节点已索引；关键词查询返回匹配节点及相邻节点 |

尚在实验或规划中：
- MergeGate 集成（受控执行审查）
- 完整 OpenClaw CLI 兼容层
- 基于文档内容的知识图谱链接提取（当前为层级结构）
- 中国市场商业叙事完善

重要补充：

- LARC 已经是一个可运行的、面向飞书 Agent work 的 runtime surface
- 但现阶段它仍然主要是供 Claude Code 等上层 Agent 使用的 supervised runtime
- 当前最自然的主路径是 `OpenClaw Agent -> official openclaw-lark plugin + LARC`
- Lark IM / webhook bot ingress 更适合作为后续可选入口，而不是当前的核心必经路径

更多背景请看：

- [PLAYBOOK.md](PLAYBOOK.md)
- [docs/agentic-larc-mvp-2026-04-14.md](docs/agentic-larc-mvp-2026-04-14.md)
- [docs/larc-vs-lark-cli-and-openclaw.md](docs/larc-vs-lark-cli-and-openclaw.md)
- [docs/goal-aligned-playbook.md](docs/goal-aligned-playbook.md)
- [docs/permission-model.md](docs/permission-model.md)
- [docs/auth-suggest-cases.md](docs/auth-suggest-cases.md)
- [CONTRIBUTING.md](CONTRIBUTING.md)
- [docs/terminology-glossary.zh-CN.md](docs/terminology-glossary.zh-CN.md)

---

## License

MIT
