# Scoped TOTP, email delivery and credential-change revocation

Verified on 2026-10-03 against commit
`f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`, with uncommitted implementation and
test changes in the shared worktree. Another workspace participant advanced HEAD during this
continuation; this record covers the final combined run on the stated commit.

`bin/rails test test/controllers/auth/step_up_admission_test.rb test/operations/identity_step_up_totp_verification_committer_test.rb test/consumers/totp_window_consumer_test.rb test/operations/identity_step_up_email_delivery_recorder_test.rb test/services/credential_security_transition_test.rb test/operations/identity_step_up_ceremony_cancellation_committer_test.rb test/unit/security/public_entrypoint_inventory_test.rb`
passed: **32 tests, 275 assertions, zero failures, errors or skips**.

The tests exercised APP scoped admission and actual TOTP verification without Auth root
credentials; credential replay and ownership checks; encrypted Noticed job execution through the
existing APP mailer and test delivery adapter; delivered-code verification; suspension rejection;
and credential changes closing pending transactions and admitted Auth continuity while retaining
the current root session. Turnstile and Jump are stubbed in HTTP tests. Delivery used the test
adapter, not an external SMTP service. No browser or production log verification was performed.

Targeted RuboCop passed for nine changed consumer, controller, operation, service and test files.
The new revocation test first failed because the pending transaction remained pending; it passed
after connecting revocation to the existing authoritative transaction and ceremony rows.

OTP observability remediation remains excluded from this implementation at the user's direction
and tracked in its accepted ADR and active plan. These results do not establish completion of
R01–R16 or replace the previously failing full-suite result. Enrollment, credential management,
logout/refresh lifecycle integration, legacy-path retirement and broader regression checks remain.
