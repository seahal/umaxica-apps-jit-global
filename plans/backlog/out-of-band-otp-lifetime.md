# Out-of-Band OTP Lifetime

Status: `ALREADY_SATISFIED` (verified 2026-09-22)

## Requirement

Authentication one-time passwords and SMS signup confirmation codes MUST have a
finite lifetime of no more than ten minutes. Email signup confirmation is
evaluated as contact confirmation, but the implementation uses the same shorter
bound. A shorter lifetime remains valid.

The product's accepted deviation for email transport in sign-in and Step-Up is
recorded in `docs/security/otp-audit.md`; it does not relax expiry, replay,
rate-limit, purpose-binding, or session-binding requirements.

## Current implementation

`CommonOtpPolicy::MAX_OOB_TTL` is the single upper-bound source and is set to
ten minutes. Purpose-specific policy names remain available so callers retain
their semantic distinction:

| Constant | Meaning | Consumers |
|---|---|---|
| `CommonOtpPolicy::AUTHENTICATION_TTL` | Authentication OTP lifetime | `CommonOtp::OTP_EXPIRATION_MINUTES`, including app/com sign-in, Step-Up, recovery, and related record-backed OTP paths |
| `CommonOtpPolicy::SIGN_UP_CONFIRMATION_TTL` | Signup contact-confirmation lifetime | `SignOtpCeremony`, `SignTelephoneOtpDelivery`, and app/com signup confirmation paths |

Both purpose-specific constants alias `MAX_OOB_TTL`; they cannot drift to
different values without changing the shared policy source. Workflow tickets
that have a separate lifecycle remain separate from the OTP secret lifetime.

The existing `OtpLockable` concern performs the expiry check using the writer
database clock and rejects blank, infinite, or otherwise non-comparable expiry
values. Successful verification consumes the OTP under the record lock. Resend
does not reset the server-side failed-attempt counter.

## Verification

The prior stale description of three independent twelve-minute constants was
incorrect for the current HEAD. The current policy and public ceremony behavior
were verified against the real PostgreSQL/Valkey-backed test environment.

RED contract check before adding the shared bound:

```text
NameError: uninitialized constant CommonOtpPolicy::MAX_OOB_TTL
13 runs, 56 assertions, 0 failures, 1 error, 0 skips
```

GREEN focused verification after the policy alias and expiry-boundary tests:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/services/sign_otp_ceremony_test.rb \
  test/services/sign/telephone_otp_delivery_test.rb

15 runs, 77 assertions, 0 failures, 0 errors, 0 skips
```

The broader app/com signup OTP controller set was also verified at 47 runs,
298 assertions, 0 failures, 0 errors, 0 skips. No external provider, AWS,
Cloudflare, production, or shared database was contacted.

The new public behavior tests cover an OTP that succeeds immediately before
the ten-minute boundary and an OTP rejected at the boundary. Existing tests
cover database-clock expiry calculation, resend cooldown, failed-attempt
persistence, and one-time consumption.

## Disposition

No separate dry-run, preview, or simulation path is required for this OTP
lifetime item. No workflow-ticket lifetime was shortened merely to satisfy the
OTP bound. The historical ASVS finding should be treated as remediated in the
current implementation; its original evidence remains historical evidence of
the earlier twelve-minute state.
