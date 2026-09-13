# PWA Offline Fallback on the Rails Standard Implementation

## Context

- Original plan/spec: a dedicated offline page so a disconnected browser sees an application page
  instead of its own connection-error screen. Navigation fallback only; not an offline-first
  application, no installable manifest.
- Direction change (2026-08-07): the 2026-08-06 implementation (surface-local `service_workers` and
  `offlines` controllers under `BareController`, shared
  `app/views/shared/pwa/service_worker.js.erb`, resourceful routes) was discarded before it was ever
  committed. The replacement uses `Rails::PwaController`, the generator's route form, and the
  generator's templates.
- Related decisions/docs: `adr/pwa-offline-route-exception.md` (rewritten),
  `adr/csp-and-permissions-policy.md`, `docs/security/public-entrypoints.md`.

## Upstream references pinned at implementation time

- Rails `main`, `8.2.0.alpha`, `vendor/bundle/ruby/4.0.0/bundler/gems/rails-0e8569c84cb7`.
- Read at that revision: `railties/lib/rails/pwa_controller.rb`,
  `railties/lib/rails/application_controller.rb`, `railties/lib/rails.rb:37`
  (`autoload :PwaController`),
  `railties/lib/rails/generators/rails/app/templates/config/routes.rb.tt:9-12`,
  `railties/lib/rails/generators/rails/app/templates/app/views/pwa/{service-worker.js,offline.html.erb}`.
- `offline.html.erb` is new in the PWA scaffold and is not in the 8.2 release notes: Edge API, may
  still change.
- `@inertiajs/core` 3.6.1, `@hotwired/turbo-rails` 8.0.23, `vite_rails` 3.11.1.

## Decisions Made During Implementation

- Decision: write the controller as `"/rails/pwa#service_worker"` with a leading slash.
  - Why: the route lines sit inside `scope(module: :base)` and `scope(module: :app)`. Without the
    slash Rails resolves `Base::App::Rails::PwaController`, which does not exist. Verified with
    `bin/rails routes | grep pwa`: all twenty routes resolve to `rails/pwa#…`.
  - Alternatives considered: hoisting the routes outside the module scopes. That would put them
    outside the host constraint blocks too, which is wrong — each origin must serve its own.

- Decision: keep the generator's `/service-worker` path, with no `.js` suffix.
  - Why: a registration's default scope is the script's _directory_. The script is at the origin
    root either way, so the root scope holds and no `Service-Worker-Allowed` header is needed. The
    earlier implementation's `.js` suffix was not required by anything.
  - Follow-up: `src/pwa/register.ts` and both e2e specs were updated to the new URL.

- Decision: drop the per-path fallback exclusions (`/.well-known/`, `/oauth/`, `/oidc/`, `/social/`,
  `code`/`state` query parameters).
  - Why: they existed to stop the retry control replaying a consumed authorization code. The
    official template retries with `<form action="." method="get">`, which requests the current
    URL's directory with no query string. There is no failing case left to justify the exclusions.
  - Follow-up: `e2e/pwa_offline_auth.spec.ts` asserts the retry target for
    `/social/google/callback?code=…&state=…` is `/social/google/` and carries neither parameter.

- Decision: accept `skip_forgery_protection` and the endpoint-local `unsafe-inline` from
  `Rails::PwaController` / `Rails::ApplicationController` rather than reimplementing the controller.
  - Why: direction from the task. Both are framework code, not application code, and are scoped to
    two public static GETs. `test/unit/security/skip_forgery_protection_usage_test.rb` scans
    `app/controllers/**` and is unaffected.
  - Follow-up: `test/controllers/pwa_endpoints_test.rb` pins that `/` still carries no
    `unsafe-inline` and still emits `worker-src 'self'`, so the relaxation cannot silently widen.

- Decision: enforce the `PUBLIC_PWA_OFFLINE` category with a dedicated test rather than a predicate
  in `documented_public_category`.
  - Why: `PublicEntrypointInventoryTest#application_route_entries` only considers controller paths
    prefixed with an application surface, so `rails/pwa` routes never reach the predicate. Leaving
    the predicate in place would have been dead code that looked like enforcement.
  - Follow-up: the new test asserts exactly twenty GET routes, two distinct paths, on `rails/pwa`.

- Decision: the worker performs no runtime caching.
  - Why: it makes "no authenticated HTML, page props, JSON, CSRF token, or `Set-Cookie` response is
    ever cached" structural instead of reviewed. This is also what the official recipe does.

