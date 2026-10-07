# Token Lifetime Policy By Surface

## Status

Accepted (2026-06-02)

Implementation is deferred. The codebase is under large-scale editing, so this ADR records the
accepted policy only. The implementation steps are tracked in
`plans/backlog/token-lifetime-policy-by-surface-implementation.md`; no token-lifetime constants are
changed by this ADR.

## Context

`adr/acme-session-and-token-authority.md` makes `acme/www` the single authority for user sessions,
refresh-token families, access-token issuance, and step-up freshness. That ADR fixes _who_ issues
and rotates tokens but does not fix _how long_ each token lives per surface.

The current canonical lifetimes are:

- Access token: `Security::TokenLifetimes::AUTH_ACCESS_JWT_TTL = 1.hour`
  (`Authentication::Base::ACCESS_TOKEN_TTL`).
- Refresh token: `Authentication::Base::REFRESH_TOKEN_TTL = 30.days`, mirrored by
  `Refreshtokenable::REFRESH_TTL = 30.days`.
- Step-up freshness: `StepUp::Requirement::DEFAULT_TTL = 15.minutes`.
- Restricted session: `Authentication::Base::RESTRICTED_SESSION_TTL = 15.minutes`.
- Login session: `VisitorToken::LOGIN_SESSION_TTL` and
  `OperatorToken::LOGIN_SESSION_TTL = 12.hours`.

A separate "1 year" value (`expires: 365.days`) lives in `config/environments/production.rb`, but it
is the **HSTS `max-age`** (`config.ssl_options.hsts`), not an auth-cookie expiry. The auth cookie
has no independent one-year horizon; its expiry follows the access/refresh TTLs. This ADR makes the
refresh-token TTL the governing session horizon per surface, and the auth cookie horizon must not
exceed it.

These values are applied uniformly across surfaces today. The `org` (staff / operator) surface
carries stronger business authority than the `app` (end-user) surface, so a uniform refresh horizon
over-exposes staff sessions. A long-lived refresh horizon (any multi-month refresh, up to a one-year
reach) on a staff surface is too aggressive for the privilege it grants.

## Decision

Token lifetimes are set per surface. `acme/www` remains the only authority that issues and enforces
these lifetimes.

### `app` (end-user) surface

- Access token: 5–15 minutes (down from the current 1 hour). 15 minutes is the upper bound; 5
  minutes is acceptable.
- Refresh token: 30–90 days. The existing 30-day refresh TTL stays inside this band. A longer
  horizon (up to one year) is permitted **only if** refresh-token rotation and reuse/replay
  detection are active for that family. Rotation and reuse detection are mandatory whenever the
  refresh horizon exceeds 90 days.

### `org` (staff / operator) surface

- Access token: ~5 minutes. The staff surface leans to the short end of the access-token band.
- Refresh token: 8–12 hours, or at most a few days. The multi-month / one-year horizon is not
  permitted on `org`.
- Step-up freshness: unchanged at 15 minutes (`StepUp::Requirement::DEFAULT_TTL`).

### Cross-cutting requirements

- Refresh-token rotation and reuse/replay detection remain mandatory regardless of surface, per
  `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md`. The 90-day-plus `app` allowance does
  not relax this; it depends on it.
- Refreshed access tokens keep `acr=aal1` and step-up freshness stays non-sticky across refresh, per
  `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md`.
- The production auth cookie horizon must not exceed the surface refresh-token TTL. The cookie is a
  transport horizon, not an independent session-lifetime authority.

## Consequences

- `app` access tokens get shorter, increasing refresh frequency. Because access refresh is
  transparent and rotation is already in place, the user-visible cost is low while the exposure
  window of a leaked access token shrinks.
- `org` sessions become substantially shorter-lived, requiring staff to re-authenticate within hours
  rather than days. This is the intended trade for the stronger authority staff hold.
- The one-year reach for `app` is retained as an option but is now explicitly gated on rotation plus
  reuse detection, not granted by default.
- Lifetime constants must become surface-aware rather than a single shared pair. The implementation
  plan covers where the per-surface split lands (`Security::TokenLifetimes`, `Authentication::Base`,
  and the operator/visitor token models).

## Related

- `adr/acme-session-and-token-authority.md`
- `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md`
- `adr/authentication-assurance-level-boundaries.md`
- `adr/step-up-authentication-redesign.md`
- `adr/cookie-domain-scope-by-surface.md`
- `plans/backlog/token-lifetime-policy-by-surface-implementation.md`

## Delivered reconciliation (2026-10-06)

The implementation cycle applied the surface-aware lifetimes to root sessions, step-up freshness,
RP access and refresh credentials, and app Secret evidence. A step-up continuation extends no
freshness window. RP refresh evaluates the refresh credential independently of access and uses the
bounded encrypted delivery receipt described by `adr/base-authority-and-self-rp-separation.md`.
The former “implementation is deferred” statement is superseded for these boundaries; unrelated
future lifetime policy remains outside this cycle.
