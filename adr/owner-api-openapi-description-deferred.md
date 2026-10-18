# Base Owner APIs Stay Out of the Public OpenAPI Descriptions for Now

Accepted: 2026-10-17 (deferral; revisit before any non-Base caller uses these APIs)

## Context

`test/contracts/openapi_route_coverage_test.rb` requires every routed `/api/v0` operation to appear
in its surface description under `openapi/` (`adr/api-versioning-and-client-conventions.md`).

R5 (one.md R5-WU12/14/15/17) added about 100 server-to-server owner operations under Base `/api/v0`:
`avatar`, `membership`, `iam`, `support`, `publishing`, `identity/standing`, `identity/selection`
and `tech-capability-checks`. Their only caller is the same realm's Base Self-RP. Each call needs a
private_key_jwt bound to the exact URL plus the actor's Access JWT. Their contract is
`docs/architecture/avatar-authority-contract-proposal.md` and the owner and relay tests.

## Decision

The coverage test skips these paths (`OWNER_API_PATHS`). They are not described in `openapi/` for
now. The user decided on 2026-10-17 to leave this as is, because no client uses these APIs through a
published contract yet.

## Consequences

- The "every `/api/v0` route is described" rule has a known gap for these prefixes. A client-facing
  operation added under one of them would not be caught by the coverage test.
- Publishing them as-is would read as an external promise; keeping them out avoids that.

## Revisit when

Any caller other than the realm's own Base Self-RP needs one of these APIs, or the prefixes gain an
operation meant for a browser or external client. The options considered then were:

- describe them in the public `openapi/*.yml`, marked server-to-server, and remove the exemption;
- or add a separate internal description (for example `openapi/internal/*.yml`) and have the
  coverage test accept either the public or the internal description.
