# Sign-Up Compensation

## Purpose

Document retry, rollback, and cleanup behavior for unfinished sign-up attempts. This boundary covers
pending sign-up cycles before durable account completion. It does not cover sign-in/session failure
after sign-up completion.

## Durable Ticket

- `ClientSignUpFlow` is the durable sign-up ticket on `app`.
- `VisitorSignUpFlow` is the durable sign-up ticket on `com`.
- Ordinary OTP failure keeps the ticket retryable.
- A stale session should redirect back to the start of the current sign-up surface.
- Cleanup must only touch artifacts owned by the current ticket.

## OTP Retry

- Blank OTP submissions fail closed with a field error.
- Wrong OTP submissions fail closed with a field error and may increment attempt count.
- Locked OTP submissions end the current flow and do not create a session.
- Expired OTP submissions fail closed and return to the start of the sign-up surface.
- Dummy or replayed flows must not leak whether a real OTP existed.

## Finalization Boundary

- `finalize_sign_up_from_checkpoint!` is the sign-up completion gate.
- `IdentityGraphProvisioner.call!` runs inside that boundary before any sign-in handoff.
- `establish_signed_in_session!` is the shared session-issuance helper for the sign-up handoff, with
  no cooldown or limit exemption.
- If graph provisioning fails, the boundary must stop before handoff and must not issue auth state.
- If session issuance fails after durable provisioning, the completed actor data must remain intact
  and the request must fail as a sign-in-domain problem, not as a sign-up rollback.

## Cleanup Scope

- Cleanup must only delete pending email, telephone, or social artifacts created by the current
  ticket.
- Cleanup must not delete registered actor data that predates the current sign-up cycle.
- Cleanup must be idempotent.

## Concurrent Finalization

- The ticket row lock serializes concurrent finalize requests.
- Only one identity graph may be provisioned for the ticket.
- A second finalize attempt should fail deterministically as stale, already-finalized, or otherwise
  non-advancing.

## Related

- `docs/security/sign-up-sequence.md`
- `docs/security/social-callback-boundary.md`
