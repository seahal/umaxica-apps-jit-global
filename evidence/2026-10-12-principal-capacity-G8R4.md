# App and Com principal public-ID capacity slice

Date: 2026-10-12

Repository: `/home/global/workspace`

Branch: `feature`

Code HEAD: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`

The worktree was already dirty and all existing staged, unstaged and untracked changes were
preserved. No reset, clean, stash, worktree, push, production operation or shared-database
operation was performed.

## Red and Green

The slice covers the clearly owned principal identities `app_zenith.clients.public_id` and
`com_zenith.visitors.public_id`. The existing model contracts issue NanoID-21 values, but the
catalog had no database capacity checks. After adding the two targets to the public contract test,
the pre-migration run failed as expected:

```text
5 runs, 14 assertions, 2 failures, 0 errors, 0 skips
```

The implementation adds four migrations:

- `db/app_principals_migrate/20261012091000_add_client_public_id_capacity_check.rb`
- `db/app_principals_migrate/20261012091001_validate_client_public_id_capacity_check.rb`
- `db/com_principals_migrate/20261012091000_add_visitor_public_id_capacity_check.rb`
- `db/com_principals_migrate/20261012091001_validate_visitor_public_id_capacity_check.rb`

Each pair adds a named `NOT VALID` `char_length(public_id) <= 25` check and validates it in a
separate migration. The direct SQL contract rejects a 26-character update in a savepoint and
preserves the original row. The focused command included the new contract plus the existing Client
and Visitor model suites and passed:

```text
111 runs, 220 assertions, 0 failures, 0 errors, 0 skips
```

All four migrations were reversed and reapplied in the run-owned app/com databases, and both
structure dumps were regenerated. The ORG 16-character human code and all other unbounded
identifier candidates remain outside this slice.

This record proves only the two disposable-schema checks. It does not claim all-table capacity,
real/shared data application, global narrowing, or production readiness.

## Gate 2 after the slice

After the focused Green result, the full Rails suite ran with four workers against all twenty
run-owned databases and completed with:

```text
15101 runs, 128126 assertions, 0 failures, 0 errors, 0 skips
```

All four worker receipts recorded completed cleanup. `bun run test` completed with `99 files
passed` and `1140 tests passed`. These results are current disposable-environment evidence for the
worktree and do not close the remaining unbounded identifier inventory, final staff-event cutover,
production/shared data application or unrelated phase acceptance.
