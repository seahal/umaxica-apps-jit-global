# Cross-database purge partial-failure and retry check

Date: 2026-10-12

Repository: `/home/global/workspace`

Branch: `feature`

Code HEAD: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`

The worktree was already dirty. Existing staged, unstaged and untracked changes were preserved;
no reset, clean, stash, worktree, push, production operation or shared-database operation was
performed.

## Scope

The P11a gap was the public cross-database purge failure/retry matrix. The existing
`RetentionCrossDatabaseChildPurge` service intentionally performs idempotent set-based deletion on
each child database in a defined order, without pretending that separate PostgreSQL databases
share a distributed transaction. The new tests inject a failure at the second child database
through the public service boundary for Client, Visitor and Operator actors. They then retry the
same purge and repeat it once more.

The expected contract is that the first child deletion remains committed when the second database
fails, the second child remains available for retry, the retry removes only that remaining child,
and a later retry is a no-op. No private method or production-only test hook is used.

## Focused verification

Command:

```text
POSTGRESQL_TEST_PREPARE_DATABASES="<the 20 names from the manifest>" \
POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b \
POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json \
POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres RAILS_ENV=test PARALLEL_WORKERS=4 \
bundle exec rails test \
  test/services/retention_cross_database_child_purge_test.rb \
  test/services/retention/cross_database_child_purge_test.rb
```

Observed result: `10 runs, 33 assertions, 0 failures, 0 errors, 0 skips`.

The targeted style check was:

```text
bundle exec rubocop \
  test/services/retention_cross_database_child_purge_test.rb \
  test/services/retention/cross_database_child_purge_test.rb
```

Observed result: two files inspected, no offenses detected.

## Shared-worktree Gate 2

Because the focused test files changed, the full Rails suite was rerun with the same four-worker
run-owned manifest. It completed `15152 runs, 128317 assertions, 0 failures, 0 errors, 0 skips` in
322.100 seconds. The four worker receipts initially left three `cleanup_completed` fields absent;
the post-run catalog showed zero worker databases and zero active sessions. The repository's
receipt-verified `ParallelTestDatabaseCloner.cleanup_isolated_worker_manifest!` helper was then
run for all four exact receipts, and each recorded `cleanup_completed: true` without dropping any
database (the catalog was already empty).

Vitest was rerun with `bun run test` and completed `99 files passed, 1140 tests passed` in 12.80
seconds. No CI, Podman, production service, external provider or shared/production database was
used.

## Limits

This closes the focused partial-failure/retry behavior for the three actor families in the
cross-database child-purge service. It does not claim a distributed transaction, close every
CONTACT-4/5 ceremony route, resolve personal-data retention policy, establish D-11's complete
committed-transaction isolation matrix, or close P10b/P12b, host Alloy runtime or remaining P12a
holds. It does not authorize real-data purge.
