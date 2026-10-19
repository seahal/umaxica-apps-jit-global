# Authentication Capacity Control and Waiting Room

Recorded 2026-10-19. Deferred out of the three.md cycle by user decision. No design exists yet; this
is more than a single decision.

## Current state

- No capacity limit, queue, flag, gate or waiting room exists. Existing `AuthCeremonyAdmission`,
  `BaseAuthAdmissionCoordinator`, `SignUpSuspensionGuard` and `FqdnAvailabilityGate` are security or
  availability controls, not capacity permits, and must not be repurposed.
- Brute-force protection for password and OTP still comes from the existing rate limits.
- The route/cost inventory and the future connection contract are in
  `docs/security/authentication-capacity-admission.md` (Entry Control versus Execution Control,
  server-derived inputs, enforcement on direct POST, callback, resume, Passkey, social, Entra and
  Sign-Up-to-Sign-In handoff paths).

## Decisions needed

- What is limited (which flows and which expensive operations) and the limit values.
- Where the capacity state lives (for example Valkey) and how it is shared across processes.
- Outage policy when that store is unavailable: fail closed, fail open for entry only, or a bounded
  local fallback.
- Whether and where a waiting outcome is shown, and its order and wait-estimate behavior.

## Affected

three.md U07; two.md REQ-C01-C06; four.md AC-C01-AC-C06; one.md third handoff.
