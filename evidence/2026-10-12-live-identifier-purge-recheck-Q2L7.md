# Live identifier and dead-history focused recheck

Date: 2026-10-12

Repository: `/home/global/workspace`

Branch: `feature`

Code HEAD: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`

The worktree was already dirty; existing staged, unstaged and untracked changes were preserved.
No reset, clean, stash, worktree, push, production operation or shared-database operation was
performed. The test used the run-owned disposable PostgreSQL manifest
`tmp/acceptance-isolated-20261010p8b-primary.json` with four workers.

The focused command was:

```text
POSTGRESQL_TEST_PREPARE_DATABASES="<manifest database names>" \
RAILS_ENV=test PARALLEL_WORKERS=4 \
POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b \
POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json \
POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres \
bundle exec rails test \
  test/models/live_identifier_namespace_test.rb \
  test/models/live_identifier_creation_concurrency_test.rb \
  test/operations/dead_identifier_purge_test.rb \
  test/operations/dead_identifier_purge_concurrency_test.rb
```

Observed result:

```text
68 runs, 437 assertions, 0 failures, 0 errors, 0 skips
```

The result covers normalized APP/COM/ORG Email and Telephone live-namespace checks, database
uniqueness boundaries, conflict-transaction reuse, irreversible purge/history creation, future
reuse, legal-retention refusal, repeated purge, and concurrent create/purge behavior. It is current
focused evidence only; it does not close the remaining OTP proof-retirement work, the P12a staff
event final PK/FK cutover, D-11 isolation-level coverage, Avatar P10b/P12b, host Alloy runtime
checks or privacy-retention decisions.
