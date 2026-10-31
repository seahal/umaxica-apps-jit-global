# Passkey registration owner binding

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had uncommitted changes affecting these results.
- A focused test initially failed because a new credential already assigned to a different owner was silently reassigned by the common registration operation. The operation now raises before mutation if the supplied new credential's owner differs from the actor.
- APP and ORG cases verify that a mismatched new credential remains unpersisted and unchanged, with no new source audit. Matching preassigned owners are accepted and audited. Existing blank-owner creation remains exercised by the operation and finalizer suites.
- `PARALLEL_WORKERS=1 bin/rails test test/operations/passkey_registration_operation_test.rb test/operations/identity_passkey_registration_committers_test.rb test/operations/identity_passkey_ceremony_final_committer_test.rb test/jobs/passkey_audit_delivery_job_test.rb test/security/invariants/passkey_registration_writer_invariant_test.rb`: 49 runs, 296 assertions, 0 failures, 0 errors. A later test-only line wrap was not rerun.
- RuboCop passed for the operation and test file after the line wrap; scoped `git diff --check` passed before that wrap. HTTP flows, direct database insertion, WU-A5 slot enforcement and the full suite remain outside this check.

## HTTP follow-up

- At the same HEAD with a dirty worktree, `PARALLEL_WORKERS=1 bin/rails test test/controllers/auth/app/up/checkpoint_passkeys_controller_test.rb test/controllers/auth/app/settings/passkeys_controller_test.rb test/controllers/auth/org/settings/passkeys_controller_test.rb` passed: 19 runs, 362 assertions, 0 failures, 0 errors.
- These controller files exercised the existing APP signup and APP/ORG settings paths. They do not prove every real-browser or provider path, direct database insertion, or WU-A5 slot enforcement.