- Decision (same day, follow-up): extend the fallback from six hosts to ten by adding
  `side/{app,com,org}` and `palm/app`.
  - Why: the requirement is "every page whose HTML Rails serves directly, where Next.js is not the
    frontend". `side` renders settings, dashboard, the sign-out ceremony, and the OIDC callback;
    `palm` renders a landing page and a sign-out notice. Both are Rails-rendered browser HTML.
  - Excluded, with evidence rather than preference: `core/{app,com,org}` and the `docs`, `help`,
    `news`, `info` content surfaces. `docs/architecture/docs-help-news-content-boundary.md` gives
    public HTML, article pages, SEO, `robots.txt`, and `sitemap.xml` for `docs`/`help`/`news`/`core`
    to Next.js, and `docs/operations/core-nextjs-zero-cookie-edge-contract.md` sends every path on
    the public Core host except `/api/v0/*`, `/auth/*`, `/sso/*` to the Next.js origin. A Rails
    `/service-worker` there would not be reachable without an edge-contract change.
  - Follow-up: if that edge contract changes, revisit the surface list in the ADR.

- Decision: the `side` and `palm` entrypoints register the worker and nothing else.
  - Why: those layouts shipped no JavaScript at all before this change. Importing `../application`,
    as the base/sign entrypoints do, would pull Turbo, Stimulus, and Inertia into the control plane
    — an unrelated behaviour change. The layouts gained only `vite_client_tag` and one
    `vite_typescript_tag`.
  - Alternatives considered: a nonce'd inline `<script>` in the layouts. It avoids a bundle but
    duplicates registration logic that already exists in TypeScript.
  - Follow-up: `test/integration/layout_rendered_title_smoke_test.rb` covers the layouts; it failed
    with `Vite Ruby can't find entrypoints/palm/app.ts in the manifests` until
    `RAILS_ENV=test bin/vite build --mode test` was re-run, because `config/vite.json` sets
    `autoBuild: false` for test. Anyone adding an entrypoint has to rebuild that manifest.

## Deviations From Plan

- Change: Inertia network handling is not implemented, and the decision is deferred to measurement.
  - Why: staged verification was the instruction. Inertia 3.6.1 navigates with `XMLHttpRequest`,
    whose request mode is never `navigate`, so the worker is not expected to answer it.
  - Risk: an unresponsive `<Link>` click on `/groups`, the only Inertia page today.
  - Follow-up: `e2e/pwa_offline_base.spec.ts` contains the measurement case. If it fails, add
    `router.on("networkError", …)` handling and nothing more.

- Change: no CI job for the Playwright suite.
  - Why: it needs browser binaries and a booted multi-host stack; that is a separate provisioning
    decision.
  - Risk: the e2e suite is not enforced on push.

- Change: manifest and installability not implemented.
  - Why: out of scope. `policy.manifest_src(:self)` was already set and is unchanged.
  - Follow-up: a separate task; it must first settle icon delivery given
    `config.public_file_server.enabled = false` in production.

## Review Notes

- Tests run and passing, after the side/palm extension:
  `bin/rails test test/controllers/pwa_endpoints_test.rb test/unit/security test/controllers/layout_controller_contract_test.rb test/integration/routes test/integration/layout_rendered_title_smoke_test.rb test/integration/static_assets_endpoints_test.rb`
  (193 runs, 2199 assertions, 0 failures); `pnpm vitest run spec/pwa` (6 passed); `pnpm lint`;
  `pnpm format`; `tsc --noEmit` on `tsconfig.app.json` and `tsconfig.node.json`; `rubocop` on the
  touched Ruby files.
- Environment note: the test databases had to be created and migrated in this container
  (`RAILS_ENV=test bin/rails db:create db:migrate`) before any Minitest could boot. That failure was
  pre-existing and not caused by this change.
- Tests **not** run: `e2e/` (Playwright). Browser binaries are absent from the development container
  and the suite needs real surface origins (`E2E_BASE_SERVICE_URL`, `E2E_AUTH_SERVICE_URL`). The
  normal / Turbo / Inertia navigation behaviour is therefore **unverified**, including the Inertia
  measurement that gates any further work.
- Cloudflare: unchanged from the earlier note and still to be confirmed before rollout —
  `/service-worker` and `/offline` must reach Rails on all ten hosts, and `/service-worker` must not
  carry a long edge TTL.
