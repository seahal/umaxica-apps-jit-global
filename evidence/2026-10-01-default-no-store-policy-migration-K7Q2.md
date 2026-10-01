# Default No-Store Policy Migration

- Date: 2026-10-01
- Commit: `3133db7f909b191dc3f0a4e44092c2ad4725870a`, with uncommitted changes. All results below
  were obtained on the working tree carrying this migration plus the user's pre-existing uncommitted
  Xper changes (`app/assets/stylesheets/xper.css`, `app/views/layouts/xper/app/application.html.erb`,
  `app/views/xper/app/roots/index.html.erb`), which were not modified.
- Decision: `adr/global-and-publishing-default-no-store-policy.md`. Current rules and inventory:
  `docs/reference/http-cache-policy.md`.

## Baseline

`bundle exec rails test` before any controller change: 12137 runs, 1 failure, 2 skips. The failure
was `FlatRubySourceLayoutInvariantTest`, reporting `app/controllers/concerns/default_no_store.rb:
missing DefaultNoStore` because the concern file was created while the suite was running, after
eager loading. It passed in every later run. `bun run test`: 87 files, 1067 tests passed.

## Per-root procedure

For each policy root, in this order: add representative request tests (200, redirect where the
family has one, response halted by the FQDN availability gate) and move the root into the invariant
test's `POLICY_ROOTS`; run them and observe the failures ("RED"); declare
`include ::DefaultNoStore` and `prepend_before_action :apply_default_no_store` on the root; run the
targeted Minitest files, the policy and gate invariants, and `bun run test`. A full
`bundle exec rails test` and `bun run test` ran after each family. Tests for roots not yet migrated
were excluded from intermediate runs by `-n` name filter.

Order: Xper (app, com, org ApplicationController; app, com, org BareController), Auth (app, com, org
ApplicationController; app, com, org BareController; RedirectOnlyController), Base (app, com, org,
dev, net ApplicationController; then BareController), Edit (ApplicationController,
BareController), Guid (BareController), Info, Docs, News, Help (app, com, org BareController).

Every root showed failing tests before its declaration and passed after it. Targeted results per
root (last line per root; earlier failing lines in the run log were test or script mistakes, listed
below):

| Root | Targeted Minitest | Vitest |
| --- | --- | --- |
| Xper app/com/org Application | 57 / 59 / 61 runs, 0 failures | 1067 passed |
| Xper app/com/org Bare | 63 / 65 / 67 runs, 0 failures | 1067 passed |
| Auth app/com/org Application | 871 / 533 / 461 runs, 0 failures | 1067 passed |
| Auth app/com/org Bare | 861 / 407 / 411 runs, 0 failures | 1067 passed |
| Auth RedirectOnly | 1168 runs, 0 failures | 1067 passed |
| Base app/com/org/dev/net Application | 275 / 911 / 914 / 916 / 918 runs, 0 failures | 1067 passed |
| Base app/com/org/dev/net Bare | 922 / 925 / 928 / 930 / 932 runs, 0 failures | 1067 passed |
| Edit Application / Bare | 76 / 88 runs, 0 failures | 1067 passed |
| Guid Bare | 44 runs, 0 failures | 1067 passed |
| Info app/com/org | 92 / 95 / 98 runs, 0 failures | 1067 passed |
| Docs app/com/org | 101 / 104 / 107 runs, 0 failures | 1067 passed |
| News app/com/org | 110 / 113 / 116 runs, 0 failures | 1067 passed |
| Help app/com/org | 119 / 122 / 125 runs, 0 failures | 1067 passed |

Family full runs (`bundle exec rails test`; `bun run test` 1067 passed each time):

