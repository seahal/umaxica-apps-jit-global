# API Versioning and Client Conventions Without Governing Standards

**Status:** Accepted (2026-08-16); section 4 amended (2026-08-22)

## Status

Accepted (2026-08-16). Section 4 amended on 2026-08-22: the target OpenAPI version changes from
3.2.x to 3.0.4. Sections 1 through 3 are unchanged. See "Amendment 2026-08-22" below.

**None of the four areas below is governed by a published standard.** Each is either a de facto
industry practice, an unpublished IETF draft, or a specification maintained outside the IETF. They
are recorded here rather than in `docs/reference/api-design-standards.md`, which carries only rules
with a published specification behind them.

Specification status was verified against the IETF Datatracker on 2026-08-16 and is restated below,
because two of these areas are commonly — and incorrectly — described as standards.

## Context

The repository exposes versioned endpoints under three parallel namespaces at the same version
number: `/api/v0`, `/edge/v0`, and `/web/v0`. `adr/api-route-vocabulary-consolidation.md` (Accepted
2026-06-13) selected `/api/v0` as the canonical namespace but recorded no versioning _policy_ — what
`v0` promises, what forces `v1`, and how a retired version is announced.

Related current facts:

- `Deprecation` and `Sunset` header emission does not exist anywhere in the repository.
- `app/controllers/concerns/rate_limit.rb:19-20` emits `X-RateLimit-Layer` and `X-RateLimit-Rule`,
  neither of which is a registered or drafted field name, and both of which disclose internal
  enforcement structure.
- `POST /api/v0/token/refresh`
  (`app/controllers/core/{app,com,org}/api/v0/token/refreshes_controller.rb`) consumes and rotates a
  refresh credential with no retry-safety mechanism. A network-level retry loses the credential.
- `public/openapi.yml` is 100 lines describing a single path, `/v0/health`, which **the router does
  not serve** — the real routes are `/health` and `/health/{liveness,readiness,startup}`
  (`config/routes/docs.rb:17-22`). Its `Error` schema `{error, message, details}` matches no
  controller output, and its `servers` list contains only `*.localhost` hosts.

  _Superseded observation, retained as the context this ADR was decided in._ The file was rewritten
  after this ADR was accepted. As of 2026-08-22 it is 581 lines describing nine paths at
  `openapi: 3.2.0`, with an RFC 9457 `Problem` schema. Two accuracy defects of the same kind persist
  and are addressed by the amendment below.

## Decision

### 1. Versioning: path-based major versions

`/api/v{n}`, continuing the existing form. Date-based versioning with a header selector — the model
GitHub, Stripe, and Shopify use — was considered and **rejected**: it exists to let a large
third-party developer population upgrade independently, and it imposes per-version response
transformation machinery. This API's consumers are first-party (the Next.js edge applications and
the native client). If a broad third-party public API is ever offered, that is a new decision, not
an extension of this one.

`v0` means the contract is not frozen. Declaring `v1` is a deliberate act that commits to the
deprecation policy in `docs/reference/api-design-standards.md`.

A new major version is **required** for: removing or renaming a field, narrowing a type, adding a
required request field, changing the status code for an existing condition, or changing the meaning
of an existing problem `type` URI.

A new major version is **not required** for: adding an optional response field, adding an endpoint,
adding a new problem `type` URI, or changing an opaque cursor's encoding
(`adr/api-collection-contract.md`). Clients must tolerate unknown response fields; a client that
breaks on an added field is not owed a version bump.

### 2. Idempotency: `Idempotency-Key`, as a de facto convention only

Adopted for any `POST` that mints, rotates, or consumes a credential, or that otherwise cannot be
safely retried.

**Status, stated plainly: `draft-ietf-httpapi-idempotency-key-header` is expired and archived.** Its
last revision was v07 (2025-10-15); the Datatracker marks it "Expired & archived — no longer
active", with intended RFC status "(None)". There is no active IETF work and no expectation of
publication. The header is adopted purely because Stripe's implementation made it the de facto
convention, and a widely recognized header name is better than inventing a private one.

Server behavior: store the first response keyed by `(key, route, authenticated subject)` and replay
it for a repeat within the retention window. A repeat of the same key with a different request body
is `422`.

### 3. Rate-limit quota headers: `RateLimit` and `RateLimit-Policy`, defensively

The invented `X-RateLimit-Layer` and `X-RateLimit-Rule` fields are removed. They are not merely
non-standard: naming the rule that fired tells a caller how to reshape traffic to evade it, which
contradicts `docs/security/observability-boundary.md`. Which rule fired belongs in logs and metrics.

The replacement field names are `RateLimit` and `RateLimit-Policy`, from
`draft-ietf-httpapi-ratelimit-headers`.

