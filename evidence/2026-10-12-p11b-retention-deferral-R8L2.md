# P11b Avatar retention deferral recheck

Date: 2026-10-12

This recheck followed nine.md Section 14.2 after the staff-event P12a Gate 2. The repository was
at HEAD `ccceabd05d2e3a8f923ce398046f99d026a5b78e` with the existing dirty worktree preserved.
The tests used the run-owned disposable PostgreSQL manifest
`tmp/acceptance-isolated-20261010p8b-primary.json`, host `primary`, and four workers. No CI,
Podman, production service, external provider or shared/production database was used.

## Acceptance boundary

`RetentionPurgeJob` handles eligible Avatars through `AvatarPurgeDeferral.record!`. It locks the
candidate, preserves the Avatar and all ownership/moniker history, records a reason-scoped
`(avatar_id, reason_code)` row, and increments the observation count on repeated runs. An eligible
Avatar without concrete ownership history receives the explicit `retention_policy_pending` reason;
the absence of an ownership period never authorizes deletion. The table has a database-enforced
unique pair and positive attempt count, and the model updates the existing row under a lock.

The focused tests exercise ownership-history deferral, ownerless creation rejection before
retention, concurrent deferral convergence, moniker preservation, repeated execution, and the
retention job input boundaries. The adjacent dead-identifier concurrency and cross-database child
purge tests were also run to ensure this job boundary did not regress its neighboring retention
writers.

## Verification

Focused command:

```text
POSTGRESQL_TEST_PREPARE_DATABASES=<manifest databases> POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres RAILS_ENV=test PARALLEL_WORKERS=4 bundle exec rails test test/jobs/avatar_retention_purge_test.rb test/jobs/retention_purge_job_test.rb
```

Result: `21 runs, 89 assertions, 0 failures, 0 errors, 0 skips`.

Neighboring command:

```text
POSTGRESQL_TEST_PREPARE_DATABASES=<manifest databases> POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres RAILS_ENV=test PARALLEL_WORKERS=4 bundle exec rails test test/jobs/avatar_retention_purge_test.rb test/jobs/retention_purge_job_test.rb test/operations/dead_identifier_purge_concurrency_test.rb test/services/retention_cross_database_child_purge_test.rb
```

Result: `38 runs, 180 assertions, 0 failures, 0 errors, 0 skips`.

Targeted RuboCop inspected six affected job/model/test files and reported no offenses. The prior
current Gate 2 immediately before this recheck passed Rails `15148 runs, 128275 assertions, 0
failures, 0 errors, 0 skips` and Vitest `99 files, 1140 tests`; this recheck changed no runtime
code, so no additional full gate was required. This evidence does not decide the unresolved
personal-data retention duration or authorize physical Avatar/history deletion, and it does not
close P12b cutover/write-barrier work.
