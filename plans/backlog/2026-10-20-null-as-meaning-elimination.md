# Eliminate NULL as Meaning

Recorded 2026-10-20. Status: backlog, required, not started.

## Rule

`AGENTS.md` (Governing Principles and Constraints) forbids giving database NULL a meaning or
branching on NULL. The user made this absolute on 2026-10-20, and existing violations must be
resolved.

## Inventory on 2026-10-20

Static counts from `db/*_structure.sql`, `app/` and `lib/`. Each item still needs a case-by-case
review: a count is not a list of violations.

| Pattern                                                                                        | Count |
| ---------------------------------------------------------------------------------------------- | ----: |
| Nullable boolean columns (`ThreeStateBooleanChecker`)                                          |    15 |
| Nullable `*_at` timestamp columns, typically state markers such as `revoked_at`, `consumed_at` |   757 |
| Nullable columns in total                                                                      |  1969 |
| `IS NULL` / `IS NOT NULL` in Ruby code                                                         |    98 |
| `where(...: nil)` / `where.not(...: nil)` in Ruby code                                         |   147 |

Partial unique indexes such as `WHERE ended_at IS NULL` or `WHERE revoked_at IS NULL` also encode
state through NULL, and change together with their columns.

## Approach

1. Start with the 15 nullable booleans (`plans/backlog/2026-10-20-nullable-boolean-columns.md`).
2. For each state marker, introduce an explicit NOT NULL state (status reference table or enum),
   keep the timestamp as a fact, and move every reader and writer to the state column in the same
   change. Follow `generic/lifecycle-transition-writers.mdc` and update `docs/mermaid/` when a state
   axis changes.
3. Write characterization tests before each change, and accept only changes that keep observable
   behavior. Record each result in `evidence/`.
4. Backfills of existing rows are bulk updates of identity, security or audit state, and need
   explicit risk and recovery approval before they run.
