# Email signup HTTP and deferred COM recovery

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`; uncommitted implementation changes affected the checks.

The independent implementation worker migrated all 24 original browser, OTP-Ticket-fault and
Source-before-Ticket recovery cases in `contact_email_signup_source_audit_test.rb` to actual
encrypted Notifier code handoff and typed transaction/generation proof. Assertions were retained.

`bin/rails test test/integration/contact_email_signup_source_audit_test.rb`:

- Seed 52454: 24/806, ten failures and ten errors. Actual OTP controllers had already promoted the
  Email verification status; the new final binding writer incorrectly required only pending status.
  It now permits the two explicit existing signup states while preserving original consumed proof,
  checkpoint, actor, browser, destination and candidate checks. No other status is admitted.
- Seed 21711: 24/927, ten COM failures, no errors. Test-local canonical recovery credential-kind
  reference rows were missing. Required `DEFAULTS` were added without changing assertions.
- Seed 51931: 24/1020, one failure, no errors/skips. COM `ticket_failure_retry` still loses the
  original `/identity/recovery-secret` distribution destination. Existing credential and reveal
  IDs remain unchanged. The unchanged top-up helper returns nil when no new values are issued.

The last failure is the previously user-deferred Non-Goal tracked in
`plans/backlog/com-recovery-distribution-interruption.md`, not a green gate. No change to COM
recovery distribution, its ten-secret quantity, or production data was made. This evidence retains
the observed failure for that next-cycle task; it does not remove or relax the test.

Email OTP controllers now use the named `mark_sign_up_verified!` model writer instead of direct
status-FK assignment. Its original live Parent/browser/owner/candidate and consumed bounded receipt
checks retain the existing verified-before-binding phase. Six model cases first failed for the
missing API (seed 43014); the combined model/timing/signin/resend/withdrawal check subsequently passed
38/260, seed 16888. Scoped lint on the independent Email binding concern, two OTP controllers and
its status-writer test passed after private-helper extraction. The actual HTTP matrix above includes
that integration and still reports the deferred recovery failure honestly.
