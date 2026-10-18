# Coverage Batch 17

Date: 2026-07-04 UTC

This batch focused on unblocking the Rails test runner and then attempting the required coverage
pass. The non-coverage suite now passes in parallel mode. The coverage run, however, aborted late
with a new failure in `EmailDeliveryTest#test_deliver_later_enqueues_a_job_in_solid_queue`, so there
is no trustworthy end-of-batch Rails/VP coverage delta to report yet.

## Coverage Snapshot

- Starting Rails coverage: 90.51% (44,277 / 48,918 relevant lines) from `coverage/.resultset.json`.
- Ending Rails coverage: not finalized; `COVERAGE=true bin/rails test test/` aborted on a late test
  failure before a summary could be emitted.
- Starting VP coverage: not measured in this batch.
- Ending VP coverage: not run.

## Selected Targets

1. `test/support/parallel_test_database_cloner.rb`
2. `test/support/parallel_test_database_cloner_test.rb`

These were chosen to unblock `bin/rails test` in a fresh test database setup and to keep the change
small while verifying the replica-clone behavior directly.

## Tests Added

- Added two focused unit tests for `ParallelTestDatabaseCloner.ensure_replica_databases`:
  - creates a missing replica DB from its base DB
  - skips a replica DB that already matches its base DB

## App / DB Changes

- No `app/**` or `db/**` files were changed in this batch.
- The only code change was in `test/support/parallel_test_database_cloner.rb`.

## Dead-Code Evidence

- None. No code deletion was attempted in this batch.

## Commands Run

- `bin/rails test`
- `RAILS_ENV=test bin/rails db:prepare`
- `bin/rails test test/support/parallel_test_database_cloner_test.rb`
- `vp check --fix`
- `bundle exec rubocop -a test/support/parallel_test_database_cloner.rb test/support/parallel_test_database_cloner_test.rb`
- `COVERAGE=true bin/rails test test/`

## Skipped Risky Areas

- `config/**`, `bin/**`, routes, fixtures, factories, and dependency files were left untouched.
- VP config issues surfaced in `vp check --fix` (`src/entrypoints/inertia.tsx` /
  `@styles/application.css`) were not changed because they sit outside the allowed file set for this
  batch.
- Security-sensitive auth/session/OIDC flows were not modified.

## Next Batch Candidates

1. `app/presenters/base/com/identity/activity_log.rb`
2. `app/presenters/base/org/identity/activity_log.rb`
3. `app/controllers/concerns/preference_core.rb`
4. `app/services/sign_up_artifact_cleanup.rb`

The Rails coverage report still shows these as sizable uncovered areas with relatively deterministic
branches, which makes them better next-step candidates than the auth/session-heavy controllers.
