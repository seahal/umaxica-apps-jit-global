# Secure Jump Gateway Redirector (2026-05-28)

## Status

Accepted.

## Context

Redirect intent must not be represented as a raw URL in application query parameters. Raw
`return_to`, `redirect_uri`, `to`, `next`, or `url` parameters are too easy to turn into open
redirect aliases.

This Rails app also no longer hosts the Jump redirect endpoint. Redirects leave the app through the
external Jump gateway origin, for example `https://jump.umaxica.net/`.

## Decision

Rails issues only signed, short-lived Jump redirect tokens.

- The public Jump URL uses `?rt=`.
- `rt` is not a raw URL, raw path, opaque database public id, or generic return marker.
- `rt` must be a compact signed token with issuer, audience, purpose, expiry, and destination
  claims.
- Raw `return_to`, `redirect_uri`, or external URL values must never be copied directly into `?rt=`.
- Invalid, unsigned, malformed, expired, wrong-issuer, wrong-audience, or wrong-purpose `rt` values
  fail closed.

The external Jump gateway verifies the inbound Rails-issued token against the issuing surface JWKS.
For an internal return, the gateway issues its own signed return token and redirects back to the
app. The app verifies that returned token with `JumpRtReturnVerifier` against the Jump public JWKS
only (`https://jump.umaxica.net/.well-known/jwks.json` derived from the configured Jump origin).
Return tokens are ES384, at most 30 seconds, with 5 seconds of clock leeway. JWKS fetch failures
fail closed. Rails must not hold the Jump gateway private key.

This Rails app must not expose `jump_*` route helpers, DB-backed `JumpLink` models, or
`JumpLinkable` lifecycle behavior.

## Consequences

- The old `/?to=:public_id` DB-backed JumpLink flow is retired.
- `AppJumpLink`, `ComJumpLink`, `OrgJumpLink`, and `JumpLinkable` are not public application
  abstractions.
- Redirect safety lives in signed-token issuance and verification, not in per-surface redirect
  records.
- Tests must assert the absence of app-hosted Jump routes and legacy JumpLink models, and must cover
  issuer/audience/purpose/TTL validation for `rt`.
