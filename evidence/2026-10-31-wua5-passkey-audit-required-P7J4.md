# Passkey registration audit requirement

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting application code, documentation and tests.

Before the change, `PasskeyRegistrationOperation.call!` accepted `audit: nil` and could commit a credential without its principal-side audit outbox row. A focused new test reproduced that gap (1 run, 1 assertion, 1 failure). The four source call sites inspected already supply audit data. The operation now requires an audit argument, refuses a non-Hash value, and always writes the existing outbox event within the credential transaction. A missing event field raises and rolls back the credential. Existing tests that directly invoked the operation were updated to supply audit data; the nontransactional concurrency test cleans up the audit rows created by its own actors.

With the configured local test environment:

- `PARALLEL_WORKERS=1 bin/rails test test/operations/passkey_registration_operation_test.rb test/models/client_passkey_test.rb test/models/operator_passkey_test.rb test/jobs/passkey_audit_delivery_job_test.rb` passed: 44 runs, 176 assertions.
- The independent-writers slot race case passed: 1 run, 6 assertions.
- `PARALLEL_WORKERS=1 bin/rails test test/operations/passkey_registration_operation_concurrency_test.rb test/operations/identity_passkey_registration_committers_test.rb test/operations/identity_passkey_ceremony_final_committer_test.rb` passed: 26 runs, 125 assertions.
- RuboCop passed for the operation, its test, both Passkey model tests and the audit-delivery job test. Including `test/models/auth_ceremony_revocation_concurrency_test.rb` reported six offenses on lines outside this change; those unrelated lines were not altered. `git diff --check` passed for all changed files.

The runbook now reflects the ten-row operation limit, the existing outbox and retired COM authentication. This change does not implement the WU-A5 database slot constraint, cover direct database inserts, prove all cross-database failure windows, or run the full suite.
