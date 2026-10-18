# OTP email enqueue audit

- Date: 2026-09-21 UTC
- Scope: the legacy OTP mailer adapter and the Noticed rollout adapter
- External provider access: none
- Secrets: no OTP, recipient address, token, or message body was logged or persisted in the audit metadata

## Finding and TDD

The two adapter paths scheduled email successfully but did not record the enqueue fact in the
durable Chronicle boundary. The regression tests were added first and failed with two missing
`notification.delivery.email.enqueued` rows. The initial failure also showed that the focused test
had not prepared the existing `security` Chronicle retention policy; the test now creates that
required reference row explicitly, without changing application behavior.

## Change

Both email adapters now record a successful enqueue after the existing mailer or Noticed enqueue
returns. The event uses the email record as the Chronicle subject and retains only the controlled
purpose value. It does not claim provider acceptance, delivery, retry, or permanent failure. The
existing encrypted job-argument boundary and outbound suspension behavior remain unchanged.

## Verification

Focused command:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/adapters/otp_adapter_email_characterization_test.rb \
  test/adapters/otp_adapter_test.rb \
  test/adapters/otp_email_plaintext_boundary_test.rb \
  test/notifiers/notify/otp_notifiers_test.rb \
  test/services/otp_email_notifier_rollout_test.rb
```

Result: `33 runs, 109 assertions, 0 failures, 0 errors, 0 skips`.

Static/security checks:

- Changed-file RuboCop: 4 files inspected, no offenses.
- Brakeman 8.0.6: 0 errors, 0 security warnings.
- Full Rails suite: `11475 runs, 73310 assertions, 0 failures, 0 errors, 6 skips`.

Provider receipt, delivery outcome, retry, permanent failure, archive, and legal-retention policy
remain unimplemented because their owner and external contract are not approved by the frozen plan.
