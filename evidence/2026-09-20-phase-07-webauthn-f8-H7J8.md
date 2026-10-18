# Phase 07 WebAuthn F8 remediation

Date: 2026-09-20
Branch: `feature`
Scope: app/com direct Passkey sign-in and app/com registration policy

## Implemented contract

- App and com options requests issue anonymous challenges without account lookup or identifier
  selection. The serialized `allowCredentials` list is empty and real credential IDs are absent.
- Verification resolves the surface-local Passkey row by assertion credential ID, uses the saved
  public key, ignores the browser `userHandle` as an identity authority, and preserves UV, RP/origin,
  sign-count, verified-PII, session, restricted-session, rate-limit, Turnstile, risk, and audit
  checks.
- App and com registration require `residentKey: "required"`; org registration retains
  `residentKey: "discouraged"`. Org normal, Emergency, MFA, and Step-Up remain actor-known.
- The old app/com dummy-padding and identifier-first options path is not retained as a compatibility
  flow. Existing non-discoverable app/com credentials require re-registration.

## Verification performed

All commands were run from `/home/global/workspace` with `UMAXICA_ENV_FILE` set to the repository's
`.env.devcontainer.example`; no secret values were recorded.

- Focused app/com and registration Rails tests: 46 runs, 222 assertions, 0 failures, 0 errors, 0 skips.
- Actor-known org/MFA/Step-Up and WebAuthn regression Rails tests: 115 runs, 602 assertions, 0
  failures, 0 errors, 0 skips.
- Architecture baseline and registration focused tests after the visibility fix: 20 runs, 3,135
  assertions, 0 failures, 0 errors, 0 skips.
- Rails full suite: 11,379 runs, 72,689 assertions, 0 failures, 0 errors, 5 skips.
- Frontend focused Passkey tests: 3 files, 93 tests passed.
- Frontend full Vitest suite: 85 files, 1,062 tests passed.
- `bun run typecheck`: passed.
- `bun run lint`: passed.
- `bun run format:check`: passed.
- Targeted Ruby RuboCop: 15 files inspected, no offenses.

The five Rails skips are existing suite skips; they were not added or changed by this remediation.
No production or remote database reset, external credential registration, or external service write
was performed.
