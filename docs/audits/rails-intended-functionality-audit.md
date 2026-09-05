# Rails Intended Functionality Audit

Date: 2026-08-11 Scope: this Rails repository only. No Next.js, Edge, Workers, Cloudflare
Dashboard/Access/Tunnel, or DNS change was made or is proposed here.

> **Note (2026-09-03):** this audit describes the health probes as JSON and the `/health`
> aggregate as an HTML/`406` snapshot. That is superseded by the 2026-09-03 text+JSON health
> contract — the probes are now `text/plain` and a separate `/api/v0/health.json` +
> `/api/v0/revision.json` family carries the machine JSON. The Host Authorization findings in §5.1
> (exact-match of the four singular text probe paths in `lib/health_probe_paths.rb`;
> `/api/v0/*.json` deliberately not exempt) still hold. Current contract:
> `docs/reference/health-endpoints.md`.

## How to read this document

Every claim is tagged so inference is never presented as fact:

- **[repo]** — verified by reading this repository at the cited path.
- **[run]** — verified by executing something in this session; the command and result are recorded.
- **[upstream]** — documented behaviour of a dependency, verified against the vendored gem source or
  official documentation.
- **[inference]** — reasoned from the above but not executed. Never treated as evidence of a defect.
- **[decision]** — a choice the user made during this audit.

## Executive summary

Five areas were reconstructed from code, tests, ADRs, routes, and the lockfile, then compared
against runtime behaviour.

One real defect was found and repaired: **an Inertia visit that requires authentication received a
bare `302` instead of the protocol's `409` + `X-Inertia-Location`**, which strands the SPA on its
current page. It was reproduced [run], repaired, and is now covered by a regression test that fails
against the pre-repair code.

The rest of the Inertia protocol surface turned out to be **correct** — component, props, `url`,
`version`, `encryptHistory`, Inertia navigation, and stale-version handling all behave as
documented. The audit brief's premise that "current page" was broken is therefore only partly right,
and the document says so with the recorded evidence.

The **per-FQDN Flipper kill switch did not exist** and has been implemented, fails closed, and is
proven by test to run ahead of rate limiting, authentication, and the controller action, on every
one of the 43 gated surface controllers.

**Shrine/S3 is vestigial** — audited only, no feature implemented. **Authentication matches its
ADRs**, including the critical Cloudflare-Access-is-not-Rails-identity boundary. Two Rails-local
findings were raised outside the pre-authorized repair scope: the production Host Authorization
exemption was approved and repaired to an exact-match path list (§5.1), and the unrouted palm hosts
remain documented and unchanged (§5.2).

## 1. Evidence table

