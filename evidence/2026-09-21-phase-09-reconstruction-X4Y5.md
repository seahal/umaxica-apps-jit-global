# Phase 09 test-database reconstruction verification

Date: 2026-09-21

## Safety boundary

The repository's configured PostgreSQL test target was verified before the reset. The operation
was limited to the isolated `test_*` databases on that target; no development, production, shared
database, credentials, or external service configuration was changed. No application server or
worker process was running before the reset.

## Migration and seed results

The following command completed successfully after the test-only target was verified:

```text
export UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
RAILS_ENV=test bin/rails db:migrate:reset
```

The post-reset `RAILS_ENV=test bin/rails db:version` check reported the expected current
migration version for all 20 configured test databases. The repository seed was then run twice:

```text
RAILS_ENV=test bin/rails db:seed
RAILS_ENV=test bin/rails db:seed
```

Both runs completed successfully. No seed code or data was changed during this verification.

## Structure dump results

`RAILS_ENV=test bin/rails db:schema:dump` was run twice after reconstruction. The SHA-256 hashes
of all generated `db/*_structure.sql` files were identical between runs, and a scan found no
business-data `INSERT` statements. The only insert statements represented schema migration
metadata.

The existing `db:verify_no_schema_drift` task still reports worktree drift because the repository
contains newly populated structure dumps in place of the former committed stubs. That non-zero
result is not treated as a clean-drift pass; the dumps still require the normal review/commit of
the approved reconstruction.

## Test results

The first focused test invocation exposed a missing explicit
`POSTGRESQL_TEST_PREPARE_DATABASES` setting in `.env.devcontainer.example`. The repository's
existing `config/ci.rb` scope was used without changing the environment file:

```text
POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db
```

Focused lifecycle tests before the semantic rename:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/models/concerns/retainable_test.rb \
  test/models/concerns/token_status_management_test.rb
```

Result: 36 runs, 133 assertions, 0 failures, 0 errors, 0 skips.

After the Retainable rename, the focused retention/token lifecycle set was expanded to include
refresh-token, flow, purge-job, withdrawal, sign-up-artifact, and all three token model tests:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/models/concerns/retainable_test.rb \
  test/models/concerns/token_status_management_test.rb \
  test/models/concerns/refresh_tokenable_test.rb \
  test/models/concerns/flow/base_test.rb \
  test/jobs/retention_purge_job_test.rb \
  test/services/withdrawal_lifecycle_test.rb \
  test/services/sign_up_artifact_cleanup_test.rb \
  test/models/client_token_test.rb \
  test/models/visitor_token_test.rb \
  test/models/operator_token_test.rb
```

Result: 177 runs, 624 assertions, 0 failures, 0 errors, 0 skips. A missing `discard_at` locale
key was found by the first run and corrected before the passing rerun.

Full Rails suite:

```text
bin/rails test
```

Result before the semantic rename: 11,437 runs, 73,131 assertions, 0 failures, 0 errors, 5 skips.

The full suite was rerun after the rename and locale/documentation updates:

```text
bin/rails test
```

Result: 11,438 runs, 73,139 assertions, 0 failures, 0 errors, 5 skips. Exit code was 0.

The five skips are reported by the suite and were not added or changed by this verification.

## Retainable semantic rename

The unreleased schema was reconstructed on the verified isolated test databases, then all
Retainable tables were renamed from `discarded_at` to `discard_at` and from `purged_at` to
`purge_eligible_at`. The migration is intentionally not presented as a live backward-compatible
production migration: the task explicitly permits reconstruction without old-data compatibility.
The migration uses `safety_assured` only for this authorized unreleased schema reconstruction after
strong_migrations correctly blocked a live-style column rename.

Rails metadata inspection after migration reported 58 registered Retainable models with no old
retention columns. The generated structure dumps were regenerated twice after the rename; their
SHA-256 hashes matched. The only remaining `purged_at` structure column is
`publishing_media_files.purged_at`, which is a separate non-Retainable publishing field and is
intentionally outside this rename.

## Writer database clock slice

The RED test `ApplicationRecordTest#test_database_now_reads_the_writer_database_clock` initially
failed because no database-clock accessor existed. `ApplicationRecord.database_now` now reads an
uncached `clock_timestamp()` through the model's writing pool and returns the adapter `Time`
value. `RetentionPurgeJob` obtains a clock value per owning model/database rather than sharing one
Ruby wall-clock value across databases, and sign-up artifact cleanup obtains a per-cycle-database
value unless an explicit decision-unit time is supplied by its caller.

Focused verification after this slice:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/models/application_record_test.rb \
  test/jobs/retention_purge_job_test.rb \
  test/jobs/retention_purge_legal_hold_test.rb \
  test/services/sign_up_artifact_cleanup_test.rb
```

Result: 33 runs, 126 assertions, 0 failures, 0 errors, 0 skips. Targeted RuboCop reported no
offenses for the four changed implementation/test files.

## Remaining Phase 09 work

The initial-schema reconstruction was then completed as a TDD slice. A new tooling assertion first
failed because four migrations loaded `db/initial_schemas/*.rb`. The schema bodies were moved into
the owning migrations using the standard migration DSL, the obsolete four files were removed, and
the initial foreign-key block uses the repository's explicit `safety_assured` exception because
these migrations run only while bootstrapping a clean database. The `force: :cascade` options from
the generated schema definitions were removed; the first conversion attempt correctly failed on
that Strong Migrations guard and was corrected before the successful reset.

After the corrected reset, the authority test passed with:

```text
74 runs, 329 assertions, 0 failures, 0 errors, 0 skips
```

The final full Rails suite was run after the reset and conversion:

```text
11,440 runs, 73,144 assertions, 0 failures, 0 errors, 5 skips
```

The five skips are existing suite skips; no skip was added by this slice. The generated structure
dumps were regenerated twice after the successful reset and matched byte-for-byte. No business-data
INSERT statements were present.

The follow-up writer-database-clock slice covered refresh-token rotation, device-session activity,
RP-session issue/rotate/revoke, OIDC connection touches, and refresh reuse. Its focused set passed
with 153 runs, 624 assertions, 0 failures, 0 errors, and 0 skips; the subsequent full suite passed
with 11,450 runs, 73,177 assertions, 0 failures, 0 errors, and 5 existing skips. See
`evidence/2026-09-21-database-clock-state-transitions-H8J9.md` for the lock/decision-time audit.

The follow-up database-clock state-transition slice is recorded in
`evidence/2026-09-21-database-clock-state-transitions-H8J9.md`. It covers Retainable scheduling/
discarding and token status transitions, including preservation of the selected writer-clock
`updated_at`.

The normal local review/commit of the generated schema artifacts also remains. This evidence does
not claim that every historical migration in every database path has been rewritten into a single
new migration; the approved initial loader paths are now direct migrations, while historical
migrations remain for reconstruction history and are still exercised by the clean reset.
