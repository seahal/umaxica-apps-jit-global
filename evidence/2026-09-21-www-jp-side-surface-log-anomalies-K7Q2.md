# www-jp Side Surface Log Anomalies

- Date: 2026-09-21
- Commit: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9` (worktree had many uncommitted changes; the log
  reflects whatever code the development server had loaded at request time)
- Source: `log/development.log` (27 lines mention `www-jp`, around lines 2503 and 160400–161060),
  `log/development.access.jsonl` (7 entries)
- Scope: requests with host `www-jp.umaxica.{app,com,org}` (`Side::{App,Com,Org}::*` controllers)

## Summary

| # | Symptom | Hosts | Count in window | Root cause |
| - | ------- | ----- | --------------- | ---------- |
| 1 | `422 Unprocessable Content` on SSO start, `redirect_target.rejected reason=invalid_jump_rt_url` | app, org, com | 5 | `JumpRtSurface.namespace_for_controller` has no `Side::` branch |
| 2 | `401 Unauthorized` on top-level HTML `GET /`, `preference.token.refresh.failed` | com | 1 | Stale preference refresh cookie; hard-fails an HTML navigation |
| 3 | `security.csp_violation.reported` for `wss://localhost:3036/vite-dev/` | app, com, org | every page view | CSP allows `wss://<request host>:3036`, Vite HMR client connects to `wss://localhost:3036` |

## 1. SSO start returns 422 (blocking)

Observed (`Side::App::Sign::EntriesController#create`, `Side::App::DashboardsController#show`,
`Side::Org::Sign::EntriesController#create`, and two `Side::Com::*` requests):

```
oidc.sso.redirect_policy.jump  request_host=www-jp.umaxica.app target_host=base.app.localhost
                               decision=jump reason_code=site_mismatch
redirect_target.rejected       kind=external source=jump_rt_issue reason=invalid_jump_rt_url
Filter chain halted as :enforce_access_policy!
Completed 422 Unprocessable Content
```

Sign-in and every `auth_required` page on the side surfaces is therefore unusable.

Cause chain, confirmed with `bin/rails runner` in this session:

1. `OidcSsoInitiator#redirect_to_oidc_authorization_url` chooses `:jump` because the side host
   (`*.umaxica.*`) and the authorize host (`base.*.localhost`) are cross-site.
2. `CommonRedirect#redirect_to_jump_url` defaults `namespace:` to
   `JumpRtSurface.namespace_for_controller(self.class.name)`
   (`app/values/jump_rt_surface.rb:11`). Its service regex covers `Auth|Sign`, `Acme`, `Core`,
   `Base` only. `namespace_for_controller("Side::App::Sign::EntriesController")` returns `nil`.
3. `JumpRtIssuer#initialize` calls `JumpRtSurface.normalize_namespace(nil)`, which raises
   `ArgumentError, "unsupported Jump RT issuer surface: nil"`.
4. `redirect_to_jump_url` rescues `ArgumentError` and turns it into `token = nil`
   (`app/controllers/concerns/common_redirect.rb:47`).
5. The nil token is logged as `invalid_jump_rt_url`, although the URL
   (`https://base.app.localhost/oauth/authorize?...`) is valid. The real error is lost.

Even with a `Side` branch, `JitSecurityJwtRegistry::SURFACE_NAMESPACES`
(`lib/jit_security_jwt_registry.rb:16`) contains no `SIDE_*` entry (only
`OIDC_CLIENT_NAMESPACES` does), so the side surfaces have no Jump RT signing key. Which namespace
a side controller should sign with is a design decision, not a one-line fix.

Refactoring grounds:

- Surface/service identity is derived from controller class-name regexes in more than one place,
  and the lists have drifted (`SURFACE_NAMESPACES` vs `OIDC_CLIENT_NAMESPACES` vs
  `namespace_for_controller`). A single declared surface registry would make a missing surface a
  boot-time error instead of a per-request 422.
- `rescue ArgumentError` → `nil` in `redirect_to_jump_url`, plus the `return nil` guards in
  `JumpRtIssuer#call`, collapse configuration errors (unknown namespace, missing key) and input
  errors (bad URL) into one reason. This conflicts with `generic/no-silent-fallback.mdc` and
  `generic/fail-fast.mdc`: a configuration defect should raise, and input rejection should carry
  its specific reason.

## 2. Preference refresh returns 401 on an HTML navigation

Observed (`Side::Com::RootsController#index`):

```
preference.token.refresh.failed  preference_type=ComPreference format=html path=/
Filter chain halted as :set_preferences_cookie
Completed 401 Unauthorized
```

The next request (cookies already cleared by `handle_preference_refresh_failed`) created a new
preference (302, 207 ms, 84 queries) and then rendered 200. The browser saw a bare 401 page in
between.

Cause: `PreferenceRefreshTokenTransport#load_preference_record_from_refresh_token!` found the
preference but the presented refresh token was not valid (not a replay), and
`PreferenceTransport#set_preferences_cookie` calls `render_preference_refresh_error!` regardless of
request format. The exact sub-reason (digest mismatch, expiry, revocation) is not in the log:
`preference.token.refresh.failed` has no `reason` field, unlike `refresh.binding_denied`.
The most likely trigger is a refresh cookie issued by an earlier server/database state for the same
public id, but the log alone cannot confirm which check failed.

Refactoring grounds:

- A preference token (theme, language, cookie consent) is not an authentication credential; failing
  a top-level HTML navigation with 401 is disproportionate when the same code path self-heals on
  the next request. Decide explicitly whether HTML requests should clear and re-issue in the same
  request.
- Add the failing check as a `reason` to `preference.token.refresh.failed`, matching the
  binding-denied event, so the failure is diagnosable.
- The recovery request cost 84 queries for preference creation; worth measuring separately.

## 3. CSP blocks the Vite HMR WebSocket (development only)

Observed on every side page:

```
blocked_uri=wss://localhost:3036/vite-dev/  effective_directive=connect-src
original_policy: connect-src 'self' https://challenges.cloudflare.com
                 ws://www-jp.umaxica.app:3036 wss://www-jp.umaxica.app:3036
```

Cause: `config/initializers/content_security_policy.rb:61` allows the Vite port on the *request
host*, but `vite.config.ts` sets no `server.hmr.host`, so the Vite client connects to the dev
server's configured host (`localhost`). The CSP comment assumes the two hosts are the same; that
assumption breaks once development is reached through the public `www-jp.*` hostnames
(`vite.config.ts` `allowedHosts` already anticipates this). Effect: no hot reload and noisy CSP
reports; no production impact.

Refactoring grounds: derive both the CSP source and the Vite HMR host from one setting instead of
two independent assumptions.

## Not an anomaly

- `302` from `set_region` (`/` → `/?ri=jp`) and `303` from `Sign::OutsController#new` are normal.
- Base surfaces redirecting to `www.umaxica.app/?ri=us` are outside this scope.