| Area                          | Intended behavior                                                                   | Current implementation                                                                               | Runtime/test evidence                                                                                                       | Status                         |
| ----------------------------- | ----------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------ |
| Inertia page object           | Component, props, `url`, `version`, `encryptHistory` embedded for the client        | `inertia_rails 3.22.0`, initializer identical to the upstream generator template                     | `test/integration/inertia_page_contract_test.rb` asserts each key against the parsed `data-page` JSON — passes [run]        | working                        |
| Inertia navigation            | `X-Inertia` GET returns the page object as JSON with the correct current-page `url` | Gem default (`renderer.rb:134`, `url: @request.original_fullpath`)                                   | Same file: JSON body, `X-Inertia: true`, `url == "/groups?ri=jp"` — passes [run]                                            | working                        |
| Inertia asset version         | Stale client version answered `409` + `X-Inertia-Location`                          | `config.version = ViteRuby.digest`; `InertiaRails::Middleware`                                       | Same file: stale version returns 409 with the location — passes [run]                                                       | working                        |
| **Inertia auth redirect**     | Leaving the SPA must use `409` + `X-Inertia-Location` [upstream]                    | `handle_auth_required_html` issued a plain `302`                                                     | Reproduced: `302` to `/oauth/authorize` [run]; now `409`                                                                    | **repaired**                   |
| Inertia client boot           | SPA mounts on `#app`                                                                | `src/entrypoints/inertia/base_app.tsx` (was `src/entrypoints/inertia.tsx`), `@inertiajs/react 3.6.1` | Only test is `spec/entrypoints/inertia.test.ts`, which **mocks** `createInertiaApp`                                         | untested (see §2.4)            |
| Flipper FQDN gate             | 503 before rate limiting for a switched-off or unknown FQDN                         | Did not exist                                                                                        | `test/integration/fqdn_availability_gate_test.rb`, 15 tests — pass [run]                                                    | **implemented**                |
| Flipper registry discipline   | All reads through `FeatureFlags`                                                    | `app/values/feature_flags.rb` + invariant test                                                       | New flags registered; invariants pass [run]                                                                                 | working                        |
| Shrine/S3                     | Not wired                                                                           | Boot-time `Shrine.storages` only; no uploader, no attachment, no S3                                  | `app/uploaders/` holds only `.keep`; `aws-sdk-s3` never required [repo]                                                     | vestigial (audit only)         |
| Authentication (Entra)        | `tid+oid` lookup, `openid profile`, no UserInfo, `acct=0`, no JIT                   | Matches `adr/org-entra-id-sign-in-boundary.md` on every point checked                                | `lib/omniauth/strategies/umaxica_entra.rb:43`, `app/lib/external_sign_in/{providers/entra_id,org_entra_resolver}.rb` [repo] | working                        |
| Cloudflare Access boundary    | Access identity must not become Rails identity                                      | Rails reads no `CF-Access-*` header anywhere                                                         | Repo-wide grep returns nothing [repo]                                                                                       | working                        |
| Health endpoints              | `/health` + three probes, internal-only                                             | As documented; no `/up` route exists                                                                 | `docs/operations/health-check.md` matches routes [repo]                                                                     | working                        |
| Production host authorization | Exclude health probes from DNS-rebinding protection                                 | Excluded exact `/health` only, against its own comment                                               | `test/config/health_probe_paths_test.rb` drives the real middleware — passes [run]                                          | **repaired** (§5.1)            |
| Palm corporate/staff hosts    | —                                                                                   | Configured hostnames with no route                                                                   | `config/routes/palm.rb` constrains `palm_service` only [repo]                                                               | **finding, awaiting decision** |
| Test suite                    | Protects the above                                                                  | 9941 runs at baseline; none exercised Inertia's protocol or any FQDN gate                            | Baseline [run]                                                                                                              | gap, now closed for both       |

## 2. Confirmed defects

### 2.1 Inertia authentication redirect strands the SPA (repaired)

**Symptom.** An Inertia visit to a `:private` endpoint by an unauthenticated client received
`302 Found` to the OIDC authorization endpoint.

**Reproduction [run].** With `test/integration/inertia_page_contract_test.rb` in place and the
repair absent:

```
Expected response to be a <409: conflict>, but was a <302: Found> redirect to
<https://www.umaxica.app/oauth/authorize?client_id=base-rails-rp&code_challenge=...>
```

**Root cause.** `AuthenticationBase#handle_auth_required_html` and
`AuthenticationBase#authenticate!` branch only on `request.format.json?`. An Inertia visit sends
`Accept: text/html, application/xhtml+xml` plus `X-Inertia: true`, so it took the HTML branch and
got a redirect.

**Why that breaks the current page [upstream].** An Inertia visit is a `fetch` call. The browser
follows a 3xx transparently, so the client receives the credential ceremony's HTML as the body of
what it believes is an Inertia response, raises _"All Inertia requests must receive a valid Inertia
response"_, and leaves the application showing the page it was already on with no route to sign-in.
The protocol reserves `409` with `X-Inertia-Location` for leaving the Inertia application; the
client converts that into a full document visit (`InertiaRails::Controller#inertia_location`, gem
`controller.rb:171`).

**Affected files.** `app/controllers/concerns/authentication_base.rb` — two redirect sites.

**Why existing tests missed it.**

1. `test/controllers/base/app/groups_controller_test.rb` asserted HTML substrings
   (`assert_select "script[data-page='app']"`, `assert_includes response.body, '"component":...'`)
   and never sent an `X-Inertia` header, so no test ever exercised the Inertia request path.
2. Its unauthenticated case asserted `assert_response :redirect` — which is precisely the broken
   behaviour, pinned as correct.
3. `spec/entrypoints/inertia.test.ts` mocks `createInertiaApp` and asserts a console message, so no
   JavaScript test observes real client behaviour either.
4. The repo does not use `InertiaRails::Minitest` (`inertia.component` / `inertia.props`), which the
   gem ships specifically to assert on the page object rather than the markup around it.

**Repair.** A single private method, `convert_redirect_to_inertia_location!`, called after each
authentication redirect. It is a no-op unless `request.inertia?`, so no non-Inertia behaviour
changes — confirmed by the unchanged
`test "a plain unauthenticated browser request still redirects"` and by the full suite. It writes
the status, header and body directly rather than calling the gem's `inertia_location`, because that
helper uses `head`, which refuses to run once `redirect_to` has written a body.

