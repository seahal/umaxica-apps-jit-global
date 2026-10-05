# Email OTP availability and Cookie support retirement

- Date: 2026-10-04 UTC.
- Commit: `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`.
- Worktree: uncommitted authentication changes and unrelated concurrent work.
- Database: owned isolated run `20261003auth6f3`, manifest
  `tmp/auth-boundary-isolated-20261003auth6f3.json`; APP ticket preparation, one worker.

The unused SignEmailOtpVerificationSupport concern and its COM inclusion-only harness test were
removed after confirming zero production consumers. Server challenge, issuer, verifier, admission
and independent-connection tests passed **23 runs / 264 assertions**, seed 3950. Other legacy
surface concerns and their tests remain pending deliberate coverage migration.

StepUpAvailableMethods now excludes Email OTP when every eligible verified email is currently
locked or discarded, using the principal writer clock and credential state. Configured methods
remain separate, and credential history still prevents bootstrap. This removes the active method
policy's dependency on the empty cache cooldown query. Issuance throttling remains owned by the
DB-backed issuer; a resend cooldown does not hide an existing verifiable code. Passkey/TOTP
availability and the existing ticket attempt cutoff are preserved. No new ordinary-request
callback, schema or public payload was added.

The corrected boundary tests failed against the previous availability policy on APP and COM
at one microsecond before lock expiry: **6 runs / 16 assertions, 2 failures**, seed 19994.
At expiry and after expiry the method is available. Exact
Rational microsecond offsets avoid Float-to-database timestamp truncation; an initial Float-based
test construction had not preserved the intended neighboring timestamp and was corrected.

The final command passed **34 runs, 207 assertions, no failures/errors/skips**, seed 62361:
`bin/rails test test/policies/step_up_email_availability_test.rb
test/services/step_up/available_methods_test.rb test/controllers/auth/step_up_admission_test.rb
test/operations/identity_step_up_email_verification_committer_test.rb`.
RuboCop inspected the changed policy and new policy test: no offenses. `git diff --check` passed.

These tests establish policy classification and the existing
admission/verifier regressions, not physical replica behavior or genuine root-login establishment.
The writer availability check is advisory; verification and issuance retain their locked writer
checks. Credential-management admission, remaining legacy paths and other full-ledger work remain
incomplete. OTP logging remediation is excluded; browser verification is user-owned.
