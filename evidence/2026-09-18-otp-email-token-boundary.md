# OTP email verification-token queue boundary verification

- Date: 2026-09-18 UTC
- Branch: `feature`
- Base commit for this slice: `fb6d94c7b58f03f6bf0f7457c36dbed3d897c700`
- Pre-existing working-tree changes were preserved and were not staged.

## Finding and change

The Action Mailer OTP adapter and the Noticed OTP notifier previously passed the email verification
bearer token as a serialized job parameter. The OTP code was already encrypted, but the verification
token was not. Both producers now encrypt the token with a purpose-separated
`OutboundSensitivePayload` value before enqueue. The three surface mailers decrypt only at render
time. A read-only legacy fallback remains for already queued/direct legacy mailer arguments; no
current producer emits that field.

## Verification

- Standalone Active Record encryption round-trip smoke: passed
  (`email_verification_token_encryption_smoke: PASS`).
- Ruby syntax checks for the changed production and test files: passed.
- RuboCop for the changed production and test files: passed; 13 files inspected, no offenses.
- Focused Rails test command:
  `VALKEY_TEST_HOST=127.0.0.1 VALKEY_TEST_PORT=6379 CACHE_REDIS_URL=redis://127.0.0.1:6379/3 RATE_LIMIT_REDIS_URL=redis://127.0.0.1:6379/4 AUTH_STATE_REDIS_URL=redis://127.0.0.1:6379/5 VALKEY_NAMESPACE_RUN_ID=email-token-red-20260918 POSTGRESQL_TEST_HOST=127.0.0.1 POSTGRESQL_PORT=5432 bundle exec bin/rails test test/services/outbound_sensitive_payload_test.rb test/adapters/otp_email_adapter_test.rb test/adapters/otp_adapter_email_characterization_test.rb test/notifiers/notify/otp_notifiers_test.rb test/mailers/email/surface_mailers_test.rb`
  was blocked during Rails schema boot because PostgreSQL at `127.0.0.1:5432` is unavailable. No
  development, staging, or production datastore fallback was used.

## Remaining verification

The database-backed enqueue/render tests and actual Solid Queue worker execution remain unverified
until the repository's isolated PostgreSQL, Valkey, and queue-worker services are available. No
email provider was contacted.
