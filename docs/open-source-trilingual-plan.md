# LARC Open Source Trilingual Plan

> Plan for taking this project from a private incubation repo to a China-facing open-source project with English, Chinese, and Japanese support.

---

## 1. Intent

The goal is not to open-source "everything as-is".

The goal is to turn LARC into:

- a China-facing open-source runtime story around Lark-native agents
- a repo that can be understood in English, Chinese, and Japanese
- a project whose permission-first design is legible to external contributors
- a credible reference implementation for office-work agent operations

For now, the repository can remain private.
This document defines what must be true before changing visibility.

---

## 2. Strategic Positioning

### Primary market

- Chinese Lark / Feishu developers
- teams exploring agent operations beyond coding workflows
- builders who care about approval, auditability, and tenant-level control

### Secondary markets

- English-speaking Lark / automation developers
- Japanese teams evaluating agent governance for back-office work

### Core message

Most agent tooling is strongest in code and local filesystems.
LARC is interesting because it treats Lark itself as the operating surface:

- Drive as disclosure-chain storage
- Base as memory and registry substrate
- IM as action and coordination surface
- Approval as execution control
- Wiki as knowledge and graph surface

---

## 3. Non-Goals

- do not open-source private tenant data, credentials, or internal operational secrets
- do not publish naming or wording that depends on third-party product branding
- do not claim full OpenClaw parity before the runtime proves it
- do not launch three languages with inconsistent meaning across docs

---

## 4. Readiness Gates Before Opening The Repo

### Gate A: Product clarity

- README clearly explains what LARC is, why Lark matters, and what problem it solves
- the repo distinguishes current truth, proven behavior, and future roadmap
- the permission-first wedge is visible within the first few sections

### Gate B: Technical clarity

- `larc auth suggest` is documented with representative cases
- bootstrap, memory, and send/task basics have reproducible checks
- command surface is aligned with real `lark-cli` behavior

### Gate C: Open-source hygiene

- repo contains no accidental internal names, tokens, or confidential paths
- historical asset names are neutralized or clearly marked as legacy/internal
- contribution guide, license, and support boundaries are present

### Gate D: Trilingual documentation baseline

- top-level docs have English, Chinese, and Japanese versions or mirrors
- terminology is normalized across all three languages
- one language is declared canonical for each document family

---

## 5. Recommended Language Policy

### Canonical authoring language

- English for source-of-truth technical docs and code-adjacent documentation

### Published mirrors

- Simplified Chinese for China-facing README, quickstart, and positioning docs
- Japanese for founder-context notes, strategy notes, and selected guides

### Rule

Do not maintain three divergent originals.
Maintain one canonical source and two maintained mirrors for public-facing documents.

Recommended mapping:

- `README.md` as English canonical
- `README.zh-CN.md` as Chinese mirror
- `README.ja.md` as Japanese mirror

The same pattern should apply to:

- quickstart
- permission model summary
- contribution guide
- architecture overview

---

## 6. Documentation Architecture

### Tier 1: Public entry docs

- `README.md`
- `README.zh-CN.md`
- `README.ja.md`
- `CONTRIBUTING.md`
- `CONTRIBUTING.zh-CN.md`
- `CONTRIBUTING.ja.md`
- `docs/terminology-glossary.md`
- `docs/terminology-glossary.zh-CN.md`
- `docs/terminology-glossary.ja.md`

Purpose:

- explain the project in under 5 minutes
- onboard developers from all three language groups

### Tier 2: Core technical docs

- architecture overview
- permission model
- approval model
- disclosure-chain model
- command alignment notes

Purpose:

- make design decisions legible
- help contributors reason about tradeoffs

### Tier 3: Internal incubation docs

- private playbooks
- asset intake notes
- founder-context strategy docs

Purpose:

- remain private until sanitized
- feed the public docs later

---

## 7. Workstreams For OSS Preparation

### Workstream 1: Open-source hygiene

Tasks:

- neutralize third-party product naming
- rename legacy assets where needed
- separate publishable docs from incubation docs
- add a preflight grep for sensitive strings before release

Done when:

- the repo can be screened quickly for naming, tenant, and credential issues

### Workstream 2: Trilingual public docs

Tasks:

- create trilingual README set
- create trilingual quickstart set
- create short trilingual explanation of permission-first design
- define a terminology glossary

Done when:

- a Chinese developer can understand the project without relying on English only

### Workstream 3: Contributor experience

Tasks:

- add issue templates
- add contribution rules
- define what is in scope for community contributions
- define what remains experimental

Done when:

- external contributors know how to participate without guessing

### Workstream 4: China-facing narrative

Tasks:

- position LARC against generic agent tooling
- explain why Lark is strategically different from plain API wrappers
- show approval, audit, and governance as first-class features
- prepare one or two demos that resonate with real office-work scenarios

Done when:

- the project story feels native to the China market, not translated after the fact

---

## 8. Recommended Release Sequence

### Phase 0: Private incubation

- keep repo private
- fix naming, scope docs, and command alignment
- turn current private docs into publishable raw material

### Phase 1: Public docs skeleton

- create trilingual README and quickstart
- add license, contribution guide, and governance boundaries
- add architecture overview and permission summary

### Phase 2: Public technical credibility

- publish reproducible checks for bootstrap, memory, and auth suggest
- publish representative permission cases
- publish known limitations and current truth

### Phase 3: China-facing launch

- publish Chinese README as a first-class document, not a translation afterthought
- prepare demo screenshots and use cases oriented to Feishu workflows
- coordinate announcement copy around permission-first office agents

### Phase 4: Community scaling

- accept external docs fixes and command-alignment contributions
- add multilingual issue labels
- publish a lightweight roadmap for community-safe areas

---

## 9. Immediate Backlog

1. Neutralize third-party product naming across public and semi-public docs.
2. Classify docs into public-ready vs incubation-only.
3. Create a trilingual terminology glossary for Lark, OpenClaw, approval, authority, and disclosure-chain language.
4. Draft `README.md`, `README.zh-CN.md`, and `README.ja.md` as a coordinated set.
5. Draft `CONTRIBUTING.md`, `CONTRIBUTING.zh-CN.md`, and `CONTRIBUTING.ja.md` as a coordinated set.
6. Add a release checklist for private-to-public transition.
7. Use that checklist as the hard gate before any visibility change.
8. Publish a dated release-readiness assessment before the first public opening.

---

## 10. Recommendation

The best path is:

1. keep the repository private for now
2. prepare it as if it will become public
3. make Chinese the strongest public-facing narrative
4. use English as the canonical technical authoring base
5. use Japanese as a maintained mirror and founder-context bridge

This keeps the current execution velocity while building toward a credible open-source launch.
