# The Preference Tree on Inertia, Across All Three Base Surfaces — Implementation Notes

## Context

- Original plan/spec: none. The work started from a request to exercise Inertia Rails on
  `https://www.umaxica.{com,app,org}/preference?ri=jp`, then to convert everything under
  `/preference` on all three surfaces.
- Related decisions/docs/plans: `research/implementation/inertia-per-surface-vite-pipeline.md` (the
  per-FQDN entrypoint and layout convention this change is the first real consumer of),
  `.agents/harnesses/rules/project/surfaces.mdc`, `adr/frontend-architecture-toolchain.md`.
- Implementation date: 2026-08-12.

## Findings That Motivated The Change

- Inertia was fully wired but almost entirely unused: `Base::App::GroupsController#index` was the
  only `render inertia:` call, and nine of the ten per-surface layouts and entrypoints had never
  been on a request path. `src/pages/base/com` and `src/pages/base/org` held only a `.gitkeep`.
- `/preference` is the natural first shared page: all three base surfaces route it, it is
  `AUTHENTICATION_MODE = :open` so it needs no session, and the three controllers already shared one
  ERB template (`base/shared/preferences/show`), so converting it exercises three FQDNs at once
  without inventing a shared abstraction that did not already exist.

## Decisions Made During Implementation

- Decision: convert the whole `/preference` tree — the index and the twelve edit screens — on all
  three surfaces, and leave `/preference/emails/:id/edit` out.
  - Why emails is out: it is the only screen under `/preference` that does not descend from
    `PreferencesBaseController`. It inherits `BareController` with `AUTHENTICATION_MODE = :bare`, is
    authenticated by a token in the URL, and renders a Turnstile widget. It is a different trust
    path that happens to share a URL prefix.
  - Also out: `/preference/screen/edit`. It answers 500 today and did before this change —
    `BasePreferenceScreenDispatch::SCREEN_ACTIONS` has no `screen` key, so `fetch` raises. The route
    exists but nothing maps it to a preference. Left as found.
  - Consequence: the index and every screen now link with Inertia's `<Link>`. Only the index up
    link, which leaves the preference tree for a server rendered page, stays a plain `<a href>`.
- Decision: `SurfaceInertiaPage` derives the layout from `controller_path` and is the single marker
  for "this controller renders Inertia".
  - Why: the layout was a hand-written string per controller, which can name another surface's shell
    and has to be repeated on every new screen. Including the concern once on each surface's
    `PreferencesBaseController` covers the index and all twelve screens, and
    `grep -rl SurfaceInertiaPage app/controllers` is now an accurate inventory.
  - It pairs with `render inertia: true`, which derives the component name from the same
    `controller_path`. Nothing about the pairing is enforced yet; that is the open follow-up.
- Decision: props are built in controller concerns (`BasePreferenceIndexPage` for the index,
  `BasePreferenceScreenPage` for the screens) rather than a value object or resolver.
  - Why: every value in the props is either a translation or a route helper result, both of which
    are controller-level concerns; the concern is a direct transcription of the ERB it replaces. It
    reuses `preference_base_i18n_key`, `preference_surface_key`, and `preference_route_authority`
    from `PreferenceCore`. `BasePreferenceScreenPage` produces the four screen shapes the four
    shared ERB templates produced: `option` (region, timezone, language, theme), `selectable` (the
    six list screens), `cookie`, and `customizations`.
  - Why a shared concern is not a surface violation: the three surfaces already shared one ERB
    template for this page, so the shared abstraction predates this change.
- Decision: the hrefs are generated with route helpers, not assembled as strings.
  - Why: `PreferenceGlobal#default_url_options` merges the resolved request context into every
    generated URL. That is how `ri` is always present and how `lx`, `ct`, and `tz` survive into the
    links, which is the invariant `preference_global_param_context_test` pins.
- Decision: the controllers call `render inertia: true` instead of naming the component.
  - Why: `InertiaRails::Configuration#component_path_resolver` defaults to
    `"#{controller_path}/#{action_name}"`, which is exactly the surface-qualified name the
    entrypoints expect (`base/com/preferences` + `show`). Naming it by hand is a second source of
    truth that can drift from the controller it lives in.
  - Note: `Base::App::GroupsController#index` still passes the literal `"base/app/groups/index"`,
    which resolves identically; it can be simplified the same way.
