# OTP Security Boundary

Status: partial hardening recorded on 2026-09-21

> Contract supersession (2026-10-07): the record-owned HOTP and shared stateful policy below are
> historical, not the current recommendation. See `adr/realm-separated-identifiers-and-dead-history.md`
> for independent Email/Telephone policies, failure-count preservation, ceremony ownership and
> realm-separated keys. Its controller/delivery migration is in progress. All verification counts
> below belong to their historical runs and do not certify this migration. Step-Up is not merged
> into identifier-backed or ceremony-record HOTP.

## Classification

Email OTP used for sign-in and Step-Up is an explicit product risk acceptance
for email transport. This is an accepted deviation from NIST guidance on
email as an out-of-band authenticator; it does not relax replay resistance,
rate limiting, expiry, purpose binding, or session binding requirements.

Email and SMS codes used during signup are contact-confirmation codes, not
general authentication credentials. TOTP is a separate authenticator and is
app-only.

## Current ceremony-owned signup boundary

APP/COM Email and Telephone signup now use independently implemented typed ceremony operations.
Random six-digit proof has a five-minute limit clamped to the original parent deadline; Root,
browser, actor, purpose and candidate binding are not replaced by a public lookup reference.
Resend rotates the original unconsumed generation without resetting candidate or shared failures.
Consumption is atomic on the Ticket ceremony, while Source failure reset is a separate guarded
operation that preserves newer writes. Bounded receipt retries are not fresh verification;
live wrong-code receipt guesses use both failure budgets, and expired receipts grant no authority.
Canonical UTC timestamps preserve keyed verification across request and worker timezones.

Email codes are encrypted before Noticed queue persistence, and concrete Mailers validate current
transaction/generation immediately around delivery. Telephone signup carries its code and fixed
transaction/generation tuple inside the encrypted version-three SMS envelope. Cancellation,
expiry and superseded generations refuse transport. Generic SMS and remaining credential
registration delivery have separate purposes; neither is a signup HOTP fallback.

This does not certify complete OTP migration. Authenticated credential-registration and remaining
legacy dependencies are still being replaced; full-suite/gate verification is not complete.
See `adr/realm-separated-identifiers-and-dead-history.md` for the current contract and retained
implementation boundaries.

## Historical implementation guarantees (2026-09-21)

- Authentication OTPs use a ten-minute maximum lifetime.
- Signup confirmation codes use the same ten-minute lifetime, including SMS.
- EmailOtpPolicy and TelephoneOtpPolicy own independent lifetime, resend and overwrite-window
  constants. The former CommonOtpPolicy is removed. The existing record-backed paths retain their
  ten-minute bounds during caller replacement; the new ceremony-owned verifier has its own
  five-minute bound clamped to the parent transaction deadline. Complete HTTP migration is pending.
- HOTP material and counters are generated with the existing CSPRNG-backed
  `ROTP` and `SecureRandom` paths. Generated codes are compared at their
  fixed six-digit width, preserving leading-zero semantics.
- Record-backed OTP verification reads, validates, consumes, and increments
  failure state under the record lock.
- Resending a code invalidates the old code without resetting the server-side
  failed-attempt counter. A new secret does not provide a new attempt budget.
- OTP private keys on Email and Telephone models use Active Record Encryption;
  the model can decrypt them for verification while the database value is not
  plaintext.
- Delivery adapters use the existing encrypted outbound payload boundary, so
  OTP values are not placed in queue arguments as plaintext.
- Email adapters record successful enqueue and enqueue failure as separate
  sanitized Chronicle facts without recipient or OTP content; provider delivery
  receipts remain outside the current contract.
- App and com email sign-in create requests use a server-side, normalized-address
  cooldown bucket before account lookup. The response is the existing generic
  cooldown response for both registered and unregistered addresses; the
  client-session cooldown remains an auxiliary UX guard, not the security
  boundary.
