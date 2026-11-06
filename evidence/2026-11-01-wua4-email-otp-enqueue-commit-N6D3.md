# WU-A4 XDB-14 APP Email OTP enqueue boundary

Date: 2026-11-01

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had extensive pre-existing
uncommitted and untracked changes; 711 entries were present at the pre-evidence status check. No
commit was created.

The APP Email signup delivery issuer now rejects an ambient Source or Ticket writer transaction
before OTP issuance. The existing initial signup and OTP resend endpoints map this typed refusal to
their current 503 delivery-unavailable response. The refusal path does not issue an OTP or call the
notifier. At the queue callback, the queue-refusal test verifies that both writer transactions are
closed and a distinct PostgreSQL backend can observe the new OTP generation and committed Source
cooldown.

Verification:

- Focused Email/Telephone outer-transaction and queue-refusal cases in
  `test/operations/sign_up_otp_delivery_concurrency_test.rb`: 4 runs, 40 assertions, 0
  failures/errors/skips.
- Full `test/operations/sign_up_otp_delivery_concurrency_test.rb`: 16 runs, 164 assertions, 0
  failures/errors/skips.
- `test/integration/contact_email_signup_source_audit_test.rb --name '/anonymous email signup complete preserves its Source boundary/'`:
  1 run, 0 assertions, 1 error during fixture setup. PostgreSQL reported
  `client_authority_locks.client_id=980190963` missing from `clients`; the case body did not run. No
  cleanup was performed.
- Scoped RuboCop inspected seven changed Ruby files with no offenses. Ruby syntax checks for the
  Email delivery issuer and both Email controllers passed; `git diff --check` passed.

The first focused run exposed an assertion callback whose `self` was the stub job object. The test
now captures the test case explicitly; the focused and full concurrency-file runs passed afterward.

This verifies the issuer transaction boundary and queue-refusal state, not successful public HTTP
rendering of the typed refusal, real queue acceptance, SMTP delivery, or recipient receipt. No
migration, production/Neon operation, or full-suite run occurred.
