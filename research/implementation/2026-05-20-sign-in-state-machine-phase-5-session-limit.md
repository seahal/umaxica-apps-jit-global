# Sign-In State Machine Phase 5 Session Limit Boundary

Phase 5 adds `SignIn::SessionLimitManager` as the DB transaction boundary for cycle-backed
restricted session handling.

Current behavior:

- accepts only cycles at `SESSION_LIMIT_PENDING`;
- requires actor binding by `principal_id`;
- creates a restricted token and binds it to `cycle.token_id`;
- rotates the restricted refresh token with the restricted-session TTL;
- promotes only when the active session count is below the surface limit;
- advances promoted cycles to `GUARDRAIL_PENDING`;
- cancels by revoking the restricted token and transitioning the cycle to `FAILED`;
- requires the current token to match the cycle-bound restricted token for promote/cancel.

The existing `SessionLimitGate` and controller session keys remain compatibility paths until the
later surface-controller wiring phase. They should not be treated as the long-term authority once
controllers call this manager.