**Regression test.** `test/integration/inertia_page_contract_test.rb`, test _"an unauthenticated
Inertia visit leaves the app with a location refresh, not a redirect"_ — the test whose failure is
quoted above.

### 2.2 No FQDN availability kill switch existed (implemented)

**Symptom.** There was no way to take a single FQDN out of service at the Rails layer. `flipper` was
in use, but every read lived in a service, adapter, or job; no controller consulted a flag [repo].

**Implementation.**

- `app/values/fqdn_availability_registry.rb` — the explicit allowlist. 29 slots, each mapping to the
  hostnames that reach it, mirroring `constraints(host:)` in `config/routes/*.rb` (boot-config slot,
  the same environment variables, the same literal development aliases). The feature name is derived
  from the **slot**, never from the `Host` header, so no request input can name a feature.
- `app/values/feature_flags.rb` — 29 `:availability`-polarity flags, generated from the slot list so
  the two lists cannot drift.
- `app/controllers/concerns/fqdn_availability_gate.rb` — `prepend_before_action`, renders `503` with
  `Retry-After: 60`, JSON or plain text by negotiation, no Rails flash.
- Included in all 43 surface base controllers (`*/application_controller.rb`,
  `*/bare_controller.rb`).
- Six controllers declare their own `prepend_before_action`, which would land ahead of an inherited
  one; each now calls `ensure_fqdn_gate_first!` immediately after.

**Fail-closed properties, each asserted [run].** Explicitly disabled → 503. Never written → 503
(availability polarity). Flag store raising → 503, rescuing the named
`ActiveRecord::ActiveRecordError` boundary only, never `StandardError`. Routable host with no
registry entry → 503 with reason `unknown_fqdn`.

**Ordering, asserted on the callback chain rather than inferred [run].** For every controller that
includes the gate, `enforce_fqdn_availability!` is the **first** `before_action` and precedes the
`rate_limit` callback. Two further tests prove the consequences directly: the rate-limit store's
`increment` is never called (0 invocations, via a stub), and no `avatar_groups` query is issued (via
a `sql.active_record` subscriber). A separate test proves no authentication redirect is emitted.

**Health exemption.** `/health` and everything beneath it bypass the gate, per
`adr/internal-health-endpoint-edge-isolation.md`: switching a public FQDN off must not blind the
internal probes that report why. Asserted [run].

**Unknown `Host` — precise behaviour.** A hostname the application does not serve never matches a
`constraints(host:)` block, so **routing** rejects it with `404` before any controller exists to
consult a switch [run]. That is the outer fail-closed layer; the gate's `unknown_fqdn` branch is the
inner backstop for a host that becomes routable without a registry entry. Both are tested. The
outcome is fail-closed in both cases, but the status code differs by layer, and the audit records
that rather than claiming a uniform 503.

**Drift protection.** `test/security/invariants/fqdn_availability_registry_invariant_test.rb` fails
if a route gains a hostname with no switch, if a routed boot-config slot has no switch, if a slot
resolves to no hostname, if two slots claim one hostname, or if any slot's flag is not
availability-polarity.

## 3. Confirmed working behavior

Not everything examined was broken. The following were verified and are correct:

- **The Inertia page object and navigation.** Component name, `props`, `url` (including the query
  string), `version` equal to `ViteRuby.digest`, and `encryptHistory` are all correct on the initial
  document; an `X-Inertia` GET returns the same page object as JSON with the same `url`; a stale
  `X-Inertia-Version` yields `409` + `X-Inertia-Location` [run]. The brief's "current page" premise
  was correct only for the authentication path in §2.1.
- **`config.parent_controller` is not a defect.** `Base::App::GroupsController` does not descend
  from `::ApplicationController`, which looks alarming, but `InertiaRails::Engine` includes
  `InertiaRails::Controller` into **all** of `ActionController::Base`; `parent_controller` only
  feeds the generators [upstream, `engine.rb:9-13`, `configuration.rb:50`].
- **The Inertia initializer is not misconfigured.** It is byte-for-byte the upstream generator
  template plus the `parent_controller` line [upstream,
  `lib/generators/inertia/install/templates/initializer.rb`].
