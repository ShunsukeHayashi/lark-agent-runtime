# LARC Goal-Aligned Playbook Draft

> Goal-first master draft for deciding whether each task moves this repository closer to the intended outcome.
> This document is the parent playbook. Existing implementation playbooks remain useful, but should be judged against this one.

---

## 1. Goal

Build a practical Lark-native runtime for office-work agents that brings OpenClaw-style agent operation into back-office and white-collar workflows.

The intended end state is not just "a CLI that talks to Lark".
The intended end state is:

- agents can run inside a Lark-centered operating model
- disclosure-chain style context loading can be reproduced through Lark Drive / Base / Wiki
- permission scope selection is explicit, minimal, and fast
- the system can tell, before execution, what the agent can do and under whose authority
- office-work tasks can be executed with stronger permission control than typical agent products
- the architecture is credible enough to scale to many agents, many workspaces, and China-facing go-to-market

---

## 2. Why This Matters

Coding agents spread first because their execution surface is relatively simple:

- local filesystem
- git repository
- CI
- terminal commands

General office-work agents have not spread at the same rate because their execution surface is harder:

- permissions are fragmented
- authority is unclear
- data is distributed across many SaaS tools
- approval and audit trails are weak
- memory and configuration are not naturally unified

Lark is unusual because it combines:

- chat environment
- docs / wiki / drive
- base/database
- approval
- messaging
- identity and tenant concepts
- relatively fine-grained permissions

This makes Lark a strong candidate for a permission-first office agent substrate.

---

## 3. Non-Goals

To avoid drift, these are explicitly not the first goal:

- perfect OpenClaw CLI compatibility
- a full fork of `lark-cli`
- solving every Lark product surface at once
- mass agent deployment before permission control is trustworthy
- public launch before security, permissions, and narrative are coherent

---

## 4. Core Thesis To Validate

This project succeeds if it proves the following thesis:

> "A Lark-centered runtime can reproduce the useful operating properties of agent runtimes for office work, while improving permission control, auditability, and execution safety."

This thesis breaks into five claims:

1. Lark Drive can act as a practical pseudo-filesystem for disclosure-chain style loading.
2. Lark Base can act as structured memory / registry / audit storage.
3. Lark permissions can be modeled well enough to produce best-match scope guidance quickly.
4. Agent actions can be routed through explicit authority boundaries.
5. This creates a better foundation for office agents than today's common ad hoc automations.

---

## 5. Success Conditions

The project should be considered directionally successful only if all of the following become true.

### A. Runtime success

- `bootstrap`, `memory`, `send`, `task`, `agent`, `auth` work as one coherent runtime, not isolated demos
- disclosure-chain files are consistently loaded from Lark-backed sources
- local cache behavior is understandable and recoverable

### B. Permission success

- for a given task description, the system can infer likely required scopes
- it can explain why those scopes are needed
- it can distinguish read, write, approval, and tenant/user authority paths
- it can produce a practical authorization next-step

### C. Agent-operations success

- agents can be registered in batches with known capabilities
- each agent has an explicit workspace, memory surface, and communication path
- future multi-agent rollout has a clear control plane

### D. Evidence success

- there are live checks that prove the design in a real tenant
- permission failures are captured as design inputs, not hidden as manual fixes
- the repo can explain what is already proven and what is still speculative

### E. Product-story success

- the repo can clearly state why this matters beyond ordinary automation
- the repo can explain why Lark is strategically different
- the repo can explain why permission-first design is the wedge

---

## 6. Failure Modes To Avoid

These are signs that work is drifting away from the goal.

- adding commands without improving the permission model
- wrapping more raw APIs without clarifying authority boundaries
- importing assets that do not improve the core runtime or permission story
- focusing on agent count before control-plane quality exists
- claiming compatibility before disclosure and memory behavior are stable
- building China-facing positioning without clear proof points

---

## 7. Workstreams

All future tasks should belong to one of these workstreams.

### Workstream 1: Lark pseudo-filesystem runtime

Purpose:
Reproduce OpenClaw-style disclosure loading using Lark-native storage surfaces.

In scope:

