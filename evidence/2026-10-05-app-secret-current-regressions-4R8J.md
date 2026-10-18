# App Secret current-source regressions

Observed on 2026-10-05 UTC against HEAD
`e8f2371bc5cbefd2087c728aeeef4e318463d33f`, with uncommitted Secret changes
and unrelated concurrent changes present. Verification used the guarded runner
`/tmp/umaxica-secret-recovery-db-task.rb` and task-owned disposable PostgreSQL
databases identified by `20261005recovery`. No shared database was applied.

Each command below starts with
`bundle exec ruby /tmp/umaxica-secret-recovery-db-task.rb test`.

- `test/jobs/client_secret_audit_outbox_purge_job_test.rb test/operations/client_secret_audit_outbox_purger_test.rb test/operations/client_secret_completed_issuance_purger_test.rb test/jobs/client_secret_audit_delivery_job_test.rb test/integration/oidc_initiated_sign_in_completion_test.rb`:
  seed 25416, 31 runs, 331 assertions, no failures, errors, or skips; 25.427 seconds.
- `test/integration/root_login_establishment_flow_test.rb test/controllers/concerns/auth/session_issuance_boundary_surfaces_test.rb test/integration/app_passkey_secret_session_step_up_test.rb test/integration/app_secret_signup_journey_test.rb test/operations/client_secret_claim_concurrency_test.rb test/operations/client_secret_resolution_concurrency_test.rb test/operations/client_secret_manual_reservation_concurrency_test.rb test/operations/client_secret_storage_confirmation_concurrency_test.rb test/integration/org_root_login_establishment_test.rb`:
  seed 1892, 73 runs, 1661 assertions, no failures, errors, or skips; 17.158 seconds.
- `test/controllers/auth/route_naming_test.rb test/integration/routes/auth_sign_ceremony_route_contract_test.rb test/integration/app_secret_login_journey_test.rb test/services/recovery_passcode_top_up_test.rb test/unit/security/org_emergency_access_invariants_test.rb test/controllers/auth/org/verification/emergency_step_up_prohibition_test.rb`:
  seed 16951, 64 runs, 1354 assertions, no failures, errors, or skips; 9.763 seconds.

The initial outbox group had 19 runs and 140 assertions, with two failures
(seed 36197). Earlier standalone runtime audit rows occupied bounded scan slots;
the tests ran only the first queued continuation. The tests now execute the full
public Active Job continuation chain without deleting existing audit rows or
changing the collection expectations. A focused retry passed with seed 30334,
2 runs and 10 assertions. RuboCop passed for the two changed outbox test files.

The older Rails lock owner terminated before these fresh processes began.
Previously waiting processes had loaded earlier file versions: their results
are distinct from these current-source runs and do not establish completion.

These results cover the named HTTP, session, audit, collection, concurrency,
and surface regression tests. They do not establish the complete concurrency
matrix, browser Secret root-login journey, confirmed positive-allocation
collection, bounded replay-barrier retirement, or fresh-build and legacy-table
DDL reconstruction. Operational retention values remain proposals requiring
approval; shared database application remains separate and unauthorized.

Additional current-state commands:

- `bundle exec ruby /tmp/umaxica-secret-recovery-db-task.rb routes --grep sign_in_secret`
  exited 0. It reported `new_auth_app_sign_in_secret` GET
  `/sign/in/secret/new` and `auth_app_sign_in_secret` POST `/sign/in/secret`,
  both targeting `auth/app/sign/in/secrets`.
- `bundle exec ruby /tmp/umaxica-secret-recovery-db-task.rb db:verify_no_schema_drift`
  exited 1, reporting modified `db/app_ticket_structure.sql`,
  `db/app_zenith_structure.sql`, `db/com_ticket_structure.sql`, and
  `db/org_ticket_structure.sql`. This is a failed verification, not proof of
  migration completion. These files were already modified at the beginning of
  this continuation; their provenance and intended contents require inspection.

Confirmed positive-allocation increment:

- A new public-operation test initially failed with `NoMethodError` for
  `call_confirmed!` (seed 33890, 1 run, 0 assertions, 1 error).
- After adding that entry and sharing the existing bound-authority lock path,
  `bundle exec ruby /tmp/umaxica-secret-recovery-db-task.rb test test/operations/client_secret_completed_issuance_purger_test.rb`
  passed: seed 37802, 6 runs, 31 assertions, no failures, errors, or skips;
  5.800 seconds. The new test proves existing credentials prevent allocation
  deletion. It does not prove successful confirmed-allocation collection.
- Inspection of all four structure-file diffs found one CHECK-expression
  serialization change per file, casting each array element to text instead of
  casting the array to text[]. No table or column change appears in these diffs.
  The schema-drift command nevertheless remains failed; no hand edits or commits
  were used to hide its result.
- The first static check reported eight offenses in the new operation. Audit
  selection was separated from collection orchestration without changing guards
  or thresholds. The same six tests passed afterward (seed 17485, 31 assertions,
  5.783 seconds). `bundle exec rubocop app/operations/client_secret_issuance_purger.rb test/operations/client_secret_completed_issuance_purger_test.rb`
  then passed with two files inspected and no offenses.

The next confirmed-allocation test uses the actual public manual reservation,
presentation, confirmation, management revocation, delivery job and credential
purger. It initially failed (seed 33243, 1 run, 2 assertions): collection returned
`purged` before the credential's purge audit was delivered. The collector now
requires durable Chronicle `secret.purged` facts for every created credential,
including matching nonsecret Client and credential references. The targeted
retry passed (seed 17087, 1 run, 9 assertions).

The periodic lifecycle now invokes confirmed-allocation collection after receipt
reconciliation. The first four-file regression run found three missing explicit
proof-retention configurations (seed 13128, 21 runs, 133 assertions, 3 errors).
The affected lifecycle tests now provide and restore an explicit setting instead
of introducing a production default. The subsequent command
`bundle exec ruby /tmp/umaxica-secret-recovery-db-task.rb test test/operations/client_secret_completed_issuance_purger_test.rb test/jobs/client_secret_audit_delivery_job_test.rb test/operations/client_secret_audit_outbox_purger_test.rb test/jobs/client_secret_audit_outbox_purge_job_test.rb`
passed with seed 4553, 21 runs, 155 assertions, no failures, errors, or skips,
in 13.589 seconds. The positive-allocation test executes the real lifecycle job
for deletion and verifies its surviving undelivered purge outbox and retained
original token record. It does not establish signup/Passkey collection or all
proof-retention boundaries and races.

`bundle exec rubocop app/jobs/client_secret_lifecycle_job.rb app/operations/client_secret_issuance_purger.rb test/operations/client_secret_completed_issuance_purger_test.rb test/jobs/client_secret_audit_delivery_job_test.rb test/operations/client_secret_audit_outbox_purger_test.rb`
passed with five files inspected and no offenses. Operational proof retention
remains mandatory and unapproved; no shared database application occurred.