- The identifier bucket is reserved only after the request's Turnstile result
  has been evaluated successfully. Failed Turnstile requests use the existing
  IP-scoped controls and cannot reserve another address's bucket.
- Authentication OTP expiry is fail-closed for malformed timestamp values:
  both PostgreSQL infinity sentinels and values that cannot be compared as a
  finite time are treated as expired. Authentication OTPs therefore cannot
  become timeless through an invalid persisted expiry.

## Verification performed

The following focused boundaries were exercised with the real PostgreSQL and
Valkey-backed test environment:

- OTP lifetime and signup ceremony: 9 runs, 50 assertions, 0 failures.
- Resend, lifetime, email, telephone, and storage boundaries: 93 runs, 318
  assertions, 0 failures.
- The same group plus the architecture baseline: 96 runs, 3382 assertions,
  0 failures.
- Full Rails suite after the hardening: 11404 runs, 72968 assertions, 0
  failures, 0 errors, 5 skips.

## Scope boundary

This document records implemented hardening, not a claim that every OTP audit
question is closed. The fresh-session enumeration boundary is covered for app
and com email sign-in and sign-up email/telephone contact-confirmation paths.
Withdrawal re-entry and other recovery-style entry points, provider delivery timing, and live
external delivery remain open checks. They must be verified with fake adapters or controlled
integration tests and must not use real recipient addresses or SMS charges.

## Latest verification

After the app/com sign-up email and telephone enumeration remediation, independent recovery and
withdrawal re-entry regression coverage, and sign-up OTP failed-attempt persistence coverage, the
full Rails suite ran with the repository PostgreSQL and Valkey services: 11418 runs, 73057
assertions, 0 failures, 0 errors, and 5 skips. Other recovery-style provider delivery timing and
live external delivery remain outside this result.

The OTP secret-delivery boundary was then rechecked with the email, Noticed,
SMS-job, and encrypted-payload tests: 21 runs, 74 assertions, 0 failures, 0
errors, and 0 skips. This verifies repository-side queue/payload handling only;
provider-side logs, APM payloads, and live external delivery remain unverified.

## Latest finite-expiry regression

The public `OtpLockable` contract was exercised after a RED test reproduced a
`Float::INFINITY` expiry reaching the time comparison and raising before the
OTP was rejected. The implementation now treats positive and negative infinity,
blank expiry, and non-comparable expiry values as expired. The focused OTP
regression suite completed with 154 runs, 588 assertions, 0 failures, 0 errors,
and 0 skips. This is a repository-side guarantee; it does not replace the
separate audit of all provider delivery and external observability boundaries.

The subsequent full Rails suite completed with 11469 runs, 73281 assertions,
0 failures, 0 errors, and 6 existing skips. No skip was added for this
regression.

On 2026-09-22, the public signup ceremony boundary tests were revalidated after
making the shared upper-bound source explicit. An OTP succeeded immediately
before the ten-minute boundary and was rejected at the boundary. The focused
ceremony/delivery set passed with 15 runs, 77 assertions, 0 failures, 0 errors,
and 0 skips; the complete Rails suite passed with 11536 runs, 73426 assertions,
0 failures, 0 errors, and 8 existing skips. Evidence:
`evidence/2026-09-22-oob-otp-lifetime-revalidation-M7N8.md`.

## Writer database clock verification

OTP issue, cooldown, expiry, and failed-attempt transition paths use the owning
writer database clock for each decision unit. The focused regression set covers
the model boundaries and app/com signup and signin controller paths; tests stub
the public model `database_now` boundary rather than assuming Rails time travel
advances PostgreSQL.

The focused suite completed with 283 runs, 1418 assertions, 0 failures, 0
errors, and 0 skips. The final Rails suite completed with 11472 runs, 73290
assertions, 0 failures, 0 errors, and 6 existing skips. This is a repository-side
verification; operational clock-drift bounds and unrelated historical timestamp
uses remain outside this OTP slice.
