# Out-of-Band OTP Lifetime

## Context

The OWASP ASVS 5.0 review of 2026-09-19
(`evidence/2026-09-19-owasp-asvs-5-checklist-review-V5R8.md`, finding F4) found that email and SMS
one-time codes stay valid for 12 minutes. ASVS 5.0 requirement 6.5.5 limits out-of-band
authentication requests, codes, and tokens to a maximum lifetime of 10 minutes.

This document records the finding. No change was made on 2026-09-19.

## Current behavior

The lifetime is defined three times, each as `OTP_EXPIRATION_MINUTES = 12`:

| Constant | Used for |
|---|---|
| `CommonOtp::OTP_EXPIRATION_MINUTES` (`app/controllers/concerns/common_otp.rb`) | `generate_otp_for`, `generate_otp_attributes`; the `expires_at` of sign-up email and telephone sessions (app and com), withdrawal re-entry, enforcement recovery, and `SignEmailRegistrable` |
| `SignOtpCeremony::OTP_EXPIRATION_MINUTES` (`app/services/sign_otp_ceremony.rb`) | `store_otp` for sign-in email and telephone codes |
| `SignTelephoneOtpDelivery::OTP_EXPIRATION_MINUTES` (`app/services/sign_telephone_otp_delivery.rb`) | `otp_expires_at` for telephone delivery |

The other controls already meet ASVS: codes are HOTP values from a random base32 key, cleared on
successful verification under `with_lock`, and limited to 5 attempts followed by a 15-minute lockout
(`OtpLockable`). No locale string or mail template states the lifetime, so the change does not alter
user-facing copy.

## Why it matters

A longer window extends the time during which a code intercepted from email or SMS remains usable.
The margin is small (2 minutes), so the risk is low. It is still a failed Level 1 requirement and
should be corrected.

## Proposal

1. Define one constant as the source of the out-of-band code lifetime, at 10 minutes or less, and
   make `SignOtpCeremony` and `SignTelephoneOtpDelivery` reference it instead of keeping their own.
2. Check that session `expires_at` values derived from the constant still cover the resend flow and
   the resend cooldown.
3. Update tests that assert a 12-minute window, and add boundary tests at the new limit: valid just
   before it and rejected just after it.

## Open questions

- Whether sign-up and withdrawal re-entry sessions, which reuse the same constant for their own
  `expires_at`, should keep a separate and longer workflow lifetime from the code itself.
