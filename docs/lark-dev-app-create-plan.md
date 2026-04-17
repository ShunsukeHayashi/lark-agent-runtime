# Lark Dev App Create Plan

> Execution plan for creating and validating a Lark Developer Console app that can safely support `lark-cli` and `larc quickstart`.
> This plan complements, and does not replace, the operator-facing setup guide in [docs/lark-app-setup.md](./lark-app-setup.md).

---

## 1. Goal

Create an authentication model for LARC testing and development that:

- can authenticate `lark-cli`
- keeps `App Secret` local to the app owner or the provisioned machine
- minimizes cross-user secret distribution
- has the minimum practical scopes for current LARC workflows
- is easy to verify, rotate, and retire

---

## 2. Current Truth

- LARC uses `lark-cli` as the execution surface for Lark APIs.
- `lark-cli` currently needs a Lark app with `App ID` and `App Secret`.
- The old setup story leaned too heavily on handing `App Secret` to testers.
- That creates avoidable problems:
  - shared secret sprawl
  - weak revocation hygiene
  - poor operator ergonomics
  - a confusing boundary between app bootstrap and user OAuth login
- What is missing is an execution-oriented plan and a repeatable playbook that can be used during setup, review, and handoff.

---

## 3. Success Criteria

This work is successful when all of the following are true:

1. A Lark custom app exists in the correct region (`lark` or `feishu`).
2. The app has the minimum verified scopes for current LARC usage.
3. The app has been published after scope changes.
4. `App Secret` is not broadly distributed to testers by default.
5. A tester can complete:
   - `lark-cli config init`
   - `lark-cli auth login`
   - `larc quickstart`
6. Evidence exists for who created the app, when it was published, what scopes were granted, and which auth mode was used.

---

## 4. Recommended Auth Modes

### Mode A — Self-owned dev app

Recommended for:

- developers
- technical testers
- long-lived internal use

Flow:

1. each user creates their own Lark dev app
2. each user keeps their own `App Secret`
3. each user runs `lark-cli config init` locally
4. each user completes `lark-cli auth login`

Why this is best:

- no secret handoff between people
- clean ownership and rotation
- least confusing mental model

### Mode B — Operator-provisioned workstation

Recommended for:

- managed laptops
- internal QA devices
- guided onboarding sessions

Flow:

1. an operator creates or owns the app
2. the operator configures `lark-cli` directly on the target machine
3. the user only completes OAuth login and `larc quickstart`

Why this is acceptable:

- secrets stay local to the machine
- users do not receive the raw secret value

### Mode C — Shared app secret handoff

Use only as a fallback for short-lived testing.

Why this is weak:

- secret spreads across people and machines
- rotation becomes expensive
- responsibility is unclear

Rule:

- do not treat this as the default onboarding path

---

## 5. Boundaries

In scope:

- self-owned app flow
- operator-provisioned flow
- app creation and permission setup
- publish and verification flow
- secure local provisioning
- tester validation path

Out of scope:

- public marketplace app packaging
- production bot distribution
- tenant-wide rollout automation
- committing credentials or tenant secrets into this repo

---

## 6. Phases

### Phase A — Decide the app boundary

Questions to settle before opening Developer Console:

- Which region is the target: `lark` or `feishu`?
- Which auth mode will be used: self-owned, operator-provisioned, or fallback shared-secret?
- Which LARC workflows must work on day 1?

Default recommendation:

- use Mode A for developers
- use Mode B for managed internal devices
- keep Mode C only as an emergency fallback
- start with the smallest scope set that supports current LARC live paths
- expand only after a failed verification shows the gap

### Phase B — Create the custom app

Required actions:

- open the correct Developer Console
- create a custom app
- set a clear name such as `larc-dev` or `larc-test`
- enable Bot

Expected output:

- app shell exists
- `App ID` and `App Secret` are available only to the app owner or provisioning operator

### Phase C — Add minimum practical scopes

Use the scope set already documented in [docs/lark-app-setup.md](./lark-app-setup.md) as the current baseline.

Scope groups:

- Drive / docs
- Base
- IM
- Wiki
- Approval / task

Important rule:

- do not add speculative future scopes unless a real LARC workflow already depends on them

### Phase D — Publish and record evidence

Required actions:

- save scope changes
- publish the app
- capture publish timestamp and scope snapshot in a private operator note

Recommended evidence:

- app name
- app region
- publish date
- scope list
- operator name

### Phase E — Provision without broad secret sharing

Required actions:

- choose the provisioning path based on the auth mode

Mode A:

- the user keeps their own `App ID` and `App Secret`
- no cross-user secret handoff happens

Mode B:

- the operator performs `lark-cli config init` on the machine directly
- the user never receives the raw secret value

Mode C:

- if unavoidable, share through an approved secure channel
- rotate after the short test window ends

Required tester flow:

```bash
lark-cli config init --app-id <App ID> --app-secret-stdin --brand lark
lark-cli auth login
larc quickstart
```

### Phase F — Verify and close the loop

Minimum verification:

- `lark-cli auth login` completes
- `larc quickstart` completes
- at least one LARC live path is confirmed after setup

Examples:

- `larc bootstrap --agent main`
- `larc send "test message"`
- `larc task list`

If verification fails:

1. identify the exact failing command
2. identify whether the problem is credentials, region, scopes, or publish state
3. update the app scopes only if the failure proves a real gap
4. re-publish before retrying

---

## 7. Risks and Controls

| Risk | Impact | Control |
|---|---|---|
| Wrong region chosen | login/API flow fails | decide region in Phase A before app creation |
| Scopes added but app not re-published | testers see stale permissions | require publish check in Phase D |
| App Secret handed to many testers | credential sprawl | prefer Mode A or Mode B |
| Shared secret fallback is treated as normal | weak long-term auth hygiene | explicitly mark Mode C as temporary |
| Scope set becomes too broad | weak permission story | add only verified scopes for current workflows |
| App deleted during test window | all testers break | disable Bot later instead of deleting immediately |

---

## 8. Deliverables

- this plan: `docs/lark-dev-app-create-plan.md`
- operator guide: `docs/lark-app-setup.md`
- execution playbook: `playbook/lark-dev-app-create.yaml`

---

## 9. Exit Condition

The playbook can be considered complete when a new operator can:

1. read this plan
2. follow the playbook
3. choose the right auth mode
4. create and publish a Lark dev app
5. provision access without normalizing secret handoff
6. watch the tester finish `larc quickstart` without undocumented steps
