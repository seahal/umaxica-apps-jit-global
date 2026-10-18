# Token Lifetime Policy By Surface — Implementation

**Status: BACKLOG. Deferred while the codebase is under large-scale editing.**

This plan implements the accepted decision in `adr/token-lifetime-policy-by-surface.md`. Do not
start implementation until the current large-scale edits settle and this plan is promoted to
`specs/`. This file changes no code by itself.

## Goal

Make token lifetimes surface-aware:

- `app` (end-user): access token 5–15 min; refresh token 30–90 days (one-year reach only with
  rotation + reuse detection).
- `org` (staff / operator): access token ~5 min; refresh token 8–12 hours up to a few days; step-up
  freshness unchanged at 15 min.

`acme/www` stays the only authority that issues and enforces these lifetimes.

## Current State

Single shared lifetimes applied across surfaces:

- `app/services/security/token_lifetimes.rb`: `AUTH_ACCESS_JWT_TTL = 1.hour`.
- `app/controllers/concerns/authentication/base.rb`: `ACCESS_TOKEN_TTL = AUTH_ACCESS_JWT_TTL`,
  `REFRESH_TOKEN_TTL = 30.days`, `RESTRICTED_SESSION_TTL = 15.minutes`.
- `app/models/concerns/refresh_tokenable.rb`: `REFRESH_TTL = 30.days`.
- `app/models/visitor_token.rb` / `app/models/operator_token.rb`: `LOGIN_SESSION_TTL = 12.hours`.
- `app/services/step_up/requirement.rb`: `DEFAULT_TTL = 15.minutes`.
- `config/environments/production.rb`: auth cookie `expires: 365.days` (the only "1 year" value; the
  refresh-token record TTL is already 30 days).

## Implementation Steps

1. Introduce surface-aware lifetime constants. Decide the home for the split — extend
   `Security::TokenLifetimes` with per-surface access/refresh values and have `Authentication::Base`
   (and the operator/visitor token models) read the surface-correct value rather than a single
   shared `ACCESS_TOKEN_TTL` / `REFRESH_TOKEN_TTL`.
2. Set `app` access TTL to a value in 5–15 min (target: 15 min upper bound, confirm with product
   before going to 5 min) and keep `app` refresh TTL at 30 days. Leave the >90-day path gated behind
   active rotation + reuse detection; do not enable it by default.
3. Set `org` access TTL to ~5 min and `org` refresh TTL to 8–12 hours (start at the conservative
   end; confirm whether "a few days" is needed operationally before widening).
4. Align the production auth cookie horizon so it never exceeds the surface refresh TTL. The cookie
   is a transport horizon, not an independent session lifetime.
5. Confirm step-up freshness stays at 15 min (`StepUp::Requirement::DEFAULT_TTL`); no change.
6. Verify refreshed access tokens still downgrade to `acr=aal1` and that step-up freshness remains
   non-sticky across refresh after the lifetime split.

## Test Plan

- Update refresh-token service / token-model tests to assert per-surface TTLs rather than a single
  shared value.
- Add controller coverage that `app` and `org` access tokens expire on their respective horizons.
- Add coverage that the auth cookie horizon does not outlive the surface refresh TTL.
- Re-run the existing refresh/revoke/replay tests referenced in
  `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md` to confirm rotation and reuse detection
  still hold under the new horizons.

## Open Questions

- `app` access TTL target: 15 min or 5 min? ADR allows the band; pick a concrete value with product.
- `org` refresh TTL target: 8–12 hours vs a few days? Start at 8–12 hours unless operations need
  longer.
- Where the per-surface split physically lives (single `TokenLifetimes` map vs surface-local
  constants) — settle during step 1.

## Related

- `adr/token-lifetime-policy-by-surface.md` (accepted decision)
- `adr/acme-session-and-token-authority.md`
- `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md`
- `adr/step-up-authentication-redesign.md`
