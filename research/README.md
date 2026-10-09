# Research

Institutional memory that is not a source of truth: what was investigated, what was tried, what
failed, what was rejected and why, the constraints that applied at the time, and the conditions
under which a question is worth reopening.

`adr/` records the decisions that were accepted. This directory is the shadow history behind them.

## Standing

- Nothing here is normative. Do not implement from a research document.
- A document here may be stale, incomplete, superseded, internally inconsistent, or wrong. Finding
  one in that state creates no obligation to fix it.
- Re-verify any fact taken from here before a current decision depends on it.
- Unlike `evidence/`, research is not immutable. Correct, annotate, rewrite, reorganize or delete it
  when that is useful. Do not delete the record of a failed or rejected approach merely because it
  is old; that record is the reason this directory exists.

## What goes where

- `research/implementation/YYYY-MM-DD-<task-slug>.md` — decisions, deviations, compromises and
  handoff context discovered while carrying out a change. See
  `.agents/harnesses/rules/generic/implementation-notes.mdc`.
- `research/<topic>.md` or `research/YYYY-MM-DD-<topic>.md` — investigations, audits, shape
  proposals, comparisons and field notes.
- Research that belongs to one accepted change lives with it, in `specs/<feature>/research.md`.

`research/local/`, `research/private/` and `research/tmp/` are ignored by Git.

## Promotion

Content that stops being provisional moves out:

- an accepted decision → `adr/`
- proposed future work → `plans/backlog/`
- an accepted change → `specs/<feature>/`
- implemented, stable behavior → `docs/`

Write in English, per `docs/reference/repository-language-policy.md`.

This directory replaces the former `notes/`, `memos/` and `plans/analysis/`. Records under
`evidence/` that cite those paths are historical and are left as written.
