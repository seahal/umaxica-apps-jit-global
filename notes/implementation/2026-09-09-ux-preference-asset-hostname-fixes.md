# UX / Preference / Asset / Hostname Fixes — Implementation Notes

## Context

- Task: investigate and fix an accumulated set of UX, preference, auth-surface, asset, and hostname
  issues under a strict TDD workflow.
- Implementation date: 2026-09-09.
- Baseline: `bin/rails test` before any change — 12856 runs, 21 failures, 0 errors, 2 skips. The 21
  failures are pre-existing and unrelated (see "Baseline failures" below).

## Decisions Made During Implementation

### 1. Auth header sign-in/up navigation removed outright

- Decision: delete `primary_navigation` from `SurfaceChrome` and the `<nav aria-label="Primary">`
  block from the three `auth/*/application.html.erb` layouts, plus the now-dead
  `@hide_auth_navigation` / `hide_sign_up_auth_navigation` mechanism and the
  `sign.{app,com,org}.layout.nav` locale keys.
- Why: `primary_navigation` was only ever populated for the auth family and only ever held
  sign-up / sign-in / logout, decided from `logged_in?` — the login-state awareness the task says
  the auth surface should not carry. In-page ceremony links (e.g. "already have an account?") live
  in the Inertia page bodies and are untouched.
- Alternatives considered: keeping the flag and returning `nil` — rejected as leaving dead
  machinery.

### 4. Side sign-out asset: no code change, add a guard

- Decision: `app/assets/stylesheets/application.css` exists and is correct at HEAD (the accepted
  2026-09-07 frontend-stack ADR puts side/core/jump/palm/base/auth `*/application` layouts on
  Importmap + Propshaft). The reported `Propshaft::MissingAssetError` reproduces only in a tree
  where that file is absent — it has been deleted and re-added several times during the stack
  churn. Added a contract test in `layouts_stylesheet_test.rb` pinning the file, its Propshaft
  resolution, and the importmap-not-Vite stack for every one of those layouts.
- Why not convert side to Vite: it would mix stacks in one surface, which the ADR forbids.

### 3. Region change resets the whole regional bundle

- Decision: extend the existing region→language force-update to also rewrite `date_format` and
  `time_format` to the region defaults, all in the one existing cross-DB dual-write transaction,
  all marked explicit.
  - US → English, `DateFormat::US`, `TimeFormat::HOUR_12`.
  - JP → Japanese, `DateFormat::ISO`, `TimeFormat::HOUR_24`.
- Why: the established product semantic (confirmed in `preference_core.rb` before this change and
  in `adr/localization-preference-flow.md`) is that a region change is a bundle reset — it already
  force-set language and marked it explicit. Extending to the other two region-owned defaults is
  consistent; each is still overridable on its own screen afterwards. Existing option
  records/enums are reused.
- `update_region_and_language_preferences!` renamed to `update_region_and_regional_defaults!`;
  `language_option_id_for_region_option` replaced by `regional_default_option_ids`.

### 5. Side gets its own web preference authority

- Decision: add `Side::{App,Com,Org}::Web::V0::{Themes,Cookies}Controller` and routes, mirroring
  the auth and core web preference authorities exactly (same shared `PreferenceWeb*` concerns).
- Why: the Side chrome renders theme and cookie-consent controls, but `config/routes/side.rb` had
  no `/web/v0/*` routes, so the control's `PATCH /web/v0/theme` 404'd and the frontend swallowed
  it as a best-effort write. Auth and core already carry these endpoints; Side was the outlier.
- The `persistTheme` / `fetchStoredTheme` best-effort JS behaviour is deliberate and covered by
  `spec/lib/theme.test.ts` ("keeps the requested theme when the endpoint rejects the write") — the
  cookie is a legitimate local fallback. It is left as-is; the missing endpoint was the bug.

### 6. Turnstile frozen-URI fix is central

- Decision: fix `OutboundHttp::Connection.build` to work on a private copy of the URI, rather than
  only unfreezing `JitSecurityTurnstileVerifier::VERIFY_URI`.
