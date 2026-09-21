# OTP Secret Boundary Verification

Date: 2026-09-20

## Scope

This check covered the OTP delivery and sensitive-payload boundaries used by
the app, com, and org email paths and the SMS delivery job. It did not send a
real email or SMS and did not contact an external provider.

## Repository evidence

- Email OTP values are encrypted before the legacy mailer job or Noticed
  delivery job receives them.
- SMS delivery uses the versioned encrypted delivery envelope; plaintext SMS
  job payloads are rejected.
- OTP private keys on email and telephone records use Active Record Encryption.
- The inspected OTP error-report contexts contain service/action metadata and
  record identifiers, not OTP values or complete submitted codes.

## Verification

Command:

```text
env UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example PARALLEL_WORKERS=1 bin/rails test test/adapters/otp_email_plaintext_boundary_test.rb test/notifiers/notify/otp_notifiers_test.rb test/jobs/outbound/sms_delivery_job_test.rb test/services/outbound_sensitive_payload_test.rb test/services/outbound/sensitive_payload_test.rb
```

Result: 21 runs, 74 assertions, 0 failures, 0 errors, 0 skips.

The latest full Rails suite result before this read-only audit was 11,418
runs, 73,057 assertions, 0 failures, 0 errors, and 5 skips. No production
code was changed for this check.

## Limits

This evidence does not establish that external provider logs, APM payloads, or
live delivery infrastructure preserve the same boundary. Those require a
controlled provider-side verification and remain unverified here.
