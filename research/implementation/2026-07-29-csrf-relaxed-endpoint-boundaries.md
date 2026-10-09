# CSRF Relaxed Endpoint Boundaries Implementation Notes

## Context

- Original issue: GitHub #611
- Related decisions and docs:
  - `docs/security/security-headers.md`
  - `docs/security/observability-boundary.md`
  - `docs/vendor/identity/04_cookie-session-token-matrix.md`
- Implementation date: 2026-07-29

## Decisions Made During Implementation

- OAuth token exchange, Apple Server Notifications, and the six OIDC backchannel logout receivers
  now inherit from `ActionController::API`.
  - These endpoints do not use cookie or Rails session authentication.
  - OAuth token exchange relies on its client, grant, and PKCE contract.
  - Apple notifications require a bounded JSON body and a verified Apple JWS with issuer, audience,
    signature, freshness, and replay constraints.
  - Backchannel logout requires a verified logout token with issuer, audience, event, session id,
    and replay constraints.
  - The previous `null_session` declarations were removed because the API controller boundary
    expresses the protocol contract without loading browser CSRF protection.
- CSP violation report intake remains the sole explicit application CSRF exception.
  - Browser CSP reports cannot supply a Rails authenticity token and may use `Origin: null`.
  - The endpoint accepts bounded, sanitized, rate-limited, unauthenticated telemetry only.
  - It must not authenticate an actor or mutate user, account, session, cookie, or credential state.

## Review Notes

- Focused protocol, rate-limit, controller-boundary, and security-invariant tests were run.
- No database migration was required.
