---
name: lark-shared
version: 1.0.0
description: "Lark/Feishu CLI shared foundation: app configuration initialization, authentication (auth login), identity switching (--as user/bot), permission and scope management, Permission denied error handling, security rules. Triggered when the user needs first-time setup (lark-cli config init), login authorization (lark-cli auth login), insufficient permissions, switching user/bot identity, configuring scopes, or first-time lark-cli usage."
---

# lark-cli Shared Rules

This skill guides you on how to operate Lark resources via lark-cli and what to watch out for.

## Configuration Initialization

First-time use requires running `lark-cli config init` to complete app configuration.

When helping a user initialize the configuration, run the following command in background mode, then read the output, extract the authorization URL, and send it to the user:

```bash
# Initiate configuration (this command blocks until the user opens the link and completes the flow, or it times out)
lark-cli config init --new
```

## Authentication

### Identity Types

Two identity types, switched via `--as`:

| Identity | Flag | How to Obtain | Use Case |
|----------|------|--------------|----------|
| User identity | `--as user` | `lark-cli auth login` etc. | Access the user's own resources (calendar, Drive, etc.) |
| Bot identity | `--as bot` | Automatic — only needs appId + appSecret | App-level operations, accessing the bot's own resources |

### Identity Selection Principles

The output `[identity: bot/user]` shows the current identity. Bot and user behave very differently — confirm the identity matches the target requirement:

- **Bot cannot see user resources**: Cannot access a user's calendar, Drive documents, mailbox, or other personal resources. For example, `--as bot` querying events returns the bot's own (empty) calendar.
- **Bot cannot act on behalf of the user**: Messages are sent in the app's name; created documents are owned by the bot.
- **Bot permissions**: Only requires scope grants in the Lark Developer Console — no `auth login` needed.
- **User permissions**: Requires scope grants in the Developer Console AND user authorization via `auth login` — both layers must be satisfied.

### Handling Insufficient Permissions

When a permission-related error occurs, **adopt different solutions based on the current identity type**.

The error response contains key information:
- `permission_violations`: Lists missing scopes (select one)
- `console_url`: Link to the Lark Developer Console permission configuration page
- `hint`: Suggested fix command

#### Bot Identity (`--as bot`)

Provide the `console_url` from the error to the user and guide them to grant the scope in the console. **Never** run `auth login` for bot identity.

#### User Identity (`--as user`)

```bash
lark-cli auth login --domain <domain>           # Authorize by business domain
lark-cli auth login --scope "<missing_scope>"   # Authorize by specific scope (recommended — follows least-privilege principle)
```

**Rule**: `auth login` must specify a scope (`--domain` or `--scope`). Multiple logins accumulate scopes (incremental authorization).

#### Agent-Initiated Authentication (Recommended)

When acting as an AI agent helping the user complete authentication, run the following command in background mode to initiate the authorization flow, then send the authorization URL to the user:

```bash
# Initiate authorization (blocks until the user completes or it times out)
lark-cli auth login --scope "calendar:calendar:readonly"
```

## Update Check

After a `lark-cli` command runs, if a new version is detected, the JSON output will contain a `_notice.update` field (with `message`, `command`, etc.).

**When you see `_notice.update` in the output, after completing the user's current request, proactively offer to help the user update**:

1. Inform the user of the current and latest version numbers.
2. Propose running the update (both CLI and Skills need to be updated together):
   ```bash
   npm update -g @larksuite/cli && npx skills add larksuite/cli -g -y
   ```
3. After the update completes, remind the user: **exit and reopen the AI Agent** to load the latest Skills.

**Rule**: Do not silently ignore update notices. Even if the current task is unrelated to the update, inform the user after completing their request.

## Security Rules

- **Never output secrets** (appSecret, accessToken) as plaintext to the terminal.
- **Confirm user intent before any write or delete operation**.
- Use `--dry-run` to preview dangerous requests.
