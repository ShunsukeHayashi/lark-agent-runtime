# LARC Terminology Glossary

English | [简体中文](terminology-glossary.zh-CN.md) | [日本語](terminology-glossary.ja.md)

---

## Purpose

This glossary keeps key LARC terms aligned across English, Chinese, and Japanese.

Use it when writing:

- README and public docs
- permission and approval docs
- issue templates and contribution docs
- future multilingual release materials

---

## Core Terms

| English | Chinese | Japanese | Meaning |
|---|---|---|---|
| Lark Agent Runtime | Lark Agent Runtime | Lark Agent Runtime | Official product name of the project |
| LARC | LARC | LARC | Short name of Lark Agent Runtime |
| Lark-native | 飞书原生 | Lark ネイティブ | Built around Lark surfaces instead of treating Lark as only an API endpoint |
| disclosure chain | 披露链 | ディスクロージャーチェーン | Ordered context files such as `SOUL.md → USER.md → MEMORY.md → HEARTBEAT.md` |
| permission-first | 权限优先 | 権限先行 | Explain scopes and authority before executing actions |
| scope | scope / 权限范围 | スコープ | The API permission required for a capability |
| authority | 执行身份 / authority | 実行権限主体 | The identity type under which an action is performed |
| user authority | 用户身份执行 | ユーザー権限主体 | Action performed as a real named person, usually via `user_access_token` |
| bot authority | 机器人身份执行 | Bot 権限主体 | Action performed as the app or tenant bot, usually via `tenant_access_token` |
| mixed authority | 混合执行身份 | 混合権限主体 | A workflow that spans more than one authority type |
| permission intelligence | 权限智能 | Permission intelligence | The part of LARC that infers, explains, and checks permissions |
| minimum likely scopes | 最小可能权限集 | 最小想定スコープ | The narrowest realistic scope set for a task hypothesis |
| execution gate | 执行门控 | 実行ゲート | A control point that decides whether an action may proceed |
| approval gate | 审批门控 | 承認ゲート | Using Lark Approval as an execution control layer |
| memory surface | 记忆表面 | 記憶面 | The storage layer used for agent memory, such as Base |
| operating surface | 运行表面 | 実行面 | The native product surface where an agent actually works |

---

## Usage Notes

- Prefer `authority` when talking about who an action runs as.
- Prefer `scope` when talking about API permission units.
- Prefer `Lark-native` when describing the architectural stance of the project.
- Prefer `disclosure chain` when talking about ordered agent context loading.

---

## Translation Rule

If a term becomes ambiguous in one language, update this glossary first before expanding the wording across README or design docs.
