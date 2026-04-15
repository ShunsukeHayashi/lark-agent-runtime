# LARC Asset Intake Plan

> Concrete plan for deciding which legacy repositories, local assets, and references should be brought into this repo.

---

## 1. Purpose

This document turns asset discovery into implementation decisions.

It answers:

- what to import first
- why it matters
- where it should land in this repo
- what success would look like

---

## 2. Intake Principles

Bring assets in only if they strengthen one of these:

- permission intelligence
- disclosure-chain runtime behavior
- approval / authority handling
- agent registry / control-plane design
- realistic office-work demos

Do not import assets only for archive completeness.

---

## 3. Highest-Priority Source Repositories

### Priority 1: Internal legacy backoffice automation repository

Why it matters:

- strongest known source of real Lark auth / approval / Base logic
- directly aligned with this repo's biggest wedge

Bring in first:

- auth and token handling patterns
- approval instance creation / approve / reject patterns
- Base schema and workflow design notes

Likely landing zones:

- `lib/approve.sh`
- `lib/auth.sh`
- `config/scope-map.json`
- `docs/permission-model.md`
- `docs/approval-model.md`

Success looks like:

- this repo explains tenant/user/token authority more clearly
- approval create/preview/upload behavior becomes less ad hoc
- scope inference becomes grounded in real Lark action models

### Priority 2: `larksuite/openclaw-lark`

Why it matters:

- strongest external proof that OpenClaw × Lark can be made coherent
- especially valuable for permissions and tool scope framing

Bring in first:

- permission URL and scope design ideas
- tool capability structure
- integration semantics between agent runtime and Lark permissions

Likely landing zones:

- `docs/openclaw-compatibility.md`
- `docs/permission-model.md`
- future `lib/openclaw-compat.sh`

Success looks like:

- this repo can explain exactly where it matches or diverges from `openclaw-lark`
- permission design becomes less speculative

### Priority 3: `ShunsukeHayashi/lark-openapi-mcp`

Why it matters:

- best fallback path when `lark-cli` shortcuts are not expressive enough
- useful for direct OpenAPI and auth transport patterns

Bring in first:

- auth transport and OpenAPI wrapper patterns
- direct API call structure that can complement `larc`

Likely landing zones:

- `docs/api-surface-strategy.md`
- future helper layer if `lark-cli api` usage expands

Success looks like:

- the project has a clear rule for when to use shortcut commands versus direct OpenAPI

### Priority 4: `larksuite/cli`

Why it matters:

- canonical upstream behavior
- source of truth for command shape and auth flow

Bring in first:

- command references
- auth and scope handling semantics
- error and output conventions

Likely landing zones:

- implementation cleanup across `lib/*.sh`
- `docs/cli-alignment.md`

Success looks like:

- fewer assumptions in wrapper code
- better resilience to command misuse

### Priority 5: `ShunsukeHayashi/mergegate`

Why it matters:

- execution review and gate orchestration
- useful once approval and risky-action boundaries are solid

Bring in first:

- review gate concepts
- execution-control workflow
- issue-driven control patterns

Likely landing zones:

- future `lib/mergegate.sh`
- `docs/execution-gates.md`

Success looks like:

- risky office actions gain explicit gate semantics instead of direct execution

---

## 4. Highest-Priority Local Assets

### CRM assets

Best candidates:

- [crm-assets/Lark_base_template.md](/Users/shunsukehayashi/study/larc-openclaw-coding-agent/crm-assets/Lark_base_template.md)
- [crm-assets/ppal-lark-base-field-map.md](/Users/shunsukehayashi/study/larc-openclaw-coding-agent/crm-assets/ppal-lark-base-field-map.md)
- [crm-assets/ppal-crm-requirement.md](/Users/shunsukehayashi/study/larc-openclaw-coding-agent/crm-assets/ppal-crm-requirement.md)
- [crm-assets/ppal-crm-review.md](/Users/shunsukehayashi/study/larc-openclaw-coding-agent/crm-assets/ppal-crm-review.md)
- [crm-assets/legacy-backoffice-SPEC.md](/Users/shunsukehayashi/study/larc-openclaw-coding-agent/crm-assets/legacy-backoffice-SPEC.md)
- [crm-assets/legacy-lark-approval.ts](/Users/shunsukehayashi/study/larc-openclaw-coding-agent/crm-assets/legacy-lark-approval.ts)
- [crm-assets/legacy-lark-auth.ts](/Users/shunsukehayashi/study/larc-openclaw-coding-agent/crm-assets/legacy-lark-auth.ts)

