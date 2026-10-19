# Withdrawal Termination, Recovery and Erasure Assurance

Recorded 2026-10-19. Deferred out of the three.md cycle by user decision (no decision could be made
in this cycle).

## Current state

- APP/COM irreversible termination requires a persisted ceremony with purpose `termination`; a
  `status` ceremony is refused without being consumed.
- No issuance flow or authentication-assurance contract exists for the `termination` and `recovery`
  purposes or for privacy erasure. Those operations stay refused (fail closed).

## Decision needed

- Which proof authorizes termination, recovery and privacy erasure (for example Passkey or TOTP
  re-authentication, email OTP, support-assisted)?
- What happens when the user has lost Passkey/TOTP?
- Expiry, surface and actor binding of the issued ceremony.

## Affected

three.md U10; two.md REQ-W08-W12; four.md AC-W08-AC-W12, AC-V06; six.md open decisions.