- Decision: the surface Inertia layouts render the same ERB header and footer as their Turbo
  counterparts, and the base Inertia entrypoints import `../../controllers` to start Stimulus.
  - Why: without it the page loses the primary nav, the current banner, the cookie banner, the
    footer theme control, and the copyright — on `/preference`, the page where a user is most likely
    to look for exactly those controls. The chrome partials are ERB, and only the cookie and theme
    controls need JavaScript, which is Stimulus rather than React.
  - Turbo is deliberately not imported: every link out of the Inertia page is a full document visit,
    so Turbo Drive would only add a second navigation mechanism next to Inertia's.
  - Consequence: the layout owns the `<main id="main">` landmark, as the ERB layouts do, so page
    components render a `<section>`. `src/pages/base/app/groups/index.tsx` was adjusted to match,
    otherwise it would nest a second `<main>`.
  - Not carried over: `layouts/shared/cloudflare_turnstile_api`. No Inertia page renders a Turnstile
    widget, and the partial loads a third-party script.
- Decision: validation failures redirect back with `inertia: { errors: ... }` instead of rendering
  the screen with 422.
  - Why: the Inertia client routes any response with a 4xx status into its transport-exception path
    rather than setting the page, so a 422 render never reaches the component. Redirect-with-errors
    is the protocol's own convention, and the middleware turns it into a 303 for the DELETE.
  - Behaviour change: `DELETE /preference/customization` without confirmation answered 422 and now
    answers a redirect (303 for an Inertia request, 302 otherwise). The error text still reaches the
    screen, now through `props.errors` rather than the rendered template.
  - The "no Rails flash" contract is unaffected: Inertia errors travel in
    `session[:inertia_errors]`, which the middleware clears on the next render.
- Decision: the base family's typography lives in `src/styles/base_family.css`, imported by the six
  base entrypoints, rather than in `application.css`.
  - Why: `application.css` is loaded by every surface, and the change was asked for the three base
    FQDNs only. `base.css` already sets a body font stack globally and stays as it is for the auth,
    side, and palm families.
  - The rules follow three ics.media articles: the system font stack from
    https://ics.media/entry/200317/, `font-feature-settings: "palt" 1` from
    https://ics.media/entry/14087/, and
    `overflow-wrap: anywhere; word-break: normal; line-break: strict` plus `text-wrap: pretty` on
    running text from https://ics.media/entry/240411/.
  - The selector is `html body`, not `body`: the global rule in `base.css` ships in a different CSS
    chunk, so one extra element of specificity removes the dependence on chunk order.
  - Verified from the built manifest: the emitted `base_family-*.css` is reachable from exactly the
    six base entrypoints and from no other. `ViteEntrypointContractTest` pins that at the source.
- Decision: the CSP nonce is published as `<meta property="csp-nonce">` and handed to Inertia,
  instead of relaxing `style-src-elem`.
  - Why: both Vite's dev client and Inertia build `<style>` elements at runtime — Vite for injected
    module styles, Inertia for its progress bar and error dialog — and `style-src-elem` carries a
    nonce with no `unsafe-inline`, so the browser refused all of them. Over the tunnel that meant
    the stylesheets genuinely did not apply.
  - Vite reads `document.querySelector("meta[property=csp-nonce]")?.nonce` on its own; Inertia takes
    the value through `createInertiaApp({ nonce })`, which `cspNonce()` in `src/inertia/surface.ts`
    reads from the same tag. Neither needed a policy change.
  - `unsafe-inline` would have been the wrong fix twice over: CSP3 ignores it whenever a nonce is
    present, and it would have applied in production, where Inertia injects the same progress bar.
  - The tag went on all twenty layouts that load the Vite client, not only the base ones: the
    progress bar injection is not development-only and not base-only.
- Decision: `connect-src` gains the Vite dev server origin in development only.
  - Why: `@vite/client` opens an HMR WebSocket to the dev server port on the requested host, which
    the production policy correctly refuses. The sources are lambdas over `request.host` and the one
    configured Vite port, so no environment other than development, and no port other than the dev
    server's, is admitted.
  - Known limit: over the Cloudflare Tunnel the socket still cannot connect, because no ingress
    routes port 3036. The policy no longer reports a violation, but HMR only works when the page is
    served from an origin that can reach the dev server directly.