- **Entra ID matches its ADR** on every point checked: `uid = "tid:oid"`, `scope` is
  `[:openid, :profile]` with no `email` scope, UserInfo is never called, `info`/`credentials` return
  `{}` so no raw tokens leave the strategy, `acct == "0"` rejects guests and personal accounts,
  `ver == "2.0"`, RS256 only, issuer and audience verified, nonce compared in constant time, and
  `OrgEntraResolver` raises `IdentityNotFoundError` rather than provisioning — the ADR's "sign-in
  only; no JIT provisioning" rule [repo].
- **The Cloudflare Access boundary is intact.** A repo-wide search finds **no** reference to
  `CF-Access-Jwt-Assertion` or any `CF-Access-*` header in Rails code [repo]. Cloudflare Access
  identity is never converted into a Rails application identity;
  `adr/org-cloudflare-access-authentication-layer.md` scopes Access to read-only org content and
  leaves `auth/org`, `base/org`, `core/org` on full Operator ceremonies, which is what the code
  does.
- **Health endpoint documentation is accurate, not stale.** `/health` plus
  `/health/{liveness,readiness,startup}` on every surface; **no `/up` route exists**, and
  `docs/operations/health-check.md` already says not to use it and records that `/health/live` and
  `/health/ready` were removed without a shim [repo]. The obsolete-endpoint sweep the brief asked
  for found the documentation already correct.
- **Shrine documentation is largely accurate.** `docs/dds.md:289` and `docs/srs.md:69` already state
  that Shrine is not wired to object storage.

## 4. Shrine/S3 readiness — AUDIT ONLY, NO FEATURE IMPLEMENTATION

No Shrine or S3 code was written, and no Shrine configuration was changed.

**What exists.** `shrine 3.9.0`, `image_processing`, `ruby-vips`, and `aws-sdk-s3 1.229.0` are in
the lockfile. `config/initializers/shrine.rb` is the entire integration: `Memory` storages in test,
local `FileSystem` storages otherwise, and the `activerecord`, `cached_attachment_data`, and
`restore_cached_data` plugins.

**What does not exist.** No `Shrine::Storage::S3`. `aws-sdk-s3` is declared `require: false` and is
**never required** anywhere — only `aws-sdk-sns` is used. `app/uploaders/` contains only `.keep`. No
model includes an attachment. No `determine_mime_type`, `validation_helpers`, `derivatives`,
`url_options`, or `default_url`. No signed-URL generation, no direct-upload endpoint, no deletion or
orphan-cleanup hook. `config/storage.yml` is `Disk`-only.

**The one artefact.** `avatars.image_data jsonb not null default {}` exists in the schema
(`db/avatars_migrate/20251225200010_create_avatar_identity_core_tables.rb:22`). The `Avatar` model
never references it. It is a Shrine-shaped column with no Shrine attached.

**Naming hazard.** In this repository **"Avatar" is a domain actor** (see
`adr/avatar-account-bridge-boundary.md`, `adr/avatar-lifecycle-state-authority.md`), not a profile
image. Any future work must not conflate the two; the `image_data` column happens to sit on the
actor table.

**Readiness verdict.**

| Question                              | Answer                                                                                                                                                                                                                                                                                                                      |
| ------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Already usable                        | Nothing. The gem loads; no code path uploads, validates, derives, or serves a file.                                                                                                                                                                                                                                         |
| Incomplete                            | The `avatars.image_data` column: correct shape, no attacher, no uploader, no validation.                                                                                                                                                                                                                                    |
| Stale                                 | `docs/hld.md` listed Shrine under "Integration"; corrected in this pass. `docs/dds.md` and `docs/srs.md` were already accurate.                                                                                                                                                                                             |
| Needs implementation                  | S3 storage definition, credential lookup, an uploader class with MIME and size validation, derivatives, URL/signed-URL policy, replacement and deletion behaviour, user-deletion cleanup, orphan cleanup, and test isolation from real S3. Essentially all of it.                                                           |
| Architectural decision still required | Public vs private object model and therefore whether URLs are signed; whether the object store is reached directly or through the CDN; whether upload is direct-to-S3 or Rails-mediated; which database owns the attachment metadata given `adr/avatar-db-content-db-boundary.md`; and what happens when S3 is unavailable. |

**Can a user avatar be added later without changing the current persistence architecture?**
[inference, from the above] Yes for the Rails-side persistence: `image_data` is already a `jsonb`
column on the right table and Shrine's `activerecord` plugin is already loaded, so an attachment
could be added without a migration. No for storage: there is no S3 storage definition, no credential
lookup, and no validation, so the storage layer would be built from scratch. Nothing found in this
audit blocks that work; nothing found supports the claim that it is partly done.

