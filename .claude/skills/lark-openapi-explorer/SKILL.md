---
name: lark-openapi-explorer
version: 1.0.0
description: "Lark/Feishu native OpenAPI exploration: discover native OpenAPI endpoints not yet wrapped by the CLI from the official documentation library. Use when the user's requirements cannot be met by existing lark-* skills or registered lark-cli commands, and you need to find and call native Lark OpenAPIs."
metadata:
  requires:
    bins: ["lark-cli"]
---

# OpenAPI Explorer

> **Prerequisites:** First read [`../lark-shared/SKILL.md`](../lark-shared/SKILL.md) to understand authentication, identity switching, and security rules.

Use this skill to dig native OpenAPI endpoints from Lark's official markdown documentation library when the user's requirements **cannot be covered by existing skills or CLI-registered APIs**, then complete the task via `lark-cli api` raw calls.

## Documentation Library Structure

Lark OpenAPI documentation is organized in a markdown hierarchy:

```
llms.txt                          ← Top-level index listing all module documentation links
  └─ llms-<module>.txt            ← Module documentation with feature overview + underlying API doc links
       └─ <api-doc>.md            ← Complete description for a single API (method/path/params/response/error codes)
```

Documentation entry points:

| Brand | Entry URL |
|-------|-----------|
| Feishu (China) | `https://open.feishu.cn/llms.txt` |
| Lark (International) | `https://open.larksuite.com/llms.txt` |

> All documentation is written in **Chinese**. If the user is communicating in English, translate the documentation content to English before outputting.

## Discovery Process

Strictly follow the steps below level by level — **do not skip steps or guess APIs**:

### Step 1: Confirm Existing Capabilities Are Insufficient

```bash
# Check if a corresponding skill or registered API already exists
lark-cli <possible-service> --help
```

If a corresponding command or shortcut already exists, use it directly — **no need to continue discovery**.

### Step 2: Locate the Module from the Top-Level Index

Use WebFetch to get the top-level index and find the module documentation link related to the requirement:

```
WebFetch https://open.feishu.cn/llms.txt
  → Extract: "List all module documentation links, find links related to <user requirement keywords>"
```

- Use `open.feishu.cn` for Feishu brand
- Use `open.larksuite.com` for Lark brand
- If the user's brand is uncertain, default to Feishu

### Step 3: Locate the Specific API from the Module Documentation

Use WebFetch to get the module documentation and find the specific API documentation link:

```
WebFetch https://open.feishu.cn/llms-docs/zh-CN/llms-<module>.txt
  → Extract: "Find the API description and documentation link related to <user requirement>"
```

### Step 4: Get the Full API Specification

Use WebFetch to get the specific API documentation and extract the complete call specification:

```
WebFetch https://open.feishu.cn/document/server-docs/.../<api>.md
  → Extract: "Return the complete API spec: HTTP method, URL path, path params, query params, request body fields (name/type/required/description), response fields, required permissions, error codes"
```

### Step 5: Call the API via CLI

Use `lark-cli api` for raw calls:

```bash
# GET request
lark-cli api GET /open-apis/<path> --params '{"key":"value"}'

# POST request
lark-cli api POST /open-apis/<path> --data '{"key":"value"}'

# PUT request
lark-cli api PUT /open-apis/<path> --data '{"key":"value"}'

# DELETE request
lark-cli api DELETE /open-apis/<path>
```

## Output Format

When presenting discovery results to the user, organize as follows:

1. **API name and function**: One-sentence description
2. **HTTP method and path**: `METHOD /open-apis/...`
3. **Key parameters**: List required and common optional parameters
4. **Required permissions**: Scope list
5. **Call example**: Full `lark-cli api` command
6. **Notes**: Rate limits, special constraints, etc.

If the user is communicating in English, translate all of the above to English.

## Security Rules

- **Write/delete APIs** (POST/PUT/DELETE) must confirm user intent before calling
- Suggest using `--dry-run` to preview the request first (if supported)
- Never guess API paths or parameters — always obtain them from the documentation
- For sensitive operations (delete group, remove members, etc.), inform the user of the impact scope

## Usage Examples

### Example 1: User Needs to Add Members to a Group (Not Wrapped by CLI)

```bash
# Step 1: Confirm CLI doesn't have this wrapped
lark-cli im --help
# → No chat_members create command found

# Steps 2-4: Discover the API specification via documentation
# → POST /open-apis/im/v1/chats/:chat_id/members

# Step 5: Call
lark-cli api POST /open-apis/im/v1/chats/oc_xxx/members \
  --data '{"id_list":["ou_xxx","ou_yyy"]}' \
  --params '{"member_id_type":"open_id"}'
```

### Example 2: User Needs to Set a Group Announcement

```bash
# Step 1: Confirm CLI doesn't have this wrapped
lark-cli im --help
# → No announcement command found

# Steps 2-4: Discover via documentation
# → PATCH /open-apis/im/v1/chats/:chat_id/announcement

# Step 5: Call
lark-cli api PATCH /open-apis/im/v1/chats/oc_xxx/announcement \
  --data '{"revision":"0","requests":["<html>Announcement content</html>"]}'
```

## References

- [lark-shared](../lark-shared/SKILL.md) — Authentication and global parameters
- [lark-skill-maker](../lark-skill-maker/SKILL.md) — If you need to solidify discovered APIs into a new Skill
