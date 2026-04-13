---
name: lark-contact
version: 1.0.0
description: "Lark Contacts: query org structure, user info, and search employees. Get details for the current user or a specified user, search employees by name/email/phone. Use when you need to view personal info, find a colleague's open_id or contact details, search employees by name, or query department structure."
metadata:
  requires:
    bins: ["lark-cli"]
  cliHelp: "lark-cli contact --help"
---

# contact (v1)

**CRITICAL — Before starting, MUST read [`../lark-shared/SKILL.md`](../lark-shared/SKILL.md) using the Read tool. It contains authentication and permission handling.**

## Shortcuts (recommended — use these first)

Shortcuts are high-level wrappers for common operations (`lark-cli contact +<verb> [flags]`). Prefer shortcuts when available.

| Shortcut | Description |
|----------|-------------|
| [`+search-user`](references/lark-contact-search-user.md) | Search users (results sorted by relevance) |
| [`+get-user`](references/lark-contact-get-user.md) | Get user info (omit user_id for self; provide user_id for a specific user) |
