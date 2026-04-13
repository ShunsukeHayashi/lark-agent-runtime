# Contributing to LARC

English | [简体中文](CONTRIBUTING.zh-CN.md) | [日本語](CONTRIBUTING.ja.md)

---

## Scope

LARC is still an incubation-stage project.

Contributions are welcome, but the safest areas right now are:

- documentation improvements
- command-alignment fixes against real `lark-cli` behavior
- permission-model clarity improvements
- `auth suggest` regression cases
- non-destructive test and verification helpers

Please avoid assuming that every planned feature is already stable.

---

## Before you contribute

Please read these first:

- [README.md](README.md)
- [PLAYBOOK.md](PLAYBOOK.md)
- [docs/goal-aligned-playbook.md](docs/goal-aligned-playbook.md)
- [docs/permission-model.md](docs/permission-model.md)
- [docs/open-source-trilingual-plan.md](docs/open-source-trilingual-plan.md)

If your change affects permission logic, also read:

- [docs/auth-suggest-cases.md](docs/auth-suggest-cases.md)

---

## Good first contribution areas

### 1. Documentation

- clarify terminology
- improve examples
- fix inconsistencies across English, Chinese, and Japanese docs

### 2. Command alignment

- verify that shell wrappers match actual `lark-cli` behavior
- improve error messages when a command shape is wrong

### 3. Permission intelligence

- add realistic office-task examples
- reduce over-broad scope inference
- improve authority explanations

### 4. Verification tooling

- extend regression checks
- add non-destructive smoke tests

---

## Contribution boundaries

Please do not send changes that:

- expose tenant-specific secrets, IDs, or credentials
- assume private internal assets are public API
- add destructive automation by default
- change the project story away from Lark-native office-work agents

For now, major architectural changes should start as an issue or design note first.

---

## Documentation policy

The project is moving toward trilingual public documentation.

- English is the canonical authoring language for public technical docs
- Simplified Chinese is the primary public market mirror
- Japanese is a maintained mirror and strategy bridge

Please keep meaning aligned across languages.
Do not introduce three conflicting versions of the same concept.

---

## Pull request guidance

Prefer small, focused pull requests.

Good PRs usually:

- explain the problem clearly
- reference the relevant playbook or design doc
- describe user-facing impact
- mention what was verified

If tests were not run, say so explicitly.

---

## Suggested contribution flow

1. Open an issue or note the target doc/area.
2. Keep the change small and scoped.
3. Verify the relevant command or document path.
4. Update docs if behavior changed.
5. Explain any remaining risk or limitation in the PR.

---

## High-value open areas

- improve `auth suggest` minimum-scope precision
- strengthen approval modeling
- improve disclosure-chain realism on top of Lark Drive
- help prepare the repo for a China-facing open-source launch

---

## Questions

If the change is large or changes the product direction, start with a design discussion instead of a direct implementation PR.
