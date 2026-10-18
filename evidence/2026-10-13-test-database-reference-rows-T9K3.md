# Test database reference rows after a schema-only rebuild

## Revision and worktree

Performed against full commit `45ed455caa35c0efc2139c1969f541b5b3fc2242` on branch `feature`. The
worktree had uncommitted changes (the Step 5 Xper retirement and, from 10:54 UTC, a
`# frozen_string_literal: true` line added to 83 migration files). None of them were made by this
work; no repository file other than this record was changed. `one.md`, `two.md` and `.env` were not
edited.

## Symptom

A full `bin/rails test` run at 10:45-10:48 UTC reported `15188 runs, 118348 assertions, 50 failures,
796 errors, 0 skips`. `log/test.log` held 126 `ActiveRecord::InvalidForeignKey` lines across sign-in,
sign-out, session-limit and OIDC journeys.

## Cause

Read-only catalog queries against the local devcontainer PostgreSQL (`primary`, 10.89.0.3,
PostgreSQL 17.7) showed:

- `pg_postmaster_start_time()` was 10:37:18 UTC; every `test_*` and `development_*` database had
  been recreated at about 10:40 UTC (`ar_internal_metadata.created_at` 10:40:50 in
  `test_app_ticket_db`).
- No migration was pending in any base test database that has migration files, yet
  `client_sign_out_flow_kinds`, `client_sign_in_flow_states`,
  `client_session_limit_resolution_states` and `client_sign_up_flow_statuses` held 0 rows in
  `test_app_ticket_db`, in the worker clones `_0` and `_5`, and in `development_app_ticket_db`.
  `pg_stat_user_tables.n_tup_ins` was 0 for the three tables checked, so the rows were never inserted.
- `db/app_ticket_structure.sql` carries 130 `schema_migrations` versions. A structure load therefore
  marks data migrations such as
  `db/app_tickets_migrate/20261006160000_seed_app_sign_flow_reference_data.rb` as applied without
  replaying their inserts, as `docs/operations/db-workflow.md` describes.

The databases had been rebuilt by a structure load rather than by migrations. Which command did it
was not observed; `bin/dev` and `bin/setup` both call `bin/rails db:prepare`.

## Repair performed

All commands targeted `primary` only, after `pg_stat_activity` showed no session on any `test_*`
database.

1. Dropped all 646 databases matching `test\_%` (38 base and replica databases, 608 worker clones)
   with `drop database` generated from `pg_database` through `psql \gexec`. The 20
   `development_*` databases were left untouched.
2. `RAILS_ENV=test bin/rails db:create` created the 20 writer databases.
3. `db:test:prepare` first stopped in `DatabaseSafety.verify_catalog!` because the 18
   `test_*_replica_db` databases were absent; they were created empty with `create database`.
4. `RAILS_ENV=test POSTGRESQL_TEST_PREPARE_DATABASES=<the 20 names from .env.devcontainer.example>
   bin/rails db:test:prepare` exited 0 and ran the migration files against the empty databases. No
   `db/*_structure.sql` file changed.

`.env` lists only 7 names in `POSTGRESQL_TEST_PREPARE_DATABASES`, which
`DatabaseSafety.prepare_database_names!` rejects in this shell, so the full list was passed on the
command line for every command below.

## Results

- `test_app_ticket_db` row counts afterwards: `client_sign_out_flow_kinds` 4,
  `client_sign_in_flow_states` 14, `client_session_limit_resolution_states` 5,
  `client_sign_up_flow_statuses` 15.
- `bin/rails test test/integration/session_limit_promotion_flow_test.rb
  test/integration/oidc_initiated_sign_in_completion_test.rb
  test/integration/root_login_establishment_flow_test.rb`: `24 runs, 922 assertions, 0 failures,
  0 errors, 0 skips`.
- Full `bin/rails test`: `15188 runs, 127310 assertions, 6 failures, 29 errors, 0 skips`, with no
  `InvalidForeignKey` in the output.

## Remaining failures (not addressed)

- 14 errors, `RuntimeError: committed tests require run-owned worker receipts`
  (`ParallelTestDatabaseCloner.verify_owned_worker_execution!`) in the Avatar concurrency and
  ownership tests; they require the isolated fleet, which this run did not use.
- 13 errors, `KeyError: Missing required ENV key: PUBLIC_TECH_STAFF_URL` in
  `ConfigValuesHostFamilyValuesTest`.
- 1 error, `No route matches "http://auth.app.localhost/sign/in/device"` in
  `AuthSignCeremonyRouteContractTest`.
- 1 error, `visitor delegated to visitor_device_session, but visitor_device_session is nil`.
- 6 failures expecting 303 or 2XX and receiving 422, in the three `Base::*::SignOutsControllerTest`
  classes and neighbouring sign-out and cache-policy tests.

These were not diagnosed further.

## Not verified

- The `development_*` databases still have empty reference tables; they were not rebuilt.
- Nothing prevents the next structure-load rebuild from recreating the same state.
