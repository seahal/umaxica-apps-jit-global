# Rails–Next.js OpenAPI Contract: Audit and Design

Status: Phases 0 through E complete (2026-08-22). Phase F is complete as far as its accepted ADR
permits; the namespace migration itself is gated and is not done. Both CI jobs are written but could
not be installed, because `.github` is mounted read-only here — the patch is at
`plans/patches/openapi-contract-ci-jobs.patch` and applies cleanly. Audit date: 2026-08-22. All
external sources were verified on that date.

Phase 0 changed two files and no code:

- `adr/api-versioning-and-client-conventions.md` — section 4 amended from OpenAPI 3.2.x to 3.0.4,
  with an "Amendment 2026-08-22" section carrying the tooling evidence, the reversal condition, and
  the three accuracy defects this audit found. Sections 1 through 3 are unchanged. Its stale premise
  is corrected inline, its selective-coverage policy is recorded as accepted and carried forward,
  and its four follow-up items are marked done, superseded, or planned.

## 1. Executive summary

This repository does not need OpenAPI introduced. It needs OpenAPI enforced.

`public/openapi.yml` already exists (581 lines, `openapi: 3.2.0`, nine paths).
`adr/api-versioning-and-client-conventions.md` §4 already mandates it. `committee-rails` is already
in `Gemfile:187`. RFC 9457 Problem Details are already implemented end to end. What is missing is
the mechanism that makes the document true: no test, initializer, rake task, or CI job reads
`public/openapi.yml`.

The audit found a live contract defect that proves the point. The document declares `openapi: 3.2.0`
and uses `nullable: true` at `public/openapi.yml:523`, `:532`, `:541`. `nullable` was removed in
OpenAPI 3.1 and does not appear anywhere in the 3.1.1 or 3.2.0 specification text. JSON Schema
2020-12 ignores unknown keywords rather than rejecting them, so `slug`, `summary`, and
`published_at` are currently documented as non-nullable strings while
`app/services/publishing_entry_serializer.rb:38` emits `null` for them. The contract and the
implementation already disagree and nothing noticed.

Two further defects surfaced when the host mapping was verified, and both are the exact failure mode
the governing ADR names. `public/openapi.yml:28-29` offers `docs.jp.umaxica.app` as the example
content-surface host, but `config/environments/production.rb:191-197` records that the docs and news
surfaces have **no production host entry at all**, and `compose.yaml:285-288` records that names of
that shape "are no longer configured anywhere and Rails would reject them". Separately, all five
`/api/v0/entries` operations are documented under a `servers` block defaulting to `jp.umaxica.app`,
which is Core — and `config/routes/core.rb` does not route `entries` at any point. The document
describes two hosts that cannot serve the endpoint it attaches them to.

Two assumptions in the original proposal did not survive the audit.

First, the tooling. OpenAPI 3.2.0 is real and current (released 2025-09-19), but `committee` raises
on anything above 3.0.x and `openapi-typescript` has no 3.2 support. There is exactly one
specification version on which the entire candidate toolchain works: **3.0.x**.

Second, the consumer. The Next.js application lives in a separate repository,
`seahal/umaxica-apps-edge`, and it does not consume `/api/v0` as a typed API. It forwards those
paths byte for byte to Rails over a Cloudflare VPC binding without parsing the JSON. There are zero
named call sites, zero response types, zero runtime validation, and zero occurrences of the string
`openapi` in that repository. Client generation would be greenfield there, with nothing to generate
against a caller for.

The resulting design is deliberately narrow: fix the specification version, split the document per
surface, converge the response shapes that are already decided but unimplemented, wire `committee`
into Minitest, and gate CI on lint, drift, and `oasdiff`. Client generation, schema distribution,
and documentation UI are deferred until a real consumer exists.

## 2. Current architecture

Nine services (`base`, `auth`, `core`, `side`, `palm`, `docs`, `help`, `info`, `news`) crossed with
five surfaces (`app`, `com`, `org`, `net`, `dev`). Surface is determined entirely by
`constraints host:` in `config/routes/*.rb` — there is no path prefix. `config/routes.rb` is 37
lines of `draw` calls; the nine drawn files total 2277 lines.

`core` is the regional BFF. `jp.umaxica.app` is served jointly by Rails Core and the external
Next.js Core, split by path. The authoritative table is
`docs/operations/core-nextjs-zero-cookie-edge-contract.md:25-45`: Rails owns `/api/v0/*`,
`/web/v0/*`, `/edge/v0/*`, `/oidc/*`, `/sign/out`, `/.well-known/jwks.json`, and
`/csp-violation-report`; Next.js owns everything else with the inbound `Cookie` header removed.

Every route is reachable under two Host headers: the public cloudflared name (`PUBLIC_*`) and the
compose-network ingress alias (`PRIVATE_*`). See `config/routes/core.rb:7-10` and commit
`8d82539d9`.

Three authentication mechanisms, one per boundary, each mutually exclusive by design:

- Core BFF: first-party cookie plus `X-CSRF-Token`. `core_browser_api_boundary.rb:35-38` rejects any
  request that also carries an `Authorization` header.
- Palm native: Bearer token. `palm/app/api/v0/base_controller.rb:27-30` rejects any request that
  also carries a `Cookie` header.
- Content surfaces: unauthenticated public read.

## 3. Repository evidence

| Fact                                                                                                      | Evidence                                                                                                                             |
| --------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Ruby 4.0.6, Rails 8.2.0.alpha tracked from git `main`                                                     | `.ruby-version:1`, `Gemfile:12`                                                                                                      |
| Full Rails (`rails/all`), a few `ActionController::API` controllers                                       | `config/application.rb:44`                                                                                                           |
| Minitest, 1492 test files. `spec/` is Vitest, not RSpec                                                   | `test/`, `vitest.config.ts`                                                                                                          |
| `committee-rails` present, referenced by zero lines of code                                               | `Gemfile:187`; `grep -rn Committee app lib config test` returns nothing                                                              |
| Nine documented paths, roughly 40 JSON endpoints exist                                                    | `public/openapi.yml`; controller inventory                                                                                           |
| `/edge/v0` and `/web/v0` undocumented, ~30 controllers                                                    | `adr/api-route-vocabulary-consolidation.md`                                                                                          |
| No Jbuilder views despite the gem being present                                                           | `Gemfile:41`; `find app/views -name "*.jbuilder"` returns nothing                                                                    |
| No serializer gem; responses built by inline `render json:` and plain-Ruby services                       | `app/services/publishing_entry_serializer.rb`                                                                                        |
| All 21 `db/*_structure.sql` files are 448-byte empty dumps; no `schema.rb`                                | `db/`                                                                                                                                |
| No streaming, no multipart in any controller                                                              | `grep send_data\|send_file\|response.stream\|ActionController::Live app/controllers`                                                 |
| `pagy` present, zero usages in `app/`                                                                     | `Gemfile:126`                                                                                                                        |
| CORS middleware entirely commented out                                                                    | `config/initializers/cors.rb:11-19`                                                                                                  |
| No generated-file drift check in CI; one unused precedent exists                                          | `.github/workflows/ci.yml`; `lib/tasks/db_verify_no_schema_drift.rake`                                                               |
| CI skips documentation-only changes                                                                       | `.github/workflows/ci.yml:3-13` (`paths-ignore: docs/**`)                                                                            |
| No release machinery: no CHANGELOG, no release workflow, two tags, `private: true`                        | repository root                                                                                                                      |
| Single deployable artifact is the Rails image                                                             | `Containerfile:463`                                                                                                                  |
| `/api/v0/entries` is routed by docs, help, info, news — never by core                                     | `grep -ln "resources :entries" config/routes/*.rb`; `config/routes/core.rb` has no `entries`                                         |
| docs and news have **no production host entry**; the surfaces are not publicly servable                   | `config/environments/production.rb:191-197`                                                                                          |
| `docs.jp.umaxica.app` in the routes file is dead: absent from `config.hosts` and from the compose aliases | `config/routes/docs.rb:7`; `config/environments/production.rb:152-189`; `compose.yaml:236-291`                                       |
| Legacy `docs-jp.*` / `news-jp.*` / `help-jp.*` / `core-jp.*` aliases were deliberately removed            | `compose.yaml:285-288`                                                                                                               |
| Production hostnames for core, palm, help, info come from ENV and are not knowable from the repository    | `lib/config_values_host_family_values.rb:214-221` (`production ? env.fetch(key) : ...`, raises `KeyError` when missing)              |
| Hard-coded production hosts that _are_ knowable                                                           | `config/environments/production.rb:161-181`: `auth.umaxica.*`, `side-jp.umaxica.*`, `www.umaxica.*`, `jpx.umaxica.*`, `jp.umaxica.*` |

### Consumer repository (`seahal/umaxica-apps-edge`, public)

pnpm monorepo, 21 workspace packages. Next.js 16.3.0, React 19.2.8, TypeScript 7.0.2, pnpm 11.21,
App Router only, OpenNext on Cloudflare Workers.

| Fact                                                                      | Evidence                                                                                                            |
| ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `/api/v0` handled as an opaque reverse proxy                              | `app/core/src/lib/core-dispatch.ts:43` (`RAILS_OWNED_PREFIXES`), `:115-133` (`buildRailsRequest` forwards verbatim) |
| Zero named call sites for any `/api/v0` path                              | grep; the paths appear only in test fixtures                                                                        |
| Zero TypeScript types for Rails responses; zero `problem+json` references | `app/core/src/lib/`                                                                                                 |
| Zero runtime validation libraries (no zod, valibot, ajv, io-ts)           | all `package.json` files                                                                                            |
| Zero occurrences of `openapi` repository-wide                             | grep, including the lockfile                                                                                        |
| The only structured Rails call is a liveness probe                        | `app/core/src/lib/rails-health.ts:16` → `/health/liveness.json`                                                     |
| Production has no VPC binding; Rails transport fails closed               | `app/core/wrangler.jsonc`                                                                                           |
| CI has no reference to the Rails repository or any schema artifact        | `.github/workflows/integration.yaml`                                                                                |
| No git submodule, no npm package published by the Rails repository        | `.gitmodules` absent                                                                                                |
| The hand-written path table cannot read Rails' routes, and says so        | `app/core/src/lib/core-dispatch.ts:39-43`                                                                           |

