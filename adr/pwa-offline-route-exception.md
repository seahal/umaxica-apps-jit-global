# PWA Offline Fallback: Rails Standard Route and Controller Exception

## Status

Accepted (2026-08-07). Supersedes the 2026-08-06 revision of this ADR, which decided to serve these
endpoints from surface-local controllers under `BareController`.

## Context

When a browser has no network, users of the surfaces whose HTML Rails renders itself see the
browser's built-in connection-error screen. We want a dedicated offline page instead. The scope is a
single cached offline document and a navigation fallback; this is not an offline-first application,
and no installable-PWA manifest is in scope.

Rails ships everything this needs: `Rails::PwaController`, three route lines in the application
generator template, and `app/views/pwa/{service-worker.js,offline.html.erb}` templates. The earlier
revision of this ADR rejected that stock recipe because it conflicts with three repository rules.
Re-implementing the same behaviour locally cost twelve controllers, two concerns, six templates and
a custom media-type/CSRF workaround, and it drifted from the framework on every point.

The decision has been reversed: where a repository rule conflicts with the Rails standard here, the
rule takes an explicit, narrow exception rather than the framework being reimplemented.

Upstream pin at the time of writing: `rails/rails` `main`, `8.2.0.alpha`
(`vendor/bundle/.../rails-0e8569c84cb7`). `offline.html.erb` is new in the PWA scaffold and is not
covered by the 8.2 release notes, so treat it as an Edge API that may still change.

## Decision

### Use `Rails::PwaController` unchanged

No surface-local PWA controller and no PWA concern exists. `Rails::PwaController` inherits
`ActionController::Base` directly, so these endpoints run no authentication, tenant resolution,
policy, or database work by construction.

### Keep the generator's route form

Declare, in each of the ten affected host blocks:

```ruby
get("service-worker", to: "/rails/pwa#service_worker", as: :pwa_service_worker)
get("offline", to: "/rails/pwa#offline", as: :pwa_offline)
```

This is an approved exception to `.agents/harnesses/rules/generic/routing.mdc:34-52`, which
otherwise forbids new `get` routes and route-level `to:`/`as:`. It applies only to these two lines
in these ten blocks and does not generalise.

**Reshaping these into `resource` is forbidden.** Making the route look conventional while pointing
at the same framework controller buys nothing and hides the fact that this is the stock Rails
recipe.

The only departure from the generator's text is the leading slash on the controller. The route lines
sit inside a surface scope (`scope(module: :base|:auth|:side|:palm)`) and an audience scope
(`scope(module: :app|:com|:org)`); without the slash the route resolves to
`Base::App::Rails::PwaController`, which does not exist. Route names are disambiguated by the
enclosing `scope(as:)`, yielding `base_app_pwa_service_worker` and so on.

The path is `/service-worker`, with no `.js` suffix, exactly as the generator emits it. A
registration's default scope is the directory of its script, not its extension, so a script at the
origin root is root-scoped and no `Service-Worker-Allowed` header is involved. This matters: the
script must be same-origin with the pages it controls, and `config/environments/production.rb` sets
a separate `asset_host` and disables the public file server, so the script can be neither a Vite
artifact nor a static file under `public/`.

### Which surfaces get it

The endpoints exist on every origin whose public HTML Rails renders itself:

- `base/{app,com,org}` and `auth/{app,com,org}` — the full application surfaces.
- `side/{app,com,org}` — the Rails control plane: settings, dashboard, the sign-out ceremony, and
  the OIDC callback are all Rails-rendered browser pages.
- `palm/app` — the native RP surface's browser-facing pages (landing, sign-out notice).

`core/{app,com,org}` and the `docs`, `help`, `news`, and `info` content surfaces are excluded
because Next.js owns their public HTML: `docs/architecture/docs-help-news-content-boundary.md`
assigns public HTML, article pages, SEO, `robots.txt`, and `sitemap.xml` for `docs`, `help`, `news`,
and `core` to Next.js, and `docs/operations/core-nextjs-zero-cookie-edge-contract.md` routes every
path on the public Core host other than `/api/v0/*`, `/auth/*`, and `/sso/*` to the Next.js origin.
A Rails `/service-worker` route on those hosts would not be reachable, and the offline story there
belongs to the Next.js application. This exclusion is an edge-contract fact, not a preference; if
that contract changes, revisit it here.

The earlier revision of this ADR also excluded `side` and `palm`, on the grounds that their layouts
emit no `vite_*` tag and so have nowhere to register a worker. That reasoning is withdrawn: the
layouts now load a registration-only entrypoint (see Registration below).

`manifest` is deliberately not routed. Installability is a separate decision that must first settle
icon delivery under `public_file_server.enabled = false`.

### Use the official templates

`app/views/pwa/service-worker.js` is the generator's file with its `install` and `fetch` blocks
uncommented verbatim and the Web Push blocks removed. It caches `/offline` on install and answers
failed `request.mode === "navigate"` requests from that cache. It performs no runtime caching, so no
authenticated HTML, page props, JSON, CSRF token, or `Set-Cookie` response can enter the cache.

`app/views/pwa/offline.html.erb` is the generator's file with `lang`, the `<title>`, and three body
strings localized to Japanese. Markup, CSS, `prefers-color-scheme` handling, and the
`<form action="." method="get">` retry control are unchanged.

Both templates are shared by all ten surfaces. This is compatible with `project/surfaces.mdc` only
because they reference no user, actor, tenant, session, or database state, and rendering them
requires none. That condition is a constraint on future edits, and is pinned by
`test/controllers/pwa_endpoints_test.rb`.

### Accepted framework behaviour

