# API Design Standards

This document is the canonical design contract for the application's machine-facing JSON endpoints.

**Every rule in this document is derived from a published specification.** Each section names its
source so a design question is settled by reading that source rather than by re-deciding local
convention in review.

Areas where **no standard exists** — versioning strategy, pagination, success-response envelopes,
idempotency keys, rate-limit header fields, and the API description format — are deliberately absent
here. They are repository decisions, not standards, and are recorded as ADRs:

- `adr/api-error-format-problem-details.md` — adoption of RFC 9457 and ownership of the problem-type
  namespace.
- `adr/api-collection-contract.md` — success envelope and cursor pagination.
- `adr/api-versioning-and-client-conventions.md` — versioning strategy, `Idempotency-Key`,
  `RateLimit` header fields, and the OpenAPI target version.

Mixing the two categories in one document was the previous mistake: a rule with a published
specification behind it is verifiable, while a rule without one needs a recorded agreement.

Scope: routes under an API namespace (`/api/v0`, and the legacy `/edge/v0` and `/web/v0` namespaces
until they converge per `adr/api-route-vocabulary-consolidation.md`).

Out of scope: HTML ceremony routes, and the endpoints listed under
[Protocol exemptions](#protocol-exemptions), whose wire format is fixed by their own specification.

## Normative references

Status values below were verified against the RFC Editor and the IETF Datatracker. Verify status in
that order — RFC Editor first, Datatracker second — before citing any specification here; follow
`.agents/harnesses/rules/generic/source-policy.mdc`.

| Area | Source | Status |
| --- | --- | --- |
| HTTP semantics: methods, status codes, conditional requests, content negotiation | RFC 9110 | **Internet Standard (STD 97)**, 2022 |
| Error responses | RFC 9457 | Proposed Standard, 2023 — obsoletes RFC 7807 |
| Date and time values | RFC 3339 | Standard |
| OAuth 2.0 / OIDC security | RFC 9700 | **Best Current Practice (BCP 240)**, 2025 |
| OAuth 2.0 error responses | RFC 6749 §5.2, RFC 7009 | Proposed Standard |
| Bearer token errors | RFC 6750 §3 | Proposed Standard |
| Deprecation signaling | RFC 9745 | Proposed Standard, 2025 |
| End-of-life signaling | RFC 8594 | **Informational**, 2019 — not standards track |
| 429 status code | RFC 6585 §4 | Proposed Standard |
| `Retry-After` | RFC 9110 §10.2.3 | Internet Standard |
| JSON Pointer (validation `pointer`) | RFC 6901 | Proposed Standard |

Two entries carry a caveat that must not be lost:

- **RFC 8594 (`Sunset`) is Informational.** It is a widely implemented convention, not a standard.
  It is used here because no standards-track alternative exists, and because RFC 9745
  (`Deprecation`, standards track) explicitly complements it.
- **RFC 9700 is a BCP, not a protocol specification.** It updates the security guidance around
  RFC 6749 rather than replacing it, and it is the reason the Implicit grant and the Resource Owner
  Password Credentials grant are prohibited below.

## Errors

Every non-protocol API error response uses RFC 9457 Problem Details, served as
`application/problem+json`.

```json
{
  "type": "urn:umaxica:problem:authentication-required",
  "title": "Authentication is required.",
  "status": 401,
  "detail": "The access cookie is absent or no longer valid.",
  "instance": "/api/v0/session",
  "request_id": "0f1c2d3e-4a5b-6c7d-8e9f-a0b1c2d3e4f5"
}
```

Rules, per RFC 9457 §3:

- `type` (§3.1.1) is the machine-readable problem identity and is a URI reference. Clients branch on
  `type`, never on `title` or `detail`. A `type` value is permanent once shipped; a changed meaning
  requires a new URI.
- `title` (§3.1.2) is a short, stable, human-readable summary of the `type`. It does not vary between
  occurrences of the same `type`.
- `status` (§3.1.3) duplicates the HTTP status code and must agree with it.
- `detail` (§3.1.4) is occurrence-specific prose, aimed at a human, and is not for programmatic
  consumption. It must never carry tokens, cookies, authorization headers, full request parameters,
  secrets, exception classes, or database topology
  (`.agents/harnesses/rules/generic/absolute-rules.mdc`, `docs/security/observability-boundary.md`).
- `instance` (§3.1.5) identifies the specific occurrence when useful; omit it rather than inventing
  one.
- Extension members (§3.2) are permitted by the specification. This repository defines exactly two:
  - `request_id` — the request correlation identifier, always present.
  - `errors` — field-level validation problems, present only on 422, shaped as
    `[{"pointer": "/email", "type": "urn:umaxica:problem:invalid-format", "detail": "…"}]`, where
    `pointer` is an RFC 6901 JSON Pointer into the request body.

  Any further extension member requires updating this document first.
- Per §3.1.1, a client **must not** automatically dereference a `type` URI. The URI is an
  identifier; this document is its documentation.

Do not emit bare `{"error": "…"}`, `{"error": {"code": …}}`, `{"status": …, "error": …}`, or
message-only bodies. Those give clients no stable identifier and no negotiated media type.

### Problem type registry

`type` URIs use the URN namespace `urn:umaxica:problem:`, consistent with the `urn:umaxica:` prefix
already used for JWT issuers. A URN is used rather than an `https` URI because RFC 9457 §3.1.1 only
encourages dereferenceability, the application's public hosts are region-scoped
(`adr/core-canonical-public-host.md`), and a URI that resolves to nothing is worse than one that
never promised to.

The table is authoritative. Each row is a permanent public contract.

| `type` (after `urn:umaxica:problem:`) | Status | Meaning |
| --- | --- | --- |
| `bad-request` | 400 | The request was malformed. |
| `authentication-required` | 401 | No usable credential was presented, or it is no longer valid. |
| `token-expired` | 401 | The presented refresh credential is expired or already consumed. |
| `authorization-denied` | 403 | Authenticated, but lacking the required scope or policy grant. |
| `csrf-verification-failed` | 403 | The browser request failed CSRF verification. |
| `not-found` | 404 | The addressed resource does not exist or is not visible to the caller. |
| `method-not-allowed` | 405 | The method is not supported on this resource; see `Allow`. |
| `not-acceptable` | 406 | No representation satisfies the request's `Accept`. |
| `unsupported-media-type` | 415 | The request body media type is not `application/json`. |
| `validation-failed` | 422 | Well-formed but semantically invalid; see the `errors` member. |
| `rate-limited` | 429 | A rate limit was exceeded; see `Retry-After`. |
| `server-error` | 500 | An unhandled failure. Carries no `detail`; correlate by `request_id`. |
| `service-unavailable` | 503 | The endpoint is disabled by configuration, or a dependency is down. |

Splitting the two 401 causes is deliberate: a client must be able to distinguish "re-authenticate the
human" from "exchange the refresh credential" without parsing prose. Never widen an existing `type`
to cover an additional cause; add a row.

An unregistered `type` must not ship. The registry is enforced in code by `ProblemType`
(`app/values/problem_type.rb`), which raises on an unknown slug rather than inventing a URI.

Failures that never reach a controller — a routing miss under `/api/`, an unhandled exception — are
rendered by `ApiProblemExceptionsApp` (`app/services/api_problem_exceptions_app.rb`), installed as
`config.exceptions_app`. Without it, Rails serves `public/404.html` and `public/500.html`, so an API
client receives an HTML page. That app never emits `detail`: an exception message can carry request
parameters, identifiers, or internal state, and this document goes to the caller. Non-API paths keep
the static HTML pages.

## Status codes

RFC 9110 §15 semantics and vocabulary.

- `200` — a representation is returned.
- `201` — a resource was created; include `Location` (§15.3.2).
- `204` — success with no representation (§15.3.5). Do not return `200` with an empty body or a
  `{"ok": true}` placeholder.
- `400` — malformed syntax.
- `401` — authentication required or failed (§15.5.2). Bearer endpoints include `WWW-Authenticate`
  (RFC 6750 §3).
- `403` — authenticated but not permitted (§15.5.4).
- `404` — not found (§15.5.5). Prefer `404` over `403` when existence itself is confidential.
- `405` — method not allowed; include `Allow` (§15.5.6).
- `406` — no representation acceptable under the request's `Accept` (§15.5.7).
- `409` — a state conflict the caller can resolve (§15.5.10).
- `415` — unsupported request media type (§15.5.16).
- `422` — well-formed but semantically invalid. **RFC 9110 §15.5.21 names this "Unprocessable
  Content"**, not "Unprocessable Entity". Use Rails' `:unprocessable_content` exclusively;
  `:unprocessable_entity` is the deprecated alias and must not appear in new code.
- `429` — rate limited (RFC 6585 §4).
- `503` — dependency or feature-flag unavailability; include `Retry-After` when a retry window is
  known.

## Methods

RFC 9110 §9.

- `GET` and `HEAD` are **safe** (§9.2.1): no state change, no credential rotation, no audit-bearing
  side effect.
- `GET`, `HEAD`, `PUT`, and `DELETE` are **idempotent** (§9.2.2). `POST` is not.
- A `POST` that mints, rotates, or consumes a credential is not safely retryable. Transport-level
  idempotency for those endpoints is a repository decision with no governing standard; see
  `adr/api-versioning-and-client-conventions.md`.

## Representations

- Success media type is `application/json`; error media type is `application/problem+json`.
- Field names are `snake_case` and stable. Renaming a field is a breaking change.
- A field's type never varies by value. A field that is sometimes an object and sometimes a string
  has no contract. `null` for absence is acceptable; a type change is not.
- Identifiers exposed to clients are public identifiers (`public_id`), never database primary keys.
- All timestamps are RFC 3339 with an explicit `Z` offset and second-or-finer precision:
  `2026-08-16T12:34:56Z`. Do not emit epoch integers, local offsets, or bare dates for instants.
  RFC 3339 is a profile of ISO 8601; "ISO 8601" alone is not a sufficient specification, because it
  permits forms RFC 3339 forbids.
- Enumerated values are lowercase `snake_case` strings; never expose Rails integer enum backing
  values.
- The shape of collection responses is a repository decision; see `adr/api-collection-contract.md`.
- Follow `.agents/harnesses/rules/generic/data-shape-design.mdc` for the underlying shape rules.

## Content negotiation

RFC 9110 §12.

- API endpoints declare `application/json` and honor `Accept`. When the request's `Accept` excludes
  both `application/json` and `application/problem+json`, respond `406` (§15.5.7). Overwriting
  `request.format` unconditionally is not negotiation; it is ignoring the request.
- A request with no `Accept` accepts anything (§12.5.1) and must not be refused. The ranges `*/*` and
  `application/*` both satisfy the rule.
- A request carrying a body must declare `Content-Type: application/json`; anything else is `415`. A
  request with no body has no media type to reject and must not be refused for declaring nothing —
  the token refresh endpoint carries its credential in a cookie and sends no body at all.
- Both checks run before authentication and before CSRF verification. Whether a request can be
  answered at all does not depend on who is asking, and a body that cannot be parsed is rejected
  before anything tries to read it.
- Errors are returned as `application/problem+json` even when the request asked only for
  `application/json`. RFC 9457 §3 defines it as a JSON media type, so any client that can parse JSON
  can parse it. A `406` is likewise sent as a problem document even though the caller said it accepts
  neither: §15.5.7 permits a representation the client did not ask for, and an explanation beats an
  empty body.

Enforced by `ApiContentNegotiation` (`app/controllers/concerns/api_content_negotiation.rb`), included
by every `/api/v0` boundary. `/edge/v0` and `/web/v0` do not enforce it yet, because their
controllers still emit pre-Problem-Details error shapes and a negotiated `406` there would give one
endpoint two error formats.

## Caching and conditional requests

RFC 9110 §13 (conditional requests) and §5.2 / RFC 9111 (cache directives).

- Credential, session, and token endpoints set `Cache-Control: no-store`. This is already the
  practice for token and bearer endpoints and is mandatory.
- Read-only public content endpoints emit `ETag` and/or `Last-Modified` and answer `If-None-Match` /
  `If-Modified-Since` with `304` (§13.1, §15.4.5). Published content carries a publication timestamp,
  so unconditional re-transfer is avoidable.
- A cacheable response whose body varies by authenticated subject requires `Vary` and `private`.

## Deprecation and sunset

Any endpoint being retired signals it on the wire before removal:

- `Deprecation` (RFC 9745) — the deprecation instant, as an HTTP date field, e.g.
  `Deprecation: @1735689600`.
- `Sunset` (RFC 8594, Informational) — the earliest removal instant, in IMF-fixdate form, e.g.
  `Sunset: Sat, 01 Aug 2026 00:00:00 GMT`.
- `Link` with `rel="deprecation"` (RFC 9745 §3) pointing at documentation, and
  `rel="successor-version"` (RFC 5829) pointing at the replacement.

An endpoint is not removed until it has carried `Sunset` for the announced window. Removing an
endpoint that never advertised a sunset leaves clients with no remediation path and is prohibited.

This applies to each `/edge/v0` and `/web/v0` route as it converges on `/api/v0`
(`adr/api-route-vocabulary-consolidation.md`).

## Authentication

- Browser clients authenticate with the first-party cookie transport
  (`adr/core-browser-jwt-cookie-transport-and-nextjs-zero-cookie-boundary.md`) plus CSRF verification
  on unsafe methods.
- Native and machine clients authenticate with `Authorization: Bearer` (RFC 6750). Bearer endpoints
  reject cookie-bearing requests and set `Cache-Control: no-store`.
- A single endpoint accepts exactly one credential transport. Accepting either invites
  confused-deputy and CSRF-on-bearer defects.
- `401` from a bearer endpoint includes `WWW-Authenticate: Bearer error="invalid_token"`
  (RFC 6750 §3.1).
- Per RFC 9700 (BCP 240): Authorization Code with PKCE for all clients. The Implicit grant and the
  Resource Owner Password Credentials grant must not be used or reintroduced.
- Rate limiting exceeded returns `429` (RFC 6585 §4) with a `rate-limited` problem document and
  `Retry-After` in seconds (RFC 9110 §10.2.3). Which quota headers accompany it is a repository
  decision; see `adr/api-versioning-and-client-conventions.md`. Internal diagnostics — which rule
  fired, which layer enforced it — belong in logs and metrics, never in response headers or bodies,
  because they tell a caller how to shape traffic to evade the limit.
- Surface separation (`app` / `org` / `com`) is absolute at the API layer as everywhere else; see
  `.agents/harnesses/rules/project/surfaces.mdc`.

## Protocol exemptions

These endpoints keep their specification-defined wire format and are **exempt** from the Problem
Details rule. Converting them would break protocol conformance.

| Endpoint group | Governing format |
| --- | --- |
| OAuth 2.0 authorization, token, revocation, introspection | `{"error", "error_description"}` — RFC 6749 §5.2, RFC 7009 |
| OIDC endpoints including UserInfo and back-channel logout | RFC 6750 §3.1 bearer errors, OIDC Core |
| WebAuthn / passkey ceremony endpoints | Shapes fixed by the WebAuthn specification and the browser API |
| DBSC endpoints | Device Bound Session Credentials; see `docs/architecture/dbsc.md` |
| MCP endpoints (`app/controllers/concerns/mcp_endpoint.rb`) | **JSON-RPC 2.0** — the response is produced by the MCP transport, not by application code |
| `/health`, `/health/*` | Text probe contract (`text/plain`) in `docs/reference/health-endpoints.md`; edge-blocked per `adr/internal-health-endpoint-edge-isolation.md` |
| `/api/v0/health.json`, `/api/v0/revision.json` | Machine health/revision contract in `docs/reference/health-endpoints.md` (`application/json`, `pass/warn/fail`, `406` on non-JSON `Accept`) — not the Problem Details error format |
| `/.well-known/*` | The specification defining each resource |

An exemption covers the response format only. Status codes, TLS, logging, rate limiting, and surface
separation still apply.

## Verification expectations

A behavior change to an API endpoint carries request tests asserting, at minimum:

- the success status code and the exact response media type;
- the error status code, the `application/problem+json` media type, and the `type` URI;
- the authorization failure case for every credential-bearing endpoint.

Do not assert on `title` or `detail` prose. Those are allowed to change between releases — that is
precisely why `type` exists.