## 5. Rails-local findings raised outside the original repair scope

§5.1 was raised as a finding, approved by the user [decision], and repaired to the user's
specification (exact-match paths, not a prefix). §5.2 remains documented and unchanged.

### 5.1 Production host authorization excluded only the exact `/health` path (repaired)

The original code [repo]:

```ruby
# Skip DNS rebinding protection only for health checks and load balancer probes.
config.host_authorization = { exclude: ->(request) { request.path == "/health" } }
```

The comment names load balancer probes in the plural; the implementation matched one path. The probe
set this application mounts is four (`docs/operations/health-check.md`,
`adr/internal-health-endpoint-edge-isolation.md`), so `/health/liveness`, `/health/readiness` and
`/health/startup` were answered by Host Authorization rather than by the probe whenever the caller
addressed the origin by a name outside `config.hosts`.

#### What the probes actually send — evidence

Before changing anything, every probe definition in this repository was inventoried [repo]:

| Prober                            | Definition                                                                                               | Sends a `Host`?                                                      |
| --------------------------------- | -------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| Container health check            | `Containerfile:161-162` — `ruby -rsocket -e "TCPSocket.new('127.0.0.1', …).close"`                       | **No HTTP at all.** A TCP connect. Never reaches Host Authorization. |
| `core` service (Rails) in Compose | `compose.yaml:4-287`                                                                                     | **No `healthcheck:` block.**                                         |
| `bin/tunnel-origin-check`         | `bin/tunnel-origin-check:75` — `http://${host}:3000/health`                                              | Yes — one of 28 served `*.localhost` names, all in `config.hosts`.   |
| Manual operator probing           | `podman/core/preferences/.bash_history:1466-1468` — `curl http://base.app.localhost:3000/health/startup` | Yes — a served host.                                                 |
| Kubernetes / Kamal                | none found (`livenessProbe`/`readinessProbe`/`startupProbe` return no matches; no `config/deploy.yml`)   | n/a                                                                  |

**Conclusion: no HTTP health probe in this repository depends on the exemption.** The only container
health check is a TCP connect, and every HTTP prober that does exist already addresses the origin by
a hostname `config.hosts` accepts. The exemption is a backstop for orchestrator configuration that
lives outside this repository and cannot be inspected from here.

#### Repair

`lib/health_probe_paths.rb` holds the four paths and matches them **exactly**:

```ruby
config.host_authorization = { exclude: ->(request) { HealthProbePaths.probe?(request) } }
```

Exact matching rather than a `/health/` prefix is deliberate [decision]. A prefix test would hand
the exemption to every future path under `/health/` silently, at the moment it is added — a later
probe returning richer diagnostics would lose DNS rebinding protection without anyone deciding it
should. A fifth path must now be added to the list on purpose.

#### What the exemption costs

A path listed here is reachable by a DNS rebinding attacker, who can read the response. That is
accepted for these four because their public JSON is deliberately limited to `status`, the probe
name, `{ "database": "ok" }`, and a surface label and revision — never exception classes, messages,
credentials, or topology (`docs/reference/health-endpoints.md`). The three added paths expose
**nothing that `/health` did not already expose**: the `/health` snapshot nests all three probe
payloads, and it was already exempt. The change widens the path count without widening the
information.

#### Preferred alternative, ahead of any exemption

**Give the probe a `Host` header that is already in `config.hosts`.** A probe that does so needs no
exemption at all, and every HTTP prober in this repository already works this way. Concretely, for
an orchestrator probe:

```yaml
livenessProbe:
  httpGet:
    path: /health/liveness
    port: 3000
    httpHeaders:
      - name: Host
        value: www.umaxica.app # a name already in config.hosts
```

If the out-of-repository orchestrator configuration can be changed this way, the exemption list
should shrink rather than grow, and `HealthProbePaths::PATHS` could eventually be emptied. That
decision needs the production probe configuration, which is not visible from this repository.

#### Regression test

`test/config/health_probe_paths_test.rb` drives the real `ActionDispatch::HostAuthorization`
middleware — asserting the predicate in isolation would not prove the exemption works. With an
allowlist of one host and a probe `Host` of `base-app-7d9f4c` (a container-name shape, deliberately
not allowed):