- Why: Faraday mutates the URI passed to `Faraday.new(url:)`. Every caller that passes a shared URI
  constant was exposed; `VERIFY_URI` was merely the only `.freeze`d one, so it was the only one
  that raised. The central fix also stops the non-frozen shared constants (e.g. the Apple JWKS
  URI) being rewritten under concurrent requests.

### 7. i18n propagation — audit result, not a rewrite

- Finding: auth and side already resolve the locale from the preference JWT (`Actor.preferences`)
  and the `?lx` overlay only, through the shared `PreferenceGlobal` / `PreferenceLocalization` /
  `ActorSupport` concerns. The domain-scoped `language` / `ct` / `tz` cookies are write-only
  browser mirrors and are read by no request code — there is no competing second source to remove.
  Added `preference_read_symmetry_test.rb` contract tests pinning that a stale/forged `language`
  cookie cannot override the resolved locale.
- Remaining gap (not fixed here): an anonymous language choice on www is not seen on a first visit
  to auth/side, because `__Host-preference_access` is host-scoped and `?lx` is deliberately not
  auto-forwarded (`adr/localization-preference-flow.md`, pinned by
  `preference_global_param_context_test.rb`: "lx NOT added to navigation links when NOT in
  request", "redirect to add ri does NOT add lx automatically"). Closing it needs a cross-surface
  preference handoff (a signed param, or a deliberately domain-scoped read-only projection cookie)
  — an ADR-level design decision. Signed-in users are unaffected: `PreferenceAdoption` reconciles
  each surface token with the shared per-account preference on every request. This should be
  promoted to `plans/`.

### 9. EID → GUID migration is a clean cut

- Decision: rename the EID surface to GUID, move `eid.umaxica.net` → `guid.umaxica.id` (prod) and
  `eid.net.localhost` → `guid.net.localhost:3000` (dev), with no compatibility period.
- Why no compat period: nothing outside the repository consumed `eid.*` — the edge route table is
  derived from `config/routes/*.rb`, and there is no external registration against the EID host.
  Keeping both would leave `.id` and `.net` mixed, which the task forbids.
- `.net` in `guid.net.localhost` is the internal surface-family label every localhost origin uses
  (`base.net.localhost`, `core.net.localhost`), not a public TLD; it is the deliberate matched
  pair with the `.id` public host.
- The devcontainer network never had `eid` aliases; `guid.net.localhost` and `guid.umaxica.id` are
  now added.
- Deployment action required outside this repo: production must set `PUBLIC_GUID_SERVICE_URL`
  instead of `PUBLIC_EID_SERVICE_URL` before boot (documented in the ADR).

## Deviations From Plan

- #9 was specified as migrating a `guid`/`uid` service. No such service, string, or `.id` TLD
  exists anywhere in the repo. On the user's explicit instruction the EID surface was treated as
  the service and migrated. `adr/eid-entity-identifier-surface.md` is superseded by
  `adr/guid-identifier-surface.md`.
- #7's cross-surface anonymous propagation gap was not closed (see above) — it is architecture, not
  a bug fix, and improvising it would contradict an accepted ADR and its regression tests.

## Review Notes

- Tests run: per-issue targeted suites (all green), full `bun run test` (1047 pass), `bin/brakeman`
  (0 warnings), `bun run format:check` / `typecheck` / `lint` (clean), full `bin/rails test` (see
  evidence file `evidence/2026-09-09-ux-preference-asset-hostname-fixes.md`).
- Baseline failures (pre-existing, unrelated — confirmed present before any change):
  - `*HealthsControllerTest` ×9 (`auth/{app,com,org}`, `base`, `base/{app,com,org}`,
    `acme_roots_test` SurfaceHealthEndpointTest) — a `/x` extended-regex vs plaintext-body
    mismatch.
  - `Base::Org::Publishing::EntryArchivesControllerTest` ×2.
  - `Base::Org::Support::AccountSessionsControllerTest` ×5.
  - `Auth::Org::VerificationsControllerTest` ×4 (302 to `www.umaxica.org/oauth/authorize` instead
    of 2xx).
  - `AuthSettingsRemovalCompatibilityTest` ×1 (org passkey removal redirect).
