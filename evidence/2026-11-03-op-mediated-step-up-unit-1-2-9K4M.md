# OP mediated step-up: Unit 1 and Unit 2 recheck

Date: 2026-11-03

Commit: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`

The worktree had extensive uncommitted changes, including the OP mediated step-up work. This record
covers only the Unit 1 persistence and Unit 2 Chronicle audit boundaries; it does not certify the
full implementation.

## Test database inventory

Before the database-backed tests, a read-only recursive foreign-key inventory ran through
`RAILS_ENV=test bin/rails runner -` and was constrained to `test_app_zenith_db` on host `primary`.
It excluded fixture Client IDs and reported 7 fixture Clients, 0 non-fixture Clients, and 0 direct
or transitive target rows (`clients: 0`). Rows deleted: none. No database was reset or dropped, and
no development database, replica, worker clone, `leak_template_*` database, or fixture was touched.

## Verification

Command: `PARALLEL_WORKERS=1 bin/rails test` with the following test paths:

```text
test/models/client_step_up_audit_outbox_attempt_test.rb
test/models/client_step_up_audit_outbox_delivery_state_test.rb
test/models/client_step_up_audit_outbox_test.rb
test/models/client_step_up_commit_test.rb
test/models/client_step_up_context_state_test.rb
test/models/client_step_up_context_test.rb
test/models/client_step_up_context_transition_test.rb
test/models/operator_step_up_audit_outbox_attempt_test.rb
test/models/operator_step_up_audit_outbox_delivery_state_test.rb
test/models/operator_step_up_audit_outbox_test.rb
test/models/operator_step_up_commit_test.rb
test/models/operator_step_up_context_state_test.rb
test/models/operator_step_up_context_test.rb
test/models/operator_step_up_context_transition_test.rb
test/models/rp_step_up_audit_outbox_attempt_test.rb
test/models/rp_step_up_audit_outbox_delivery_state_test.rb
test/models/rp_step_up_audit_outbox_test.rb
test/models/rp_step_up_state_status_test.rb
test/models/rp_step_up_state_test.rb
test/models/rp_step_up_state_transition_test.rb
test/models/rp_base_org_step_up_audit_outbox_attempt_test.rb
test/models/rp_base_org_step_up_audit_outbox_delivery_state_test.rb
test/models/rp_base_org_step_up_audit_outbox_test.rb
test/models/rp_base_org_step_up_state_status_test.rb
test/models/rp_base_org_step_up_state_test.rb
test/models/rp_base_org_step_up_state_transition_test.rb
test/jobs/step_up_audit_delivery_job_test.rb
test/policies/chronicle_record_policy_test.rb
```

Result: 86 runs, 301 assertions, 0 failures, 0 errors, 0 skips.

Migration application and schema comparison were not rerun during this recheck. Their results are
recorded in the corresponding Unit 1 and Unit 2 entries in `zero.md`. The full suite and later units
remain unverified.

## Recheck on 2026-11-03

Commit: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree remained extensively uncommitted,
including in-progress Unit 3 changes.

Before the test run, a read-only recursive foreign-key inventory through
`RAILS_ENV=test bin/rails runner -` used `Client.lease_connection` and asserted host `primary` and
database `test_app_zenith_db`. It found 7 fixture Clients, 0 non-fixture Clients and 0 direct or
transitive target rows. Rows deleted: none. No database was reset or dropped; no development
database, replica, worker clone, `leak_template_*` database or fixture was touched.

Command: `PARALLEL_WORKERS=1 bin/rails test` with the 26 Unit 1 persistence model test paths listed
above, `test/jobs/step_up_audit_delivery_job_test.rb`, and
`test/policies/chronicle_record_policy_test.rb`.

Result: 86 runs, 301 assertions, 0 failures, 0 errors, 0 skips. The run emitted the existing
`nanoid` future frozen-string warnings. Ruby syntax and RuboCop passed for
`app/services/oidc_token_exchange_coordinator.rb`; these checks do not verify Unit 3 behavior. No
migration application or schema comparison was run in this recheck.

## Recheck on 2026-11-03 14:47 UTC

Commit: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree remained extensively uncommitted.

Before tests, a read-only recursive foreign-key inventory through
`RAILS_ENV=test bin/rails runner -` asserted host `primary` and database `test_app_zenith_db`. It
found 7 fixture Clients, 0 non-fixture Clients, and 0 direct or transitive dependent rows. Rows
deleted: none. No other database or fixture was touched.

Command: the same 26 Unit 1 persistence model test paths,
`test/jobs/step_up_audit_delivery_job_test.rb`, and `test/policies/chronicle_record_policy_test.rb`,
run with `PARALLEL_WORKERS=1 bin/rails test`.

Result: 86 runs, 301 assertions, 0 failures, 0 errors, 0 skips. Existing `nanoid` future
frozen-string warnings were emitted. Migration application and schema comparison were not rerun.

## Recheck on 2026-11-03 15:20 UTC

Commit: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree remained extensively uncommitted,
including later OP/RP work.

Before the database-backed run, a read-only recursive foreign-key inventory asserted host `primary`
and database `test_app_zenith_db`. It found 7 fixture Clients, 0 non-fixture Clients, and 0 direct
or transitive dependent rows. Target tables and deleted rows: none. No other database or fixture was
touched.

Command: `PARALLEL_WORKERS=1 bin/rails test` with the same 26 Unit 1 model test paths listed in the
initial verification section above, plus `test/jobs/step_up_audit_delivery_job_test.rb` and
`test/policies/chronicle_record_policy_test.rb`.

Result: 86 runs, 301 assertions, 0 failures, 0 errors, 0 skips. The job tests cover lost enqueue
recovery, repeated delivery, Chronicle commit with lost source acknowledgement, concurrent delivery,
explicit retention mapping, and all four OP/RP outbox sources. Existing `nanoid` future
frozen-string warnings were emitted. `git diff --check -- zero.md` passed, and a trailing-whitespace
scan of both files found none.

Migration application and schema comparison were not rerun. Their earlier results remain in the Unit
1 and Unit 2 entries of `zero.md`.

## Recheck on 2026-11-03 15:42 UTC

Commit: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree remained extensively uncommitted,
including later OP/RP implementation work.

Before the database-backed test run, a read-only fixture-aware inventory asserted host `primary` and
database `test_app_zenith_db`. It found 7 fixture Clients, 0 non-fixture Clients, and 0 directly or
transitively referencing rows. Target tables and rows deleted: none. No database was reset or
dropped; no fixture, development database, replica, worker clone, or `leak_template_*` database was
touched.

Command: `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test` with the same 26 Unit 1 persistence
model test paths listed above, `test/jobs/step_up_audit_delivery_job_test.rb`, and
`test/policies/chronicle_record_policy_test.rb`.

Result: 86 runs, 301 assertions, 0 failures, 0 errors, 0 skips. The run emitted existing `nanoid`
future frozen-string warnings. Migration application and schema comparison were not rerun; their
earlier results remain recorded in `zero.md`.

## Recheck after the 18:30 owner decisions

Date: 2026-11-03 15:54 UTC

Commit: efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8

The worktree had extensive uncommitted changes, including later OP/RP step-up work. This recheck
made no application or migration changes.

The owner-approved persistence migration versions were present in the four OP/RP test writer
databases and the four corresponding development writer databases. The Chronicle security retention
migration was present in test and development; the stored policy was duration 365 days and
non-permanent in both environments.

Immediately before the test run, the authorized read-only recursive FK inventory asserted host
primary and database test_app_zenith_db. It found 7 fixture Clients, 0 non-fixture Clients and 0
direct or transitive dependent rows. Tables and rows deleted: none. The initial inventory query
stopped at composite foreign keys without writing; the refined query handled composite-key tuples
and completed. No database was reset or dropped, and no development, replica, worker-clone,
leak_template_* database or fixture was cleaned or modified.

Command: RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test with the 26 unit 1 persistence model
files, test/jobs/step_up_audit_delivery_job_test.rb, and
test/policies/chronicle_record_policy_test.rb.

Result: 86 runs, 301 assertions, 0 failures, 0 errors, 0 skips. Existing nanoid future frozen-string
warnings appeared.

bundle exec rubocop passed on eight unit 2 files: the code registry, source registry, outbox writer,
delivery job, Chronicle policy, delivery job test, policy test, and security retention migration.
bin/jobs check reported valid Solid Queue configuration.

Migration/schema-dump comparison was not repeated in this recheck; prior results remain in the unit
records in zero.md. Later units and the full suite remain unverified.

## Recheck after the 18:30 owner decisions — 16:06 UTC

Commit: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had extensive uncommitted changes,
including later OP/RP step-up work.

Before verification, a read-only recursive foreign-key inventory was constrained to host `primary`,
database `test_app_zenith_db`. It found 7 fixture clients and 1 non-fixture client. The full target
set was `clients=1`, with no direct or transitive referencing rows in any other table. That
table/count was listed before deletion. The authorized cleanup deleted exactly that non-fixture
`clients` row. A second read-only inventory immediately before tests found 7 fixture clients, 0
non-fixture clients, and 0 direct/transitive target rows. No database was reset or dropped; no
development, replica, worker-clone, or `leak_template_*` database was cleaned, and fixtures were
unchanged.

Command: `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test` with the same 26 Unit 1 persistence
model test paths listed in the initial verification section above, plus
`test/jobs/step_up_audit_delivery_job_test.rb` and `test/policies/chronicle_record_policy_test.rb`.

Result: 86 runs, 301 assertions, 0 failures, 0 errors, 0 skips. Existing `nanoid` future
frozen-string warnings appeared. Migration application, schema comparison, and recurring-job
configuration were not rerun in this recheck; their prior results remain recorded in `zero.md`.

## Recheck after the 18:30 owner decisions — 17:20 UTC

Commit: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree remained extensively uncommitted.

The revision-8 persistence implementation was unchanged. The combined Unit 1 and Unit 2 run found
four errors in RP APP/ORG state tests because their test `public_id` strings were 20 characters
while the model requires exactly 21. Corrected the affected test inputs in
`test/models/rp_step_up_state_test.rb`, `test/models/rp_step_up_state_transition_test.rb`,
`test/models/rp_base_org_step_up_state_test.rb`, and
`test/models/rp_base_org_step_up_state_transition_test.rb`. No application or migration file
changed.

### Test database cleanup inventory

The fixture-aware recursive FK inventory was constrained to host `primary`, database
`test_app_zenith_db`. It found 7 fixture Clients, 0 non-fixture Clients, and 0 direct or transitive
target rows. Target tables and counts: none. Rows deleted: none. No test database was reset or
dropped, no fixture was changed, and no replica, worker clone, or `leak_template_*` database was
cleaned.

One initial inventory command omitted `RAILS_ENV=test`; it read the default connection's database
name and aborted before issuing table queries. A later repeat had a Ruby syntax error before
execution. Neither command wrote to a database. A corrected fixture-aware inventory then completed
against `test_app_zenith_db` before the first verification run. After correcting the four test
identifiers, the inventory was repeated successfully against that same asserted test database before
rerunning the suite; it again found 7 fixture Clients, 0 non-fixture Clients, and 0 recursive target
rows. No cleanup was needed. Separate read-only migration and retention queries connected to the
explicitly asserted test and development writer databases; they performed no writes.

### Verification

Command: `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test` with the 26 Unit 1 persistence model
files listed above, `test/jobs/step_up_audit_delivery_job_test.rb`, and
`test/policies/chronicle_record_policy_test.rb`.

The first run produced 86 runs, 297 assertions, 0 failures, 4 errors, and 0 skips. All four errors
were the invalid 20-character test IDs described above. The rerun after correction passed: 86 runs,
301 assertions, 0 failures, 0 errors, 0 skips. Existing `nanoid` future frozen-string warnings
appeared.

`bundle exec rubocop` passed on the eight Unit 2 files (code catalog, source registry, outbox
writer, delivery job, Chronicle policy, delivery and policy tests, and security retention migration)
and on the four corrected RP state test files. `bin/jobs check` reported valid Solid Queue
configuration.

Read-only migration verification found the required Unit 1 create/seed/constrain/validate migrations
in all four OP/RP writer databases for both test and development. The Unit 2 security retention
migration was present in test and development Chronicle. The stored `security` row was
`duration_days=365, permanent=false` in both. No migration was applied during this recheck.

The owner's cleanup authorization was used only for the main test database inventory; it found no
rows requiring deletion. The non-test DB queries above were read-only verification only. Units 1 and
2 are complete against accepted revision 8 for the checks listed here. This evidence does not
certify later units or the full implementation.

## Recheck after the 18:30 owner decisions — 17:51 UTC

Commit: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree remained extensively uncommitted,
including later OP/RP step-up work. This recheck changed no application or migration file.

### Test database cleanup

The owner-authorized recursive FK inventory asserted host `primary` and database
`test_app_zenith_db`. Before cleanup it found 7 fixture Clients and 1 non-fixture Client. The
complete target set was `clients=1`; no direct or transitive rows in child tables referenced that
Client. The listed target row count was one, and exactly that non-fixture `clients` row was deleted.
No row values were output or recorded. Immediately before each test run, a read-only inventory again
found 7 fixture Clients, 0 non-fixture Clients, and 0 recursive target rows. No reset or drop was
run; no fixture, development database, replica, worker clone, or `leak_template_*` database was
touched.

### Unit 1

Command: `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test` with the 26 Unit 1 persistence model
test files listed in the initial verification section above.

Result: 54 runs, 172 assertions, 0 failures, 0 errors, 0 skips. Existing `nanoid` future
frozen-string warnings appeared. The test set covers the owner-approved closed persistence
vocabularies, including the RP `dispatch_started` transition. Migration application and schema-dump
comparison were not repeated; prior results are in `zero.md`.

### Unit 2

Command:
`RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/jobs/step_up_audit_delivery_job_test.rb test/models/client_step_up_audit_outbox_test.rb test/models/client_step_up_audit_outbox_attempt_test.rb test/policies/chronicle_record_policy_test.rb`.

Result: 39 runs, 156 assertions, 0 failures, 0 errors, 0 skips. Existing `nanoid` future
frozen-string warnings appeared. `bundle exec rubocop` passed on 59 Unit 1/2 implementation and test
files; `bin/jobs check` reported valid Solid Queue configuration. Migration application and the
stored Chronicle retention row were not re-queried; prior results are in `zero.md`.

This record covers the Unit 1/2 recheck only. Unit 3–7 behavior and full-suite acceptance remain
unverified by this record.