Two things `Rails::PwaController` does would be forbidden if we wrote them ourselves. Both are
accepted, endpoint-scoped, and not replicated anywhere else.

1. **`skip_forgery_protection`.** `protect_from_forgery` installs an after action,
   `verify_same_origin_request`, that raises `ActionController::InvalidCrossOriginRequest` for any
   GET returning a JavaScript media type. A service worker script must be served with a JavaScript
   media type, so without the skip `/service-worker` always fails. Both endpoints are public, static
   GETs that read no state and change none, so there is no CSRF surface to protect.
   `test/unit/security/skip_forgery_protection_usage_test.rb` scans `app/controllers/**` only and is
   unaffected; this is framework code, not application code.
2. **Endpoint-local `unsafe-inline` and disabled nonce.** `Rails::ApplicationController` declares
   `content_security_policy { script_src :self, :unsafe_inline; style_src :self, :unsafe_inline }`
   and `disable_content_security_policy_nonce!`. This applies to the `/service-worker` and
   `/offline` responses only; the application policy in
   `config/initializers/content_security_policy.rb` is unchanged and still emits nonces everywhere
   else. `test/controllers/pwa_endpoints_test.rb` pins that the relaxation does not leak to `/`.

### Registration

Registration lives in `src/pwa/register.ts` and is invoked from the ten surface entrypoints, not
from `src/entrypoints/application.ts`: `src/entrypoints/core/dev.ts` also imports that module, and
the core/dev origin serves no `/service-worker`.

- `src/entrypoints/{base,sign}/{app,com,org}.ts` import `../application` as they always did, then
  register.
- `src/entrypoints/side/{app,com,org}.ts` and `src/entrypoints/palm/app.ts` register and do nothing
  else. They deliberately do **not** import `../application`: those layouts shipped no JavaScript
  bundle before this change, and pulling Turbo, Stimulus, and Inertia into the control plane would
  be an unrelated behaviour change. Their layouts gained only `vite_client_tag` and a
  `vite_typescript_tag` for the registration entrypoint.

### CSP

`config/initializers/content_security_policy.rb` sets `policy.worker_src(:self)` instead of `:none`.
`worker-src` governs `ServiceWorker` scripts, so `:none` blocks `navigator.serviceWorker.register()`
outright. `:self` admits only same-origin scripts; because this application serves no static
JavaScript from its own origin, that is effectively the one Rails-rendered `/service-worker`. This
is the only application-wide policy change: no wildcard, no scheme source, no `unsafe-inline`.

### No path exclusions

The worker answers every failed navigation on the origin, including authentication protocol paths.
The earlier revision excluded `/.well-known/`, `/oauth/`, `/oidc/`, `/social/`, and navigations
carrying `code` or `state`, to stop the retry control replaying a consumed authorization code. The
official template's retry is `<form action="." method="get">`, which requests the current URL's
_directory_ with no query string, so it cannot replay a code. No failing case justifies the
exclusions, so they are not carried over. `e2e/pwa_offline_auth.spec.ts` pins the retry target.

### Inertia

No Inertia-specific handling is implemented. Inertia navigates with `XMLHttpRequest`, whose request
mode is never `navigate`, so the worker is not expected to answer it. Whether that produces a broken
experience is measured by `e2e/pwa_offline_base.spec.ts`, not assumed. If and only if that test
shows a failure, the remedy is `router.on("networkError", …)` from Inertia's own API.
Worker-synthesized Inertia responses (`409` with `X-Inertia-Location`), custom protocol handling,
and offline storage of POST/form contents are out of scope.

## Consequences

- `/service-worker` and `/offline` become part of the external contract of ten origins. Browsers
  bind a registration to its script URL, so renaming either path strands registered clients.
- Cloudflare must route `/service-worker` and `/offline` to Rails on all ten hosts, and must not put
  a long edge TTL on `/service-worker`: the browser honours the script's `Cache-Control` until the
  registration goes stale at 86400 seconds, so a long TTL delays worker updates by up to a day.
- The `PUBLIC_PWA_OFFLINE` category in `docs/security/public-entrypoints.md` covers routes served by
  a framework controller, which `test/unit/security/public_entrypoint_inventory_test.rb` skips by
  construction; that test enforces the category with a dedicated assertion instead.
- Removing the routes is not a sufficient rollback. A registered service worker outlives its route,
  so retirement means shipping a worker that unregisters itself and clears its caches, keeping the
  route alive until clients update, and purging the CDN copy of the script.

## Rollback

1. Replace `app/views/pwa/service-worker.js` with a no-op worker that calls
   `self.registration.unregister()`, deletes the `offline` cache, and claims clients.
2. Stop creating new registrations: remove the `registerOfflineServiceWorker()` calls from the
   `base`/`sign` entrypoints, and remove the `vite_*` tags from the `side` and `palm` layouts.
3. Keep the `/service-worker` route serving that worker until clients have updated (up to 86400
   seconds of registration staleness).
4. Purge the Cloudflare cache entry for `/service-worker`.
5. Only then remove the routes and templates, restore `policy.worker_src(:none)`, and mark this ADR
   superseded.

Steps 1 and 2 alone are enough to disable the fallback in an emergency.

## Related

- `.agents/harnesses/rules/generic/routing.mdc`
- `.agents/harnesses/rules/generic/absolute-rules.mdc`
- `.agents/harnesses/rules/project/surfaces.mdc`
- `adr/csp-and-permissions-policy.md`
- `adr/frontend-architecture-toolchain.md`
- `docs/architecture/docs-help-news-content-boundary.md`
- `docs/operations/core-nextjs-zero-cookie-edge-contract.md`
- `docs/security/public-entrypoints.md`
- `notes/implementation/2026-08-07-pwa-offline-rails-standard.md`
