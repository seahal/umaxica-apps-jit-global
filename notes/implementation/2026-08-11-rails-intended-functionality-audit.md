# Rails Intended Functionality Audit -- Implementation Notes

## Context

- Original plan/spec: a Rails-only "grill me with docs" audit of functionality expected to work by
  2026-08-11 -- reconstruct intent from code and decision records, reproduce what is actually
  broken, repair only what is explicitly in scope, and leave documentation plus test evidence.
- Deliverable and full findings: `docs/audits/rails-intended-functionality-audit.md`.
- Related decision documents checked for consistency:
  `adr/internal-health-endpoint-edge-isolation.md`,
  `adr/org-cloudflare-access-authentication-layer.md`, `adr/org-entra-id-sign-in-boundary.md`,
  `adr/avatar-db-content-db-boundary.md`, `docs/operations/health-check.md`,
  `docs/reference/feature-flags.md`.
- Implementation date: 2026-08-11.

## Decisions made during implementation

- Decision: the Inertia repair converts the authentication redirect to `409` + `X-Inertia-Location`
  at the two `AuthenticationBase` redirect sites, rather than in a redirect helper or middleware.
  - Why: `authenticate!` and `handle_auth_required_html` are the only places that redirect _out of_
    the Inertia application. Converting in `CommonRedirect` or `OidcSsoInitiator` would also catch
    ordinary same-origin redirects between Inertia pages, which the protocol wants to stay `302`.
    The guard is `request.inertia?`, so nothing outside an Inertia visit changes behaviour.
  - Alternatives considered: an `after_action`. Rejected -- a halted `before_action` chain skips
    `after_action` callbacks entirely, which is exactly the case here.
  - Follow-up needed: none.

- Decision: the conversion writes `status`, header and body directly instead of calling the gem's
  `InertiaRails::Controller#inertia_location`.
  - Why: that helper calls `head`, and `ActionController::Head#head` raises
    `AbstractController::DoubleRenderError` when a response body already exists -- which it does,
    because `redirect_to` has just run. `Metal#response_body = nil` does not clear the
    `@_response_body` flag (it only calls `response.reset_body!`), so resetting first does not help.
    Assigning status/header/body replaces the redirect in place with no private-API poking.
  - Alternatives considered: clearing `@_response_body` by hand. Rejected as a private-state poke.
  - Follow-up needed: if `inertia_rails` ever exposes a render-safe `inertia_location`, collapse
    this back onto it.

- Decision: the FQDN allowlist is a new value object (`app/values/fqdn_availability_registry.rb`)
  built from the same three sources each route file uses, rather than reusing
  `ConfigValues::HostFamilyValues` members directly.
  - Why: `HostFamilyValues` is neither a superset nor a subset of what the router serves. It omits
    `base_network`, `base_developer`, `core_network`, `core_developer`, and the whole `docs_*` and
    `news_*` families (all routed via environment variables and literals), and it _includes_
    `palm_corporate`, `palm_staff`, and the `acme_*` family, which no route constrains on. Deriving
    switches from it would have left routed hosts with no switch and created switches with no
    effect.
  - Alternatives considered: one flag per `HostFamilyValues` member, which was the shape the user
    approved. Deviated deliberately and recorded here; the granularity the user chose (one switch
    per FQDN slot, not per surface family) is preserved -- only the slot list is corrected to match
    the router. 29 slots rather than 24.
  - Historical follow-up: `palm_corporate` / `palm_staff` were configured hosts with no routes.
    Integrated F9 removed those values on 2026-09-24; Palm remains app-only.

- Decision: six controllers call a new `ensure_fqdn_gate_first!` class method.
  - Why: `prepend_before_action` in a subclass lands _ahead_ of one declared in its parent, so
    `Auth::Org::Web::V0::ThemesController` and five others pushed the availability switch into
    second place behind their own prepended callback. Caught by the ordering test, not by
    inspection.
  - Alternatives considered: relaxing the ordering assertion to "before rate limiting" only, which
    the six controllers already satisfied. Rejected -- one of the displaced callbacks issues a
    redirect, so a switched-off FQDN would have redirected instead of returning 503.
  - Follow-up needed: none. `FqdnAvailabilityGateTest` fails if a seventh controller forgets.

