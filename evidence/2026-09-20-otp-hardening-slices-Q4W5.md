# OTP hardening slices

Date: 2026-09-20

## RED checks

- The new SMS/signup lifetime assertion failed because
  `SignTelephoneOtpDelivery` stored a 12-minute expiry instead of the required
  ten-minute bound.
- The signup ceremony lifetime assertion failed for the same 12-minute policy.
- The resend regression failed because `otp_attempts_count` changed from 1 to 0
  after issuing a replacement code.
- The database-boundary assertions failed because `otp_private_key` was stored
  as plaintext.
- The counter-boundary assertions failed because the previous counter format
  concatenated a timestamp and a random value, producing values beyond the
  model's unsigned 64-bit counter range.
- The full suite initially detected one architecture-baseline failure after a
  resend helper method was added to `OtpLockable`. The implementation was
  adjusted to reuse the existing `clear_otp(reset_attempts:)` interface; the
  baseline was not changed.

## GREEN checks

Focused OTP lifetime and signup tests:

```text
9 runs, 50 assertions, 0 failures, 0 errors, 0 skips
```

Resend, lifetime, Email, Telephone, and encrypted-storage tests:

```text
93 runs, 318 assertions, 0 failures, 0 errors, 0 skips
```

The same group plus the architecture baseline:

```text
96 runs, 3382 assertions, 0 failures, 0 errors, 0 skips
```

The counter boundary tests after replacing timestamp concatenation with a
cryptographically secure unsigned 64-bit random counter:

```text
20 runs, 110 assertions, 0 failures, 0 errors, 0 skips
```

The final Rails full suite after these changes:

```text
11404 runs, 72976 assertions, 0 failures, 0 errors, 5 skips
```

## Implemented boundary

Authentication and signup OTPs now use a shared ten-minute policy. Resend
invalidates the prior code without resetting failed-attempt history. Email and
Telephone OTP private keys are encrypted through Active Record Encryption, and
the tests verify model decryption together with the absence of plaintext in
the tests verify model decryption together with the absence of plaintext in
the PostgreSQL value. OTP counters are generated solely with
`SecureRandom.random_number(1 << 64)`; timestamps are not encoded into the
counter.

The run emitted existing OmniAuth negative-path diagnostics and Ruby constant
reinitialization warnings; neither produced a test failure or error.