- Drive-backed disclosure files
- Base-backed memory
- Wiki-backed knowledge augmentation
- bootstrap/cache rules

Done when:

- runtime behavior is consistent and live-checkable
- disclosure sources are explicit
- Drive vs Base vs Wiki boundaries are intentional

### Workstream 2: Permission intelligence

Purpose:
Make permission understanding the main differentiator.

In scope:

- scope map quality
- task-to-scope inference
- profile design
- auth check/login flow
- user vs tenant vs bot authority semantics

Done when:

- task descriptions map to practical scopes with low ambiguity
- the system can explain permission choices clearly
- common permission pain points are documented and reduced

### Workstream 3: Agent operating model

Purpose:
Turn Lark into an agent control surface rather than just a destination API.

In scope:

- agent registry
- batch registration
- chat routing
- workspace ownership
- agent identity and capability declarations

Done when:

- many agents can be created with predictable behavior
- each agent has clear authority, storage, and messaging semantics

### Workstream 4: Approval and execution control

Purpose:
Clarify where execution must stop, request authority, or escalate.

In scope:

- approval helper flow
- preview / create / upload path
- future MergeGate integration
- execution gates before risky actions

Done when:

- the line between suggestion, preview, and execution is clear
- business approval paths are explicit

### Workstream 5: Knowledge graph and context graph

Purpose:
Use Lark-native document linking as a graph substrate for agent reasoning and impact analysis.

In scope:

- Wiki mentions
- `[[link]]` or equivalent document relationships
- graph build/query strategy
- future GitNexus-like impact reasoning for office knowledge

Done when:

- the system can explain related documents, dependencies, and likely impact areas

### Workstream 6: Productization and narrative

Purpose:
Translate the architecture into a compelling story and usable product direction.

In scope:

- README / docs framing
- China-facing positioning
- trilingual open-source readiness (English / Chinese / Japanese)
- differentiation vs current AI agent tools
- proof-oriented demos and case studies

Done when:

- a third party can understand the problem, why Lark matters, and what is novel here
- the repo has a credible path from private incubation to trilingual open-source release

---

## 8. Phase Structure

### Phase A: Ground The Runtime

Question:
Can Lark Drive / Base / IM act as a usable operational substrate?

Required outcomes:

- stable bootstrap
- stable memory round-trip
- stable send/task/agent basics
- live-check path

### Phase B: Make Permissions The Wedge

Question:
Can this project tell users "what permission is needed, why, and what to do next" better than alternatives?

Required outcomes:

- trusted scope map
- auth inference with rationale
- authority model documentation
- permission-review findings turned into implementation tasks

### Phase C: Turn It Into An Agent Platform

Question:
Can many office agents be instantiated and governed coherently?

Required outcomes:

- batch registration
- agent capability model
- control-plane docs
- clear registry semantics

### Phase D: Add Controlled Execution Gates

Question:
Can high-risk business actions be previewed, approved, and executed safely?

Required outcomes:

- approval flow model
- explicit preview vs create boundaries
- integration plan for MergeGate-like review

### Phase E: Add Knowledge Graph Value

Question:
Can Lark-native linked knowledge improve agent planning and impact analysis?

Required outcomes:

- document graph model
- query/use cases
- practical integration path into runtime

---

## 9. How To Judge Whether A Task Is Worth Doing

Before starting any task, answer these five checks.

### Check 1: Which workstream does it move?

If none, it is likely drift.

### Check 2: What project risk does it reduce?

Examples:

- runtime instability
- permission ambiguity
- authority confusion
- poor multi-agent operability
- weak product differentiation

### Check 3: What proof does it create?

A good task should create at least one of:

- working code
- live verification
- clearer permission mapping
- reusable asset integration
- clearer product story

### Check 4: Does it improve the wedge?

The wedge is not "Lark access".
The wedge is "permission-first office agent runtime".

### Check 5: Can the effect be measured?

If the task cannot produce a visible before/after, it needs refinement.

### Quick scoring rubric

Score each candidate task from 0 to 2 on these four axes:

