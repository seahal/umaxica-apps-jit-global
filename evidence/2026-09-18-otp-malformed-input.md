# OTP malformed-input hardening verification

- Date: 2026-09-18 UTC
- Branch: `feature`
- Starting commit for this slice: `4ddf4fe1a`
- Pre-existing working-tree changes were preserved and were not staged.

## Finding

The shared record-backed OTP verifier and the sign-up ceremony passed untrusted code strings
directly into comparison/verification paths. The generated HOTP is six ASCII digits, so malformed
length, non-numeric, and nil input must be rejected as invalid input rather than reaching a
length-sensitive comparison or the HOTP library with an invalid type.

## Implementation

- `CommonOtp#verify_hotp_code` now normalizes and validates the six-digit input before HOTP
  verification.
- `CommonOtp#secure_compare_otp` validates the generated-code length and numeric shape before the
  constant-time comparison; the dummy verifier uses the same boundary.
- `SignOtpCeremony` uses the same input boundary before its direct comparison.
- Regression tests cover short record-backed codes, oversized dummy input, nil/basic HOTP input, and
  malformed sign-up verification input.

## Verification

- `bundle exec ruby -e '...'` standalone OTP smoke covering valid, short, oversized, nil, and
  sign-up comparison inputs: passed (`otp_hotp_input_smoke: PASS`).
- `ruby -c` for the two production files and two test files: passed.
- `bundle exec rubocop app/controllers/concerns/common_otp.rb app/services/sign_otp_ceremony.rb test/controllers/concerns/common_otp_consumption_test.rb test/services/sign_otp_ceremony_test.rb`:
  passed; 4 files inspected, no offenses.
- The Rails test command with explicit loopback test Valkey variables reached Rails boot but stopped
  before test execution because PostgreSQL hostname `primary` was unavailable. No fallback or
  non-test datastore was used; CF-002 remains open.

## Boundary retained

No OTP length, expiry, attempt threshold, resend cooldown, delivery provider, authentication
decision, or secret logging behavior was changed. Raw OTP values are not added to logs or job
arguments.
