# LARC 术语表

[English](terminology-glossary.md) | 简体中文 | [日本語](terminology-glossary.ja.md)

---

## 目的

这个术语表用于让 LARC 的关键概念在英文、中文、日文之间保持一致。

适用范围：

- README 与公开文档
- permission / approval 相关文档
- issue template 与 contribution docs
- 未来的三语言发布材料

---

## 核心术语

| English | Chinese | Japanese | 含义 |
|---|---|---|---|
| Lark Agent Runtime | Lark Agent Runtime | Lark Agent Runtime | 本项目的正式名称 |
| LARC | LARC | LARC | Lark Agent Runtime 的简称 |
| Lark-native | 飞书原生 | Lark ネイティブ | 不把 Lark 只当作 API 终点，而是把它当作 Agent 实际运行表面 |
| disclosure chain | 披露链 | ディスクロージャーチェーン | 类似 `SOUL.md → USER.md → MEMORY.md → HEARTBEAT.md` 的顺序上下文链 |
| permission-first | 权限优先 | 権限先行 | 先解释 scopes 和 authority，再执行动作的设计方式 |
| scope | scope / 权限范围 | スコープ | 一个能力所需的 API 权限单位 |
| authority | 执行身份 / authority | 実行権限主体 | 一个动作究竟以什么身份执行 |
| user authority | 用户身份执行 | ユーザー権限主体 | 以真实用户身份执行，通常对应 `user_access_token` |
| bot authority | 机器人身份执行 | Bot 権限主体 | 以应用或租户机器人身份执行，通常对应 `tenant_access_token` |
| mixed authority | 混合执行身份 | 混合権限主体 | 一个流程跨越多种 authority type |
| permission intelligence | 权限智能 | Permission intelligence | LARC 中负责推断、解释、检查权限的核心部分 |
| minimum likely scopes | 最小可能权限集 | 最小想定スコープ | 针对某个任务假设的最窄现实权限集合 |
| execution gate | 执行门控 | 実行ゲート | 决定动作是否允许继续的控制点 |
| approval gate | 审批门控 | 承認ゲート | 将 Lark Approval 用作执行控制层 |
| memory surface | 记忆表面 | 記憶面 | 用来保存 Agent 记忆的表面，例如 Base |
| operating surface | 运行表面 | 実行面 | Agent 实际工作的原生产品表面 |

---

## 用法说明

- 讨论“以谁的身份执行”时，优先使用 `authority`
- 讨论 API 权限单位时，优先使用 `scope`
- 描述项目架构立场时，优先使用 `Lark-native`
- 讨论顺序上下文加载时，优先使用 `disclosure chain`

---

## 翻译规则

如果某个术语在某种语言里开始变得含糊，请先更新这个术语表，再扩散到 README 或设计文档。
