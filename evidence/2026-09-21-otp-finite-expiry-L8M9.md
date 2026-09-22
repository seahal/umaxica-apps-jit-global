# OTP finite-expiry regression

- Date: 2026-09-21
- Workspace: `/home/global/workspace`
- Scope: `OtpLockable` authentication OTP expiry and related OTP delivery/security regressions
- External services: no AWS, Cloudflare, or real email/SMS delivery was used

## RED

Added a public-behavior regression for a persisted positive PostgreSQL timestamp
infinity on an OTP record. Before the fix, `otp_expired?` attempted to compare
the infinity value with `ActiveSupport::TimeWithZone` and raised
`ArgumentError: comparison of Float with ActiveSupport::TimeWithZone failed`.
That was a fail-closed error in this path, but it left malformed authentication
state dependent on an exception rather than the explicit expired contract.

## GREEN

`OtpLockable#otp_expired?` now treats blank, either infinity sentinel, and
non-comparable timestamp values as expired. A valid finite expiry continues to
use the normal current-time comparison. The public contract also verifies that
the record is not active and returns no OTP material for a positive-infinity
expiry.

Focused command:

```text
export UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
export POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db
export PARALLEL_WORKERS=1
bin/rails test test/models/concerns/otp_lockable_test.rb test/models/concerns/email_test.rb test/models/concerns/telephone_test.rb test/services/sign_otp_ceremony_test.rb test/services/sign/in/otp_resend_policy_test.rb test/services/sign/in/otp_resend_service_test.rb test/services/sign_in_otp_resender_failures_test.rb test/controllers/auth/app/in/emails_controller_enumeration_test.rb test/controllers/auth/com/in/emails_controller_enumeration_test.rb test/jobs/outbound/sms_delivery_job_test.rb test/services/outbound_sms_audit_test.rb test/models/chronicle_test.rb test/subscribers/jwt_anomaly_subscriber_test.rb test/jobs/retention_purge_legal_hold_test.rb test/jobs/retention_purge_job_test.rb
```

Result: `154 runs, 588 assertions, 0 failures, 0 errors, 0 skips`.

The focused result covers repository-side behavior only. Provider-side logs,
APM payloads, live delivery receipts, and external delivery timing remain
unverified as required by the OTP audit boundary.

The focused regression was followed by:

```text
bin/rails test
```

Result: `11469 runs, 73281 assertions, 0 failures, 0 errors, 6 skips`.
The skips were reported by the existing suite; no skip was added for this
change.
