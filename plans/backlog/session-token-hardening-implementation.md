# Session/Token Hardening — Implementation

**Status: BACKLOG. Deferred while the codebase is under large-scale editing.**

This plan implements the accepted decision in `adr/session-token-hardening-baseline.md`. Do not
start the remaining implementation until the current large-scale edits settle and this plan is
promoted to `specs/`. This file changes no code by itself.

## Goal

Bring production session/token handling up to the accepted hardening baseline. Several targets are
already met; the remaining work below covers credential-change revocation, the step-up
refresh-family decision, optional broader no-store behavior, and future tuning of renewal policy.

## Current State (evidence)

- Cookie options: `Authentication::CookieService#auth_cookie_options` → `Core::CookieOptions.for`
  (`app/services/core/cookie_options.rb`): `httponly:true`, `path:"/"`, `domain:false`, `secure`
  (prod), `same_site::strict` (DONE), `partitioned:true` (prod). Cookie name prefixes are gated on
  `Jit::SessionCookieConfig.force_secure?` (`app/config/auth/io_keys.rb`,
  `Authentication::CookieName`).
- Cookie prefix map: `__Host-` for auth (access/refresh/DBSC), session (`__Host-session`), and
  verification cookies (all host-only); `__Secure-` for preference cookies (apex-scoped for
  cross-subdomain reads, so `__Host-` is not possible).
- Refresh token opaque (digest-only) + rotation/reuse/family-revoke: `Sign::RefreshTokenService`,
  `RefreshTokenable` (`rotate_refresh!`, `create_rotated_token_record!`).
- Access token JWT: `Authentication::JwtTokens` (accepted, no change).
- Re-issue: login `reset_session` at `app/controllers/concerns/authentication/base.rb:352`; step-up
  `Sign::VerificationStepUpLifecycle#consume_step_up_session!` (`reset_session` + freshness stamp,
  no refresh-family rotation); risk `Sign::Risk::Enforcer` clears step-up freshness.
- Timeouts: `RefreshTokenable::REFRESH_TTL = 30.days` absolute (preserved across rotation). Idle
  expiry is implemented through the token-theft hardening slice and `SecurityTokenLifetimes`; future
  work may still tune renewal policy and per-surface values.
- HSTS: `config/environments/production.rb` `ssl_options.hsts` `expires:365.days`, `subdomains:true`
  (enabled), `preload:false` (deferred).
- Logout: `Authentication::Logoutable`, `Authentication::SessionRevoker.revoke_all_for`.

## Implementation Steps

1. **Cookie SameSite=Strict.** DONE: `same_site: :lax` → `:strict` in
   `Authentication::CookieService#auth_cookie_options` and `auth_cookie_deletion_options`, with the
   auth-cookie tests updated to expect `:strict` (cookie_service_test, base_coverage_test,
   cookie_security_invariant_test, app/org edge token refreshes_controller_test). Tests could not be
   executed yet: the suite does not boot due to an unrelated in-flight routing error
   (`config/routes/acme.rb` references undefined `acme_app_host`). Re-run once the routing refactor
   settles, and verify OIDC/social callback and signed return-target flows still complete (callbacks
   must set the cookie on their own response).
2. **Credential-change revocation.** On password / passkey / email-credential change, revoke other
   active sessions and refresh-token families for the actor via
   `Authentication::SessionRevoker.revoke_all_for` (or `logout_all_sessions_for!` at the controller
   boundary). Keep the current session alive where the change is self-service; revoke the rest. Wire
   this at the credential-write boundary, not in a controller `after_action`.
3. **Idle timeout + sliding renewal.** DONE for idle expiry in the token-theft hardening slice:
   refresh and access-token resolution enforce idle windows through `SecurityTokenLifetimes`.
   Remaining future work is renewal tuning, if needed, without extending beyond the absolute cap
   (`discarded_at`).
4. **Step-up re-issue decision.** Decide whether step-up elevation rotates the refresh-token family
   in addition to `reset_session`. If yes, call the rotation path inside `consume_step_up_session!`.
5. **HSTS strict.** DONE for `includeSubDomains`: `subdomains: true` is set in
   `config/environments/production.rb` (production only, one-year max-age). `preload` is still
   `false` and deferred — enabling it is effectively irreversible and requires reviewing the asset
   host (`asset-jp.umaxica.net`) and regional domains first. Note the CDN may override the header.
6. **(Optional) Global no-store.** Broaden `Cache-Control: no-store` to authenticated HTML responses
   rather than only the current selective endpoints.

## Test Plan

- Cookie attributes: `Set-Cookie` carries `__Host-` prefix, `Secure`, `HttpOnly`, `SameSite=Strict`,
  `Path=/`, no `Domain`, `Partitioned` in production.
- Credential change revokes other sessions/refresh families and keeps (or drops) the current session
  per the chosen policy.
- Idle timeout expires an unused session; future sliding renewal tuning must not exceed the absolute
  cap.
- Step-up elevation behaves per step 4 (session id rotated; refresh family rotated if decided).
- HSTS header carries `includeSubDomains; preload` with the configured max-age.
- Re-run refresh/revoke/replay suites to confirm rotation + reuse detection still hold.

## Open Questions

- Whether the current per-surface idle timeout values need product tuning.
- Whether step-up elevation rotates the refresh-token family (step 4).
- Whether to enable HSTS `preload` given it is effectively irreversible for affected domains (step
  5).
- Whether credential change keeps the current session or forces a full re-login (step 2).

## Related

- `adr/session-token-hardening-baseline.md` (accepted decision)
- `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md`
- `adr/session-reset-on-privilege-transition.md`
- `adr/token-lifetime-policy-by-surface.md`
