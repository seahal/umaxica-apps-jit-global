# Refresh/Revoke AAL Downgrade And Replay Hardening

## Status

Accepted on 2026-04-07.

> **Partial supersession (2026-06-02):** The vocabulary and security properties in this ADR remain
> useful, but authority ownership is superseded by `adr/identity-authority-boundary.md`. `acme/www`
> owns session, token, account, preference, authorization, downstream-token trust, and step-up
> freshness. `sign/id` owns only credential inventory and short-lived credential ceremony state.

## Context

GitHub issue `#612` tracked three concrete requirements in the authentication pipeline:

- refreshed access tokens must downgrade to `acr=aal1`
- revoked session state must block refresh
- replay and family-compromise paths must be covered by tests

The current codebase now implements these behaviors in the refresh path and documents the token
claim normalization in code.

## Decision

The authentication pipeline keeps `aal1` as the default access-token context after refresh, even if
the previous interaction reached a higher assurance level.

Refresh token reuse is treated as a compromise event. When replay is detected, the system revokes
all tokens for the same actor and emits security telemetry.

Normal revoke state also blocks later refresh attempts.

## Evidence

- `Authorization::TokenClaims.normalize_acr` defaults blank values to `aal1`.
- `Sign::RefreshTokenService` handles replay as a first-class branch and revokes actor token
  families.
- `test/controllers/sign/org/edge/v0/token/refreshes_controller_test.rb` verifies:
  - refreshed access tokens carry `acr=aal1`
  - refreshed access tokens clear `amr`
  - replay returns `401` and records `refresh_reuse_detected`
  - revoked session tokens return `401`
- `test/services/sign/refresh_token_service_test.rb` verifies:
  - rotation increments the generation counter
  - replay revokes all actor tokens and marks compromise
  - revoked tokens stay invalid without false compromise marking

## Consequences

- Step-up state is intentionally not sticky across refresh.
- Replay detection is part of the security contract, not a best-effort extra.
- Future work such as hard revoke or real-time revoke should build on this baseline rather than
  weaken it.

## Related

- Related notes: `adr/oidc-claims-decision.md`
