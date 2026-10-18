# Registration evidence and isolated database verification

- Date: 2026-10-03 UTC.
- Commit: `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`.
- The worktree contained authentication changes and another participant's unrelated uncommitted Rails, frontend, localization and Secret changes. No commit or external deployment was made.

Twenty task-owned disposable PostgreSQL copies were created from verified test writers using the existing isolated-test manifest mechanism. Catalog ownership, OID and comments are checked by the existing test safety guard. Run ID: `20261003auth6f3`; manifest: `tmp/auth-boundary-isolated-20261003auth6f3.json`. `PARALLEL_WORKERS=1` was used. Only the isolated APP principal and APP/COM/ORG ticket copies were selected for migration preparation. The user explicitly approved the concurrent Secret rebuild in `codex_integrity_20261003auth6f3_app_zenith`; it was applied there. Shared test, development and production databases were not rebuilt.

The generated actor-specific `Separate*RegistrationEvidenceFromStepUpCredential` migrations all applied successfully. Their verified registration branch requires a NULL existing-credential reference, no assurance claim, and false phishing-resistance flags. The normal branch requires the actual existing credential reference. Rollback requires draining verified registrations before restoring the old constraint; rollback was not run.

The initial combined operation/model/HTTP command stopped during global fixture loading: 20 runs, 0 assertions, 20 errors. The concurrent Secret migration removed `client_secret_credential_kinds` while its old fixture remains. This is a preparation failure, not an HTTP success result. The updated COM complete HTTP journey has not executed successfully.

Focused tests use Rails class-local fixture selection for data they own; global test setup and the concurrent Secret implementation remain unchanged. Command: `bin/rails test test/operations/identity_totp_enrollment_issuer_test.rb test/operations/identity_totp_enrollment_verification_committer_test.rb test/models/opaque_step_up_transaction_test.rb`, with the isolated run/manifest, the four named preparation databases and one worker. Final result: **17 runs, 294 assertions, 0 failures, 0 errors, 0 skips** (seed 53709).

Observed coverage includes encrypted server-side pending TOTP storage, repeated starts preserving identity/deadline, deadline microsecond boundaries, real initial code confirmation and replay rejection, durable fourth/fifth failures and subsequent refusal, title-length boundaries and code sentinels, cancellation/logout/refresh closing registration authority, six actor/purpose combinations rejecting DB mutations into ordinary assurance evidence, normal proof API rejection, and Base freshness rejection of an opaque registration result. No credential is created and no Base freshness is issued by enrollment confirmation.

RuboCop passed for the two enrollment operations, the step-up transaction concern, three targeted test files, and three constraint migrations: nine files, no offenses. These checks do not establish completion of controller connection, Base registration finalization, parallel races or the entire R01–R16 ledger. Browser verification remains user-owned. OTP logging remediation is excluded by the user and tracked separately. The APP Email primary JSON success contract remains held.