- all four probe paths return `200` and reach the application;
- `/healthcheck`, `/health/foo`, `/health/liveness/extra`, `/health/`, and `/groups` return `403`;
- a hypothetical `/health/diagnostics` returns `403`, pinning the no-inheritance property;
- an allowed host reaches the application on every path.

### 5.2 `palm_corporate` and `palm_staff` are configured but unrouted

`ConfigValues::HostFamilyValues` defines `palm_corporate` and `palm_staff` with real hostnames
(`palm-jp.umaxica.com`, `palm-jp.umaxica.org`), but `config/routes/palm.rb` constrains on
`palm_service` only [repo]. They are configuration for surfaces that do not exist.

Surfaced by the new registry invariant, which is deliberately scoped to routed slots and carries a
comment explaining the exclusion. Giving them an availability switch would give an operator a
control with no effect. Either the routes are missing or the configuration is dead; that is a
product question, not one this audit can answer from evidence.

Related and already documented in the repository: `config/environments/production.rb:186-193`
records that the docs and news surfaces have no production host entry.

## 6. Deferred work (outside this repository)

- The Cloudflare edge rule blocking public `/health*` traffic is owned in the Cloudflare dashboard
  (`adr/internal-health-endpoint-edge-isolation.md`); this audit cannot verify it and did not try.
- The Cloudflare Access policy for org docs/help/info/news is likewise external
  (`adr/org-cloudflare-access-authentication-layer.md`).
- Real-browser verification of Inertia client behaviour needs a running origin
  (`E2E_BASE_SERVICE_URL`); see §7.
- The integrated status page named as the user-facing availability SSoT is an external service.

## 7. Known gap: no browser-level Inertia test

The Inertia repairs and contracts here are all **server-side**. One client-side risk was identified
but **not** confirmed, and is recorded as inference rather than a finding:

`app/views/layouts/base/app/inertia.html.erb` tags the only script that boots the SPA with
`data-turbo-eval="false"`, while the sibling `app/views/layouts/base/app/application.html.erb` on
the same host loads Turbo Drive via `src/entrypoints/application.ts` [repo]. A Turbo Drive visit
into `/groups` would then swap the body without evaluating the surface Inertia entrypoint
(`entrypoints/inertia/base_app.tsx`, formerly `entrypoints/inertia.tsx`), leaving `#app` empty
[inference]. This was **not** reproduced: it needs a real browser against a real origin, and
`playwright.config.ts` requires `E2E_BASE_SERVICE_URL`, which is not available in this session. It
is recorded here so it is not lost, and explicitly not counted as a defect.

The related test-quality gap is real regardless: `spec/entrypoints/inertia.test.ts` mocks
`createInertiaApp`, so no JavaScript test in this repository observes the client actually mounting.

## 8. Test evidence

All runs in this session, in order. Infrastructure: Postgres `primary`/`replica`, `valkey` (verified
reachable before starting).

| #   | Command                                                                               | Result                                                                            |
| --- | ------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| 1   | `env RAILS_ENV=test bin/rails db:prepare`                                             | success                                                                           |
| 2   | `bin/rails test` (**baseline, before any edit**)                                      | 9941 runs, 47559 assertions, **2 failures**, 0 errors, 1 skip                     |
| 3   | `bin/rails test test/integration/inertia_page_contract_test.rb` (before repair)       | 6 runs, **1 failure** — the 302-instead-of-409 quoted in §2.1                     |
| 4   | same, after repair                                                                    | 6 runs, 24 assertions, 0 failures                                                 |
| 5   | `bin/rails test test/controllers/base/app/groups_controller_test.rb`                  | 6 runs, 39 assertions, 0 failures                                                 |
| 6   | `bin/rails test test/integration/fqdn_availability_gate_test.rb`                      | 15 runs, 2878 assertions, 0 failures                                              |
| 7   | `bin/rails test test/security/invariants/`                                            | 98 runs, 559 assertions, 0 failures                                               |
| 8   | `bin/rails test` (after gate wiring)                                                  | 9967 runs, 50343 assertions, **1 failure** — `DefaultWebRateLimitTest`, see below |
| 9   | `bin/rails test test/controllers/concerns/default_web_rate_limit_test.rb` (after fix) | 2 runs, 311 assertions, 0 failures                                                |
| 10  | `bin/rubocop` on all changed files                                                    | 11 files, no offenses                                                             |
| 11  | `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`                      | 735 controllers, 557 models, **0 security warnings**, 0 errors                    |
| 12  | `bin/rails test test/config/health_probe_paths_test.rb`                               | 5 runs, 18 assertions, 0 failures                                                 |
| 13  | `bin/rails test` (final)                                                              | **9972 runs, 50667 assertions, 0 failures, 0 errors, 1 skip**                     |

