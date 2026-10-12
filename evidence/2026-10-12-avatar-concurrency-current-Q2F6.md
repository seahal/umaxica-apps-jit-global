# Avatar ownership concurrency current check

Date: 2026-10-12

This check followed nine.md Section 14.2 after the P11b recheck. It used the existing run-owned
PostgreSQL manifest `tmp/acceptance-isolated-20261010p8b-primary.json`, host `primary`, and four
Rails workers. The worktree was dirty at HEAD `ccceabd05d2e3a8f923ce398046f99d026a5b78e`; existing
changes were preserved. No shared/production database, CI, Podman or external service was used.

The selected public/direct-SQL collection covered concrete ownership period exclusion and history
preservation, Avatar creation ownership enforcement, transfer registry concurrency, trigger
inventory and independent PostgreSQL backend behavior at the relevant isolation levels.

Command:

```text
POSTGRESQL_TEST_PREPARE_DATABASES=<manifest databases> POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres RAILS_ENV=test PARALLEL_WORKERS=4 bundle exec rails test test/models/avatar_concrete_ownership_period_test.rb test/operations/avatar_ownership_transfers_concurrency_test.rb test/models/enforcement_triggers_test.rb
```

Result: `28 runs, 101 assertions, 0 failures, 0 errors, 0 skips`.

This current focused result supports the isolated ownership/trigger concurrency subconditions. It
does not establish the full Avatar transfer and consumer cutover acceptance, writer quiescence,
Group semantics, or production/shared-data application. The P12b marker remains unestablished.
