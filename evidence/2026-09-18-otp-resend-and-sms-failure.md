# OTP resend reservation and SMS discard reporting verification

- Date: 2026-09-18 UTC
- Branch: `feature`
- Base commit for this slice: `3ee90c2183a879fec97f1badd68899bf41164ce3`
- Pre-existing working-tree changes were preserved and were not staged.

## Findings and changes

- `SignInOtpResender` previously evaluated and persisted the HMAC-keyed resend history only after
  provider delivery. Concurrent requests could therefore evaluate the same old history, and a
  provider failure left no durable reservation. It now uses the existing unique body index to
  create/find the occurrence, locks that row while evaluating and recording the reservation, and
  performs provider I/O only after the reservation transaction commits.
- `Outbound::SmsDeliveryJob` already refused plaintext and mixed payloads, but its permanent
  `ArgumentError` discard was silent. The discard now reports through Rails' Active Job error
  reporter before the job is discarded; no sensitive payload is included in the report by this
  change.
- The shared `CommonOtp#generate_otp_for` helper previously stored a newly generated credential
  without acquiring the target row lock. It now generates and stores the secret, counter, and expiry
  within `record.with_lock`; delivery remains outside that transaction.

## Verification

- `ruby -c` for the two production files and two changed test files: passed.
- `bundle exec rubocop app/services/sign_in_otp_resender.rb app/jobs/outbound/sms_delivery_job.rb test/services/sign/in/otp_resend_service_test.rb test/jobs/outbound/sms_delivery_job_test.rb`:
  passed; 4 files inspected, no offenses.
- Standalone Active Job smoke using the installed Active Job source,
  `discard_on ArgumentError, report: true`, and an error subscriber: passed
  (`active_job_discard_report_smoke: PASS`).
- Standalone HOTP generation smoke with a lock-observing record: passed
  (`otp_generation_lock_smoke: PASS`).
- `VALKEY_TEST_HOST=127.0.0.1 VALKEY_TEST_PORT=6379 CACHE_REDIS_URL=redis://127.0.0.1:6379/3 RATE_LIMIT_REDIS_URL=redis://127.0.0.1:6379/4 AUTH_STATE_REDIS_URL=redis://127.0.0.1:6379/5 VALKEY_NAMESPACE_RUN_ID=otp-resend-sms-20260918 POSTGRESQL_TEST_HOST=127.0.0.1 POSTGRESQL_PORT=5432 bundle exec bin/rails test test/services/sign/in/otp_resend_service_test.rb test/jobs/outbound/sms_delivery_job_test.rb`:
  blocked before test execution because PostgreSQL at `127.0.0.1:5432` was unavailable. No
  development, staging, or production datastore fallback was used.

## Remaining verification

The database-backed resend reservation test, unique-row creation race, shared OTP Rails regression,
and Rails error-reporter test remain unverified until the repository's isolated PostgreSQL and
Valkey test services are available. No external SMS or email provider was contacted.
