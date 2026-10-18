# P3d proof-retirement schema check and Gate 2 recheck

Date: 2026-10-12

Repository: `/home/global/workspace`

Branch: `feature`

Code HEAD: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`

The worktree was already dirty at the start of the recheck. Existing staged, unstaged and
untracked changes were preserved. No reset, clean, stash, worktree, push, production operation or
shared-database operation was performed.

## Reconciliation

The requested resume procedure was followed by rereading the current `nine.md` Sections 5.3, 16
and 14.2, then checking Git status, the current evidence and the run-owned PostgreSQL manifest.
The manifest was `tmp/acceptance-isolated-20261010p8b-primary.json`, using the primary host and
four test workers. A read-only catalog query found all 20 manifest databases owned by `root`, no
worker databases, and no active sessions after the preceding focused run. The test-run receipts
for workers 0 through 3 each reported `cleanup_completed: true` and 20 owned databases.

## Focused schema contract

The P3d proof-retirement contract was extended with a PostgreSQL schema assertion in
`test/models/otp_failure_retention_test.rb`. It checks the six concrete Email/Telephone identifier
tables for absence of `otp_private_key`, `otp_counter` and `otp_expires_at`, and checks the APP/COM
source tables for absence of `sign_up_otp_context` and `credential_registration_otp_context`.
The check is reached through the public model connection boundary and does not alter production
code or treat `ignored_columns` as physical removal.

Command:

```text
POSTGRESQL_TEST_PREPARE_DATABASES="<the 20 names from the manifest>" \
POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b \
POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json \
POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres RAILS_ENV=test PARALLEL_WORKERS=4 \
bundle exec rails test \
  test/models/otp_failure_retention_test.rb \
  test/models/signup_otp_proof_database_test.rb \
  test/models/credential_registration_otp_proof_database_test.rb
```

Observed result: `43 runs, 958 assertions, 0 failures, 0 errors, 0 skips`.

## Current Gate 2

The required full Rails command was then rerun against the same run-owned manifest with four
workers:

```text
POSTGRESQL_TEST_PREPARE_DATABASES="<the 20 names from the manifest>" \
POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b \
POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json \
POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres RAILS_ENV=test PARALLEL_WORKERS=4 \
bundle exec rails test
```

Observed result: `15149 runs, 128291 assertions, 0 failures, 0 errors, 0 skips` in 338.524
seconds. The worker receipts reported completed cleanup. A post-run read-only PostgreSQL query
reported zero remaining worker databases and zero active sessions for the manifest.

The Vitest full command was:

```text
bun run test
```

Observed result: `99 files passed, 1140 tests passed` in 12.91 seconds.

## Limits

This evidence establishes the current focused schema assertion and a current Rails/Vitest Gate 2
for the dirty disposable-test worktree. It does not close the remaining CONTACT-4/5 route and
legacy-proof inventory, the cross-database partial-failure campaign, D-11's complete committed
transaction/isolation matrix, P10b Group account semantics, P12b Avatar cutover/write barrier,
the remaining P12a semantic inventory, host Alloy runtime verification or privacy-retention
policy. It does not claim production/shared-data application. `db:verify_no_schema_drift` was not
rerun by this check; the previously classified intended uncommitted structure-dump drift remains
separate from this Gate 2 result.
