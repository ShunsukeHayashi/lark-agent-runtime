# LARC Permission Model

> Working model for how LARC should reason about permissions, authority, and execution boundaries.

---

## 1. Purpose

LARC is not trying to be "a CLI with many Lark commands".
Its wedge is:

> a permission-first runtime for office-work agents

This document defines the minimum model needed to make that wedge real.

---

## 2. Core Question

For any requested task, LARC should answer:

1. Which Lark surface is involved?
2. What exact scope is likely required?
3. Which authority path is needed?
4. Is this read, write, approval submission, or approval action?
5. What is the next safe step?

---

## 3. Authority Types

### User authority

Use when the action must be performed as a real, named person and Lark should attribute the action directly to that user.

Typical examples:

- reading and editing user-facing docs
- reading contacts and directory data
- creating Base records in a user's business workflow
- creating approval instances on behalf of an applicant
- approving or rejecting approval tasks as a human approver

Typical token shape:

- `user_access_token`

Provisioning shape:

- user authorizes the app via OAuth
- token is scoped to one user
- best fit for audit-trail-sensitive business actions

### Tenant authority

Use when the action is app-level, service-level, or infrastructure-like.

Typical examples:

- backend-side approval instance creation where the app mediates the action
- app-wide service calls
- system-level integrations that do not represent a specific human action directly

Typical token shape:

- `tenant_access_token`

Provisioning shape:

- app is granted tenant-wide capability
- no per-user OAuth step is required for the app itself
- useful for backend-side coordination and system-managed flows

### Bot authority

Use when the action is system-initiated on behalf of the tenant and mainly targets communication or automation surfaces.

Typical examples:

- sending IM messages as a bot
- posting notifications
- posting to a group chat
- background or scheduled automation reads where user identity is not the point

Typical token shape:

- bot/app identity, commonly backed by tenant-level app authority

Provisioning shape:

- app must be added to the target chat or space
- chat-level availability matters as much as token scope

### Mixed authority

Some workflows span more than one authority type.

Examples:

- CRM follow-up:
  record creation may be user-identity while IM notification is bot-identity.
- Approval routing:
  instance creation may be app- or user-mediated, while approval action is strictly user-mediated.

LARC should not collapse these into a single vague answer.

Provisioning shape:

- split the task by authority boundary
- use user token for user-attributed record or document actions
- use bot/app authority for notifications and tenant-managed automation

---

## 4. Permission Surface Categories

### Documents and Wiki

Purpose:

- working knowledge
- policy docs
- procedural docs

Typical scope classes:

- read: `docs:doc:readonly`, `wiki:wiki:readonly`
- write: `docs:doc`, `docs:doc:create`, `wiki:wiki`
- manage: `wiki:wiki.node`

### Drive

Purpose:

- disclosure-chain source files
- uploaded artifacts
- shared workspace files

Typical scope classes:

- read: `drive:drive:readonly`
- write/create: `drive:file:create`
- manage: `drive:drive`

### Base / Bitable

Purpose:

- memory
- registry
- audit
- CRM and operational records

Typical scope classes:

- read: `base:record:readonly`
- create: `base:record:created`
- update/manage: `bitable:app`, `bitable:record`, `bitable:table`

### IM

Purpose:

- notifications
- agent/user communication

Typical scope classes:

- send: `im:message:send_as_bot`
- read: `im:message:readonly`

### Approval

Purpose:

- controlled business execution
- authority boundary management

This surface should be modeled in finer grain than before.

Typical scope classes:

- read definitions/status: `approval:approval:readonly`
- create instance: `approval:instance:write`
- act on approval task: `approval:task:write`
- broad legacy write/admin behavior: `approval:approval:write`

### Contact / Directory

Purpose:

- resolving users, departments, approvers, assignees

Typical scope classes:

- read: `contact:user.base:readonly`, `contact:department.base:readonly`
- manage: `contact:user.base`, `contact:department.base`

---

## 5. Permission Semantics By Action Type

### Read

The action inspects data but should not mutate business state.

Examples:

- read a doc
- check approval status
- list Base records

### Create

The action creates a new business object.

Examples:

- create CRM record
- create task
- submit approval instance

### Update

The action mutates an existing object.

Examples:

- update wiki page
- edit Base record
- complete task

### Act

The action is not generic mutation; it is a governed business decision.

Examples:

- approve task
- reject task

This category should remain distinct from create/update.

---

## 6. Current LARC Mapping Rules

Today, `auth suggest` uses keyword-triggered task detection from:

- [lib/auth.sh](/Users/shunsukehayashi/study/larc-openclaw-coding-agent/lib/auth.sh)
- [config/scope-map.json](/Users/shunsukehayashi/study/larc-openclaw-coding-agent/config/scope-map.json)

This is good enough for an early wedge, but it has limits:

- wording sensitivity
- under-detection of compound tasks
- over-detection when nouns imply write access
- weak distinction between user, tenant, and bot execution

---

## 7. Improvements Introduced In This Iteration

The current repo now distinguishes more clearly between:

- approval instance creation
- approval task action
- CRM record creation
- CRM follow-up messaging

Examples:

- `"create expense report and request approval"`
  -> `base:record:created` + `approval:instance:write`
- `"approve an approval task for an expense request"`
  -> `approval:task:write`
- `"create crm record and send a follow-up message"`
  -> Base + CRM + contact lookup + IM scopes

This is not final, but it is closer to the actual business semantics.

The current CLI explanation is sourced from `authority_notes` in
[config/scope-map.json](/Users/shunsukehayashi/study/larc-openclaw-coding-agent/config/scope-map.json),
so future authority wording should be updated there first and then reflected here.

---

## 8. Known Gaps

### Gap 1: Legacy approval write scope is still present

`approval:approval:write` still appears in profiles for compatibility, but the runtime should increasingly prefer:

- `approval:instance:write`
- `approval:task:write`

### Gap 2: Mixed authority is only partially expressed

The current output can say `user or bot`, but it does not yet explain which sub-step belongs to which authority.

### Gap 3: Heuristic rather than deterministic inference

Current inference is regex-driven.
Longer term, it should combine:

- task classes
- API/action semantics
- evidence from real successful flows

### Gap 4: Scope minimization still needs tuning

Some compound tasks still return slightly broader scope sets than ideal.

---

## 9. Design Rule Going Forward

When adding or revising a permission mapping:

1. Prefer the narrowest scope that matches the real action.
2. Separate instance creation from task action.
3. Default noun-only mentions to read, not write.
4. Only infer write when an action verb makes it explicit.
5. Preserve mixed authority when a workflow spans user and bot roles.

---

## 10. Immediate Backlog

1. Add task examples and expected scopes as test fixtures for `auth suggest`.
2. Reduce over-broad CRM compound scopes.
3. Decide whether `approval:approval:write` remains in user-facing recommendations or becomes compatibility-only.
4. Add authority explanations to `auth suggest` output.
5. Fold in legacy backoffice automation assets and `openclaw-lark` findings to make the mapping less heuristic.

---

## 11. Canonical Authority Notes

These should stay aligned with `authority_notes` in `scope-map.json`.

### user

- Label: `user (user_access_token)`
- Why: the action must be attributable to a real named person for audit trail, quota, and permission purposes
- Provisioning: user authorizes the app via OAuth

### bot

- Label: `bot (tenant_access_token)`
- Why: the action is system-initiated on behalf of the tenant rather than a specific person
- Provisioning: app must be present in the target chat or space

### either

- Label: `either (user or bot depending on context)`
- Why: the compound task spans actions that belong to different authority types
- Provisioning: split execution by authority boundary whenever possible