- Goal leverage: does it directly strengthen the permission-first office agent thesis?
- Runtime leverage: does it improve the actual Lark-backed runtime rather than documentation alone?
- Proof leverage: does it create live evidence, deterministic behavior, or clearer authority boundaries?
- Reuse leverage: does it unlock high-value legacy assets instead of duplicating them?

Interpretation:

- `7-8` = do now
- `5-6` = do soon
- `3-4` = only if it unblocks a higher-priority task
- `0-2` = likely drift

---

## 10. Task Template

All major tasks should be written in this shape.

### Task

One sentence describing the action.

### Why this matters

State which workstream and which risk it addresses.

### Expected impact

State exactly how the project gets closer to the goal.

### Evidence of success

State how completion will be verified.

### Not success

State what would look busy but not actually help.

---

## 11. Reuse-First Asset Intake

Existing assets should be pulled in only when they strengthen the goal.

### High-priority assets already identified

- `crm-assets/Lark_base_template.md`
- `crm-assets/ppal-lark-base-field-map.md`
- `crm-assets/ppal-crm-requirement.md`
- `crm-assets/ppal-crm-review.md`
- `crm-assets/legacy-backoffice-SPEC.md`
- `crm-assets/legacy-lark-approval.ts`
- `crm-assets/legacy-lark-auth.ts`
- `miyabi-lark-assets/MCP_INTEGRATION_PROTOCOL.md`
- `miyabi-lark-assets/permissions/wiki-PERMISSIONS.md`
- `miyabi-lark-assets/token-management/token-manager.ts`
- `miyabi-lark-assets/token-management/tenant-manager.ts`
- old disabled `lark-dev` skill assets
- archived `agent-skill-bus` / OpenClaw orchestration references

### High-priority external source repos already identified

- internal legacy backoffice automation repository
- `ShunsukeHayashi/lark-openapi-mcp`
- `larksuite/openclaw-lark`
- `larksuite/cli`
- `ShunsukeHayashi/mergegate`

### What each source is good for

- legacy backoffice automation assets
  Best source for real approval, auth, Base, and tenant/user token implementation patterns.
- `lark-openapi-mcp`
  Best source for direct OpenAPI connectivity, auth handling, and API wrapper patterns when shortcut commands are insufficient.
- `openclaw-lark`
  Best source for permission URL flow, tool scope design, and OpenClaw-to-Lark integration semantics.
- `larksuite/cli`
  Canonical reference for command behavior, auth flow, and which abstractions belong in `larc` versus upstream.
- `mergegate`
  Best source for controlled execution workflow, review gates, and multi-step agent operations.

### Intake rule

Do not import assets just because they exist.
Import them only if they improve one of:

- permission modeling
- Lark runtime behavior
- agent control-plane design
- approval / authority handling
- CRM / office-work proof cases

### Intake priority order

1. Permission and token logic
2. Approval and authority flow
3. Runtime sync and disclosure-chain behavior
4. Agent control-plane and orchestration
5. CRM / domain proof assets
6. Narrative and marketing collateral

---

## 12. Current Assessment Of This Repo

As of now, this repository is broadly moving in the right direction.

Stronger areas:

- clear problem framing
- Lark-as-runtime thesis
- core CLI shape
- permission framing exists
- approval and agent operations are already treated as first-class concerns

Weaker areas:

- task-to-goal linkage is not explicit enough
- permission modeling is present but not yet the unquestionable center
- asset reuse has not yet been systematically folded back into implementation
- OpenClaw compatibility and knowledge graph remain more conceptual than operational

This means the repo is directionally correct, but still needs a stronger goal-governance layer.

---

## 13. Immediate Next Steps

1. Use this document as the parent playbook for evaluating all future tasks.
2. Convert the current implementation plan into workstream-aligned tasks.
3. Turn permission review findings into a dedicated backlog.
4. Pull high-priority legacy assets into a structured intake plan.
5. Define one proof-oriented milestone for each phase.

---

## 14. First Milestone To Lock

The next milestone should be:

> "For a realistic office task, LARC can explain the minimum likely scopes, load the right disclosure context, and safely route the next executable action."

If a task does not make that milestone more real, it should probably wait.
