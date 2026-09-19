# Palm App-Only Implementation Notes

## Context

- Related decisions/docs/plans: `notes/implementation/2026-06-13-base-palm-sitemap-endpoints.md`,
  `docs/architecture/controller-lifecycle.md`.
- Implementation date: 2026-06-14.

## Decisions Made During Implementation

- Decision: Palm exposes only the app-audience native API surface.
  - Why: native clients are only planned for the app audience; com and org have no native app
    product target.
  - Alternatives considered: preserving uniform app/com/org placeholder endpoints, rejected because
    that would expose unsupported surfaces and keep stale route helpers alive.
  - Follow-up needed: do not restore Palm com/org endpoints without a new accepted decision.

- Decision: `Health::Profiles::Com` and `Health::Profiles::Org` remain.
  - Why: those profiles are shared by other surfaces such as Base, Help, Docs, and News.
  - Alternatives considered: deleting profile constants with the Palm endpoints, rejected because
    that would break unrelated surface health checks.
  - Follow-up needed: none.

## Deviations From Plan

- Change: The older active surface plan originally said Palm should be scaffolded as app/com/org
  uniform triples.
  - Why: the current user decision supersedes that older plan.
  - Risk: low; the implementation removes routes, controllers, views, translations, and tests for
    the unsupported Palm variants while retaining app coverage.
  - Follow-up: keep stable docs and future plans aligned with Palm app-only behavior.

## Review Notes

- Tests run:
- `RAILS_ENV=test bin/rails routes | grep palm` — only `palm_app_*` routes remain (host
  `palm.jp.umaxica.app`).
- `RAILS_ENV=test bin/rails test test/controllers/public_robots_routing_test.rb test/controllers/csp_violation_reports_controller_test.rb test/integration/read_only_surfaces_test.rb test/integration/health_endpoints_test.rb`
  — 24 runs, 0 failures (DB was reachable on the 2026-06-14 verification pass).
- `RAILS_ENV=test bin/rails test test/controllers test/integration` — all Palm/surface tests green.
- Gap found and fixed during verification: `test/controllers/controller_base_inheritance_test.rb`
  `BARE_CONTROLLERS` still listed `Palm::Com::BareController` / `Palm::Org::BareController`
  (constant form, so the earlier `palm_com|palm/com` grep missed it). Removed both; kept
  `Palm::App::BareController`. This also keeps the "BARE_CONTROLLERS stays in sync with
  bare_controller.rb files on disk" guard passing.
- Pre-existing unrelated failures: `test/integration/oidc_rp_browser_flow_test.rb` (Acme OAuth, 422
  "Invalid request") fails independently of this change — the file has no Palm references and is
  unmodified in the working tree. Out of scope for Palm app-only.
- Documentation promotion needed: none currently.

## Native Callback Boundary Update

- Context: Current Palm app routes include inert `/oauth/callback`, `/oauth/callback/ios`, and
  `/oauth/callback/android` stubs. Earlier review treated them as static reserved callbacks with no
  token exchange or state mutation, but warned against deletion before checking native registration
  and external dependencies.
- Decision: Palm native implementation policy remains open. Do not decide whether Palm is a backend
  RP or whether native apps receive `redirect_uri` directly in this cleanup.
- Decision: Palm-specific OAuth/OIDC route names are not accepted going forward. OAuth/OIDC public
  entry points should use the common interface such as `/auth/callback`; Palm device credential,
  token binding, refresh transport, and session transport belong under API namespaces such as
  `/api/v0/device/*`, `/api/v0/token/*`, or `/api/v0/session/*`.
- Decision: iOS/Android differences must be expressed through client registration and credential
  metadata, not through URL paths.
- Classification:
  - OAuth/OIDC public entry point to keep: none under Palm today.
  - Common entry point candidate: consolidate any future Palm RP callback need toward a common
    `/auth/callback` shape or direct native `redirect_uri`, after the native policy is accepted.
  - Future API namespace candidates: device credential, token binding, refresh transport, and
    session transport APIs.
  - Reserved/deprecated: current `/oauth/callback*` Palm stubs.
  - Do not delete now: current `/oauth/callback*` Palm stubs until native app registration, provider
    console settings, external documentation, and access logs have been checked.