That last line is the concrete value proposition for a shared schema artifact.

### Two stale comments in Rails, corrected by this audit

- `app/controllers/concerns/api_v0_legacy_error_member.rb:6-8` states the legacy `error` member
  exists because "the Next.js edge application ... and the native Palm client" read it. The edge
  application does not read it.
- `app/controllers/concerns/core_browser_api_boundary.rb:115-119` states that `{"refreshed": true}`
  is returned instead of `204` because "the external Next.js app reads that key". It does not.

## 4. API inventory

In scope for the first iteration (the nine paths already documented):

| Path                                                                  | Controller                                                        | Auth          | Notes                                                                                                     |
| --------------------------------------------------------------------- | ----------------------------------------------------------------- | ------------- | --------------------------------------------------------------------------------------------------------- |
| `/health`, `/health/liveness`, `/health/readiness`, `/health/startup` | `concerns/health_check_rendering.rb`                              | none          | blocked at the edge publicly                                                                              |
| `/api/v0/session`                                                     | `core/{app,com,org}/api/v0/sessions_controller.rb`                | cookie + CSRF | `no-store`                                                                                                |
| `/api/v0/token/refresh`                                               | `core/{app,com,org}/api/v0/token/refreshes_controller.rb`         | cookie + CSRF | rotates cookies                                                                                           |
| `/api/v0/profile`                                                     | `palm/app/api/v0/profiles_controller.rb`                          | Bearer        | `app` surface only                                                                                        |
| `/api/v0/entries`, `/api/v0/entries/{slug}`                           | `{docs,help,info,news}/*/api/v0/entries_controller.rb` (12 files) | none          | only endpoints with ETag/304. **Not routed by core.** Publicly servable on help and info only — see below |

### Host reachability of `/api/v0/entries` (verified 2026-08-22)

`resources :entries` is declared in `config/routes/{docs,help,info,news}.rb` and nowhere else.

| Service | Route host constraint                                                                                       | Production `config.hosts` entry | Publicly servable                 |
| ------- | ----------------------------------------------------------------------------------------------------------- | ------------------------------- | --------------------------------- |
| docs    | `ENV["PRIVATE_DOCS_SERVICE_URL"]`, `docs.jp.umaxica.app`, `docs.app.localhost` (`config/routes/docs.rb:7`)  | **none**                        | **no**                            |
| news    | `ENV["PRIVATE_NEWS_SERVICE_URL"]`, `news.jp.umaxica.app`, `news.app.localhost` (`config/routes/news.rb:7`)  | **none**                        | **no**                            |
| help    | `boot_config…help_service.host`, `help.jp.umaxica.app`, `help.app.localhost` (`config/routes/help.rb:7-11`) | `boot_hosts.help_service.host`  | yes, host from `HELP_SERVICE_URL` |
| info    | `boot_config…info_service.host`, `info.app.localhost`, `info.umaxica.app` (`config/routes/info.rb:7-8`)     | `boot_hosts.info_service.host`  | yes, host from `INFO_SERVICE_URL` |

`config/environments/production.rb:191-197` states this explicitly:

> "The docs and news surfaces have no host entry. Their only entries here were `docs.*.localhost`
> and `news.*.localhost` — private development ingress names, which no production request can carry:
> the edge routes no such name, and `ConfigValues::HostFamilyValues` defines no docs/news member to
> derive a real one from. … Add the real ingress hosts here (preferably via `boot_config`) before
> serving either surface publicly."

Consequences for the specification:

- The `docs.jp.umaxica.app` example at `public/openapi.yml:28-29` must be removed. It is a host
  Rails rejects, and naming it is precisely what
  `adr/api-versioning-and-client-conventions.md:93-106` calls "worse than no description".
- `/api/v0/entries` must not appear under a Core `servers` entry. Core does not route it.
- Real production hosts for core, palm, help, and info come from ENV
  (`lib/config_values_host_family_values.rb:214-221` fetches with no fallback in production and
  raises `KeyError` when absent), so they cannot be enumerated from the repository. Only
  `jp.umaxica.{app,com,org}` and the other literals in `config/environments/production.rb:161-181`
  are knowable statically.
- The docs and news editions **are documented** (D16). Their routes exist and are exercised today —
  `config/routes/{docs,news}.rb:40,80,120` declare `resources :entries` for all three surfaces, the
  compose environment supplies `PRIVATE_DOCS_*` / `PRIVATE_NEWS_*` as `*.{app,com,org}.localhost`
  (`compose.yaml:158-169`), and `test/contracts/publishing_entry_api_contract_test.rb:14` already
  drives the docs edition through `ENV.fetch("PRIVATE_DOCS_SERVICE_URL")`. What they lack is a
  public ingress host, not an implementation. They therefore carry **no `servers` entry** — see §10.

Out of scope for the first iteration: `/edge/v0` and `/web/v0` (~30 controllers); roughly 15 ad-hoc
`{error: ...}` / `{status: "ok"}` renders outside any versioned namespace; and the protocol-fixed
endpoints that `docs/reference/api-design-standards.md:266-282` exempts by design (OAuth 2.0, OIDC,
WebAuthn, DBSC, MCP, `.well-known`).

## 5. Existing type and validation mechanisms

Rails: `app/values/problem_type.rb` is a closed registry of 13 problem types that raises `KeyError`
on an unregistered slug (`:62-65`) rather than inventing a URI. `ProblemDetailsRendering` derives
status from the registry rather than accepting it as a parameter. `ApiProblemExceptionsApp` is
installed as `config.exceptions_app` (`config/application.rb:127`) and handles routing misses under
`/api/` only (`:20`). `ApiContentNegotiation` enforces 406/415 before authentication and CSRF. This
layer is mature; the contract work does not need to change it.

Rails contract testing today: `test/contracts/publishing_entry_api_contract_test.rb:29` pins the
exact key set with `assert_equal ENTRY_KEYS, entry.keys`. Hand-maintained, and the natural thing to
replace with `committee`.

Consumer: no validation of any kind. The in-repo Vite/Inertia frontend has a hand-rolled narrowing
module, `src/lib/payload.ts`, whose header explains that asserting a type onto `response.json()`
"tells the compiler a lie the server is under no obligation to keep". That module does not touch
`/api/v0`.

## 6. Official documentation findings

Every item below was verified on 2026-08-22 against the primary source.

**OpenAPI specification.** 3.2.0 was released 2025-09-19 and is the current version; 3.1.2 shipped
the same day (OAI Releases API; `spec.openapis.org/oas/latest.html`). The OAI states forward
compatibility only — "All existing 3.1 documents will work without modification after updating the
version number" (`learn.openapis.org/upgrading/v3.1-to-v3.2.html`). It is silent on whether a 3.2
document is valid 3.1; the published 3.1 meta-schemas pin `^3\.1\.\d+$`. Version tolerance is scoped
to patch releases only: "Tooling which supports OAS 3.1 SHOULD be compatible with all OAS 3.1.*
versions."

`nullable` was removed in 3.1: "Replace nullable with type arrays … This functionality makes the
OpenAPI-specific nullable keyword redundant" (`learn.openapis.org/upgrading/v3.0-to-v3.1.html`). The
keyword does not occur in the 3.1.1 or 3.2.0 specification text.

Three things the OAI does not provide, which matter here:

- **CSRF cannot be expressed.** The 3.1.x Security Scheme Object has no CSRF or double-submit
  construct. `apiKey` in `cookie` is supported and `apiKey` in `header` is supported; combining them
  in one Security Requirement entry gives AND semantics. Nothing in the specification names this a
  CSRF mechanism.
- **Conditional requests have no official modelling guidance.** `304`, `If-None-Match`, and
  `Last-Modified` do not appear in 3.1.1 or 3.2.0. Only ETag header _syntax_ examples exist.
- **API versioning has no official guidance.** `info.version` is explicitly "the version of the
  OpenAPI Document … distinct from … the version of the API being described".

**committee 5.6.3.** Local primary evidence,
`vendor/bundle/ruby/4.0.0/gems/committee-5.6.3/lib/committee/drivers.rb`: line 57 accepts only
`hash['openapi']&.start_with?('3.0.')`; lines 71-73 raise
`OpenAPI3Unsupported.new('Committee does not support OpenAPI 3.1+ yet')` for anything `>= 3.1`. The
upstream blocker is `openapi_parser` issue #152, open since 2023-07-10.

`Committee::Rails::Test::Methods` hooks `integration_session`, so it works in Minitest
`ActionDispatch::IntegrationTest`; the README shows RSpec examples only, and the default schema path
is `Rails.root/docs/schema/schema.json`, so `committee_options` must be overridden. Version 5.6.3
fixed the Minitest "test is missing assertions" problem (`#473`). `assert_schema_conform` takes an
expected status; omitting it triggers a `Committee.need_good_option` warning. Since 5.0 it validates
both request and response. `committee-rails` carries "Looking for maintainers!" in its README.

