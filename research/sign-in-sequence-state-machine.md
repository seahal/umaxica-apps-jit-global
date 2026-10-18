# Sign-In Sequence State Machine Notes

**Status:** Draft note (2026-05-13)

This note captures design discussion for a future hardening pass on the sign-in sequence. It is not
current behavior and should not be treated as stable documentation until implemented and promoted to
`docs/security/sign-in-sequence.md` or a full ADR.

## Current Flow Summary

The current app sign-in flow is:

1. `/sign/in/new`
2. Primary method selection.
3. Primary authentication through email OTP, passkey, passcode, or social login.
4. MFA challenge when required.
5. Session-limit management when required.
6. Checkpoint.
7. Dashboard.
8. If a safe `rt` return path is present, jump there after dashboard; otherwise the dashboard or
   default destination ends the sequence.

`rt` is carried through checkpoint and dashboard. It does not skip dashboard in the current design.

## Problem

The sequence should be monotonic. After the actor advances from one gate to the next, older gates
should not be reusable as a way to move backward or bypass later gates.

The gates discussed were:

- Primary authentication to MFA decision/challenge.
- MFA decision/challenge to session-limit handling.
- Session-limit handling to checkpoint.
- Checkpoint to dashboard.
- Dashboard to final return path.

The concern is that if intermediate sign-in states are represented by new `UserTokenStatus` values,
some existing token checks may treat those values as "not expired, not revoked, not restricted" and
therefore allow normal application behavior. That would mix token validity with sign-in flow
progress and create a fragile enforcement surface.

## Direction

Do not use `UserTokenStatus` to represent sign-in sequence progress.

Keep token status focused on durable token/session validity:

| Status       | Meaning                                                |
| ------------ | ------------------------------------------------------ |
| `ACTIVE`     | Usable session token.                                  |
| `RESTRICTED` | Restricted session token for session-limit management. |
| `EXPIRED`    | Expired token.                                         |
| `REVOKED`    | Revoked token.                                         |

Represent sign-in progress separately as a short-lived sequence state. The state can initially live
in the Rails session, matching existing `pending_mfa`, checkpoint, and session-limit gate patterns.
If auditability, cross-device coordination, or server-side forced cancellation becomes required,
promote it to a short-lived DB model such as `Sign::In::Flow`.

## Sequence State

The state machine should make both required and skipped gates explicit. Example states:

- `primary_verified`
- `mfa_evaluated`
- `mfa_required`
- `mfa_verified`
- `mfa_skipped`
- `session_issued`
- `session_gate_required`
- `session_gate_passed`
- `checkpoint_pending`
- `checkpoint_passed`
- `dashboard_reached`
- `completed`

The important rule is that "MFA is not required" is still a decision result. The flow should always
call the MFA decision step after primary authentication. If MFA is unnecessary or bypassed by the
primary method, record a skip result such as:

- `required: false`
- `result: skipped`
- `reason: actor_mfa_disabled` or `auth_method_bypassed`

## MFA Decision

MFA should be evaluated through a common decision object instead of ad hoc controller conditionals.

Inputs:

- Actor (`User`, `Staff`, or `Customer`).
- Surface (`app`, `org`, or `com`).
- Primary auth method (`email`, `passkey`, `passcode`, `social`, etc.).
- Actor MFA setting, currently `multi_factor_id` with `multi_factor_enabled` retained as a
  transitional compatibility column.
- Surface-specific available methods.
- Future risk-based signals, if added.

Passkey and social login may bypass MFA by policy, but they should still pass through the decision
function and produce an explicit decision.

## Guarding Normal Behavior

Normal application behavior should require both:

1. The token is normally usable, for example `UserTokenStatus::ACTIVE`.
2. The sign-in sequence is complete, or no sign-in sequence is in progress.

If a token is `ACTIVE` but the sequence is incomplete, a guard should only allow the current
required sign-in sequence paths, for example session management, checkpoint, dashboard, and logout.
Other normal routes should redirect to the current required gate or fail closed.

This would generalize the current restricted-session behavior:

- `RestrictedSessionGuard` limits `RESTRICTED` tokens to session management.
- A future `Sign::In::SequenceGuard` should limit incomplete `ACTIVE` sign-in flows to the next
  required sign-in gate.

## Reuse Across Surfaces

The sign-in sequence abstraction should be shared across `app`, `org`, and `com`, while preserving
surface boundaries.

Shared:

- State-machine rules.
- Forward-only transition checks.
- MFA decision interface.
- Sequence guard behavior.
- Redirect-to-next-step orchestration.

Surface-specific:

- Actor class (`User`, `Staff`, `Customer`).
- Token model (`UserToken`, `OperatorToken`, `CustomerToken`).
- Route helpers.
- Dashboard/settings paths.
- Session-limit constants.
- Available MFA methods.

One possible shape:

- `Sign::In::Sequence` for state and transition rules.
- `Sign::In::MfaDecision` for required/skipped MFA decisions.
- `Sign::In::SequenceGuard` as a controller concern.
- Small surface route adapters for `app`, `org`, and `com`.

Keep heavy business logic out of controllers and concerns. Concerns should be thin integration
layers; state transitions and decisions should live in plain Ruby objects or a short-lived model.

## Authentication Assurance Notes

The AAL1/AAL2 boundary definitions and per-surface method lookup have moved to
`docs/security/authentication-assurance-levels.md` and
`adr/authentication-assurance-level-boundaries.md`.

Sign-in establishes `AAL1`. Explicit verification / step-up establishes short-lived `AAL2`.
