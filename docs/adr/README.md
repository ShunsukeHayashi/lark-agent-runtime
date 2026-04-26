# Architecture Decision Records

This directory contains Architecture Decision Records (ADRs) for Lark Harness.

An ADR captures a significant architectural decision, the context that drove it,
and the consequences of choosing it. Use ADRs when a choice will shape future
work and would be hard to reverse, or when the *non*-obvious option is the
right one.

## Numbering

- Filename: `NNNN-kebab-title.md` — four digits, monotonically assigned
- Once an ADR has a number, it is permanent. Superseded ADRs stay in the directory
  with `Status: Superseded by NNNN`. Do not delete.

## Status lifecycle

| Status | Meaning |
|---|---|
| `Proposed` | Drafted; awaiting review |
| `Approved` | Reviewed and accepted; implementation may proceed |
| `Rejected` | Reviewed and not accepted; kept for historical context |
| `Superseded by NNNN` | Replaced by a later ADR |

## Writing an ADR

1. Copy `template.md` to the next free number (e.g. `0002-foo.md`)
2. Fill in Context / Decision / Consequences
3. Open a PR with status `Proposed`
4. On review approval, update status to `Approved` in a follow-up commit

## Index

| # | Title | Status |
|---|---|---|
| 0001 | [Executor architecture](0001-executor-architecture.md) | Proposed |
