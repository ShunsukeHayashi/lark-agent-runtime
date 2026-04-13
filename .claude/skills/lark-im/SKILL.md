---
name: lark-im
version: 1.0.0
description: "Lark Instant Messaging: send/receive messages and manage group chats. Send and reply to messages, search chat history, manage group members, upload/download images and files, manage emoji reactions. Use when the user needs to send messages, view or search chat history, download files from chats, or view group members."
metadata:
  requires:
    bins: ["lark-cli"]
  cliHelp: "lark-cli im --help"
---

# im (v1)

**CRITICAL — Before starting, MUST use the Read tool to read [`../lark-shared/SKILL.md`](../lark-shared/SKILL.md). It contains authentication and permission handling.**

## Core Concepts

- **Message**: A single message in a chat, identified by `message_id` (om_xxx). Supports types: text, post, image, file, audio, video, sticker, interactive (card), share_chat, share_user, merge_forward, etc.
- **Chat**: A group chat or P2P conversation, identified by `chat_id` (oc_xxx).
- **Thread**: A reply thread under a message, identified by `thread_id` (om_xxx or omt_xxx).
- **Reaction**: An emoji reaction on a message.

## Resource Relationships

```
Chat (oc_xxx)
├── Message (om_xxx)
│   ├── Thread (reply thread)
│   ├── Reaction (emoji)
│   └── Resource (image / file / video / audio)
└── Member (user / bot)
```

## Important Notes

### Identity and Token Mapping

- `--as user` means **user identity** and uses `user_access_token`. Calls run as the authorized end user, so permissions depend on both the app scopes and that user's own access to the target chat/message/resource.
- `--as bot` means **bot identity** and uses `tenant_access_token`. Calls run as the app bot, so behavior depends on the bot's membership, app visibility, availability range, and bot-specific scopes.
- If an IM API says it supports both `user` and `bot`, the token type changes who the operator is. The same API can succeed with one identity and fail with the other because owner/admin status, chat membership, tenant boundary, or app availability are checked against the current caller.

### Sender Name Resolution with Bot Identity

When using bot identity (`--as bot`) to fetch messages (e.g. `+chat-messages-list`, `+threads-messages-list`, `+messages-mget`), sender names may not be resolved (shown as open_id instead of display name). This happens when the bot cannot access the user's contact info.

**Root cause**: The bot's app visibility settings do not include the message sender, so the contact API returns no name.

**Solution**: Check the app's visibility settings in the Lark Developer Console — ensure the app's visible range covers the users whose names need to be resolved. Alternatively, use `--as user` to fetch messages with user identity, which typically has broader contact access.

### Card Messages (Interactive)

Card messages (`interactive` type) are not yet supported for compact conversion in event subscriptions. The raw event data will be returned instead, with a hint printed to stderr.

## Shortcuts (Prefer Using These First)

Shortcuts are high-level wrappers for common operations (`lark-cli im +<verb> [flags]`). Prefer Shortcuts when available.

| Shortcut | Description |
|----------|-------------|
| [`+chat-create`](references/lark-im-chat-create.md) | Create a group chat; user/bot; creates private/public chats, invites users/bots, optionally sets bot manager |
| [`+chat-messages-list`](references/lark-im-chat-messages-list.md) | List messages in a chat or P2P conversation; user/bot; accepts --chat-id or --user-id, resolves P2P chat_id, supports time range/sort/pagination |
| [`+chat-search`](references/lark-im-chat-search.md) | Search visible group chats by keyword and/or member open_ids (e.g. look up chat_id by group name); user/bot; supports member/type filters, sorting, and pagination |
| [`+chat-update`](references/lark-im-chat-update.md) | Update group chat name or description; user/bot; updates a chat's name or description |
| [`+messages-mget`](references/lark-im-messages-mget.md) | Batch get messages by IDs; user/bot; fetches up to 50 om_ message IDs, formats sender names, expands thread replies |
| [`+messages-reply`](references/lark-im-messages-reply.md) | Reply to a message (supports thread replies); user/bot; supports text/markdown/post/media replies, reply-in-thread, idempotency key |
| [`+messages-resources-download`](references/lark-im-messages-resources-download.md) | Download images/files from a message; user/bot; downloads image/file resources by message-id and file-key to a safe relative output path |
| [`+messages-search`](references/lark-im-messages-search.md) | Search messages across chats (supports keyword, sender, time range filters) with user identity; user-only; filters by chat/sender/attachment/time, supports auto-pagination via `--page-all` / `--page-limit`, enriches results via batched mget and chats batch_query |
| [`+messages-send`](references/lark-im-messages-send.md) | Send a message to a chat or direct message; user/bot; sends to chat-id or user-id with text/markdown/post/media, supports idempotency key |
| [`+threads-messages-list`](references/lark-im-threads-messages-list.md) | List messages in a thread; user/bot; accepts om_/omt_ input, resolves message IDs to thread_id, supports sort/pagination |