**rswag.** RSpec is mandatory — "extends rspec-rails 'request specs'". A GitHub issue search for
Minitest returns zero results. Not viable in this repository. It also does not claim 3.1 support
(issue #464 open since 2021).

**openapi-typescript 7.13.0 (MIT).** "Supports OpenAPI 3.0 and 3.1". No 3.2 support; issue #2577
open since 2026-02-04. Node 20+. Uses `@redocly/openapi-core` internally and honours `redocly.yaml`.
Ships a `--check` flag for verifying generated types are up to date, which implies committing them.
Last release 2026-02-11.

**openapi-fetch 0.17.0 (MIT).** A runtime library only, ~6 kB, consuming the `paths` type. Two
consequences that shape the design: the `error` field is a flat union over all non-2xx responses
rather than a per-status discriminated type, so `response.status` branching is manual; and `onError`
middleware "does not handle error responses with 4xx or 5xx HTTP status codes". Official runtime
support is stated for browsers, Node 18+, and TypeScript 4.7+; Cloudflare Workers is not stated.
Passthrough of `next: { revalidate, tags }` is not documented. No runtime validation at all — types
are erased at build.

**oasdiff v1.29.1 (Apache-2.0).** Reads 3.0, 3.1, and 3.2. `oasdiff breaking` reports `ERR` and
`WARN`. The requested cases map as: `response-required-property-removed` ERR;
`response-optional-property-removed` WARN; `response-required-property-added` INFO;
`response-optional-property-added` INFO; `request-property-enum-value-removed` ERR;
`response-property-enum-value-added` **WARN**; `response-property-became-not-nullable` INFO but
`response-property-became-nullable` **ERR**; `response-property-type-changed` ERR;
`response-success-status-removed` ERR; `new-required-request-parameter` ERR;
`required-response-header-removed` ERR; `optional-response-header-removed` WARN. All three
nullability encodings are normalised to the same thing. Documented false negative: response header
_schema_ changes are not checked (issue #1094). The `--open` flag uploads the comparison to
oasdiff.com.

**Redocly CLI 2.47.0 (MIT).** "Supports OpenAPI 3.2, 3.1, 3.0 and OpenAPI 2.0". `lint`, `bundle`,
`split`, `join` need no account; the commercial surface is Reunite hosting behind `login`/`push`.
Four built-in rulesets: `spec`, `recommended`, `recommended-strict`, `minimal`. ESM-only, Node >=
22.12.

**Documentation UI.** Swagger UI 5.32.0+ supports 3.2 but requires relaxed CSP — unresolved
inline-style violations (#3370, #10655) and `unsafe-eval` for SVG (#7540). Redoc rejects 3.2
outright (`Unsupported OpenAPI version: 3.2.0`, issues #2746/#2762/#2773) but its
`redocly build-docs` emits fully static HTML with no CDN. Scalar's 3.2 support is partial and in
progress. None has an official Rails integration.

## 7. Tool comparison

|                    | committee 5.6.3                                                        | openapi-typescript 7.13              | oasdiff 1.29.1                 | Redocly CLI 2.47          | Redoc            | Swagger UI   | Scalar               |
| ------------------ | ---------------------------------------------------------------------- | ------------------------------------ | ------------------------------ | ------------------------- | ---------------- | ------------ | -------------------- |
| OpenAPI 3.0.x      | yes                                                                    | yes                                  | yes                            | yes                       | yes              | yes          | yes                  |
| OpenAPI 3.1.x      | **raises**                                                             | yes                                  | yes                            | yes                       | yes              | yes          | yes                  |
| OpenAPI 3.2.0      | raises                                                                 | no (#2577)                           | reads                          | lint yes, `build-docs` no | **rejects**      | yes          | partial              |
| Test framework     | framework-agnostic; works in Minitest                                  | n/a                                  | n/a                            | n/a                       | n/a              | n/a          | n/a                  |
| Runtime constraint | Ruby, test-time                                                        | Node 20+                             | Go binary / Docker / GH Action | Node >= 22.12, ESM-only   | browser          | browser      | browser              |
| Cloudflare Workers | n/a                                                                    | n/a                                  | n/a                            | n/a                       | n/a              | n/a          | n/a                  |
| License            | MIT                                                                    | MIT                                  | Apache-2.0                     | MIT                       | MIT              | Apache-2.0   | MIT                  |
| Adoption cost      | low; gem already present                                               | low                                  | low                            | low                       | low              | low          | low                  |
| Long-term risk     | **high** — "Looking for maintainers!"; 3.1 blocked upstream since 2023 | medium — no release since 2026-02-11 | low                            | low                       | medium (3.2 gap) | medium (CSP) | medium (3.2 partial) |

`openapi-fetch` 0.17.0 (MIT) is a runtime library with no codegen; its risks are the flat error
union, the `onError` behaviour, the undocumented Workers support, and the 0.x version line.

Alternatives that generate Zod (Orval, Hey API, kubb — all MIT) were reviewed. None states OpenAPI
3.0 or 3.1 support explicitly in its own documentation, so adopting one would require verification
work that the current design does not need.

## 8. OpenAPI version decision

**OpenAPI 3.0.4.** See D1.

3.0.x is the only version on which `committee`, `openapi-typescript`, `oasdiff`, Redocly, Redoc,
Swagger UI, and Scalar all work. Choosing 3.1 would disqualify `committee` and therefore the entire
Rails-side validation strategy, which is the primary goal. Choosing to stay on 3.2 would disqualify
both Rails validation and TypeScript generation.

3.0.4 rather than 3.0.3 because it is the current patch release of the 3.0 line (2024-10-24) and the
OAS states that tooling "SHOULD be compatible with all OAS 3.0.* versions" and "SHOULD NOT"
distinguish patch versions.

What is given up: JSON Schema 2020-12 alignment, type arrays, `webhooks`, `components.pathItems`,
and the 3.2 additions (`$self`, `additionalOperations`, `itemSchema`, `in: querystring`, tag
hierarchy, optional response `description`). None of these is used by the nine in-scope paths, and
the API has no streaming or webhook endpoints.

A side effect worth naming: the three `nullable: true` usages become _correct_ under 3.0.4, because
`nullable` is the 3.0 keyword. The defect is repaired by the version decision rather than by editing
those lines.

This contradicts `adr/api-versioning-and-client-conventions.md` §4, which specifies 3.2.x. That ADR
must be amended before implementation. Per
`.agents/harnesses/rules/project/repository-knowledge-tree.mdc:32-33`, the conflict is called out
here rather than resolved silently.

## 9. Source-of-truth decision

**The hand-written specification is the sole source of truth, and drift is enforced mechanically.**
See D2.

Accuracy is not produced by the direction of authoring. It is produced by enforcement. The
`nullable` defect is what unenforced hand-authoring looks like after a few months. The alternatives
were rejected on evidence, not preference:

- _Test-generated_ requires rswag, which requires RSpec. This repository uses Minitest. Writing a
  Minitest equivalent means maintaining a generator, and cases the tests do not exercise disappear
  from the contract silently, which is its own drift.
- _Code-first generation_ has no type source. Responses are built by inline `render json:` hashes
  and plain-Ruby service objects; all 21 `db/*_structure.sql` files are empty dumps and there is no
  `schema.rb`.
- _A separate contract repository_ requires release machinery this repository does not have (no
  CHANGELOG, no release workflow, two tags, `private: true`).

Enforcement is four gates: `committee` request and response validation in Minitest, a bidirectional
route-coverage test, Redocly lint plus a bundle drift check, and `oasdiff` on pull requests.

## 10. Schema structure

Source lives under `openapi/`, not `docs/` — `.github/workflows/ci.yml:3-13` has
`paths-ignore: docs/**`, so a contract placed there would not trigger CI.

```
openapi/
  shared/           # Problem, common parameters, common responses
  app.yml           # app surface root
  com.yml           # com surface root
  org.yml           # org surface root
redocly.yaml
public/
  openapi.app.yml   # bundled output, git-tracked
  openapi.com.yml
  openapi.org.yml
```

One document per surface (D4). `.agents/harnesses/rules/project/surfaces.mdc:24-26` makes the
surfaces absolute boundaries and forbids assuming a default host; a single document with
`servers: https://{host}` and `default: jp.umaxica.app` asserts combinations that do not exist —
`/api/v0/profile` is Palm on the `app` surface only, and `/api/v0/entries` is served by four content
services.

Within each surface document, `servers` is declared per Path Item with the real host enumerated, and
no top-level default.

The host verification in §4 constrains what may be enumerated. Only hosts that are literals in
`config/environments/production.rb:161-181` can be written into the document; core, palm, help, and
info resolve theirs from ENV at boot and cannot be known statically. Two workable options, to be
settled in Phase A:

- Write the statically knowable hosts (`jp.umaxica.{app,com,org}` for Core) as literal `servers`
  entries, and use a `{host}` **variable with an `enum` and no `default`** for the ENV-driven
  services, documenting in the variable description which ENV key supplies it.
- Or omit `servers` for the ENV-driven services entirely and state the ownership in the operation
  description. OpenAPI permits an empty `servers`, and an absent entry is more honest than a wrong
  one.

Either way, no path may carry a `servers` entry naming a host that does not route it — the current
document's `/api/v0/entries` under a Core default is the defect this rule exists to prevent.

The docs and news editions are the limiting case and settle the choice for themselves. They have no
public host at all, and the only names that reach them are `PRIVATE_*` values, which
`adr/api-versioning-and-client-conventions.md:93-106` forbids in a file served from `public/`. So
their operations are documented with **no `servers` entry**, and the operation description states
that the edition has no public ingress. An absent `servers` is accurate; any value that could be
written there would be either wrong or internal.

`PRIVATE_*` names must not appear in the bundled output;
`adr/api-versioning-and-client-conventions.md:93-106` requires that the published file "contain no
internal host names, internal route names, or operational detail that is not already public".

`additionalProperties: false` must not be used. The same ADR (L40-59) requires that "Clients must
tolerate unknown response fields", and closing the schemas would make every additive change a
validation failure.

The `Problem` schema is declared once in `openapi/shared/` and referenced from every error response,
as that ADR requires.

## 11. Rails validation strategy

**Minitest integration tests only, validating both request and response.** See D7.

`Committee::Rails::Test::Methods` is included from a helper in `test/contracts/` that overrides
`committee_options` to point at the correct per-surface bundled document. Notes that will matter
during implementation:

- Always pass the expected status: `assert_schema_conform(200)`. Omitting it triggers
  `Committee.need_good_option`.
- Set `strict_reference_validation` explicitly; leaving it unset emits a deprecation warning and it
  becomes the default in the next major version.
- Tests address the `PRIVATE_*` hosts (`test/test_helper.rb:14-21`; existing precedent at
  `test/contracts/publishing_entry_api_contract_test.rb:14`). `committee` matches on path, not host,
  so the host difference is immaterial.
- Error responses are `application/problem+json`. `assert_request_schema_confirm(except:)` is
  available from 5.6.2 for testing error paths.

Middleware validation in development, staging, or production was rejected. It would put a "Looking
for maintainers!" dependency on the request path, and `committee` returns `500 :invalid_response` on
failure, which turns a contract miss into an outage. CI is where a contract violation should stop
the change. This can be revisited if production drift is ever observed.

## 12. Next.js generation strategy

**Out of scope for this iteration.** See D8.

The consumer repository has no `/api/v0` call sites, no response types, and a CI configuration
(`knip --include unlisted,unresolved`, Vitest coverage thresholds at 99%) that would actively fight
unused generated code. Generating a typed client now would be building the thing before the need.

When a real consumer appears, the approach is `openapi-typescript` for types plus `openapi-fetch`
for the client, with the generated file committed and CI failing on regeneration diff (D10);
`openapi-typescript` ships `--check` for exactly this. Two behaviours must be designed around at
that point: the `error` field is a flat union across all non-2xx statuses, and `onError` middleware
does not fire on 4xx/5xx.

The first useful consumer-side deliverable is smaller and available immediately: validating
`RAILS_OWNED_PREFIXES` in `app/core/src/lib/core-dispatch.ts:43` against the specification's
`paths`. That file's own comment at `:39-43` records that the table is hand-maintained because it
"cannot read Rails' `config/routes/core.rb`". That is the seam the schema closes.

## 13. Runtime validation strategy

**None. Compile-time types only.** See D9.

The `committee` tests and the CI gates guarantee that Rails conforms to the contract. Validating the
same contract a second time in the consumer duplicates the guarantee at the cost of a dependency the
consumer repository does not currently have.

Hand-written Zod was rejected specifically because it reproduces the failure this audit found: a
second hand-maintained description of the same shapes, drifting silently. Generated Zod (Orval, Hey
API, kubb) is the only variant that would not drift, but none of those tools states OpenAPI 3.0
support in its own documentation, and adopting one means discarding the `openapi-typescript` +
`openapi-fetch` pairing. Revisit together with D8.

The accepted risk is explicit: if Rails ships a response that violates its own contract and the
tests did not cover that path, the consumer sees a silent `undefined` rather than an error.

## 14. Authentication representation

The existing representation in `public/openapi.yml:325-361` is correct and carries forward:

- `coreBrowserCookie` — `apiKey`, `in: cookie`, name `__Host-auth_access`.
- `bearerToken` — `http`, scheme `bearer`, `bearerFormat: JWT`, documented as rejecting
  cookie-bearing requests.
- A reusable `CsrfToken` header parameter.

The CSRF requirement cannot be expressed as a security scheme; OpenAPI has no such construct in any
version. Modelling it as a required header parameter is the only faithful option and is what the
document already does. This limitation should be stated in `info.description` so that a reader does
not infer that the `securitySchemes` block is the whole authentication story.

The mutual exclusivity that Rails enforces — cookie endpoints reject `Authorization`, Bearer
endpoints reject `Cookie` — is also not expressible. It is enforced in code
(`core_browser_api_boundary.rb:35-38`, `palm/app/api/v0/base_controller.rb:27-30`) and covered by
tests; the specification should describe the rejection responses rather than pretend to constrain
the request.

Out of scope by design, per `docs/reference/api-design-standards.md:266-282`: OAuth 2.0, OIDC
including UserInfo and back-channel logout, WebAuthn, DBSC, MCP, and `.well-known`. Cloudflare
Access and Tailscale are not used by these endpoints; edge trust is `TRUSTED_PROXIES` plus
`TrustedForwardedHeaders` (`config/application.rb:82-86`), which is transport-level and not part of
the API contract.

## 15. Error model

RFC 9457 Problem Details, already implemented, unchanged. `application/problem+json`. Members:
`type`, `title`, `status`, `instance`, `request_id`, plus `detail` and `errors` when present.
`docs/reference/api-design-standards.md:59-98` defines exactly two extension members and requires
that document be updated before a third is added.

Clients branch on `type`, never on `title` or `detail`. The 13 registered types are enumerated in
`app/values/problem_type.rb:23-37` and the registry raises rather than inventing a URI. Adding a new
`type` is not a breaking change per `adr/api-versioning-and-client-conventions.md:40-59`.

Localization is not part of the contract: `type` is the machine-readable branch key and
`title`/`detail` are prose that clients must not parse.

The two transitional shapes are removed before the contract is written (D6):
`api_v0_legacy_error_member.rb` in its entirety, and the string-valued `error:` in
`publishing_content_rendering.rb:58-60`. Both `CoreBrowserApiBoundary:9` and
`Palm::App::Api::V0::BaseController:13` drop the include simultaneously.

Removing the member from the Palm boundary was raised as a risk, because native clients cannot be
forced to update. Two facts make it acceptable and the decision was reaffirmed. First,
`adr/api-versioning-and-client-conventions.md:40-59` states that "`v0` means the contract is not
frozen" and that declaring `v1` is the deliberate act that commits to the deprecation policy.
Second, the Sunset requirement in `docs/reference/api-design-standards.md:228-243` is scoped to
endpoint removal, not to response members. The removal should still be announced through whatever
channel reaches Palm releases.

`{"refreshed": true}` (`core_browser_api_boundary.rb:115-119`) becomes `204 No Content`. See D14.
The stated reason for the current shape — that the external Next.js application reads the key — was
found to be false, and `docs/reference/api-design-standards.md:140-162` requires `204` rather than
"`200` with an empty body or a `{"ok": true}` placeholder".

This is a wire-shape change, so `.agents/harnesses/rules/generic/data-shape-design.mdc:12-35`
applies. The proposal, to be approved before any implementation file is edited:

Before — `POST /api/v0/token/refresh`, `200 OK`, `content-type: application/json`:

```json
{ "refreshed": true }
```

After — `POST /api/v0/token/refresh`, `204 No Content`, no body, no `content-type`.

Authoritative source of the outcome is the `Set-Cookie` rotation performed by
`refresh_core_browser_token!` (`core_browser_api_boundary.rb:82-121`) together with the status code;
the boolean was derived from the status and carried no information the status did not already
convey. `Cache-Control: no-store` is unchanged. Error paths are unchanged and remain
`application/problem+json`. Client impact: no in-repository consumer; no consumer in
`seahal/umaxica-apps-edge`; the Palm native client does not exist yet (see D6). A client that checks
only for a 2xx status is unaffected; a client that parses the body would need to stop.

## 16. JSON naming

`snake_case`, unchanged. `docs/reference/api-design-standards.md:177-189`: "Field names are
`snake_case` and stable. Renaming a field is a breaking change." No transform layer is introduced;
`openapi-typescript` reproduces the wire names verbatim, and adding a camelCase translation would
create a second naming contract to keep in sync.

Also binding from the same section, and directly constraining what the schemas may express:

- A field's type never varies by value. A field that is sometimes an object and sometimes a string
  has no contract. This rules out type-varying `oneOf` members.
- Identifiers on the wire are `public_id`, never database primary keys.
- Timestamps are RFC 3339 with an explicit `Z` and second-or-finer precision. Not epoch integers,
  not local offsets, not bare dates. "ISO 8601" alone is not a sufficient specification.
- Enumerated values are lowercase `snake_case` strings; Rails integer enum backing values are never
  exposed.

## 17. Null and field absence

Under 3.0.4, absence is `required` omission and null is `nullable: true`. The two must not be
conflated, and the specification must say which the field uses.

The current implementation is consistent on this point and the schema needs to catch up:
`app/services/publishing_entry_serializer.rb` always emits all nine keys, with `null` for `slug`,
`summary`, and `published_at` when absent (`:38` uses `effective_from&.iso8601`). So those three are
`required` **and** `nullable: true`; they are never omitted. That is exactly what the current
document fails to express, because `nullable` is inert at 3.2.0.

Empty string and empty array are distinct from both and are not used as absence markers anywhere in
the in-scope endpoints. Defaults are a server-side concern and must not appear as `default` in a
response schema, where they would imply a value the server did not send.

`openapi-typescript` maps `nullable: true` to a union with `null`, and `required` omission to an
optional property, so the distinction survives into the generated types provided the schema draws it
correctly.

## 18. Pagination

Cursor-based, per `adr/api-collection-contract.md`, implemented before the contract is written (D5).

Target: `?limit=<1..100>&cursor=<opaque>` with envelope
`{"data": [...], "page": {"next_cursor": ..., "has_more": ...}}`.

No total count — it is not derivable cheaply and committing to it in v0 would be a promise the
implementation cannot keep. No `Link` header; the envelope is the single mechanism. Ordering must be
stable and explicit, because a cursor over an unstable order is not a contract. Cursor encoding is
opaque and changing it is explicitly non-breaking per
`adr/api-versioning-and-client-conventions.md:40-59`.

The current state is the reason this is sequenced before contract authoring:
`app/controllers/concerns/publishing_content_rendering.rb:24-30` renders every published entry for
the edition with no limit, no cursor, and no `Link` header. Writing that into a contract, even in
v0, would publish an unbounded response as an intended shape.

This is a wire-shape change, so `.agents/harnesses/rules/generic/data-shape-design.mdc:12-35`
applies: a Before/After JSON proposal must be presented and approved before implementation files are
edited.

## 19. Cache

`/api/v0/entries` and `/api/v0/entries/{slug}` are the only cacheable endpoints:
`expires_in(60.seconds, public: true)` plus `stale?(etag:, last_modified:, public: true)`
(`publishing_content_rendering.rb:26-27`, `:37-38`), with the validator computed over the rendered
payload rather than row timestamps (`:21-23`).

Everything else on the API boundary is `Cache-Control: no-store` — the Core BFF
(`core_browser_api_boundary.rb:20-22`), Palm (`palm/app/api/v0/base_controller.rb:72-74`), and the
problem exceptions app (`api_problem_exceptions_app.rb:63`).

Modelled in the specification as `If-None-Match` and `If-Modified-Since` request parameters, a `304`
response with `ETag` / `Last-Modified` / `Cache-Control` headers and no content, and the same
headers on the `200`. The OAI provides no guidance for this, so the shape is a repository decision;
it is already present at `public/openapi.yml:300-323` and carries forward.

Pagination (§18) changes the validator to a per-page value. Consumer-side caching is not designed
here — the consumer sets `cache: 'no-store'` on its only structured Rails call and uses no Next.js
fetch cache options at all.

## 20. Observability

`request_id` is already an RFC 9457 extension member and is the only observability field in the
body. `docs/reference/api-design-standards.md:59-98` permits exactly two extension members, so
nothing else goes in the payload without amending that document first.

Headers described in the contract: `Retry-After` and `RateLimit` on 429
(`app/controllers/concerns/rate_limit.rb:31-32`). `RateLimit-Policy` is deliberately omitted
(`:24-27`), and `adr/api-versioning-and-client-conventions.md:76-91` states that "no client behavior
may depend on them" and that `Retry-After` "remains the sole authoritative retry signal" — the
schema should describe the headers without implying they are actionable.

`traceparent`, Server-Timing, and an API version header are not emitted today and are not added. The
version is in the path. `adr/application-logging-boundary.md` and
`docs/security/observability-boundary.md` constrain what may be surfaced; `detail` in particular
"must never carry tokens, cookies, authorization headers, full request parameters, secrets,
exception classes, or database topology".

Note the `oasdiff` blind spot from §6: response header schema changes are not diffed (issue #1094).
Header contracts are therefore covered by the `committee` tests rather than by the breaking-change
gate.

## 21. Documentation UI

**None.** See D12. The specification files are the deliverable.

The consumers are two first-party clients. A browsable UI has no demonstrated need, and Swagger UI
in particular requires `unsafe-inline` and, for SVG, `unsafe-eval`, which conflicts with
`config/initializers/content_security_policy.rb`. If a need appears, `redocly build-docs` static
HTML is the first candidate: no CDN, no runtime scripts to whitelist, and Redocly CLI is already a
dependency for lint.

## 22. Security considerations

- The bundled documents are served from `public/` and are therefore world-readable. They must
  contain only public hosts and public route information — no `PRIVATE_*` aliases, no internal route
  names, no operational detail. This is an existing ADR requirement, and the per-surface split makes
  it easier to satisfy because each document only names its own surface's hosts.
- Splitting by surface is itself a security property. A single document listing all surfaces invites
  a reader — human or generated client — to try a path on the wrong host, which
  `.agents/harnesses/rules/project/surfaces.mdc` calls a defect.
- `oasdiff --open` uploads the comparison to oasdiff.com. It must not be used.
- Health endpoints are documented but blocked at the edge. The specification must not imply they are
  publicly reachable.
- Removing the legacy error member reduces the surface: the nested member duplicated `request_id`
  and carried a `fields` structure with no schema.
- No new production code path is introduced. Test-only validation (D7) means the contract mechanism
  cannot itself cause an incident.

## 23. Performance considerations

`committee` caches parsed schemas keyed on expanded path plus a content digest (`drivers.rb`, added
in 5.1.0), so per-test parsing cost is paid once per process. `test_helper.rb` parallelises by
physical core count, so each worker parses once.

No production request path is affected, because no middleware is installed (D7). This is the main
performance argument for the test-only decision.

CI cost: one Redocly lint job, one bundle drift check, one `oasdiff` job. All are seconds-scale.
Existing CI runs nine jobs fully in parallel with no `needs:` edges, so these add no critical path
beyond their own runtime.

Pagination (§18) is a performance improvement, not a cost: it replaces an unbounded collection
response.

## 24. Rollout strategy

Sequenced so that each phase is independently revertible and no phase depends on a later one.

Environment note: staging runs in production mode. There is therefore no distinct staging
configuration to target, which independently forecloses the "middleware in staging" variant of D7 —
enabling validation middleware there would be enabling it in production.

**Phase 0 — ADR amendment and this document. Completed 2026-08-22.** Amend
`adr/api-versioning-and-client-conventions.md` §4 from 3.2.x to 3.0.4 with the tooling rationale,
source URLs, access date, and revisit condition. Correct or archive the earlier API schema
documentation plan (since removed), whose stated premise (that `public/openapi.yml` documents only
`/v0/health`) is no longer true. Requires explicit approval, because amending an accepted ADR is a
decision, not an implementation detail.

**Phase A — restructure and repair. Completed 2026-08-22, except the CI job (blocked, see below).**
Created `openapi/` with shared components and three surface roots at 3.0.4; bundled to
`public/openapi.{app,com,org}.yml`; removed the superseded `public/openapi.yml`; added
`@redocly/cli` 2.46.1 as a devDependency and the `openapi:lint`, `openapi:bundle`, and
`openapi:verify` scripts, with the latter two wired into `pnpm check`.

Two further defects were found while verifying the implementation, and both are fixed:

- **`GET /health` is not a JSON endpoint.**
  `app/controllers/concerns/health_check_rendering.rb:17-24` answers `head :not_acceptable` unless
  the request format is HTML, then renders `shared/health/show` with `formats: :html`. The old
  document described it as `application/json` returning `HealthResult`. It is removed from the JSON
  contract and its absence is explained in each document's `info.description`. The JSON contract
  therefore covers eight paths, not nine, and the `check` enum drops `health` because that value
  never appears in a JSON response.
- **The probe responses carry an undocumented `namespace` member.** `app/services/health.rb:53-60`
  emits `<service>/<surface>` (added by commit `5a5b0f1e2`) and `HealthResult` did not describe it.
  It is now a required property.

Verification performed:

- `pnpm -s run openapi:lint` — all three documents valid.
- **`committee` parses all three bundles** with `strict_reference_validation: true`, via
  `Committee::Drivers.load_from_file`. This is the empirical check on decision D1: the whole reason
  for choosing 3.0.4 is that `committee` raises above it.
- The drift check was proved to work rather than assumed: mutating `openapi/app.yml` alone makes
  `pnpm -s run openapi:verify` exit 1, and reverting makes it exit 0.
- `pnpm -s run format:check` and `pnpm -s run deadcode` pass; no dangling code reference to the
  removed `public/openapi.yml` remains.

**Blocked: the `lint-openapi` CI job.** `.github` is mounted read-only in this environment — `mount`
reports
`tank/Projects on /home/global/workspace/.github type zfs (ro,noatime,xattr,posixacl,casesensitive)`.
This is an environment mount, not a sandbox restriction, and remounting a shared dataset is out of
scope for this work. The job below must be added to `.github/workflows/ci.yml` by hand, immediately
before the `scan-gems` job. Until it is, drift is caught only by `pnpm check` (and therefore by the
lefthook pre-push hook), not by CI.

```yaml
lint-openapi:
  name: OpenAPI Contract (redocly lint, bundle drift)
  runs-on: ubuntu-slim
  timeout-minutes: 5
  steps:
    - uses: actions/checkout@v6.0.1
      with:
        persist-credentials: false
    - name: Setup pnpm
      uses: pnpm/action-setup@v4
    - name: Setup Node.js
      uses: actions/setup-node@v6
      with:
        node-version: ${{ env.NODE_VERSION }}
        cache: pnpm
        cache-dependency-path: pnpm-lock.yaml
    - run: pnpm install --frozen-lockfile
    - name: Lint OpenAPI descriptions
      run: pnpm -s run openapi:lint
    # `openapi/` is the source of truth; `public/openapi.*.yml` must always be its bundled
    # form. Regenerating and diffing is the guard the accuracy requirement in
    # adr/api-versioning-and-client-conventions.md section 4 previously lacked.
    - name: Verify bundled output matches source
      run: pnpm -s run openapi:verify
```

### Lint rules disabled, and why

`redocly.yaml` extends `recommended` and turns off exactly three rules, each because the rule would
force an inaccuracy:

- `no-empty-servers` — no surface declares a root `servers`, by decision D15. A root default would
  attach a host to paths it does not serve.
- `operation-4xx-response` — the health probes answer 200 or 503 and nothing else. Inventing a 4xx
  would put a response in the contract that the application never sends.
- `info-license` — a first-party internal description, not a published artifact.

Unauthenticated operations declare `security: []` explicitly rather than omitting `security`, so
`security-defined` passes on its own terms rather than by exemption.

**Phase B — wire committee. Completed 2026-08-22.** Added `test/support/openapi_contract.rb` and
five contract test files, all inside the existing `test-rails` CI job.

| File                                                      | Covers                                                                                                            |
| --------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `test/support/openapi_contract.rb`                        | The helper: declares the surface, builds `committee_options`, wraps the assertions                                |
| `test/contracts/openapi_route_coverage_test.rb`           | Bidirectional router-to-description comparison                                                                    |
| `test/contracts/openapi_health_contract_test.rb`          | The three probes, plus that `GET /health` is not JSON                                                             |
| `test/contracts/openapi_core_session_contract_test.rb`    | `/api/v0/session` and `/api/v0/token/refresh`, success and refusals                                               |
| `test/contracts/openapi_palm_profile_contract_test.rb`    | `/api/v0/profile`, including both credential-transport refusals                                                   |
| `test/contracts/openapi_content_entries_contract_test.rb` | `/api/v0/entries` and `/api/v0/entries/{slug}` on all twelve service-and-surface combinations, plus 304, 404, 406 |

Committee is required from `test/support/openapi_contract.rb` rather than `test_helper.rb`, so it
stays off the load path of the other ~1490 test files.

Two assertion helpers exist, and the distinction matters:

- `assert_openapi_conform(status)` validates the request **and** the response.
- `assert_openapi_response_conform(status)` validates only the response. It is for tests whose
  request is deliberately invalid -- the CSRF-less rotation, for instance. Committee correctly
  refuses to validate an intentionally broken request, so checking it would assert that a
  deliberately malformed request is well formed.

Both clear Committee's per-instance memoisation of `request_object` and `schema_validator` first;
without that a second request in the same test would be checked against the first one's operation.

**Deviation from the plan, and why.** The plan said to replace the hand-maintained key assertions in
`test/contracts/publishing_entry_api_contract_test.rb`. They were kept and Committee added
alongside. `assert_equal ENTRY_KEYS, entry.keys` is strictly stronger than any schema this
repository is allowed to write: `adr/api-versioning-and-client-conventions.md:40-59` forbids
`additionalProperties: false`, so a schema can require every contracted member but can never object
to an extra one. Removing the key-set assertion would have been a coverage regression.

**A third defect, found by writing the tests.** `Entry.published_at` was described as nullable. It
cannot be: `publishing_publications.effective_from` is `NOT NULL`, and
`PublishingEntrySerializer#call` (`:24-25`) renders nothing at all without an active publication, so
an entry that renders always carries a timestamp. `nullable: true` was removed from it and kept on
`slug` and `summary`, which are genuinely nullable -- `slug` because
`PublishingEntrySerializer#canonical_slug` guards a possibly-absent association, and `summary`
because `publishing_entry_versions.summary` is the one nullable column behind the schema. Under
oasdiff this correction is `response-property-became-not-nullable`, which is INFO, not breaking.

Verification, run rather than assumed:

- `bin/rails test test/contracts/` -- 78 runs, 319 assertions, 0 failures.
- Adjacent suites unaffected: `core_browser_api_boundary_test`, `palm/app/api/v0/`,
  `api_problem_exceptions_app_test`, `health_endpoints_test`, `api_content_negotiation_test` -- 63
  runs, 1429 assertions, 0 failures.
- **The route-coverage test was proved to fail**, not assumed to work: deleting `/api/v0/profile`
  from the app bundle produces "the app surface routes these operations but openapi/app.yml does not
  describe them: GET /api/v0/profile".
- **Committee was proved to catch a schema-implementation mismatch**: adding a `fabricated_member`
  to `SessionSummary.required` produces
  `Committee::InvalidResponse: #/components/schemas/ SessionSummary missing required parameters: fabricated_member`.

What Committee does and does not catch, recorded so the next reader does not over-trust it:

- It **raises** on a request to a path the description omits (`Committee::Test::Methods:14-17`), so
  an undocumented endpoint cannot pass silently once a test calls it.
- It validates response **headers** as well as bodies, so the `WWW-Authenticate` and `Cache-Control`
  declarations are enforced.
- It does **not** validate the body of a `204` or a `304`
  (`SchemaValidator::OpenAPI3::ResponseValidator#validate?`). For a 304 the status and headers are
  still checked.
- It cannot object to an unexpected member, because the schemas may not close their objects. That is
  what the key-set assertions are for.

**Phase C — entries envelope and pagination. Completed 2026-08-22.**

`adr/api-collection-contract.md` deferred this as "externally breaking", on the premise that edge
applications consume the entries API. The Phase B audit disproved that premise: the edge repository
forwards `/api/v0/*` without parsing it, and the ADR itself already recorded that no code under
`src/` consumes it. The ADR was amended with an "Implementation 2026-08-22" section recording the
falsified premise rather than quietly proceeding around it.

What shipped:

- `{"entries": [...]}` became `{"data": [...], "page": {"next_cursor": …, "has_more": …}}`;
  `GET /api/v0/entries/{slug}` lost its `{"entry": …}` wrapper, per the ADR's rule that a single
  resource is returned at the top level.
- `?limit=<1..100>&cursor=<opaque>`, default 20, clamped rather than refused.
- `PublishingEntriesCursor` (new) signs the cursor with `Rails.application.message_verifier`,
  following `SessionLimitResolutionTokenRef`. It carries the publication instant and the entry's
  `public_id` — never a primary key — and the signature is what makes it unconstructible by a
  client, which is the property the ADR actually needs.
- `PublishingPublishedEntriesQuery#page` reads one row past the page to decide `has_more` rather
  than issuing a second COUNT. Its ORDER BY tiebreaker moved from the primary key to `public_id`, so
  the keyset predicate and the cursor share a sort key carrying no internal identifier.
- The ETag now covers the whole envelope, so it is page-specific.

Two refusals rather than silent fallbacks, per `generic/no-silent-fallback.mdc`: a `limit` that is
not a whole number, and a cursor that does not verify, both answer `400`. Serving page one instead
would return the wrong rows while looking successful.

Not done, deliberately: no index was added for the sort key. The previous unbounded query already
sorted on `effective_from` without one, and bounding the result set reduces the work rather than
increasing it. An index is a separate decision under `generic/migrations.mdc`.

Verification: 35 tests in `openapi_content_entries_contract_test.rb`, including a cursor walk over
seven entries in pages of three that asserts the exact expected order with no row skipped or
repeated, the clamping of `limit=0` and `limit=1000`, the two `400` refusals, and that two pages of
one collection never share an ETag.
`bin/rails test test/contracts/ test/controllers/… test/integration/read_only_surfaces_test.rb test/services/`
— 1829 runs, 7541 assertions, 0 failures.

**Phase D — legacy error members removed, refresh switched to 204. Completed 2026-08-22.**

`app/controllers/concerns/api_v0_legacy_error_member.rb` is deleted, both `include` lines are gone,
and the separate string-valued `error` member in `publishing_content_rendering.rb` went with them.
Every `/api/v0` error response now carries exactly `type`, `title`, `status`, `instance`,
`request_id`, plus `detail` and `errors` when present — asserted directly, by key set, in both
`core_browser_api_boundary_test.rb` and `publishing_entry_api_contract_test.rb`.

`POST /api/v0/token/refresh` returns `204 No Content`.

`adr/api-error-format-problem-details.md` required a `Deprecation` and `Sunset` announcement before
this removal. It was amended with a "Migration completed 2026-08-22" section explaining why the
announcement was not required: the named edge consumer does not read the member, the named native
consumer does not exist yet, `v0` is not frozen, and the Sunset rule in
`docs/reference/api-design-standards.md:228-243` is scoped to endpoint removal rather than to a
response member. The tests that existed to pin the transitional coupling were replaced in the same
change by tests asserting its absence.

**Phase E — breaking-change gate. Written 2026-08-22; installation blocked.**

The `breaking-openapi` job is in `plans/patches/openapi-contract-ci-jobs.patch` together with the
Phase A `lint-openapi` job. The patch was generated mechanically rather than hand-written and
`git apply --check` passes; the resulting workflow parses and contains all twelve jobs.

Design points worth keeping:

- It uses the official `oasdiff/oasdiff-action/breaking@v0.1.13` rather than `docker run`, because
  the `ubuntu-slim` runners are not guaranteed to have a container engine.
- A matrix over the three surfaces, `fail-fast: false`, so one surface's breakage does not hide
  another's.
- `fail-on: ERR` only. oasdiff grades adding an enum value to a response as WARN, which
  `adr/api-versioning-and-client-conventions.md` explicitly calls non-breaking; failing on WARN
  would put CI in conflict with the policy it exists to enforce.
- `review: false`, so no description is uploaded to oasdiff.com.
- A per-surface guard that skips the diff when the base branch has no description for that surface.
  Without it, the very pull request that introduces a surface would fail for lacking a baseline.

**It cannot be verified locally.** oasdiff has no npm distribution — the `oasdiff` npm name is a
reserved placeholder with no functionality — and needs Go or Docker, neither of which is present in
the development container. It therefore runs in CI only, and the first run after the patch is
applied is its first execution. The known blind spot stands: oasdiff does not diff response header
schemas (oasdiff issue #1094), so header contracts are covered by the Committee assertions from
Phase B instead.

**Phase F — the migration is gated; the step the ADR asks for first is done. 2026-08-22.**

Phase F as planned was to migrate `/edge/v0` and `/web/v0` onto `/api/v0`. That is not permitted
here. `adr/api-route-vocabulary-consolidation.md` (Accepted 2026-06-13) states:

> "Future route migration requires a compatibility review before any path changes." (§Compatibility
> requirements)
>
> "`/web/v0` and `/edge/v0` must not be removed as part of recording this decision, and must not be
> removed by future work until compatibility review confirms it is safe."
>
> "Implementation must happen later, under its own plan and review, and is explicitly out of scope
> here."

Performing the migration would bypass a gate an accepted ADR set deliberately, so it was not done.

What that ADR does prescribe as the first step is a per-endpoint classification (§Future
implementation notes: "A future migration should begin by classifying each existing `web/v0` and
`edge/v0` endpoint"). That is done, verified against the router rather than copied from the memo.

**The legacy surface is 14 distinct operations, not the ~30 controllers the earlier estimate
suggested** — 92 route entries collapse to 14 once services and surfaces are deduplicated:

| Operation                             | Classification                                                                                                                   |
| ------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `GET`/`PATCH`/`PUT` `/edge/v0/cookie` | API endpoint — migration candidate                                                                                               |
| `POST /edge/v0/dbsc`                  | API endpoint — migration candidate                                                                                               |
| `GET /edge/v0/token/check`            | API endpoint — migration candidate                                                                                               |
| `POST /edge/v0/token/dbsc`            | API endpoint — migration candidate                                                                                               |
| `POST /edge/v0/token/refresh`         | API endpoint — migration candidate. Base service; distinct from the Core `/api/v0/token/refresh`                                 |
| `GET`/`PATCH`/`PUT` `/web/v0/cookie`  | API endpoint — migration candidate. Consumed in-repo by `src/components/chrome/CookieBanner.tsx:15` and two Stimulus controllers |
| `GET`/`PATCH`/`PUT` `/web/v0/theme`   | API endpoint — migration candidate. Consumed in-repo by `src/lib/theme.ts:96`                                                    |
| `POST /web/v0/in/email/otp`           | Ceremony — the ADR does not settle this one; it delivers a sign-in credential                                                    |

The memo the ADR points at is stale on two counts, corrected here: `web/v0/in/telephone/otp` and
`edge/v0/entries` are both listed there and neither exists in the router today. The content reads
already live at `/api/v0/entries`.

Two properties make the `/web/v0` half easier than the earlier phases: its consumers are in this
repository, so a migration is a single atomic commit with no external coordination. `/edge/v0` is in
the same position as `/api/v0` was — the edge repository forwards it opaquely and parses nothing.

**What was implemented: a guard, not a migration.**
`test/integration/routes/legacy_api_namespace_guard_test.rb` pins the exact 14 operations. The ADR's
direction — "Future API routes … should converge toward `/api/v0/...`" — had no enforcement, so
nothing stopped the legacy surface from growing while the ADR said it should shrink. Adding an entry
is now a decision to move against the accepted direction, and removing one requires the
compatibility review; either way the edit is the review trigger, matching the pattern in
`.agents/harnesses/rules/project/regression-guards.mdc`. It was proved to fire: removing one entry
produces the surface-changed failure.

A second assertion catches the genuine half-migrated hazard — one service serving the same endpoint
under both a legacy namespace and `/api/v0`. It compares per service and surface, not per path,
because the same path on two hosts is two different endpoints here. The first draft of this test got
that wrong and flagged Base's `/edge/v0/token/refresh` against Core's `/api/v0/token/refresh`, which
are different credential transports on different hosts, not a duplicate.

**Two defects deliberately left in place, with reasons.**

- `ApiProblemExceptionsApp::API_PATH_PREFIX = "/api/"` still excludes the legacy namespaces, so a
  routing miss there falls back to an HTML error page. Extending the prefix now would be worse, and
  the code says why (`app/services/api_problem_exceptions_app.rb:17-19`): those namespaces still
  emit their own error shapes, so claiming them would give one endpoint two different error formats
  depending on whether the failure reached a controller. It is fixed by converging the shapes, which
  is the gated work.
- `ApiContentNegotiation` is still not applied to the legacy namespaces. Applying it would start
  returning `406` and `415` where nothing does today, to endpoints the in-repo frontend calls. That
  is a behaviour change to live browser endpoints and belongs in the same reviewed migration.

**What the compatibility review still has to decide**, so it does not start from nothing: whether
`POST /web/v0/in/email/otp` is an API endpoint or a ceremony; the compatibility mechanism per
endpoint (redirect, alias, or dual routing) required by the ADR; whether `/edge/v0` can move in one
step given that no consumer parses it; and the order in which the error-shape convergence and the
path move happen, since `ApiProblemExceptionsApp` cannot claim a namespace until its shapes have
converged.

**Deferred until a real consumer exists** — schema distribution (D11), consumer type generation and
typed client (D8, D10), documentation UI (D12). Trigger: a real `/api/v0` call site appears in the
consumer, or the production VPC binding is configured and the Rails transport is enabled.

## 25. Rollback strategy

Phases 0, A, B, and E are additive and revert by removing the added files and CI jobs; no data, no
deployed behaviour, and no client contract is affected.

Phase C changes the wire shape of `/api/v0/entries`. The rollback unit is the Rails image
(`Containerfile:463`). Because the consumer proxies these paths without parsing them and holds no
types for them, reverting does not require a coordinated consumer deploy. There is no database
migration.

Phase D changes error payloads. Rolling back restores the removed member. The Palm native client is
the only consumer that could be affected, and a client already tolerant of the RFC 9457 members will
not break on the member's return.

Rails and the consumer cannot be deployed simultaneously — separate repositories, separate
pipelines, no coordinating release. Every phase in this plan is therefore designed to be safe when
deployed alone, which is why the consumer-side phases are deferred rather than interleaved.

## 26. Decision records

Each entry: decision, context, rationale, alternatives, consequences, risks, revisit condition.

**D1 — OpenAPI 3.0.4.** _Context:_ the committed document is 3.2.0 and an accepted ADR mandates
3.2.x. _Rationale:_ 3.0.x is the only version on which the whole toolchain works; `committee` raises
above 3.0.x (`drivers.rb:71-73`) and `openapi-typescript` has no 3.2 support (#2577).
_Alternatives:_ 3.1 (loses Rails validation); keep 3.2 (loses validation and generation); dual
maintenance with a downconverted derivative (a new drift source). _Consequences:_ an accepted ADR
must be amended; the three `nullable` usages become correct. _Risks:_ 3.0 is two minor versions
behind and will fall further. _Revisit:_ when `openapi_parser` #152 lands, or if `committee` is
replaced.

**D2 — The hand-written specification is the sole source of truth; drift is enforced mechanically.**
_Context:_ 581 lines already exist and are unverified by anything; one silent defect was found.
_Rationale:_ accuracy comes from enforcement, not from authoring direction. _Alternatives:_
test-generated (rswag needs RSpec); code-first (no type source); separate contract repository (no
release machinery). _Consequences:_ four CI gates must exist for the decision to hold. _Risks:_
authoring burden grows with coverage. _Revisit:_ if the burden becomes measurably unsustainable.

**D3 — First iteration covers the nine already-documented paths.** _Alternatives:_ all of `/api/v0`;
include the legacy namespaces. _Consequences:_ most JSON endpoints remain uncontracted until Phase
F. _Risks:_ the uncovered majority keeps drifting meanwhile. _Revisit:_ Phase F.

**D4 — One document per surface (app, com, org).** _Rationale:_ `surfaces.mdc:24-26` makes the
boundaries absolute and forbids a default host; per-path service hosts differ. _Alternatives:_ a
single document with a `{host}` variable. _Consequences:_ three lint targets, three bundles, three
diffs. _Risks:_ shared components can drift between roots if `$ref` discipline slips. _Revisit:_ if
a surface is added or removed.

**D5 — Implement the collection envelope and pagination before contracting entries.** _Rationale:_
avoids publishing an unbounded response as an intended shape. _Consequences:_ Phase C precedes
contract authoring for those two paths and triggers the shape approval gate. _Risks:_ delays the two
most interesting endpoints (ETag/304, collections).

**D6 — Remove the legacy error members from Core and Palm simultaneously.** _Context:_ the edge
application does not read them, contrary to the code comment. **The Palm native client does not
exist yet** — `palm/app/api/v0/` is built against a planned client. The blast radius is therefore
zero: there is no deployed consumer of the legacy member on either boundary. _Rationale:_ v0 is
explicitly not frozen; the Sunset requirement covers endpoint removal, not response members; and
with no consumer, removing it now costs nothing while leaving it costs a permanent second error
shape. _Alternatives:_ document and deprecate; Core-only first. Both were rejected once the absence
of consumers was established. _Consequences:_ a single clean error shape before any contract is
written. The future Palm client is designed against RFC 9457 only, which is the intended end state
anyway. _Risks:_ none currently identified. _Revisit:_ not expected; reopen only if a Palm build
ships against the legacy shape before Phase D.

**D7 — Rails validation in Minitest integration tests only.** _Rationale:_ keeps a "Looking for
maintainers!" dependency off the request path; `committee` returns 500 on failure, so middleware
turns a contract miss into an outage. _Alternatives:_ middleware in development, staging, or
production sampling. The staging variant is not available: staging runs in production mode, so it is
not a separate target. _Consequences:_ drift is caught at CI time, not at runtime. _Risks:_ an
uncovered path can drift in production undetected. _Revisit:_ if production drift is observed.
_Dependency fallback:_ `committee-rails` carries "Looking for maintainers!" in its README. If it is
abandoned, `committee` itself can be used directly — `Committee::Rails::Test::Methods` is a thin
adapter that supplies `committee_options`, `request_object`, and `response_data` from
`integration_session`, and equivalent glue is a few lines in `test/contracts/`. The decision does
not become load-bearing on an unmaintained gem.

**D8 — No consumer type generation or typed client in this iteration.** _Context:_ zero call sites
in the consumer repository. _Consequences:_ the schema has no automated consumer yet. _Risks:_ the
contract could become producer-only ceremony. _Revisit:_ first real `/api/v0` call site, or
production VPC binding enabled.

**D9 — No runtime validation in the consumer.** _Alternatives:_ hand-written Zod (reproduces the
drift failure); generated Zod (requires replacing the client stack; 3.0 support unverified).
_Risks:_ an uncovered Rails contract violation surfaces as silent `undefined`. _Revisit:_ with D8.

**D10 — Generated files are committed; CI fails on regeneration diff.** _Rationale:_ type changes
become reviewable in the diff; `openapi-typescript --check` exists for it. _Consequences:_ knip and
coverage-threshold exclusions will be needed in the consumer repository. _Revisit:_ applies when D8
is revisited.

**D11 — No schema distribution yet.** _Alternatives:_ GitHub Release artifact; private npm on
`npm.flatt.tech`; sibling checkout; fetch from the public URL. _Consequences:_ the specification
stays inside this repository. _Revisit:_ with D8. Note that the consumer repository already
references `../umaxica-apps-global` as a sibling checkout, which is the cheapest starting point.

**D12 — No documentation UI.** _Rationale:_ two first-party consumers; Swagger UI conflicts with the
CSP. _Alternatives:_ `redocly build-docs` static HTML; development-only Rails mount. _Revisit:_ when
a browsing need is demonstrated.

**D14 — `POST /api/v0/token/refresh` returns `204 No Content`.** _Context:_ it currently returns
`200` with `{"refreshed": true}`; the comment justifying that shape cites a Next.js reader that does
not exist. _Rationale:_ `docs/reference/api-design-standards.md:140-162` requires `204` and
explicitly forbids "`200` with an empty body or a `{"ok": true}` placeholder". The boolean was
derived from the status. _Alternatives:_ keep the body for compatibility — rejected, there is no
consumer to be compatible with. _Consequences:_ a wire-shape change requiring the
`data-shape-design.mdc` approval gate; the Before/After proposal is in §15. The schema documents a
`204` with no content. _Risks:_ a client parsing the body would break. None exists. _Revisit:_ not
expected.

**D15 — The specification enumerates only statically knowable hosts.** _Context:_ core, palm, help,
and info resolve their production hosts from ENV with no fallback
(`lib/config_values_host_family_values.rb:214-221`); docs and news have no production host entry at
all (`config/environments/production.rb:191-197`). _Rationale:_ naming a host the router or Host
Authorization rejects is the failure mode `adr/api-versioning-and-client-conventions.md:93-106`
singles out. `docs.jp.umaxica.app` at `public/openapi.yml:28-29` is exactly that. _Alternatives:_
guess the ENV-supplied hostnames; keep a single `{host}` variable with a default. _Consequences:_
Core paths get literal `servers`; ENV-driven services get a `{host}` variable with no default; docs
and news get no `servers` at all (D16). _Risks:_ a reader cannot resolve a concrete URL for the
ENV-driven services from the document alone. That is accurate rather than misleading. _Revisit:_
when docs and news gain production host entries, or when the ENV-driven hosts are moved into
`boot_config` literals.

**D16 — The docs and news editions of `/api/v0/entries` are documented, without a `servers` entry.**
_Context:_ both are routed (`config/routes/{docs,news}.rb:40,80,120`) and reachable in development
and test via `*.{app,com,org}.localhost` (`compose.yaml:158-169`), but neither has a production host
entry (`config/environments/production.rb:191-197`). _Rationale:_ the endpoints exist, are
implemented, and are already covered by a contract test
(`test/contracts/publishing_entry_api_contract_test.rb:14`). Omitting them would leave the contract
covering two of four content services and would make `committee` coverage uneven for identical
controllers. What is missing is public ingress, not behaviour, and that is a deployment gap rather
than a contract gap. _Alternatives:_ omit them until they have public hosts — rejected, it would
under-describe working, tested code and split one uniform endpoint family across two regimes.
_Consequences:_ four content services are contracted uniformly and Phase B covers all twelve
`entries_controller.rb` files. The docs and news Path Items carry no `servers` entry, because the
only names that reach them are `PRIVATE_*` and those may not appear in a file served from `public/`.
The operation description must state that the edition has no public ingress, so a reader does not
infer one. _Risks:_ a reader could mistake "documented" for "publicly reachable". Mitigated by the
explicit description; the absent `servers` is itself the signal. _Revisit:_ when docs and news gain
production host entries, at which point `servers` is added and this decision collapses into the
ordinary case.

**D17 — The legacy namespace is pinned rather than migrated.** _Context:_
`adr/api-route-vocabulary-consolidation.md` makes `/api/v0` canonical and `/web/v0` and `/edge/v0`
transitional, but gates any path change behind a compatibility review it explicitly defers.
_Rationale:_ the direction had no enforcement, so the legacy surface could grow while the ADR said
it should shrink. A pinned set turns either direction of change into a reviewed decision without
performing the gated migration. _Alternatives:_ migrate now (bypasses an accepted ADR's gate); do
nothing (leaves the direction unenforced). _Consequences:_ 14 operations are pinned in
`test/integration/routes/legacy_api_namespace_guard_test.rb`; the classification the ADR asks for as
step one is recorded above. _Risks:_ a legitimate new legacy endpoint costs one reviewed line. That
is the intent. _Revisit:_ when the compatibility review runs.

**D13 — `oasdiff --fail-on ERR`; WARN reported but non-blocking.** _Rationale:_ ERR maps precisely
onto the ADR's major-bump list; `response-property-enum-value-added` is WARN in oasdiff but
explicitly non-breaking in the ADR, so a WARN gate would put CI in conflict with policy.
_Alternatives:_ `--fail-on WARN`; per-rule severity customisation. _Risks:_ WARN-level regressions
can merge; response header schema changes are not diffed at all. _Revisit:_ when v1 is declared.

## 27. Phased implementation plan

See §24. Every phase lists its target files there. Two gates require explicit approval before any
implementation file is touched: Phase 0 (amending an accepted ADR) and Phase C (a wire-shape change
under `.agents/harnesses/rules/generic/data-shape-design.mdc:12-35`).

Verification commands:

```bash
# Phase A
pnpm exec redocly lint openapi/app.yml openapi/com.yml openapi/org.yml
pnpm exec redocly bundle openapi/app.yml -o public/openapi.app.yml
git diff --exit-code public/

# Phase B
bin/rails test test/contracts/

# Phase C
bin/rails test test/controllers/docs/app/api/v0/entries_controller_test.rb test/contracts/

# Phase D
bin/rails test test/integration/core_browser_api_boundary_test.rb \
               test/controllers/palm/app/api/v0/profiles_controller_test.rb \
               test/services/api_problem_exceptions_app_test.rb

# Whole repository
bin/rails test && pnpm -s run ci
```

## 28. Acceptance criteria

1. `adr/api-versioning-and-client-conventions.md` §4 specifies 3.0.4 with rationale, source URLs,
   and access date.
2. Three surface documents exist under `openapi/`, bundle cleanly, and pass `redocly lint`.
3. No bundled document contains a `PRIVATE_*` host name.
4. No schema uses `additionalProperties: false`.
5. `servers` is declared per Path Item; no top-level default host.
6. `slug`, `summary`, and `published_at` are `required` and `nullable: true`, matching
   `publishing_entry_serializer.rb`.
7. All nine paths have `committee` contract tests covering success and the principal error
   responses, each asserting an explicit status.
8. The route-coverage test fails in both directions: a router path missing from the schema, and a
   schema path the router does not serve.
9. `/api/v0/entries` returns `{"data": [...], "page": {...}}` with `?limit=&cursor=`, stable
   ordering, and a working 304.
10. No `/api/v0` response contains a legacy `error` member in any form. **Met** — asserted by exact
    key set in `core_browser_api_boundary_test.rb` and `publishing_entry_api_contract_test.rb`. 10a.
    `POST /api/v0/token/refresh` returns `204` with no body, and the schema documents it as such.
    **Met.** 10b. No `servers` entry names a host that does not route the path it is attached to. In
    particular `docs.jp.umaxica.app` does not appear, and `/api/v0/entries` is not attached to a
    Core host. 10c. All four content services (docs, help, info, news) are documented. The docs and
    news editions carry no `servers` entry and their descriptions state that the edition has no
    public ingress. 10d. No `PRIVATE_*` host name appears in any bundled document, including in a
    description.
11. CI fails when the bundled output does not match the source tree.
12. CI fails on an `oasdiff` ERR and does not fail on an additive change.
13. The two false comments identified in §3 are corrected.
14. Every phase is revertible without a coordinated consumer deploy. **Met** — no phase required a
    consumer change, because no consumer parses these responses.
15. Collections are bounded, and a client that omits `limit` still receives a bounded response.
    **Met** (Phase C).
16. The legacy `/web/v0` and `/edge/v0` surface cannot grow without a reviewed decision. **Met**
    (Phase F).

### Not met, and why

- The two CI jobs are not installed. `.github` is read-only in this environment; the patch at
  `plans/patches/openapi-contract-ci-jobs.patch` applies cleanly and is the remaining action. Until
  it is applied, lint and drift are enforced only by `pnpm check` and the lefthook pre-push hook,
  and the breaking-change gate does not run at all.
- oasdiff has never been executed. It has no npm distribution and needs Go or Docker, neither of
  which exists in the development container, so the first CI run after the patch lands will be its
  first execution.
- The `/edge/v0` and `/web/v0` migration is not done, by design (D17). The two defects that depend
  on it — the exceptions app's path prefix and the missing content negotiation — are documented in
  Phase F and left in place with reasons.

## 29. Resolved questions

All five questions raised by the audit have been answered.

1. **Entries hosts — resolved, and the current document is wrong.** `resources :entries` is declared
   only in `config/routes/{docs,help,info,news}.rb`; Core does not route it. docs and news have no
   production host entry (`config/environments/production.rb:191-197`) and are not publicly
   servable. help and info resolve theirs from `HELP_SERVICE_URL` / `INFO_SERVICE_URL` at boot. The
   `docs.jp.umaxica.app` example at `public/openapi.yml:28-29` names a host Rails rejects. Recorded
   as D15 and detailed in §4.
2. **`{"refreshed": true}` — resolved: `204 No Content`.** Recorded as D14 with the Before/After
   proposal in §15, pending the shape approval gate before implementation.
3. **Staging — resolved: staging runs in production mode.** There is no separate staging target,
   which forecloses the staging-middleware variant of D7 rather than leaving it open. Noted in §24
   and D7.
4. **Palm client — resolved: it does not exist yet.** `palm/app/api/v0/` is built against a planned
   client. D6's blast radius is zero, which strengthens rather than weakens the simultaneous
   removal. The future client is designed against RFC 9457 only.
5. **`committee-rails` maintenance — resolved: a fallback is recorded.**
   `Committee::Rails::Test::Methods` is a thin adapter supplying `committee_options`,
   `request_object`, and `response_data` from `integration_session`; if the gem is abandoned,
   `committee` is used directly with a few lines of glue in `test/contracts/`. Noted in D7.

## 30. Scoping decisions settled

**Docs and news editions of `/api/v0/entries` are documented.** Recorded as D16. The routes exist
(`config/routes/{docs,news}.rb:40,80,120`), the controllers are implemented, the endpoints are
reachable in development and test, and the docs edition is already covered by a contract test. The
gap is public ingress, which is a deployment matter, not a contract matter. They carry no `servers`
entry and their descriptions say so.

No scoping questions remain open. The design is complete and ready for Phase 0 on explicit
instruction.
