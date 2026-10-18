# Preference browser transport: family capability and `/api/v0/preferences` cutover

- Commit: `7430ddea6da1e18da0b42418e5374379a52c8a4b` (branch `feature`), with this change uncommitted
  in the worktree.
- Start-time worktree: `git status --short` was empty when the work started.
- Concurrent edits: during the work, another agent session autocorrected about 30 unrelated files
  at 20:32 UTC on 2026-10-01 (for example `app/controllers/palm/app/sign/ins_controller.rb`,
  `test/integration/oidc_rp_browser_flow_test.rb`, and many `test/controllers/auth/**` files). Those
  changes are not part of this work and were left untouched.
- Decision: `adr/preference-browser-transport-family-capability.md`, plus the 2026-10-02 amendment
  in `adr/api-route-vocabulary-consolidation.md`.

## Checks run

| Check | Result |
| --- | --- |
| `bin/rails test` (full) | 12314 runs, 84476 assertions, 0 failures, 1 error, 2 skips |
| `bun run test` (Vitest, full) | 87 files, 1081 tests passed |
| `bun run test:coverage` | Every changed `src/` file is at 100%. Global function (98.76%) and branch (97.6%) thresholds still fail because of files this change does not touch (`src/features/org_admin/*`, `src/features/auth/*Cancellation.tsx`, `src/pages/auth/app/settings/totps/new.tsx`) |
| `bun run typecheck` | Only pre-existing errors remain, in `spec/features/dashboards/base_dashboard_identity.test.tsx` and `src/pages/base/org/avatars/show.tsx` |
| `oxlint` on changed TS files | Clean, apart from the pre-existing `patchPayload` scoping finding in `spec/components/chrome/cookie_banner.test.tsx` |
| `bundle exec rubocop` on changed Ruby files | No offenses |
| `bun run openapi:bundle` / `openapi:lint` | Bundles regenerated; all three descriptions valid |

About the full-suite error: `OidcRpBrowserFlowTest#test_app_email_sign-in_session-limit_handoff_completes_Core_RP_callback_without_a_root_session`
raises `NoMethodError: undefined method 'merge!' for Rack::Test::CookieJar`. The cause is the
concurrent autocorrect of that test file (`cookies.merge(` became `cookies.merge!(`), which is outside
this change.

The first full run also hit 9 `PreferenceInertiaPageContractTest` failures. In those, the
`ViteRuby.digest` the test read differed from the digest the app had served, because TypeScript
sources were edited while the suite ran. The same file passed in isolation, and the clean rerun above
passed.

## Focused contracts added

- `test/values/preference_browser_controls_registry_test.rb` checks the family × surface matrix. A
  non-existent pair (for example `palm/com`, `edit/app`, `core/dev`) and nil or empty input both raise.
- `test/integration/surface_chrome_preference_controls_test.rb` checks the chrome props for Core,
  Warp, Base, and Auth, and that Palm app returns `theme_controls`/`cookie_controls` as `nil` with no
  `/web/v0/` in the body.
- `test/integration/erb_layout_preference_controls_test.rb` checks that the Base and Auth ERB layouts
  pass the registry endpoints to the Stimulus data values.
- `test/integration/preference_browser_api_contract_test.rb` covers 4 families × 3 surfaces ×
  theme/cookie:
  - GET returns JSON with `no-store` and creates no preference row;
  - each accepted theme and consent spelling succeeds;
  - each refused partition (missing, null, empty, whitespace, unknown, escaped NUL, integers 2/-1,
    arrays, objects) returns 422 with the right JSON Pointers;
  - malformed JSON and raw NUL return 400, a non-JSON `Content-Type` returns 415, and an `Accept`
    without JSON returns 406;
  - a CSRF failure returns a 403 problem;
  - ordering: 415 is decided before CSRF, and 406 before credential checks;
  - a foreign-host access token returns 401, while a request with no credential is still served;
  - PUT has no route, and the endpoints are not reachable on the Palm host;
  - each negotiation filter is registered exactly once, ahead of forgery protection.
- `test/integration/routes/preference_api_route_contract_test.rb` checks the GET and PATCH routes,
  that PUT and the legacy `/web/v0/{theme,cookie}` paths are absent, that Palm and Edit have no
  preference API, and that the Auth OTP route is kept.
- `test/contracts/openapi_preferences_contract_test.rb` runs Committee validation of the 200, 204,
  422, and 415 responses on all 12 family/surface hosts.
- Vitest covers the `sameOriginEndpoint` refusals (cross-origin, protocol-relative, other scheme),
  the server-declared endpoint used by React and Stimulus, missing endpoint values throwing without a
  request, and the theme screen without a chrome endpoint.

## Repository search for external callers

A repository-wide search for `web/v0/(theme|cookie)` before deletion found:

- the browser callers that were changed in this work;
- tests;
- historical notes and evidence;
- `plans/analysis/rails-nextjs-openapi-contract-audit.md`, which classifies both endpoints as
  in-repo API endpoints and records that the edge app forwards only `/api/v0/*`.

Neither endpoint appears in any OpenAPI document.