Use:

- permission model examples
- realistic office workflow demos
- approval and Base schema grounding

### Miyabi Lark assets

Best candidates:

- [miyabi-lark-assets/MCP_INTEGRATION_PROTOCOL.md](/Users/shunsukehayashi/study/larc-openclaw-coding-agent/miyabi-lark-assets/MCP_INTEGRATION_PROTOCOL.md)
- [miyabi-lark-assets/permissions/wiki-PERMISSIONS.md](/Users/shunsukehayashi/study/larc-openclaw-coding-agent/miyabi-lark-assets/permissions/wiki-PERMISSIONS.md)
- [miyabi-lark-assets/token-management/token-manager.ts](/Users/shunsukehayashi/study/larc-openclaw-coding-agent/miyabi-lark-assets/token-management/token-manager.ts)
- [miyabi-lark-assets/token-management/tenant-manager.ts](/Users/shunsukehayashi/study/larc-openclaw-coding-agent/miyabi-lark-assets/token-management/tenant-manager.ts)

Use:

- token lifecycle
- tenant/user authority modeling
- MCP and runtime integration strategy

### Old skill assets

Best candidates:

- [lark-dev disabled skill](/Users/shunsukehayashi/.claude/skills.disabled/lark-dev/SKILL.md)

Use:

- recovering useful skill ergonomics
- API lookup, scaffolding, and developer-facing workflow patterns

---

## 5. Recommended Intake Order

### Intake Wave 1: Permission Core

Focus:

- legacy backoffice automation assets
- `openclaw-lark`
- `wiki-PERMISSIONS`
- token-manager patterns

Output:

- `docs/permission-model.md`
- `docs/authority-model.md`
- backlog items for `lib/auth.sh` and `config/scope-map.json`

### Intake Wave 2: Approval Core

Focus:

- `legacy-lark-approval.ts`
- approval spike notes
- `mergegate` conceptual input

Output:

- `docs/approval-model.md`
- refined `lib/approve.sh` backlog
- explicit preview/create/escalation model

### Intake Wave 3: Runtime Sync

Focus:

- disclosure-chain behavior from current repo
- asset-backed understanding of Drive/Base responsibilities
- OpenClaw compatibility semantics

Output:

- `docs/disclosure-runtime-model.md`
- design for `larc sync` or `larc publish`

### Intake Wave 4: Agent Platform

Focus:

- `register-agents`
- archived orchestration references
- future control-plane docs

Output:

- `docs/agent-control-plane.md`
- refined batch registration semantics

### Intake Wave 5: Domain Proof

Focus:

- CRM templates
- office-work demo scenarios

Output:

- one or two proof-oriented end-to-end demos
- strong README examples

---

## 6. Tasks To Create Next

1. Create `docs/permission-model.md` from legacy backoffice automation assets, `openclaw-lark`, and Miyabi token assets.
2. Create `docs/authority-model.md` covering tenant token, user token, bot identity, and execution authority.
3. Refactor `lib/auth.sh` backlog against that model.
4. Create `docs/approval-model.md` and align `lib/approve.sh` with it.
5. Design `larc sync` / `larc publish` to strengthen disclosure-chain realism.

---

## 7. Notable Non-Immediate Imports

These may matter later, but should not lead the roadmap now:

- general agent orchestration archives without Lark-specific relevance
- broad marketing or outreach templates
- repos that do not materially improve permission, approval, or runtime design

---

## 8. Decision Rule

If an asset does not make the permission-first office agent runtime more real, more provable, or more controllable, it should wait.
