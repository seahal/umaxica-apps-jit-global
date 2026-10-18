> **VENDOR-FACING REFERENCE SUPERSEDED BY `docs/vendor/identity/14_account-recovery-procedure.md`**
> This document remains historical/internal security context. For SIer, RFI/RFP, or normative
> vendor-facing reference, use `14_account-recovery-procedure.md`.

# MFA Reset Account Recovery

This document describes the approved security behavior for resetting MFA when an actor has lost,
destroyed, or can no longer use their MFA keys. The implementation is intentionally separate from
step-up verification.

## Boundary

MFA reset is account recovery. It is not a step-up method, and it must not allow a sensitive action
to proceed directly.

After reset approval, the actor must authenticate normally, register a new step-up method through
the bootstrap flow, and then complete ordinary step-up before sensitive actions are available.

## Request Rules

- Only one active MFA reset request may exist per account.
- Creating a reset request starts a 72 hour cooling-off period.
- No operator can approve the request before the 72 hour period has elapsed.
- The account owner can cancel an active request when they still have a session or path that
  satisfies the existing authentication requirements.
- Expired requests must be started again.

## Notifications And Sessions

Creating a reset request must notify the account through every safe registered notification channel
for that actor and surface. Existing sessions should also receive an in-product warning when
practical.

An MFA reset request never places a session into a restricted or other limited state, and no session
below full access may reach any MFA-reset entry point. In particular, a session-limit waiting unit
and a `RESTRICTED` (103) token cannot reach `base/{app,com,org}/identity/mfa/resets`. The retired
session guard and its MFA-reset allowlist entries have been removed; normal ACTIVE Browser RP
authentication remains the entry boundary.

## Operator Review

After the 72 hour cooling-off period, an operator may approve or deny the request through the normal
authorized org workflow.

The approving operator must be different from the requesting actor. For org actors, an operator must
not approve their own MFA reset.

Approval only authorizes credential reset and re-bootstrap. It does not trust the current browser,
complete login, or unlock sensitive actions.

## Approval Effects

Approval explicitly revokes existing MFA and passcode material for the actor and surface:

- passkeys
- TOTP credentials
- passcodes

After revocation, the actor's `multi_factor_status_id` is recalculated. If no surface-counting
step-up method remains, the status becomes `UNCONFIGURED`.

The actor must then use the existing bootstrap-exempt registration flow to register a new step-up
method. Sensitive actions remain blocked until that new method exists and normal step-up succeeds.

## Audit

The system must audit these lifecycle events:

- request creation
- cancellation
- expiry
- denial
- approval
- consumption

Audit records must include the actor, target account, operator when present, timestamps, status
transitions, and non-sensitive reason metadata.

Audit records must not include MFA secrets, passcodes, cookies, bearer tokens, authorization
headers, or full request parameters.
