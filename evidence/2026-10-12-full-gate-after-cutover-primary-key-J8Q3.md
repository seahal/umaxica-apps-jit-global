# Full Rails gate after the Avatar cutover-key migration

## Scope

This record covers the implementation working tree at commit
`a1ec83a7384a424c97671356268ec5c4ad8347d4` on branch `feature`. The worktree had
pre-existing staged, unstaged, and untracked changes; they were preserved. No
production or shared database was modified.

## Environment

The run used the disposable PostgreSQL fleet identified by
`POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p3d2` and the manifest
`tmp/acceptance-isolated-20261010p3d2-primary.json`. The fleet was rebuilt only
after the database-safety script verified that all databases and roles were
owned by that run. `db:test:prepare` and `db:migrate` completed for the verified
fleet before the test run.

## Command and result

The full Rails command was run with `PARALLEL_WORKERS=4`, the isolated run ID
and manifest above, and the explicit list of the 20 disposable test databases:

```text
bundle exec rails test
```

Observed result:

```text
15062 runs, 127729 assertions, 1 failures, 0 errors, 0 skips
```

The sole failure was the existing `Security::AcmeRenameInventoryTest` check for
the unrelated untracked document
`adr/preference-tld-sharing-and-jwt-lifecycle-reassessment.md:30`, which still
contains the retired `Apex-scoped` terminology. This record does not treat that
failure as a new regression and does not modify that unrelated document.

The focused Avatar cutover and forbidden-pattern checks immediately before the
full run passed with 9 runs, 80 assertions, 0 failures, 0 errors, and 0 skips.
The migration was applied and rolled back on the same run-owned Avatar database,
and the schema dump contained the expected primary-key constraint afterward.

This evidence establishes the executed result for this tree; it does not certify
the complete nine.md implementation or replace the remaining identifier,
ownership-cutover, retention, and host-runtime verification obligations.
