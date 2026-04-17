# T-012 — Feishu Developer Community Post

Post to: open.feishu.cn developer community + 掘金 (juejin.cn)

---

## 掘金版 (~700字)

**飞书 Agent 的权限管理层 — LARC v0.2.0 开源发布**

在飞书上跑 AI Agent，你遇到过这些问题吗？

- Bot 拿了一堆权限，实际只用了两个 scope，出问题后根本不知道哪步越权了
- `approval.tasks.approve` 调 API 返回 403，原因是 Lark 强制要求 User OAuth，Bot 永远拿不到——但错误信息根本没提这件事
- Agent 自动发了一条不该发的 IM 消息，取消不了，尴尬收场

这不是模型能力问题，是 runtime 层根本没有权限治理。

**LARC（Lark Agent Runtime）** 是专门为在飞书里运行的 AI Agent 设计的权限优先 runtime 层，MIT 开源。

核心设计是三步：

```
larc auth suggest "帮我提交差旅报销并转交审批"
# → 输出: submit_approval (high/approval gate)
#         scopes: approval:approval:write
#         identity: user_access_token  ← 必须是用户授权，Bot 无法完成

larc approve gate --task submit_approval
# → gate: approval — 触发飞书审批流，等待人工确认后才执行

larc ingress enqueue → in_progress → done/blocked
```

`larc auth suggest` 从自然语言推断最小 scope 和 identity 类型（user/bot/either），**不是让 Agent 自己去猜**。

门控策略（`config/gate-policy.json`）覆盖 32 种任务类型，每种任务有 risk 级别和 gate 策略（none/preview/approval）。high risk 操作——比如提交审批、修改 Base schema——会强制走 Lark 审批流，不会静默执行。

对于 Lark API 层面 Bot 做不到的操作（承认任务审批/驳回），LARC 明确不实现它们，而是在 queue 里标记为 `blocked`，等人类在飞书 UI 完成后恢复。这是故意的设计，不是 bug。

技术栈：bash shell、lark-cli、Lark Base/Drive/IM/Approval/Wiki API。

项目地址：https://github.com/ShunsukeHayashi/lark-agent-runtime

如果你在飞书上构建 bot 或自动化，欢迎试用和 PR。

— 林駿甫 / 合同会社みやび

---

## open.feishu.cn 开发者社区版 (~1300字)

**LARC v0.2.0 — 飞书 Agent 的权限管理 runtime，开源发布**

### 先说问题

在飞书上跑 AI Agent，最常见的两类失败方式：

1. **权限过多**：Agent 申请了整个 Drive 读写权限，实际任务只需要读一个文档。一旦出事，审计链路不清，影响面不可控。
2. **静默失败**：Agent 调用 `approval.tasks.approve` 拿到 403，原因是该 API 强制要求 User OAuth，Bot 永远拿不到。但错误没有被结构化地暴露，Agent 以为任务完成了，实际什么都没发生。

这两个问题的根源不在模型，在于飞书 Agent 缺一个 runtime 层：**在执行发生之前，解释权限、判断 identity、决定是否需要人工介入**。

---

### LARC 是什么

LARC（Lark Agent Runtime）是 AI Agent 在飞书内操作的执行与治理层，MIT 开源。

```
AI Agent（LLM 推理）
    ↓  larc ingress
LARC（权限 · 队列 · 审计 · 门控）
    ↓  lark-cli
Lark API — Drive / Base / IM / Approval / Wiki
```

LARC 不替代 Agent 的推理，它做的是：在 Agent 的每个动作落地飞书之前，回答三个问题：

- 这个任务最少需要哪些 scope？
- 这个操作应该用 Bot Token 还是 User OAuth？
- 这个任务需要立即执行、先 preview 确认、还是必须走审批流？

---

### 核心能力

**1. `larc auth suggest` — 最小权限推断**

```bash
$ larc auth suggest "把本月考勤数据汇总写入多维表格"

任务类型: write_base + read_attendance
所需 scope:
  - attendance:attendance:readonly  (identity: user)
  - bitable:app                     (identity: user / bot)
说明: 考勤数据需要 User OAuth 读取；Base 写入可用 Bot Token
```

输入自然语言，输出最小 scope 集合 + identity 类型说明。32 种任务类型，覆盖 Drive / Base / IM / Wiki / Approval / 考勤 / 会议室等常用飞书表面。

**2. `larc approve gate` — 执行门控**

`config/gate-policy.json` 为每种任务类型定义 risk 级别和 gate 策略：

| 任务类型 | risk | gate |
|---|---|---|
| `read_document` | none | none — 直接执行 |
| `send_message` | medium | preview — 展示内容后需确认 |
| `submit_approval` | high | approval — 触发飞书审批流，等待人工 |
| `manage_base` | high | approval — Schema 变更不允许静默执行 |

high risk 操作不会因为 Agent 自信就跳过门控。

**3. 队列生命周期**

```
enqueue → in_progress → done
                      ↘ blocked  ← Lark API 要求 User OAuth，Agent 物理无法完成
```

`blocked` 状态是 HITL 设计的核心。LARC 不试图绕过 Lark 的 User OAuth 限制，而是把任务标为 `blocked`，等人类在飞书 UI 完成后通过 `larc ingress resume` 恢复队列。

**`lib/approve.sh` 有意不实现 `approval.tasks.approve` 和 `approval.tasks.reject`。这是设计决策，不是功能缺失。**

---

### 快速开始

```bash
# 安装 lark-cli
npm install -g @larksuite/cli
lark-cli config init --app-id <App ID> --app-secret-stdin --brand lark
lark-cli auth login

# 安装 LARC
git clone https://github.com/ShunsukeHayashi/lark-agent-runtime
ln -sf $(pwd)/lark-agent-runtime/bin/larc ~/bin/larc

# 一键初始化
larc quickstart
larc status
```

---

### 适合谁看

- 在飞书上构建 bot 或自动化工作流的开发者
- 需要给 LLM Agent 加 HITL 门控的企业项目
- 对 Lark API 权限模型（Bot Token vs User OAuth 边界）有困惑的人

项目地址：https://github.com/ShunsukeHayashi/lark-agent-runtime

issue、PR、文档改进都欢迎。

— 林駿甫 / 合同会社みやび
