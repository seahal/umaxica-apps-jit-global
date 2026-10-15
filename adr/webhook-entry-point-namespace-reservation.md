# Webhook Entry Point Namespace Reservation (`/hook/v{n}`)

**Status:** Accepted (2026-10-15) — reservation only; no endpoint is implemented.

## Context

The repository exposes versioned JSON endpoints under `/api/v{n}`
(`adr/api-versioning-and-client-conventions.md`, `adr/api-route-vocabulary-consolidation.md`).
No inbound webhook endpoint exists today: `config/` and `app/` contain no `hook` route or
controller, and the OpenAPI amendment of 2026-08-22 records that the API has no webhook endpoints.
`adr/rails-routing-resourceful-policy.md` already lists webhook endpoints among the routes exempt
from the resourceful policy, but no ADR names where they live.

Webhooks differ from `/api/v{n}` in ways that make sharing its namespace a liability:

- The caller is an external provider (for example, email delivery or payment events), not a
  first-party client. Authentication is a provider-specific signature over the raw request body,
  not a session, bearer token, or CSRF token.
- The payload shape is owned by the provider, so the `/api/v{n}` versioning rules, Problem Details
  error contract, and collection envelope do not apply to the request.
- Rate limits, body-size limits, logging redaction, and edge/WAF rules are tuned differently from
  first-party API traffic.

This is distinct from Web Push (`adr/xper-rails-surface-retirement.md` leaves that requirement
open), which is outbound delivery to browsers and is not covered here.

## Decision

1. The path prefix `/hook/v{n}` is reserved on every surface for inbound webhook entry points.
   `/hook` is not used for any other purpose, and webhook receivers are not placed under `/api`,
   `/edge`, or `/web`.
2. `v{n}` is this repository's own major version of the receiver contract (path, verification
   scheme, acknowledgement behavior), starting at `v0`. It is independent of the provider's payload
   version and of `/api/v{n}`.
3. Each receiver is routed per provider under the surface that owns the event, for example
   `/hook/v0/<provider>`. A receiver belongs to exactly one surface; cross-surface sharing follows
   the existing surface rules (`project/surfaces.mdc`).

## Non-scope

This ADR reserves the namespace only. The following are decided when the first receiver is
implemented, in its own change and, where warranted, its own ADR: the controller base class and
inheritance, signature verification and replay protection, idempotency of event processing, rate
limits, raw-body handling, response codes, logging and audit records, and OpenAPI description.

## Consequences

- A future webhook does not need a naming decision, and `/api/v{n}` controls (CSRF exemptions,
  authentication concerns, error format) cannot be accidentally inherited by or loosened for
  provider traffic.
- Edge and WAF rules can target `/hook/` as a single prefix.
- Until a receiver exists the reservation has no code footprint; adding a non-webhook route under
  `/hook` violates this ADR.