**Status: not published.** The draft is active at v11 (2026-05-23, expiring 2026-11-24), but an
early HTTPDIR review of v10 returned "Not ready". Field syntax may still change.

Therefore the field names are adopted, but **no client behavior may depend on them**. `Retry-After`
(RFC 9110 §10.2.3, Internet Standard) remains the sole authoritative retry signal, and any client
must behave correctly with the quota headers absent. This constraint is the reason the draft is
adopted at all rather than deferred: the cost of being wrong is bounded to a header name.

### 4. API description: OpenAPI 3.0.4

_Amended 2026-08-22. The original decision was 3.2.x; see "Amendment 2026-08-22" below for why it
changed and what would reverse it._

OpenAPI is maintained by the OpenAPI Initiative under the Linux Foundation. It is not an IETF
standard and never has been; it is the de facto interface description format.

The published description must describe the endpoints that actually exist, on the hosts that
actually serve them. A description naming a route the router does not serve, or a host Host
Authorization rejects, is worse than no description: it is a published contract the application does
not honor.

Requirements:

- Target **3.0.4**.
- Declare the RFC 9457 Problem Details schema once and reference it from every error response rather
  than restating error shapes per operation.
- Attach `servers` only where the host is both real and public. Do not declare a default host, and
  do not attach a host to a path it does not serve.
- Because the files are served from `public/`, they must contain no internal host names, internal
  route names, or operational detail that is not already public. `PRIVATE_*` values are internal.
- Do not set `additionalProperties: false`. Section 1 requires that clients tolerate unknown
  response fields; closing the schemas would make every additive change a validation failure.

## Amendment 2026-08-22

### What changed

Section 4's target version changes from OpenAPI 3.2.x to **3.0.4**. Nothing else in this ADR
changes.

### Why

3.2.x cannot be validated or consumed by the tooling this repository uses. Verified 2026-08-22:

