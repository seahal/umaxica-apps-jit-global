# O-10 model concern and OTP mailer lock trace

Date: 2026-11-04

## Scope

Read-only trace of the remaining ceremony-model and APP OTP mailer paths surfaced by the O-10
lexical candidate scan.

## Observed result

The Auth / OP ceremony concerns lock their own parent or child rows and do not lock Client or
Operator rows. `AuthEmailOtpChallenge` is actor-aware: it obtains the owner and contact before the
Auth parent and challenge. The registration OTP mailer delegates to the owner-first
`EmailCredentialRegistrationOtpDeliveryGuard`; its separate reentry path takes the contact before
its OTP transaction and does not subsequently take an actor lock. Both mailer paths invoke the
transport block while their current lock scopes remain open. That is a lock-duration and delivery
outcome concern requiring a separate protocol if changed; it is not an observed actor / OP order
inversion.

The reproducible lexical intersection has 88 candidate files. The inventory now names 46 by full
path and leaves 42 unnamed. This is a triage set, not a defect count; remaining model / operation
paths and indirect callers still need reconciliation.

## Evidence and limits

- Searched the listed Auth / OP model concerns for explicit `.lock`, `with_lock` and principal-row
  locks.
- Inspected `app/mailers/email/app/otp_mailer.rb:34–110` and
  `app/operations/email_credential_registration_otp_delivery_guard.rb:30–54`.
- No tests, application code, or databases were changed or accessed.

HEAD: `b30345216886c98af1f04cbd434f067f12decf01`. The worktree was extensively uncommitted; this
read-only trace was against the worktree content.
