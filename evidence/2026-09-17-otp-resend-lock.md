# Sign-up OTP Resend Lock Verification

Date: 2026-09-17

Repository: `seahal/umaxica-apps-jit-global`

Branch: `feature`

Scope: `SignOtpCeremony#issue!` cooldown serialization for app/com sign-up contact records.

## Finding and change

The initial `cooldown_active?` check ran before `record.with_lock`, but the locked block checked
only the record lockout. Two concurrent resend requests could therefore both pass the fast check and
replace/deliver an OTP. The implementation now repeats the existing cooldown predicate after the row
lock and before `store_otp` or delivery. No cooldown duration, retry threshold, or provider contract
changed.

## Verification

| Command                                                                                                                                                                                                                                                                                                                                                               | Result                                                                                                      |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `ruby -c app/services/sign_otp_ceremony.rb`                                                                                                                                                                                                                                                                                                                           | Passed.                                                                                                     |
| `ruby -c test/services/sign_otp_ceremony_test.rb`                                                                                                                                                                                                                                                                                                                     | Passed.                                                                                                     |
| `bundle exec rubocop app/services/sign_otp_ceremony.rb test/services/sign_otp_ceremony_test.rb`                                                                                                                                                                                                                                                                       | Passed: 2 files, no offenses.                                                                               |
| `git diff --check`                                                                                                                                                                                                                                                                                                                                                    | Passed.                                                                                                     |
| `VALKEY_TEST_HOST=127.0.0.1 VALKEY_TEST_PORT=6379 CACHE_REDIS_URL=redis://127.0.0.1:6379/3 RATE_LIMIT_REDIS_URL=redis://127.0.0.1:6379/4 AUTH_STATE_REDIS_URL=redis://127.0.0.1:6379/5 VALKEY_NAMESPACE_RUN_ID=otp-hardening-20260917 bundle exec rails test test/services/sign_otp_ceremony_test.rb test/services/otp_ceremony_and_candidate_store_refusals_test.rb` | Blocked before assertions: PostgreSQL host `primary` could not be resolved. No fallback datastore was used. |

The regression test uses a lock-boundary test double only to prove the observable ordering of this
service; database-backed record creation and concurrent PostgreSQL behavior remain unverified until
the isolated test services in CF-002 are available.