- Decision: `/health` and `/health/*` bypass the gate by path, in one place, rather than by opting
  out in each of the ~60 health controllers.
  - Why: `adr/internal-health-endpoint-edge-isolation.md` defines the exemption by path, and
    `config/environments/production.rb` already expresses its own health exemption the same way. A
    single path check is greppable and matches the decision record's own vocabulary.
  - Follow-up needed: none.

- Decision: the flag-store rescue names `ActiveRecord::ActiveRecordError` only.
  - Why: `Flipper::Adapters::ActiveRecord` reaches the `platform` database, and every failure it
    raises descends from `ActiveRecordError`, connection errors included. `rescue StandardError`
    would silently fail closed on unrelated application bugs, which the repository's
    `no-silent-fallback` rule forbids.
  - Follow-up needed: if a non-ActiveRecord adapter is ever adopted, widen `FLAG_STORE_ERRORS` to
    its named error class rather than to `StandardError`.

- Decision: `test/controllers/concerns/default_web_rate_limit_test.rb` now sends
  `Host: base.net.localhost` instead of `example.com`.
  - Why: the new gate refuses an unserved hostname before the rate limiter, so the synthetic host
    could no longer reach the limit the test is about. The test's own assertions are unchanged.
  - Alternatives considered: exempting the probe controller from the gate. Rejected -- that is
    test-only behaviour in application code.
  - Follow-up needed: none, but any future test that invents a `Host` will now need a served one.

- Decision: the Host Authorization exemption lists four paths and matches them exactly, and lives in
  `lib/health_probe_paths.rb` rather than inline in `config/environments/production.rb`.
  - Why exact match, at the user's instruction: `start_with?("/health/")` would extend the exemption
    to any future path under `/health/` at the moment it is added, with no decision taken. A later
    probe returning richer diagnostics would silently lose DNS rebinding protection. Adding a fifth
    path is now a deliberate edit to a list that documents what the exemption costs.
  - Why `lib/`: environment files are evaluated before autoloading is configured, so an
    `app/values/` constant is not resolvable there. `config/application.rb` already uses
    `require_relative "../lib/..."` for the same reason.
  - Why the test drives `ActionDispatch::HostAuthorization` rather than the predicate: "the
    predicate returns true for four paths" is a weaker claim than "the exemption works". The test
    environment sets no `config.hosts`, so the middleware is inert there and had to be constructed
    explicitly with a one-host allowlist and a container-name-shaped probe Host.
  - Follow-up needed: see item 1 under "Follow-up to promote into planning".

## Evidence gathered before the Host Authorization change

The user asked for proof that the exemption is needed before widening it. Every probe definition in
the repository was inventoried; the result was not what the change assumed:

- `Containerfile:161-162` — the only container health check for Rails is a **TCP connect**
  (`TCPSocket.new('127.0.0.1', PORT).close`). It sends no HTTP request and therefore no `Host`, and
  never reaches Host Authorization.
- `compose.yaml` — the `core` (Rails) service has **no `healthcheck:` block** at all.
- `bin/tunnel-origin-check:75` — probes `http://${host}:3000/health` where `${host}` is one of 28
  served `*.localhost` names, i.e. an allowed `Host`.
- `podman/core/preferences/.bash_history:1466-1468` — manual probing uses
  `curl http://base.app.localhost:3000/health/startup`, again an allowed `Host`.
- No Kubernetes manifests and no `config/deploy.yml` exist.

So **nothing in this repository depends on the exemption**, and every HTTP prober that exists
already sets an allowed `Host`. The exemption is a backstop for orchestrator configuration outside
this repository, which cannot be inspected from here. This is recorded because it makes the
preferred direction the opposite of widening: if the production probe configuration can set an
allowed `Host`, `HealthProbePaths::PATHS` should shrink, not grow.

## Contradictions and stale guidance found