## API Resources

```bash
lark-cli schema im.<resource>.<method>   # Check parameter structure before calling any API
lark-cli im <resource> <method> [flags]  # Call the API
```

> **Important**: When using native APIs, always run `schema` first to inspect `--data` / `--params` structure. Do not guess field formats.

### chats

  - `create` — Create a group chat. Identity: `bot` only (`tenant_access_token`).
  - `get` — Get chat info. Identity: supports `user` and `bot`; the caller must be in the target chat to get full details, and must belong to the same tenant for internal chats.
  - `link` — Get a chat sharing link. Identity: supports `user` and `bot`; the caller must be in the target chat, must be an owner or admin when chat sharing is restricted to owners/admins, and must belong to the same tenant for internal chats.
  - `list` — Get the list of chats the user or bot is in. Identity: supports `user` and `bot`.
  - `update` — Update chat info. Identity: supports `user` and `bot`.

### chat.members

  - `create` — Add users or bots to a group chat. Identity: supports `user` and `bot`; the caller must be in the target chat; for `bot` calls, added users must be within the app's availability; for internal chats the operator must belong to the same tenant; if only owners/admins can add members, the caller must be an owner/admin, or a chat-creator bot with `im:chat:operate_as_owner`.
  - `delete` — Remove users or bots from a group chat. Identity: supports `user` and `bot`; only group owner, admin, or creator bot can remove others; max 50 users or 5 bots per request.
  - `get` — Get the member list of a group chat. Identity: supports `user` and `bot`; the caller must be in the target chat and must belong to the same tenant for internal chats.

### messages

  - `delete` — Revoke a message. Identity: supports `user` and `bot`; for `bot` calls, the bot must be in the chat to revoke group messages; to revoke another user's group message, the bot must be the owner, an admin, or the creator; for user P2P recalls, the target user must be within the bot's availability.
  - `forward` — Forward a message. Identity: `bot` only (`tenant_access_token`).
  - `merge_forward` — Merge-forward messages. Identity: `bot` only (`tenant_access_token`).
  - `read_users` — Query message read status. Identity: `bot` only (`tenant_access_token`); the bot must be in the chat, and can only query read status for messages it sent within the last 7 days.

### reactions

  - `batch_query` — Batch-get message emoji reactions. Identity: supports `user` and `bot`. [Must-read](references/lark-im-reactions.md)
  - `create` — Add an emoji reaction to a message. Identity: supports `user` and `bot`; the caller must be in the conversation that contains the message. [Must-read](references/lark-im-reactions.md)
  - `delete` — Delete an emoji reaction from a message. Identity: supports `user` and `bot`; the caller must be in the conversation that contains the message, and can only delete reactions added by itself. [Must-read](references/lark-im-reactions.md)
  - `list` — Get emoji reactions for a message. Identity: supports `user` and `bot`; the caller must be in the conversation that contains the message. [Must-read](references/lark-im-reactions.md)

### images

  - `create` — Upload an image. Identity: `bot` only (`tenant_access_token`).

### pins

  - `create` — Pin a message. Identity: supports `user` and `bot`.
  - `delete` — Remove a pinned message. Identity: supports `user` and `bot`.
  - `list` — Get pinned messages in a chat. Identity: supports `user` and `bot`.

## Permissions Table

| Method | Required Scope |
|--------|---------------|
| `chats.create` | `im:chat:create` |
| `chats.get` | `im:chat:read` |
| `chats.link` | `im:chat:read` |
| `chats.list` | `im:chat:read` |
| `chats.update` | `im:chat:update` |
| `chat.members.create` | `im:chat.members:write_only` |
| `chat.members.delete` | `im:chat.members:write_only` |
| `chat.members.get` | `im:chat.members:read` |
| `messages.delete` | `im:message:recall` |
| `messages.forward` | `im:message` |
| `messages.merge_forward` | `im:message` |
| `messages.read_users` | `im:message:readonly` |
| `reactions.batch_query` | `im:message.reactions:read` |
| `reactions.create` | `im:message.reactions:write_only` |
| `reactions.delete` | `im:message.reactions:write_only` |
| `reactions.list` | `im:message.reactions:read` |
| `images.create` | `im:resource` |
| `pins.create` | `im:message.pins:write_only` |
| `pins.delete` | `im:message.pins:write_only` |
| `pins.list` | `im:message.pins:read` |
