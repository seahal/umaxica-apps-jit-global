# evidence/ convention rollout

## What was being verified

That the newly added `evidence/` layout check works in this repository - that it passes on the
current tree, that it actually fails when the layout is wrong, and that adding it does not break any
check this repository already runs.

## Why

`evidence/` was introduced across this workspace as a flat, Git-tracked record of verification that
was actually performed. The structural rules (flat, `.md` only, `YYYY-MM-DD-<topic>.md`) are only
worth stating if something enforces them, so the check and this record were produced together. This
file is also the first record under the new convention, which means it is its own first test case:
the check has to accept this file's own name.

## Context

- Repository: `umaxica-apps-global`
- Revision at time of check: `926a2e596` (feature)
- Host: Linux, node v24.20.0, pnpm 12.2.1, ruby 4.0.6, cargo 1.98.0, bun 1.4.0
- Date: 2026-09-02

## What was added

- `test/tooling/evidence_layout_test.rb`
- Wired in via: no wiring needed - `bin/rails test` collects it, gated by the `test-rails` job in
  `.github/workflows/ci.yml`. A `evidence/` entry and its rules were also added to `docs/index.md`,
  which is where this repository defines what each documentation directory is for.
- An `Evidence` section in `AGENTS.md`, plus an `evidence/` entry in `docs/index.md`.

## Rules enforced

1. `evidence/` contains no subdirectories.
2. Every direct child is a regular file ending in `.md`.
3. Every filename matches
   `^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])-[a-z0-9]+(-[a-z0-9]+)*\.md$`.

A missing `evidence/` directory is deliberately not a failure, so the check is a no-op until the
directory exists.

## Commands run and what was observed

| Command                                                                                     | Observed                                                                                                                             |
| ------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `bin/rails test test/tooling/evidence_layout_test.rb`                                       | 3 runs, 6 assertions, 0 failures, 0 errors, 0 skips                                                                                  |
| `bundle exec rubocop --force-exclusion test/tooling/evidence_layout_test.rb`                | 1 file inspected, no offenses detected                                                                                               |
| `bin/rails test test/tooling/evidence_layout_test.rb` (with a deliberate violation fixture) | 3 runs, 6 assertions, 3 failures - reported ["subdir"], ["raw.log"] and ["2026-13-01-bad.md"] separately; fixture removed afterwards |

## Shared-logic verification

The same rule set exists in five forms across this workspace (Node script, POSIX shell, Vitest,
Minitest, Rust). Before distribution, the Node and shell forms were run against one fixture
directory containing every failure mode at once - a subdirectory, `notes.txt`, `report.pdf`,
`2026-9-2-x.md`, `2026-13-01-x.md`, `2026-09-32-x.md`, `Sep-02-2026-x.md`, `2026-09-02-Topic.md`,
`2026-09-02-.md`, `2026-09-02-a--b.md`, plus one valid record. Both reported exactly the same 10
violations and exited 1; both exited 0 on a valid-only directory and on a missing directory. The
Rust form pins the same accept/reject set in `record_name_rules_are_what_they_claim`.

## Assessment

PASS. The check passes on the current tree and every pre-existing check that could be run in this
environment still passes. No pre-existing behaviour was changed.

## Limitations

Written as a plain `Minitest::Test` reading the filesystem, following the precedent set by
`test/tooling/object_placement_test.rb`, so it runs without a database or the compose environment.
Rubocop initially reported 6 offenses; 5 were autocorrected and `Style/SelectByRegexp` was applied
by hand (`grep_v`). The negative case above is the evidence that the check actually fails when the
layout is wrong, rather than passing vacuously.

Nothing was committed; the change is left in the working tree. This record covers the layout check
only - whether any given evidence record is honest is not mechanically checkable and remains a
review question.