- `config/initializers/inertia_rails_compatibility.rb` says "InertiaRails 3.15 only accepts 2" while
  the installed gem is 3.22.0. The patch itself is still correct for Rails 8.2's three-argument
  `render_for_browser_request`; only the version in the comment is stale. Left as-is, since the
  version number is incidental to the reason -- flagged here so a future reader does not conclude
  the patch was removed upstream without checking.
- `docs/hld.md` listed Shrine and Active Storage under the "Integration" layer. Neither integrates
  anything; corrected. `docs/dds.md:289` and `docs/srs.md:69` were already accurate and were left
  alone.
- The health endpoint documentation the brief expected to be stale was already current: `/up` is
  explicitly documented as not the contract, and no `/up` route exists.

## Deviations from the plan and their risk

- The plan expected the Inertia "current page" defect to be broad. It is not: component, props,
  `url`, `version`, `encryptHistory`, Inertia navigation, and stale-version handling were all
  already correct and are now pinned by tests. Only the authentication path was broken. The audit
  records the disproof with the passing assertions rather than quietly narrowing the claim.
- The client-side Turbo/`data-turbo-eval` risk in the Inertia layout was **not** reproduced -- it
  needs a browser against a real origin (`E2E_BASE_SERVICE_URL`), which this session did not have.
  Recorded as inference in the audit, not as a finding. Risk: if it is real, the SPA fails to mount
  on Turbo Drive navigation into `/groups` and no server-side test would notice.
- Coverage was not measured before/after. `.simplecov` enforces line >= 94 and `COVERAGE=true`
  forces a single worker, making the run much slower than the parallel suite. All new application
  code is exercised by the new tests, but the project-wide delta is unmeasured and the audit says
  so.

## Tests run

- `env RAILS_ENV=test bin/rails db:prepare`.
- `bin/rails test` before any edit: 9941 runs, 2 failures (`CsrfNotificationEmissionTest`,
  `Jit::Security::TurnstileVerifierTest`) -- both pre-existing, both passing in later runs,
  therefore order- or parallelism-dependent.
- `bin/rails test test/integration/inertia_page_contract_test.rb` before the repair (1 failure, the
  reproduction) and after (6/6).
- `bin/rails test test/integration/fqdn_availability_gate_test.rb`: 15 runs, 2878 assertions.
- `bin/rails test test/security/invariants/`: 98 runs.
- `bin/rails test` after the gate: 9967 runs, 1 failure, fixed as described above.
- `bin/rails test` final: 9967 runs, 50649 assertions, 0 failures, 0 errors, 1 skip.
- `bin/rubocop` on all changed files: no offenses. `bin/brakeman`: 0 security warnings.
- `bin/repository-language-check`: no new violations from this work.

## Tests not run

- `pnpm -s test` / `pnpm -s check`: no `src/` or `spec/` file was changed.
- Playwright (`e2e/`): requires real origins; see the deviation above.
- `COVERAGE=true bin/rails test`: see the deviation above.
- `bin/tunnel-origin-check`: requires the `cloudflare-tunnel` service from `compose.custom.yaml`,
  which is not running here, and the audit is Rails-only.

## Follow-up to promote into planning

1. **Shrink the Host Authorization exemption rather than keep it.** Repaired in this pass to the
   four exact probe paths (audit §5.1), but the evidence above shows no in-repository prober needs
   it. If the production orchestrator probe can be configured to send a `Host` already in
   `config.hosts` — e.g. a Kubernetes `httpGet.httpHeaders` entry — then `HealthProbePaths::PATHS`
   can be reduced and possibly emptied, removing the DNS rebinding exemption entirely. This needs
   the production probe configuration, which lives outside this repository.
2. `palm_corporate` and `palm_staff` are configured hostnames with no routes. Audit section 5.2.
   Either the routes are missing or the configuration is dead.
3. No browser-level Inertia test exists; `spec/entrypoints/inertia.test.ts` mocks the adapter. Audit
   section 7.
4. `src/pages/base/app/groups/index.tsx` ignores the `groups` prop the controller serialises. Not a
   defect -- the page is a stub -- but the server and client contracts are already out of step.
