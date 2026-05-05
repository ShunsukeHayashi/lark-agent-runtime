# LARC — Lark Agent Runtime

> 面向在 Lark 内工作的 AI Agent 的、以权限管理为核心的运行时环境

[![version](https://img.shields.io/badge/version-0.2.0-blue)](bin/larc)
[![CI](https://github.com/ShunsukeHayashi/lark-agent-runtime/actions/workflows/ci.yml/badge.svg)](https://github.com/ShunsukeHayashi/lark-agent-runtime/actions/workflows/ci.yml)
[![license](https://img.shields.io/badge/license-MIT-green)](#license)
[![lark-cli](https://img.shields.io/badge/requires-lark--cli-orange)](https://github.com/larksuite/cli)

[English](README.md) | 简体中文 | [日本語](README.ja.md)

正式名称: `Lark Agent Runtime`
简称: `LARC`

---

## LARC 是什么

**LARC** 是 [OpenClaw](https://openclaw.dev) Agent 的 Lark 执行与治理层。

OpenClaw 负责 Agent 推理与执行。LARC 负责让 OpenClaw 以受控、可审计、权限清晰的方式接入 Lark 的企业表面。

```
OpenClaw Agent（LLM 执行）
    ↓  larc ingress openclaw
LARC（权限 · 队列 · 审计 · 上下文）
    ↓  lark-cli
Lark API — Drive / Base / IM / Approval / Wiki
```

如果 OpenClaw 是 Agent 本体，LARC 就是护栏：负责应用执行门控、跟踪 authority、管理任务队列，并把结果回写到 Lark。

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
| `larc approve gate` | 在执行前检查 none / preview / approval 门控要求 |
| `larc ingress openclaw` | 为 OpenClaw 构建并派发下一步受治理的动作 bundle |
| `larc ingress recover` | 在 worker 崩溃后重置停滞的 in-progress 队列项 |
| `larc agent register` | 将 Agent 注册到 Lark Base，并支持 YAML 批量注册 |
| `larc kg build` / `larc kg query` | 索引 Lark Wiki 节点图，并返回带邻居上下文的概念查询结果 |
| `larc memory` | 将日常记忆同步到 Base，支持完整分页与关键词搜索 |
| `larc status` | 统一显示 Base 连通性、OpenClaw 安装状态、daemon 状态与队列统计 |
| Claude Code skills | 在 `.claude/skills/` 中提供 Lark 相关技能集 |

---

## 快速开始

### 前提条件

```bash
which openclaw    # OpenClaw — Agent 执行引擎
which lark-cli    # lark-cli — npm install -g @larksuite/cli
which python3     # Python 3.8+
```

> **先准备 OpenClaw。** LARC 不是独立 Agent，而是 OpenClaw Agent 的 runtime layer。
> 请先把 LARC runtime skill 安装到 OpenClaw：`bash scripts/install-openclaw-larc-runtime-skill.sh`

### 安装 LARC

```bash
# 安装 LARC（自动下载到 ~/.larc/runtime/）
curl -fsSL https://raw.githubusercontent.com/ShunsukeHayashi/lark-agent-runtime/main/scripts/install.sh | bash

# 配置飞书应用凭据
lark-cli config init --app-id <App ID> --app-secret-stdin --brand lark
lark-cli auth login

# 一键完成工作区配置
larc quickstart

# 验证状态
larc status
```

> **注意**：LARC 自动安装到 `~/.larc/runtime/`，请勿直接编辑该目录内的文件。升级请使用 `larc update`。

→ 完整指南：[docs/quickstart-ja.md](docs/quickstart-ja.md)
→ 在线课程：[course/README.md](course/README.md)
→ OpenClaw 集成：[docs/openclaw-integration.md](docs/openclaw-integration.md)
→ Lark 应用设置（面向协调者）：[docs/lark-app-setup.md](docs/lark-app-setup.md)

---

## 运行模式

| 模式 | 运行方式 | 状态 |
|---|---|---|
| **Supervised** | OpenClaw + Claude Code 手动调用 `larc ingress run-once` | ✅ 稳定 |
| **OpenClaw-assisted autonomous** | OpenClaw 的 Feishu/Lark channel 负责 bot/chat 入口，官方 `openclaw-lark` 负责原子 Lark 操作，LARC 负责门控/队列/审计 | ✅ 稳定 |
| **Experimental IM loop** | `larc daemon start`：IM poller 自动入队，worker 自动派发到 OpenClaw | 🧪 实验性 |

> **IM daemon loop 仍是实验性功能。** 生产或正式试点请优先使用 supervised 或 OpenClaw-assisted 模式。
>
> **用户实际对话入口**：应当引导用户去使用 OpenClaw 的 Feishu/Lark channel 连接出来的 bot / chat app。LARC 的应用凭据只是 runtime 认证链路，不应被当作第二个用户聊天入口。

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
- 从 IM 收到消息到自动回复的 daemon 驱动全自动循环
- MergeGate 集成（受控执行审查）
- 完整 OpenClaw CLI 兼容层
- 基于文档内容的知识图谱链接提取（当前为层级结构）
- 中国市场商业叙事完善

重要补充：

- LARC 已经是可运行的飞书 Agent work runtime surface
- 但当前应主要被视为 OpenClaw 之下的 governed runtime
- 当前最自然的主路径是 `OpenClaw Agent -> OpenClaw Feishu/Lark channel -> official openclaw-lark plugin + LARC`
- Lark IM / webhook bot ingress 更适合作为后续可选入口，目前仍属 experimental
- Feishu/Lark 的 bot/chat 绑定属于 OpenClaw channel 配置（`openclaw channels login --channel feishu`），不是 plugin 单独完成的步骤
- 推荐路径仍然是 `OpenClaw Feishu/Lark channel + official openclaw-lark plugin + LARC`
- 测试用户应被引导到 OpenClaw channel 对应的 bot / chat app，而不是单独的 LARC 认证应用

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

## 验证

在提交 PR 之前可以先做轻量本地验证：

```bash
# 检查入口脚本与辅助脚本的 shell 语法
bash -n bin/larc scripts/install.sh scripts/auth-suggest-check.sh

# 检查 permission-intelligence 回归用例
bash scripts/auth-suggest-check.sh --verify
```

这些检查也会在 GitHub Actions 中自动运行。

---

## License

MIT
