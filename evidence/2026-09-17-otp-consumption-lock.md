# OTP One-Time Consumption Verification

Date: 2026-09-17

Repository: `seahal/umaxica-apps-jit-global`

Branch: `feature`

Scope: record-backed OTP verification and consumption across the existing email/telephone flows.

## Finding and change

Several existing callers verified a record without a row lock and cleared the OTP later. Two
concurrent requests could therefore both observe the same valid code before either clear committed.
The existing `CommonOtp` boundary now locks the record before verification, clears a successful code
before releasing that lock, and increments failed attempts under the same boundary. An optional
eligibility block can reject a verified code without consuming it or counting a failed attempt.

The app/com/org verification, sign-in, enforcement-recovery, and withdrawal-reentry callers were
updated to use this boundary. The sign-up `SignOtpCeremony` already had its own lock-and-consume
boundary; its resend cooldown recheck is recorded separately in
`evidence/2026-09-17-otp-resend-lock.md`.

## Static verification

| Command                                                                                                                                                                                                                                                                                                                                                                                                                                                       | Result                                                                                                                                              |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ruby -c` over the 12 changed Ruby/test files                                                                                                                                                                                                                                                                                                                                                                                                                 | Passed.                                                                                                                                             |
| `bundle exec rubocop` over the 12 changed Ruby/test files                                                                                                                                                                                                                                                                                                                                                                                                     | Passed: 12 files, no offenses.                                                                                                                      |
| `git diff --check`                                                                                                                                                                                                                                                                                                                                                                                                                                            | Passed.                                                                                                                                             |
| `rg -n "verify_otp_code\\(" app/controllers app/services app/operations --glob '*.rb'`                                                                                                                                                                                                                                                                                                                                                                        | Only the CommonOtp definition/example and the new locked helper remain; no application caller performs the old unlocked verify-then-clear sequence. |
| `bundle exec ruby -e '<CommonOtp deterministic lock-boundary check>'` with a deterministic in-memory record                                                                                                                                                                                                                                                                                                                                                   | Passed: first verification consumed the code and a second verification was refused.                                                                 |
| `VALKEY_TEST_HOST=127.0.0.1 VALKEY_TEST_PORT=6379 CACHE_REDIS_URL=redis://127.0.0.1:6379/3 RATE_LIMIT_REDIS_URL=redis://127.0.0.1:6379/4 AUTH_STATE_REDIS_URL=redis://127.0.0.1:6379/5 VALKEY_NAMESPACE_RUN_ID=otp-consumption-20260917 bundle exec rails test test/controllers/concerns/common_otp_consumption_test.rb test/controllers/concerns/telephone_registrable_test.rb test/controllers/concerns/sign_operator_telephone_registrable_guards_test.rb` | Blocked before assertions: PostgreSQL host `primary` could not be resolved. No fallback datastore was used.                                         |

The focused test double proves the public behavior of the common OTP boundary without replacing the
database locking behavior under test. Real PostgreSQL concurrency, model callbacks, and rollback
behavior remain unverified until the isolated services in CF-002 are available.

## Follow-up verification

- Date: 2026-09-17 UTC
- The first focused Rails run reached the test double and exposed a missing `locked?` method in
  `CommonOtpConsumptionTest::Record`; this was a test-model defect, not a production fallback.
- The test double now models the existing `OtpLockable` threshold contract without adding a
  test-only branch to application code.
- `bundle exec bin/rails test test/controllers/concerns/common_otp_consumption_test.rb` — passed, 3
  runs / 14 assertions.
- The focused OTP/signup regression set covering common consumption, resend failure handling, signup
  seams, ceremony behavior, resend policy, and resender failures — passed, 21 runs / 78 assertions.
- No migration, reset, external OTP delivery, or non-test datastore access was performed.

The follow-up verifies the public single-use and resend contracts through the available test
environment. It does not replace an independent PostgreSQL concurrency/rollback proof or real
provider delivery verification.