- **`committee` accepts 3.0.x only.**
  `vendor/bundle/ruby/4.0.0/gems/committee-5.6.3/lib/committee/drivers.rb:57` dispatches on
  `hash['openapi']&.start_with?('3.0.')`, and lines 71-73 raise `Committee::OpenAPI3Unsupported` for
  any version `>= 3.1`. The upstream blocker is `openapi_parser` issue #152
  (<https://github.com/ota42y/openapi_parser/issues/152>), open since 2023-07-10. `committee-rails`
  is already in `Gemfile:187` and is the only OpenAPI validator available to a Minitest suite —
  `rswag` requires RSpec (<https://github.com/rswag/rswag>, README: "extends rspec-rails 'request
  specs'").
- **`openapi-typescript` has no 3.2 support.** <https://openapi-ts.dev/introduction> states
  "Supports OpenAPI 3.0 and 3.1". Tracking issue #2577
  (<https://github.com/openapi-ts/openapi-typescript/issues/2577>) is open.
- **Redoc rejects 3.2 documents** with `Unsupported OpenAPI version: 3.2.0`
  (<https://github.com/Redocly/redoc/issues/2746>).
- 3.2.0 is real and current — released 2025-09-19 (<https://spec.openapis.org/oas/latest.html>) —
  and the OAI states that 3.1 documents are valid 3.2
  (<https://learn.openapis.org/upgrading/v3.1-to-v3.2.html>). It states nothing about the reverse
  direction, and the published 3.1 meta-schemas pin `^3\.1\.\d+$`.

3.0.x is the only version on which `committee`, `openapi-typescript`, `oasdiff`, Redocly CLI, Redoc,
Swagger UI, and Scalar all work. 3.1 would keep the type generation but lose Rails-side contract
validation, which is the primary reason for having a description at all. 3.0.4 rather than 3.0.3
because it is the current patch release of the 3.0 line (2024-10-24) and the specification states
that tooling should not distinguish patch versions.

### What is given up

JSON Schema 2020-12 alignment, `type` arrays, `webhooks`, `components.pathItems`, and the 3.2
additions (`$self`, `additionalOperations`, `itemSchema`, `in: querystring`, tag hierarchy, optional
response `description`). None is used by the endpoints currently described, and the API has no
streaming or webhook endpoints
(`grep send_data\|send_file\|response.stream\|ActionController::Live app/controllers` returns
nothing).

### A defect the version change repairs

`public/openapi.yml:523`, `:532`, and `:541` use `nullable: true` under `openapi: 3.2.0`. `nullable`
was removed in OpenAPI 3.1 (<https://learn.openapis.org/upgrading/v3.0-to-v3.1.html>: "Replace
nullable with type arrays … This functionality makes the OpenAPI-specific nullable keyword
redundant") and appears nowhere in the 3.1.1 or 3.2.0 specification text. JSON Schema 2020-12
ignores unknown keywords rather than rejecting them, so `slug`, `summary`, and `published_at` are
currently published as non-nullable strings while `app/services/publishing_entry_serializer.rb:38`
emits `null` for them. Under 3.0.4 the keyword is correct and the published contract matches the
implementation.

### Two host defects this amendment also names

Both are instances of the accuracy rule above, found on 2026-08-22:

- `public/openapi.yml:28-29` offers `docs.jp.umaxica.app` as the example content-surface host.
  `config/environments/production.rb:191-197` records that the docs and news surfaces have no
  production host entry, and `compose.yaml:285-288` records that names of that shape "are no longer
  configured anywhere and Rails would reject them".
- All `/api/v0/entries` operations sit under a `servers` block defaulting to `jp.umaxica.app`, which
  is Core. `config/routes/core.rb` does not route `entries`; only
  `config/routes/{docs,help,info,news}.rb` do.

### What would reverse this

`openapi_parser` gaining 3.1 support (issue #152), or `committee` being replaced by a validator
built on a 2020-12-capable JSON Schema implementation. At that point 3.1 becomes available and this
section should be revisited. Moving to 3.2 additionally requires `openapi-typescript` issue #2577.

### Implementation status

Applied the same day. `public/openapi.yml` was replaced by three per-surface bundles,
`public/openapi.{app,com,org}.yml`, generated by Redocly CLI from the source tree under `openapi/`.
The three defects named above are fixed: the documents declare `openapi: 3.0.4` so `nullable` is a
valid keyword, `docs.jp.umaxica.app` is gone, and `servers` now appears only on the two Core paths.
`committee` parses all three bundles with `strict_reference_validation: true`. Two further defects
found during that work are also fixed: `GET /health` was described as JSON when it renders HTML, and
the probe responses carry a `namespace` member that was undocumented.

> Superseded by the 2026-09-03 text+JSON health contract: `/health` and the probes now render
> `text/plain` (no `namespace` member), and machine JSON moved to `/api/v0/health.json` +
> `/api/v0/revision.json`. See `docs/reference/health-endpoints.md`.

### Where the full analysis lives

`plans/rails-nextjs-openapi-contract-audit.md` — the audit, the tool comparison with sources and
access dates, and the sixteen decision records this amendment implements the first of.

## Scope

Versioning policy; the idempotency mechanism; rate-limit quota header field names; the API
description format and the accuracy requirement on `public/openapi.yml`.

## Non-scope

- Error representation — `adr/api-error-format-problem-details.md`.
- Collection envelope and pagination — `adr/api-collection-contract.md`.
- Route namespace migration from `/edge/v0` and `/web/v0` —
  `adr/api-route-vocabulary-consolidation.md`, which requires its own compatibility review.
- Promoting `v0` to `v1`.
- `Deprecation` and `Sunset` semantics, which are specification-backed (RFC 9745, RFC 8594) and
  therefore recorded in `docs/reference/api-design-standards.md`.

## Consequences

- The versioning policy makes "is this change breaking?" answerable by rule rather than by argument.
- Adopting two non-standard conventions (`Idempotency-Key`, `RateLimit`) means accepting future
  churn. The exposure is bounded: `Idempotency-Key` is frozen in practice because its draft is dead,
  and `RateLimit` is constrained to a header name that no client logic may depend on.
- Removing `X-RateLimit-Rule` is a visible response change for anything that reads it. Nothing in
  this repository does; an external consumer that does was relying on internal enforcement detail it
  should not have received.
- Correcting `public/openapi.yml` will make it larger and will require keeping it current. An
  inaccurate description is the state being corrected, so drift is the failure mode to guard
  against; the accuracy requirement is the guard.
- _Amended 2026-08-22._ An accuracy requirement with no enforcement is not a guard. Between this ADR
  being accepted and 2026-08-22 the file drifted again — an inert `nullable`, a host Rails rejects,
  and a `servers` default attached to paths Core does not route — and nothing detected it, because
  no test, initializer, rake task, or CI job reads the file. The guard must be mechanical:
  `committee` request and response validation in the Minitest suite, a bidirectional route-coverage
  test, a lint and bundle-drift CI gate, and `oasdiff` on pull requests. Choosing 3.0.4 is what
  makes the first of those possible. `plans/rails-nextjs-openapi-contract-audit.md` carries the
  plan.
- Targeting 3.0.4 means tracking a specification line that the OpenAPI Initiative has moved two
  minor versions past. The exposure is bounded to the features listed above, none of which this API
  uses, and the reversal condition is recorded.
