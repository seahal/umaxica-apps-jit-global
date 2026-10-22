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

### Jump rt issuing origin (2026-09-28)

Three identifiers must not be conflated:

- **Logical ceremony issuer** — the `iss` of ceremony contracts (social, email, telephone,
  secret-credential, and similar), `https://log.umaxica.{app,com,org}` for the Auth surfaces. It
  names a trust domain and publishes no JWKS.
- **JWKS publication origin** — the origin whose `/.well-known/jwks.json` publishes a namespace's
  signing keys. For `SIGN_APP`, `SIGN_COM`, and `SIGN_ORG` that is the Auth host of the surface.
- **Jump rt issuing origin** — the `iss` of a Jump rt. Because the gateway verifies against the
  issuing surface JWKS, it must equal the JWKS publication origin of the key that signed the rt.

`JumpRtSurface.issuer_origin` owns the Jump rt issuing origin. For `SIGN_*` it reads the Auth hosts
(`sign_service`, `sign_corporate`, `sign_staff`) from the boot host registry, never from the request;
every other namespace's registry surface issuer already equals its JWKS publication origin. The
logical ceremony issuer in `JitSecurityJwtRegistry::SURFACE_ISSUER_ORIGINS` is unchanged.

The return side follows the same contract: `JumpRtReturnPolicy` accepts the Jump rt issuing origin
as the return `src`, not the logical ceremony issuer. The retired `log.umaxica.*` sources are not
accepted, since no Rails-issued rt carries them.

Observed gateway behavior (black-box, 2026-09-28): the gateway refuses an rt whose `url` origin
equals its `iss` (`x-jump-error: invalid_request`); it mediates cross-origin navigations only.

## Consequences

- The old `/?to=:public_id` DB-backed JumpLink flow is retired.
- `AppJumpLink`, `ComJumpLink`, `OrgJumpLink`, and `JumpLinkable` are not public application
  abstractions.
- Redirect safety lives in signed-token issuance and verification, not in per-surface redirect
  records.
- Tests must assert the absence of app-hosted Jump routes and legacy JumpLink models, and must cover
  issuer/audience/purpose/TTL validation for `rt`.

## Amendment: Deprecation of Jump RT External Destinations (2026-10-12)

**Status: Accepted — Deprecated for new use**

### Decision

`JumpRtIssuer.call(..., dst: "external")` is deprecated. New application code MUST NOT issue Jump RT
tokens with `dst: "external"`.

The same restriction applies to `CommonRedirect#redirect_to_jump_url` and any wrapper that issues an
equivalent external-destination Jump token.

`dst: "internal"` remains supported for approved first-party cross-origin handoffs governed by
`adr/jump-directed-rails-handoff-contract.md`.

### Responsibility Boundaries

- `pt`: Same-origin internal path targets.
- `nt`: Registered internal navigation targets.
- Jump RT: Approved first-party cross-origin handoffs.
- `xt`: External website destinations, intended to use the future `away.umaxica.net` gateway.

An origin difference alone does not classify a trusted first-party handoff as `xt`.

### Compatibility and Migration

The deprecated API remains available temporarily for compatibility. This decision does not
immediately remove the `"external"` enum value or alter existing runtime behavior.

Existing consumers must be inventoried before removal.

New callers MUST NOT use the deprecated mode. Until the Away contract is implemented, unsupported
outbound XT requests must fail closed rather than fall back to Jump external mode.

### Future Away Integration

External website navigation will be handled through the planned isolated `away.umaxica.net`
boundary; the direction is tracked in `plans/backlog/xt-away-external-navigation-gateway.md`.

The token format, issuer, audience, destination authorization, validation, and migration contract
require a separate design decision before implementation.

### Scope

This amendment changes the architectural contract only.

No Rails, Jump, or Away runtime behavior is changed by this decision.

## Amendment: Required Jump and Away Selection (2026-10-22)

**Status: Accepted; runtime implementation pending.**

This amendment supersedes gateway selection in the earlier amendments and the broad cross-origin
wording in [Rails Directed Jump Handoffs](jump-directed-rails-handoff-contract.md). Existing Jump
signing, verification and approved directed-edge requirements remain in force.

- Same-origin navigation MAY use a validated local path directly.
- Navigation between different subdomains of the same registered application domain MUST use
  `https://jump.umaxica.net` and an approved Jump edge.
- Cross-TLD navigation MUST use `https://away.umaxica.net`, including first-party destinations.
  Other external website navigation MUST also use Away.
- Rails MUST select the gateway from the initiating surface and final destination, before adding
  the gateway hop. Request input MUST NOT choose a gateway or expand destination permissions.
- Cross-origin browser navigation generated by Rails MUST use the common facade, whose immediate
  gateway destination MUST match exactly one of these two HTTPS origins. Rails helpers and
  `allow_other_host: true` do not provide this allowlist themselves.
- Unsupported destinations and unavailable Away integration MUST fail closed, with no direct or
  Jump fallback. Existing cross-origin POST and server-to-server transport contracts remain separate.

[Redirect Targets](../docs/security/redirect_targets.md#required-gateway-selection) owns the detailed
classification, origin validation and navigation requirements. Away's token format, audience,
issuer, receiver validation and rollout still require a separate implementation contract; Jump RT
MUST NOT be treated as Away authorization without that decision. OIDC registered callback URLs
remain final-receiver identities rather than gateway URLs.

This is a documentation-only decision. The existing single-Jump-gateway implementation and direct
cross-host callers have not been migrated. The absence of an Away implementation is not permission
to bypass the required route.
