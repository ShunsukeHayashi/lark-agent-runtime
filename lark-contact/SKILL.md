---
name: lark-contact
version: 1.0.0
description: "飞书通讯录：查询组织架构、人员信息和搜索员工。获取当前用户或指定用户的详细信息、通过关键词搜索员工（姓名/邮箱/手机号）。当用户需要查看个人信息、查找同事 open_id 或联系方式、按姓名搜索员工、查询部门结构时使用。"
metadata:
  requires:
    bins: ["lark-cli"]
  cliHelp: "lark-cli contact --help"
---

# contact (v1)

**CRITICAL — 开始前 MUST 先用 Read 工具读取 [`../lark-shared/SKILL.md`](../lark-shared/SKILL.md)，其中包含认证、权限处理**

## Shortcuts（推荐优先使用）

Shortcut 是对常用操作的高级封装（`lark-cli contact +<verb> [flags]`）。有 Shortcut 的操作优先使用。

| Shortcut | 说明 |
|----------|------|
| [`+search-user`](references/lark-contact-search-user.md) | Search users (results sorted by relevance) |
| [`+get-user`](references/lark-contact-get-user.md) | Get user info (omit user_id for self; provide user_id for specific user) |

## Known Limitations

### External tenant users are not searchable via API

`+search-user`, `+get-user`, and `GET /contact/v3/users` only return **users within the same tenant**.

Users from other organizations (external Lark accounts) will not appear in search results and their `open_id` / `user_id` cannot be retrieved via the contact API — even with a tenant access token (bot identity).

**Workaround options:**

| Scenario | Solution |
|---|---|
| Add external user to Wiki/Doc | Invite as guest via admin console → use `open_id` returned after invitation |
| Share document with external user | Use `open_sharing: anyone_readable` (link-based, no Lark account required) |
| Obtain external user's `open_id` | Ask the user to look up their own `open_id` in Lark profile settings |

```bash
# After admin-console invitation, use openid directly:
lark-cli wiki members create \
  --params '{"space_id":"<space_id>"}' \
  --data '{"member_id":"ou_XXXXXX","member_type":"openid","member_role":"member"}'
```

> Reference: [`docs/known-issues/lark-external-user-api-gap.md`](../docs/known-issues/lark-external-user-api-gap.md)

