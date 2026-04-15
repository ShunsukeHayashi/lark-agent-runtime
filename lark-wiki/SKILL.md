---
name: lark-wiki
version: 1.0.0
description: "飞书知识库：管理知识空间和文档节点。创建和查询知识空间、管理节点层级结构、在知识库中组织文档和快捷方式。当用户需要在知识库中查找或创建文档、浏览知识空间结构、移动或复制节点时使用。"
metadata:
  requires:
    bins: ["lark-cli"]
  cliHelp: "lark-cli wiki --help"
---

# wiki (v2)

**CRITICAL — 开始前 MUST 先用 Read 工具读取 [`../lark-shared/SKILL.md`](../lark-shared/SKILL.md)，其中包含认证、权限处理**

## Shortcuts（推荐优先使用）

Shortcut 是对常用操作的高级封装（`lark-cli wiki +<verb> [flags]`）。有 Shortcut 的操作优先使用。

| Shortcut | 说明 |
|----------|------|
| [`+node-create`](references/lark-wiki-node-create.md) | Create a wiki node with automatic space resolution |

## Known Limitations

### Adding external users to Wiki spaces

`wiki spaces members create` with an external tenant user's email returns `131005: identity not found`.
The Lark API cannot look up or add external-organization users by email.

**Workarounds:**

| Need | Solution |
|---|---|
| Invite external user | Use Lark admin console (admin.larksuite.com) → External collaborators → Invite |
| Add after invitation | Use `member_type: openid` with the `open_id` issued after admin invitation |
| Public read access | Set `open_sharing: anyone_readable` — no Lark account required |

```bash
# After admin-console invitation:
lark-cli wiki spaces members create \
  --params '{"space_id":"<space_id>"}' \
  --data '{"member_id":"ou_XXXXXX","member_type":"openid","member_role":"member"}'

# Link-based public access (no account required):
lark-cli api PUT /open-apis/wiki/v2/spaces/<space_id>/setting \
  --data '{"open_sharing":"anyone_readable"}'
```

> Reference: [`docs/known-issues/lark-external-user-api-gap.md`](../docs/known-issues/lark-external-user-api-gap.md)

## API Resources

```bash
lark-cli schema wiki.<resource>.<method>   # 调用 API 前必须先查看参数结构
lark-cli wiki <resource> <method> [flags] # 调用 API
```

> **重要**：使用原生 API 时，必须先运行 `schema` 查看 `--data` / `--params` 参数结构，不要猜测字段格式。

### spaces

- `get` — 获取知识空间信息
- `get_node` — 获取知识空间节点信息
- `list` — 获取知识空间列表

### nodes

- `copy` — 创建知识空间节点副本
- `create` — 创建知识空间节点
- `list` — 获取知识空间子节点列表

## 权限表

| 方法 | 所需 scope |
|------|-----------|
| `spaces.get` | `wiki:space:read` |
| `spaces.get_node` | `wiki:node:read` |
| `spaces.list` | `wiki:space:retrieve` |
| `nodes.copy` | `wiki:node:copy` |
| `nodes.create` | `wiki:node:create` |
| `nodes.list` | `wiki:node:retrieve` |