| After | Rails |
| --- | --- |
| Xper | 12157 runs, 0 failures, 0 errors, 2 skips |
| Auth | 12177 runs, 0 failures, 0 errors, 2 skips |
| Base | first run 32 failures (below); rerun 12204 runs, 0 failures, 0 errors, 2 skips |
| Edit + Guid (one combined run; Guid was migrated before Edit's full run) | 12211 runs, 0 failures |
| Info (later-family cases excluded by name) | 12220 runs, 0 failures |
| Docs | 12229 runs, 0 failures |
| News | 12238 runs, 0 failures |
| Help | 12247 runs, 0 failures, 0 errors, 2 skips |

## Failures found and how they were resolved

- Base full run, 32 failures: 30 were the not-yet-migrated Edit/Guid/content test files written
  ahead of migration; they were held out of the rerun. Two were real:
  `AuthenticatedResponseCachePolicyTest` asserted that an anonymous public Base HTML page and an
  authenticated JSON response were *not* `no-store`. That was the old contract; the ADR changes it,
  and both tests now assert `no-store`.
- `ensure_fqdn_gate_first!` reorders the gate ahead of `apply_default_no_store` in Auth preference,
  sign-in check, sign-in session, and OIDC handoff controllers, and `OidcRpLogoutLauncher` does the
  same in `Edit::Org::Sign::OutsController`. The invariant test failed for each; each now
  re-prepends `apply_default_no_store`.
- The sitemap concern wrote a cacheable `Cache-Control` directly. With the default in place the
  Auth sitemap returned `no-store`; `Sitemap#show_xml` now uses `expires_in` and returns
  `max-age=300, public, s-maxage=600`.
- `FqdnAvailabilityGateTest` required the gate to be the very first callback. It now allows exactly
  `apply_default_no_store` ahead of it.
- Test and script mistakes (not code defects): an Edit root test missing `ri=jp`; a wrong test path
  in one gate invocation; a trimmed test file with a syntax error in the first Info full run. Each was
  rerun as recorded above.

## Final gates

- `bundle exec rails test`: 12247 runs, 79860 assertions, 0 failures, 0 errors, 2 skips.
- `bun run test`: 87 files, 1067 tests passed.
- `bun run build`: exit 0.
- `bun run check`: exit 1 at `format:check` on `src/features/self_service/AvatarForm.tsx`,
  `src/pages/auth/org/sign/in/passkeys/new.tsx`, `src/pages/base/org/avatars/show.tsx`, none of
  which this migration touched (no JS/TS was changed). The remaining steps run individually:
  `lint` exit 1 (oxlint refuses `tmp/xper-baseline/.oxlintrc.json`, a directory that predates this
  work), `typecheck:verify` 0, `typecheck` 1 (TS2375 in
  `spec/features/dashboards/base_dashboard_identity.test.tsx` and
  `src/pages/base/org/avatars/show.tsx`), `deadcode` 0, `openapi:lint` 0, `openapi:verify` 0.
- `bundle exec rubocop` on the changed Ruby files: no offenses except two in
  `app/controllers/concerns/authentication_base.rb` (`Metrics/AbcSize`, `Layout/LineLength`), which
  are present in the HEAD version of that file too; this change edited only a comment there.
  Follow-up: both were then fixed by extracting the session/token public-id assignment in
  `load_from_token` into the private `remember_authenticated_public_ids!` (same conditions, same
  order). `bundle exec rubocop` on the file: no offenses. `bundle exec rails test` afterwards: 12247
  runs, 79860 assertions, 0 failures, 0 errors, 2 skips.

## Direct Cache-Control mutation audit

Pattern over `app` and `lib`: `response.headers["Cache-Control"]`, `headers["Cache-Control"]`,
`set_header("Cache-Control"`, `response.cache_control`, `"Cache-Control" =>`, and a bare
`"Cache-Control",` argument. HEAD: 68 matches. Working tree: 67. The only difference is the removed
sitemap header write plus one comment line in `default_no_store.rb`; no new direct mutation was
added. The remaining matches are the protocol-specific `no-store` contracts listed in
`docs/reference/http-cache-policy.md`.

## Follow-up: standalone API roots

`Base::App::Oauth::TokensController`, `Auth::App::Apple::NotificationsController`, and
`Edit::Org::Oidc::Backchannel::LogoutsController` now declare the policy as standalone roots, and the
invariant's completeness check covers every `ActionController::API` controller in the in-scope
namespaces. Before the declaration, an Apple notification rejected with `415` and a back-channel
logout rejected with `400` both answered `Cache-Control: no-cache`; the OAuth token `400` already
answered `no-store` with `Pragma: no-cache` and still does. Targeted run (new tests, invariants, and
every test file referencing these endpoints): 448 runs, 0 failures. Full `bundle exec rails test`:
12250 runs, 79867 assertions, 0 failures, 0 errors, 2 skips. `bun run test`: 1067 passed.

## Follow-up: Edit sign-in through Jump (resolved)

An anonymous `GET /publishing/info/org/entries?ri=jp` on `edit.org.localhost` raised
`JumpRtConfigurationError: No Jump RT issuer namespace is configured for controller
"Edit::Org::Publishing::Info::Org::EntriesController"`. Cause, in code unchanged since HEAD:
`OidcSsoInitiator` redirects directly to Base `/oauth/authorize` only when the request host is
same-site with the authority host (on `edit.umaxica.org` it answered `302` directly to
`https://www.umaxica.org/oauth/authorize?client_id=edit-org...`); otherwise it goes through the Jump
gateway, and `JumpRtSurface.namespace_for_controller` had no `Edit::` mapping.

With the user's approval (option A), Edit became a Jump rt issuer:

- `EDIT_ORG` added to `JitSecurityJwtRegistry::SURFACE_NAMESPACES` (its issuer origin
  `https://edit.umaxica.org` was already registered) and `Edit::` mapped to `EDIT` in
  `JumpRtSurface`.
- `GET /.well-known/jwks.json` on the Edit host (`Edit::Org::WellKnown::JwksController`, under
  `Edit::Org::BareController`, opting into `expires_in 1.hour, public: true` like the other JWKS
  endpoints). The controller and route were written by hand following the Core JWKS controller; a
  controller generator would have added a view and helper this endpoint does not use.
- Adding `EDIT_ORG` first broke 37 signed-in Edit tests: `AuthenticationJwtTokens#auth_jwt_namespace`
  resolved Edit access tokens to `SIGN_ORG` only because `EDIT_ORG` was absent from
  `SURFACE_NAMESPACES`. `ACCESS_TOKEN_SURFACE_NAMESPACES` (= `SURFACE_NAMESPACES - EDIT_ORG`) now
  carries that meaning, so Edit access tokens keep verifying as `SIGN_ORG`.

Tests: `test/integration/edit_org_jump_rt_sign_in_test.rb` (cross-site anonymous request redirects
to `jump.umaxica.net` with `no-store`; the rt verifies against the Edit JWKS with
`iss = https://edit.umaxica.org` and targets `/oauth/authorize` with `client_id=edit-org`; the JWKS
has no private fields and answers `max-age=3600, public`) and an `EDIT_ORG` mapping case in
`test/services/jump_rt/issuer_test.rb`. Before the change they failed with the error above and a
`404` for the JWKS. Full `bundle exec rails test` afterwards: 12254 runs, 79892 assertions,
0 failures, 0 errors, 2 skips. `bun run test`: 1067 passed.

Not done here (outside the repository): provisioning `JWT_EDIT_ORG_ACTIVE_KID` /
`JWT_EDIT_ORG_PRIVATE_KEY` in non-local environments, and registering `https://edit.umaxica.org`
as a trusted rt issuer at the external Jump gateway. Without the key, the environment boots and the
first cross-site Edit sign-in raises `JumpRtConfigurationError` ("signing key configuration is
incomplete"). Local development and test generate the key automatically.
