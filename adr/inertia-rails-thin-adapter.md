# Inertia Rails as a Thin Adapter

Accepted: 2026-10-05

## Context

The application renders most signed-in screens through Inertia: `inertia_rails` 3.22.0 on the
server and `@inertiajs/react`, `@inertiajs/core`, and `@inertiajs/vite` 3.8.0 on the client. It is
not a single-origin application. Every family (`base`, `auth`, `warp`, `core`, `palm`) is served on
its own hosts for the `app`, `com`, and `org` surfaces, and each of those hosts is a separate trust
boundary with its own session.

Two things had drifted from that. An initializer reopened `InertiaRails::InertiaDebugExceptions` to
add a third argument that Rails 8.2 passes; the gem has accepted that argument itself since it
gained Rails 8.2 support, so the patch only shadowed the gem's own implementation and dropped its
Markdown branch. And the configuration restated one upstream default and rendered an SSR head
helper in every layout although server-side rendering is not used.

## Decision

Inertia Rails is used as a thin adapter, through its public API only.

- **No fork, no monkey patch, no wrapper.** Nothing in this repository reopens an `InertiaRails`
  constant or wraps the renderer. A behaviour the gem does not offer is a reason to change the
  calling code or to wait for a release, not to patch the gem.
- **Configuration states only what differs from the installed gem's defaults**, and each such line
  is a contract: the asset version, mandatory history encryption, the empty `errors` hash, and the
  two Inertia.js 3 markup forms (script-element initial page, `data-inertia` head attribute). The
  client reads only those two forms, so there is no second form to keep. An option is added because
  the application needs it, never because a newer release documents it; the installed gem's source
  decides what exists.
- **No compatibility with earlier Inertia releases.** The three client packages are pinned to one
  exact release so they cannot skew.
- **History encryption is global and mandatory.** No controller, render call, or environment turns
  it off; `test/unit/security/forbidden_rails_patterns_test.rb` rejects an `encrypt_history:`
  override in application code.
- **One asset version per deployment.** It comes from `ViteRuby.digest`, a digest of the Vite
  sources, evaluated once per process. It never depends on the request host, so every tenant of one
  deployment reports the same version.
- **Multi-origin is a first-class condition.** The page object's `url` is the request's own
  origin-relative path and query, as the protocol defines; it is never rewritten to an absolute
  URL. A link inside one origin uses a `_path` helper. A link to another origin uses a `_url` helper
  whose host comes from the configured authority for that surface, never from the current request.
- **Same-origin and cross-origin navigation are different mechanisms.** Inside one origin a
  redirect stays an ordinary Rails redirect and the client follows it as an Inertia visit. A
  redirect that leaves the origin, or that leads to a page Inertia does not render, is answered
  with `409` and `X-Inertia-Location`, which the client turns into a full document visit. The
  destination is always produced by the existing redirect helpers first, so Rails open-redirect
  protection and the jump gateway checks still decide where it may go.
- **The surface page resolver is a trust boundary.** Each surface entrypoint globs only its own
  page directory and refuses a component name without its own prefix. It is not replaced by a
  shared wildcard resolver to save configuration.
- **Features not in use stay off**: server-side rendering, Precognition, prop and SSR caching,
  `default_render`, and deep merging of shared props. Screens rendered with and without Inertia
  coexist, so a controller renders an Inertia page only where it says so.

## Consequences

Upgrading Inertia is a version bump plus a read of the changelog against the five configured
lines. A release that changes a default this application relies on is caught by
`test/integration/inertia_page_contract_test.rb` and
`test/integration/preference_inertia_page_contract_test.rb`, which read the protocol payload rather
than the configuration.

The cross-origin conversion is applied where a redirect is known to leave the Inertia application,
not to every redirect automatically. The surface root controllers share no parent other than
`ActionController::Base`, so an automatic conversion would have to be installed by a concern in
each of them, which is the implicit behaviour the concern rules exclude. A new Inertia form whose
action redirects to another origin must call the conversion itself.

Clearing history at the end of each authentication ceremony, and the lifetime of secrets carried in
page props, are separate security work and are not decided here.