- Decision: each surface gets its own page module under `src/pages/base/<surface>/` for every
  component, re-exporting the shared components in `src/features/preferences/`.
  - Why: each entrypoint globs only its own page directory, so the module must exist per surface;
    the rendering itself is identical because the server sends surface-specific strings.
  - Verified: the dev server's transformed `base_org` entrypoint resolves only pages under
    `../../pages/base/org`.

## Deviations From Plan

- Change: the surface Inertia layouts grew the ERB chrome, and the base Inertia entrypoints grew a
  Stimulus import.
  - Why: the first version rendered the page in the bare Inertia shell, which silently dropped the
    nav, cookie banner, footer theme control, and copyright. See the decision above.
  - Risk: the base Inertia bundles now carry Stimulus and every controller in `src/controllers`. The
    other seven Inertia entrypoints are unchanged, so this is not yet a convention.
  - Follow-up: if a surface renders an Inertia page that needs no chrome, the Stimulus import should
    move to the layouts that use it rather than to every entrypoint.
- Change: the `up_link` still forces `ct=dr`, `lx=en`, `ri=us`, `tz=asia/tokyo`.
  - Why: it was hardcoded in the ERB. Carrying it over verbatim keeps this change behaviour
    preserving; it is clearly leftover scaffolding.
  - Follow-up: drop the overrides and let `default_url_options` supply the context.

## Removed

- `app/views/base/shared/preferences/show.html.erb` and
  `app/views/base/shared/preference/{option,selectable,cookie,customizations}.html.erb` — replaced
  by the page components; no other referrer.
- `BasePreferenceScreenDispatch#preference_screen_template` and `#preference_screen_template_name` —
  they named the ERB templates above. The component name comes from
  `BasePreferenceScreenPage#preference_screen_component_name`, which does not pluralise the
  selectable screens into names the dispatch never rendered.
- `src/pages/base/{com,org}/.gitkeep` — those directories now hold real pages.

## Review Notes

- Tests run: `bin/rails test test/integration/ test/controllers/` (3532 runs). The only failures are
  `FqdnAvailabilityGateTest` × 8, missing `ja.errors.fqdn_availability.unavailable`, and
  `ViteAssetNonceTest`, which finds no modulepreload links because `ViteRuby` reports the dev server
  as running even under `RAILS_ENV=test`, so the layouts render dev-server tags instead of manifest
  tags. Stop `bin/vite dev` and it reads the manifest. Both files are untracked in-flight work and
  neither touches `/preference`. `StepUpAuthenticationTest` failed once under parallel load and
  passes in isolation. `pnpm test` (310), `pnpm exec tsc -b`, `oxlint`, `bin/rubocop` (1467 files),
  and `erb_lint` on the touched files are clean.
- Test rework: about 81 markup assertions across `acme_preference_test.rb`,
  `preference_authority_slice_1f_test.rb`, and `preference_global_param_context_test.rb` moved from
  `assert_select` on form elements to reading the page object, through the new
  `test/support/inertia_page_object.rb` helper. Every assertion keeps its original subject; only the
  place it reads changed.
- Manual verification: on `base.{app,com,org}.localhost:3000`, `GET /preference?ri=jp` and all
  twelve `GET /preference/<screen>/edit?ri=jp` return 200 with the expected surface component, the
  surface's own entrypoint script, form actions carrying the request context, and the restored
  chrome (nav, `data-controller="theme"`, `data-controller="cookie-banner"`, copyright) with a
  single `<main>` element.
- Not verified in a browser: the client-side PATCH and DELETE. Inertia sends `X-XSRF-TOKEN` from the
  cookie `inertia_rails` sets, and its middleware copies that into `X-CSRF-Token`, which is what
  this application's `protect_from_forgery using: :header_or_legacy_token` reads. The cookie and the
  round trip are covered by the integration tests; no browser could be launched here.
- Not verified: rendering in a real browser, and the Cloudflare Tunnel path
  (`https://www.umaxica.{com,app,org}/preference?ri=jp`). No browser could be launched in this
  environment — Playwright's Chromium is missing `libatk-1.0.so.0`. The React mount is covered
  indirectly by `spec/features/preferences/preference_index.test.tsx` and the resolved page glob.