### Failure classification

- **`DefaultWebRateLimitTest` (run 8) — caused by this work, fixed.** The test drove a probe
  controller with a synthetic `Host: example.com`. The new gate correctly refused an unserved
  hostname with 503 before the rate limiter, which is the behaviour the gate exists to provide. The
  test now uses `base.net.localhost`, a hostname the application actually serves, with a comment
  recording why. This is a test correction, not a workaround: the assertion it makes about the
  300/min limit is unchanged and still passes.
- **`CsrfNotificationEmissionTest` and `Jit::Security::TurnstileVerifierTest` (run 2) —
  pre-existing.** Both failed on the untouched baseline before any edit, and neither is in a code
  path this work touches. Both passed in runs 8 and 12, so they are **order- or
  parallelism-dependent**, not deterministic failures. Recorded rather than fixed: they are outside
  this audit's scope, and the baseline proves they are not attributable to it.
- No failure in this work was environment-dependent or external-service-dependent.

### 8.1 Final full-suite result

`bin/rails test` — **9972 runs, 50667 assertions, 0 failures, 0 errors, 1 skip** (exit 0).

The suite grew by 31 runs and 3108 assertions against the baseline, and the two pre-existing
baseline failures did not recur, confirming they are order-dependent rather than deterministic.

### Coverage

`.simplecov` enforces a line-coverage minimum of 94 and `COVERAGE=true` pins `PARALLEL_WORKERS=1`,
making a coverage run substantially slower than the ~11-minute parallel suite. A before/after
coverage comparison was **not** run in this session. Stated plainly rather than estimated: all new
application code (`fqdn_availability_registry.rb`, `fqdn_availability_gate.rb`, the
`convert_redirect_to_inertia_location!` branch) is exercised by the new tests listed above, but the
project-wide percentage change is unmeasured.

## 9. Changed files

**Repairs**

- `app/controllers/concerns/authentication_base.rb` — added `convert_redirect_to_inertia_location!`
  and called it from the two authentication-redirect sites. The §2.1 defect.

**FQDN availability kill switch**

- `app/values/fqdn_availability_registry.rb` (new) — the FQDN allowlist and slot resolution.
- `app/values/feature_flags.rb` — registers one availability flag per slot.
- `app/controllers/concerns/fqdn_availability_gate.rb` (new) — the gate itself.
- 43 × `app/controllers/*/*/{application,bare}_controller.rb` — one `include ::FqdnAvailabilityGate`
  line each, immediately above the existing `include ::RateLimit`, so the ordering is visible at the
  point of declaration.
- `app/controllers/auth/{app,com,org}/preferences_base_controller.rb`,
  `app/controllers/auth/app/oidc/callbacks_controller.rb`,
  `app/controllers/auth/app/sign/in/sessions_controller.rb`,
  `app/controllers/concerns/oidc_rp_logout_launcher.rb` — `ensure_fqdn_gate_first!` after their own
  `prepend_before_action`, which would otherwise land ahead of the gate.
- `config/locales/{jp,us}/{en,ja}.yml` — the operator-facing unavailable message, in the same four
  files every other message uses.
- `.rubocop.yml` — `app/values/fqdn_availability_registry.rb` added to the existing
  `ThreadSafety/ClassInstanceVariable` exclusion list, with the reason inline (write-once
  memoization of a pure function of boot config).

**Tests**

- `test/integration/inertia_page_contract_test.rb` (new) — the Inertia protocol contract and the
  §2.1 regression test.
- `test/integration/fqdn_availability_gate_test.rb` (new) — fail-closed behaviour and callback
  ordering.
- `test/security/invariants/fqdn_availability_registry_invariant_test.rb` (new) — registry/route
  drift protection.
- `test/test_helper.rb` — enables the availability flags per test, following the existing
  `PROVIDER_FEATURE_NAMES` precedent for fail-closed flags.
- `test/controllers/concerns/default_web_rate_limit_test.rb` — served hostname instead of a
  synthetic one; see the failure classification above.

**Host Authorization (§5.1)**

- `lib/health_probe_paths.rb` (new) — the four exempt paths, exact match, with the cost of the
  exemption and the reason a prefix match was rejected recorded inline. In `lib/` rather than
  `app/values/` because environment files are evaluated before autoloading.
