# Passkey audit delivery metadata integrity

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had uncommitted changes affecting the application, tests and documentation.

The existing outbox writer rejects metadata that overrides `surface`, `external_id` or `actor_ref`, but delivery previously trusted those keys if they were already present in a stored row. A focused test simulated such a row by changing only test-transaction data. Before the fix, delivery accepted the forged actor reference instead of raising (1 run, 1 failure). An earlier probe using `update_columns` errored because the model marks metadata readonly; the test used a scoped `update_all` to simulate the already-corrupt database row instead.

The job now refuses non-object metadata and the three reserved keys before writing Chronicle. It leaves the invalid event unacknowledged, reports the failure, and continues to later events. The APP/ORG test covers a forged actor reference, later-event delivery and successful delivery after the test restores its own row. It does not prove that corrupt rows exist in any environment or exercise each reserved key independently.

With the configured local test environment, `PARALLEL_WORKERS=1 bin/rails test test/jobs/passkey_audit_delivery_job_test.rb test/operations/passkey_registration_operation_test.rb` passed (20 runs, 110 assertions). A later change to the test added only a blank line. RuboCop passed for the job and its test; `git diff --check` passed for those files and the updated runbook. The full suite and WU-A5 slot constraint were not verified. No existing audit data was migrated or repaired.

Follow-up: the focused test was expanded to exercise `surface`, `external_id` and `actor_ref` separately for APP and ORG, with a later valid event and a restored test row for each key. `PARALLEL_WORKERS=1 bin/rails test test/jobs/passkey_audit_delivery_job_test.rb -n /refuses_forged_authoritative_metadata/` passed (1 run, 36 assertions); RuboCop and `git diff --check` passed for the modified test file. No production behavior changed in this follow-up.
