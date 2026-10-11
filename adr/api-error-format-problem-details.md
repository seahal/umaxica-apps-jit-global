# API Error Format: RFC 9457 Problem Details

**Status:** Accepted (2026-08-16); step 2 completed (2026-08-22)

## Status

Accepted (2026-08-16). The two-step `/api/v0` migration below completed on 2026-08-22 when the
legacy `error` member was removed — see [Migration completed](#migration-completed-2026-08-22).

This decision selects the error representation for the application's machine-facing JSON endpoints
and establishes ownership of the problem-type identifier namespace. The rules it adopts are recorded
in `docs/reference/api-design-standards.md`; this record states what was decided and why.

## Context

The repository emits at least seven mutually incompatible JSON error shapes, observed in
`app/controllers/` as of 2026-08-16:

| Shape                                                              | Representative location                                                                                                |
| ------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------- |
| `{"error": {"code", "message", "request_id", "detail", "fields"}}` | `app/controllers/concerns/core_browser_api_boundary.rb:67`, `app/controllers/palm/app/api/v0/base_controller.rb:51`    |
| `{"error": "not_found"}`                                           | `app/controllers/concerns/publishing_content_rendering.rb:19`                                                          |
| `{"error": "Unauthorized"}`                                        | `app/controllers/concerns/sign_edge_v0_json_api.rb:12`                                                                 |
| `{"error": "<translated sentence>"}`                               | 30+ sites under `app/controllers/auth/` and `app/controllers/base/`                                                    |
| `{"status": "invalid_selection", "error": "…"}`                    | `app/controllers/base/{app,com,org}/selectors_controller.rb`                                                           |
| `{"error": "…", "error_code": "…"}`                                | `app/controllers/concerns/session_limit_gate.rb:109`, `app/controllers/concerns/sign_dbsc_registration_endpoint.rb:69` |
| `{"error": "rate_limited", "rule", "message", "retry_after"}`      | `app/controllers/concerns/rate_limit.rb:23`                                                                            |

Consequences of the split, all present today:

- A client cannot branch on a stable identifier. Four of the seven shapes put a human sentence in
  the `error` field, so the only machine-usable signal is the HTTP status code, which is too coarse
  to distinguish "re-authenticate the human" from "exchange the refresh credential".
- The two structured shapes are a literal copy-paste duplicate: `render_error` in
  `core_browser_api_boundary.rb` and in `palm/app/api/v0/base_controller.rb` are the same method
  body, maintained in two places.
- No endpoint negotiates an error media type. `application/problem+json` appears nowhere in the
  repository.
- `app/controllers/concerns/rate_limit.rb:19-20` additionally leaks which internal rule fired, via
  `X-RateLimit-Layer` and `X-RateLimit-Rule`, telling a caller how to shape traffic to evade a
  limit.

RFC 9457 (Proposed Standard, 2023; obsoletes RFC 7807) defines exactly this: a JSON error object
with `type`, `title`, `status`, `detail`, and `instance`, a registered media type
`application/problem+json`, and explicit permission (§3.2) to add extension members. Its stated
purpose is to remove the need for per-API bespoke error formats.

The alternative — writing down the existing `{"error": {"code", …}}` shape as a house standard — was
considered and rejected. It would have the lowest migration cost, but it delivers no external
verifiability: every future review would re-argue the shape from opinion, and no third-party tooling
would recognize it.

## Decision

**All non-protocol JSON API error responses use RFC 9457 Problem Details, served as
`application/problem+json`.**

Problem type identifiers use the URN namespace `urn:umaxica:problem:`.

An `https` URI was considered and rejected. RFC 9457 §3.1.1 only _encourages_ dereferenceability and
explicitly forbids clients from automatically dereferencing the URI; the application has no public
documentation site for problem types; and its public hosts are region-scoped
(`adr/core-canonical-public-host.md`), so no single origin is correct for all deployments. A URN
avoids promising a page that does not exist, and matches the `urn:umaxica:` prefix already used for
JWT issuers (`config/initializers/jwt.rb:12-13`).

Exactly two extension members are defined: `request_id` (always present) and `errors` (422 only,
carrying RFC 6901 JSON Pointers). Adding a third requires amending
`docs/reference/api-design-standards.md` first.

The registry of valid `type` slugs lives in `docs/reference/api-design-standards.md` and is enforced
in code by `ProblemType` (`app/values/problem_type.rb`), which raises on an unknown slug. An
unregistered type cannot ship, per `.agents/harnesses/rules/generic/no-silent-fallback.mdc`.

### Exemptions

The following keep their specification-defined format, because converting them would break protocol
conformance:

- OAuth 2.0 authorization, token, revocation, and introspection — RFC 6749 §5.2, RFC 7009.
- OIDC endpoints including UserInfo and back-channel logout — RFC 6750 §3.1, OIDC Core.
- WebAuthn / passkey ceremony endpoints.
- DBSC endpoints (`docs/architecture/dbsc.md`).
- MCP endpoints — `app/controllers/concerns/mcp_endpoint.rb` delegates the response to the MCP gem's
  StreamableHTTP transport, which emits **JSON-RPC 2.0** error objects. Application code does not
  construct these responses and must not reshape them.
- `/health/*` — `docs/reference/health-endpoints.md`, edge-isolated per
  `adr/internal-health-endpoint-edge-isolation.md`.
- `/.well-known/*`.

## Migration constraint

> **Superseded 2026-08-22.** The premise below — that a Next.js edge application consumes
> `/api/v0/*` in a way the error body affects — was disproved by audit. Retained as the reasoning at
> the time.

`/api/v0/*` is consumed by a Next.js edge application **outside this repository**
(`docs/operations/core-nextjs-zero-cookie-edge-contract.md:29,73,99,103`). No code under `src/`
calls `/api/v0`; the in-repository frontend references only `/web/v0/*`. The current error shape is
pinned by `test/integration/core_browser_api_boundary_test.rb:29,55,68,95,115`.

Therefore the `/api/v0` migration proceeds in two steps rather than one:

1. Emit the Problem Details document **and** retain the legacy `error` object as an RFC 9457 §3.2
   extension member. Response bodies stay backward compatible; only `Content-Type` changes.
2. Remove the legacy member after the edge application has migrated, announced with `Deprecation`
   and `Sunset` per `docs/reference/api-design-standards.md`.

Endpoints with no external consumer migrate in one step.

## Migration completed 2026-08-22

Step 2 was carried out. `app/controllers/concerns/api_v0_legacy_error_member.rb` was deleted, both
`include` lines were removed (`core_browser_api_boundary.rb`, `palm/app/api/v0/base_controller.rb`),
and the separate string-valued `error` member in `publishing_content_rendering.rb` went with them.
Every `/api/v0` error response now carries the RFC 9457 members and nothing else.

The `Deprecation` and `Sunset` announcement that step 2 called for was not required, for three
reasons established by the audit in `plans/analysis/rails-nextjs-openapi-contract-audit.md`:

- **The named consumer does not read it.** `seahal/umaxica-apps-edge` forwards `/api/v0/*` to Rails
  byte for byte over a Cloudflare VPC binding and never parses the JSON
  (`app/core/src/lib/core-dispatch.ts:43`, `:115-133`). It holds no type for a Rails response and no
  reference to `problem+json` or to the nested `error` object. The comment in the deleted file
  asserting that it did was wrong.
- **The other named consumer does not exist yet.** The Palm native client has not been built;
  `palm/app/api/v0/` is written against a planned client, which is therefore designed against RFC
  9457 alone.
- **`v0` is not frozen**, per `adr/api-versioning-and-client-conventions.md`, and the `Sunset`
  requirement in `docs/reference/api-design-standards.md:228-243` is scoped to endpoint removal, not
  to a response-member removal.

The contract tests that pinned the coupling were replaced in the same change by tests asserting the
member is absent and that the document's key set is exactly `type`, `title`, `status`, `instance`,
`request_id`.

## Scope

- The error representation for non-protocol JSON API endpoints.
- The `urn:umaxica:problem:` namespace and the registry's location and enforcement.
- The two permitted extension members.
- The exemption list.

## Non-scope

- Success-response shape, envelopes, and pagination — `adr/api-collection-contract.md`.
- Versioning, idempotency, rate-limit header fields, OpenAPI — see
  `adr/api-versioning-and-client-conventions.md`.
- Route namespace migration — `adr/api-route-vocabulary-consolidation.md`.
- Changing HTTP status codes for any existing condition. This decision changes representation, not
  status semantics.

## Consequences

- Clients gain one stable, machine-readable identifier (`type`) across every non-protocol endpoint,
  and tests assert on it rather than on translated prose.
- The duplicated `render_error` implementations collapse into one concern.
- Migration is not free: `Content-Type` changes on `/api/v0`, which breaks any client that matches
  `application/json` exactly rather than parsing what it receives. This is why step 1 above keeps
  the body compatible — a client that reads the body still works, and only a client asserting on the
  media type must change.
- The exemption list must be consulted before any mechanical sweep. A regex-driven conversion of
  `render json: { error: ... }` would silently break OAuth conformance, which is the single largest
  risk this decision carries.
- Choosing a URN means the `type` URI is not clickable. Documentation lives in
  `docs/reference/api-design-standards.md`; publishing a documentation site later does not change
  the URIs, which are permanent.