- `config/environments/production.rb` — `require_relative` for the above; the exclusion now
  delegates to it. The comment records why the exemption exists, why it is exact-match, and that
  giving the probe an allowed `Host` is preferred over any exemption.
- `test/config/health_probe_paths_test.rb` (new) — drives the real
  `ActionDispatch::HostAuthorization` middleware.

**Documentation**

- `docs/reference/feature-flags.md` — the new flag family, its polarity, the request-flow position,
  and the health exemption.
- `docs/hld.md` — removed Shrine and Active Storage from the "Integration" layer; neither integrates
  anything (§4).
- `docs/audits/rails-intended-functionality-audit.md` (this file, new).
- `notes/implementation/2026-08-11-rails-intended-functionality-audit.md` (new).

## 10. Architecture after this audit

Rails-only request flow, as the repository actually behaves after this work:

```text
request
   |
   v
Rack middleware  (TrustedForwardedHeaders, OmniAuth host matrix, InertiaRails::Middleware)
   |
   v
Host Authorization        config.hosts; production excludes exact "/health" only  [see 5.1]
   |
   v
Routing                   constraints(host:) per surface; an unserved Host -> 404
   |
   v
FQDN availability gate    prepend_before_action; unknown or switched-off -> 503   [NEW]
   |                      /health and /health/* exempt
   v
rate limit                surface-wide default_web, plus per-endpoint rules
   |
   v
current context / preference / region
   |
   v
authentication            AUTHENTICATION_MODE policy, then authenticate_*!
   |                      Inertia visits leave via 409 + X-Inertia-Location      [REPAIRED]
   v
current actor / verification / authorization  (Action Policy)
   |
   v
controller action -> Inertia page object | JSON | HTML
   |
   v
services, queries, value objects
```

Two boundaries that are deliberately _not_ in that chain:

- **Cloudflare Access** sits in front of org docs/help/info/news at the edge. It is an
  infrastructure/operator access boundary. It never becomes a Rails application identity, and Rails
  reads none of its headers.
- **The Cloudflare edge block on `/health*`** is external. The Rails-side probes remain reachable
  internally, including while an FQDN is switched off.

## 11. References

Primary documentation consulted, separated from repository fact throughout:

- Ruby on Rails 8.2 API — `ActionController::RateLimiting`, `AbstractController::Callbacks`
  (`prepend_before_action` ordering), `ActionDispatch::HostAuthorization`. Verified against the
  vendored source at `vendor/bundle/ruby/4.0.0/bundler/gems/rails-8ef2d8df565a/`.
- Inertia Rails 3.22.0 — verified against the vendored gem: `lib/inertia_rails/engine.rb`,
  `renderer.rb`, `middleware.rb`, `controller.rb`, `helper.rb`, `configuration.rb`,
  `lib/generators/inertia/install/templates/initializer.rb`, `lib/inertia_rails/minitest.rb`.
  Upstream project: https://github.com/inertiajs/inertia-rails ; protocol:
  https://inertiajs.com/the-protocol
- Flipper — https://www.flippercloud.io/docs ; adapters: https://github.com/flippercloud/flipper.
  Polarity handling is this repository's own convention, recorded in `app/values/feature_flags.rb`
  and `docs/reference/feature-flags.md`.
- Shrine — https://shrinerb.com/docs/getting-started ; S3 storage:
  https://shrinerb.com/docs/storage/s3 (consulted for the §4 readiness checklist only; nothing
  implemented).
- AWS S3 — https://docs.aws.amazon.com/AmazonS3/latest/userguide/ (presigned URLs, object ownership;
  §4 only).
- Microsoft Entra ID / OIDC — https://learn.microsoft.com/entra/identity-platform/id-tokens and
  https://learn.microsoft.com/entra/identity-platform/access-token-claims-reference for the `tid`,
  `oid`, `acct`, and `ver` claim semantics the §3 verification relies on.

Repository decision records: `adr/org-entra-id-sign-in-boundary.md`,
`adr/org-entra-omniauth-strategy-migration.md`, `adr/org-cloudflare-access-authentication-layer.md`,
`adr/internal-health-endpoint-edge-isolation.md`, `adr/avatar-account-bridge-boundary.md`,
`adr/avatar-db-content-db-boundary.md`, `adr/avatar-lifecycle-state-authority.md`,
`docs/operations/health-check.md`, `docs/reference/health-endpoints.md`,
`docs/reference/feature-flags.md`.
