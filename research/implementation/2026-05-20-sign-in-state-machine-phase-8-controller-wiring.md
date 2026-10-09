# Sign-In State Machine Phase 8 Controller Wiring

Phase 8 continues the DB-backed participant wiring in `Authentication::Base`.

Current behavior:

- checkpoint continuation prefers the DB-backed sign-in cycle when a valid locator is present;
- checkpoint participant blocking results keep the cycle at `CHECKPOINT_PENDING` instead of
  advancing to dashboard;
- dashboard sequence handling requires `show_dashboard?`, advances to `RETURN_PENDING`, then
  consumes `return_to`;
- return path consumption remains inside `SignIn::ReturnParticipant`, which clears `cycle.return_to`
  and completes the cycle;
- the legacy session carrier remains as compatibility fallback for flows that have not yet issued a
  DB-backed cycle locator.

This phase still does not remove the legacy checkpoint/session carrier fallback. Full removal should
wait until every sign-in entry route creates and rotates a DB-backed cycle locator.

Follow-up wiring completed:

- `Authentication::Base#establish_signed_in_session!` now starts a DB-backed sign-in cycle after
  primary credential success.
- MFA-required sign-ins advance the cycle to `MFA_PENDING` and keep the locator through the MFA
  challenge.
- Successful non-MFA and post-MFA login results bind the issued token to the cycle and advance the
  cycle through guardrail/checkpoint.
- `redirect_to_sign_in_sequence!` prefers the DB-backed cycle and advances an empty checkpoint stack
  before redirecting to dashboard.
- Restricted session-limit login binds the restricted token to `SESSION_LIMIT_PENDING`.
- Session-limit promotion uses `SignIn::SessionLimitManager` when a DB-backed cycle locator is
  present, then advances the promoted session to checkpoint/dashboard sequence handling.

Compatibility still retained:

- `SessionLimitGate` remains fallback for entry routes or tests without a DB-backed cycle locator.
- The existing `log_in` cookie/header issuance boundary is still the place where browser cookies and
  DBSC headers are written. The DB-backed cycle is bound immediately after that boundary succeeds.
