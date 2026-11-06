# three.md section 8: static com acceptance checks (no Rails tests run)

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`; the worktree had 850 changed paths. No commit
  was made.
- Scope: static checks only (file and route inspection). No Rails test was run, because another
  process (`bin/rails test`, full suite, started about 7 minutes earlier) was using the shared test
  databases at the time. No browser check. No production or Neon access. No application source
  changed; only `three.md` (a gitignored working document) was updated.

## Observed

- TC-10-1: in `config/database.yml` the only com connections left are `com_setting` and
  `com_setting_replica` (development, test, production). A search for `com_zenith`, `com_signal`,
  `op_base_com`, `rp_base_com`, `rp_core_com`, `rp_warp_com` in `config/database.yml`,
  `config/ci.rb`, `.env.container.devcontainer`, and `app`, `config`, `lib` (`*.rb`, `*.yml`)
  returned nothing.
- TC-1-1 / TC-2-1 / TC-3-1 (route level only): `RAILS_ENV=test bin/rails routes` printed 1,375
  lines. No route contains `visitor`; no `auth_com`, `visa_com` or `core_com` route prefix exists;
  there is no `app/controllers/{auth,visa,core}/com` directory. HTTP 404 behavior was not exercised.
- TC-1-2: 14 `warp_com` routes exist: root, revision, health (liveness, readiness, startup, api
  health), api revision, robots, sitemap, settings, CSP report, PWA service worker and offline. No
  sign, OIDC, dashboard or Preference cookie/theme route is present for Warp com.
- TC-5-1: `base_com` has 30 routes: preference index and PATCH screens (calendar, clock, cookie,
  currency, density, language, motion, pagination, region, screen, theme, timezone), DELETE
  customization, health, revision, robots, sitemap, CSP report, PWA, and
  `/api/v0/preferences/{cookie,theme,web_push}` with show and update.
- TC-CSRF-1: a diff against `b6e787107` of `app`, `config`, `lib` found no added
  `skip_forgery_protection`, `skip_before_action :verify_authenticity_token`, or weakened origin
  check line.
- TC-25-2 / TC-29-1 (name search only): no `__Secure-assurance`, `preference_refresh`,
  `preference_dbsc` or `PreferenceAdoption` in `app`, `config`, `lib` (`*.rb`).

## Findings (not fixed)

- TC-12-1 (com authentication remnants): `app/services/jit_security_jwt_anomaly_reporter.rb:54` maps
  `"visitor"` and `"customer"` to `AUTH_VISITOR`;
  `app/services/core_browser_credential_contract.rb:99` maps `"visitor"` to `surface:CORE_COM`;
  `app/models/concerns/auth_ceremony_session.rb:320` lists `visitor_id` among keys;
  `app/models/actor.rb:53` delegates `visitor?`. Whether each is a live com-realm remnant or an
  unrelated unauthenticated-actor concept was not established.
- TC-24-2 / TC-37-3 (app/org scope, not com): Auth, Core and Warp (app and org) still route
  `api/v0/preferences/{cookies,themes}#show` and `#update`; the theme update path calls
  `apply_theme_update!`, which writes a theme child record. AC-24 and AC-37 say no host other than
  Base and Visa has a Preference write path. This belongs to WU-9 acceptance, which is not closed.

## Not verified

- All Rails (H/J) acceptance cases for com, the baseline comparison, and every browser (B) case.
  They are waiting for the running full suite to finish so the shared test databases are free.
