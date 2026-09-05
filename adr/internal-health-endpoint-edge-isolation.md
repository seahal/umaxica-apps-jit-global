# Internal Health Endpoint Edge Isolation

Accepted: 2026-06-14

> **Wire-format note (2026-09-03):** the response formats described below as "HTML snapshot" and
> "JSON probe" are superseded by the 2026-09-03 text+JSON health contract. The text probes
> (`/health`, `/health/{liveness,readiness,startup}`) now return `text/plain`, and a separate
> machine family (`/api/v0/health.json`, `/api/v0/revision.json`) returns `application/json` with a
> `pass/warn/fail` vocabulary. See `docs/reference/health-endpoints.md`. The edge-isolation
> decision in this ADR — that every `/health*` path and the two `/api/v0/*.json` health paths stay
> internal-only — is unchanged.

## Context

Every surface (`acme`, `base`, `core`, `sign`, `docs`, `help`, `news`, `palm` across `app`, `com`,
and `org`) mounts the same four health endpoints under host constraints:

- `GET /health` — HTML snapshot for browsers, JSON snapshot for JSON clients.
- `GET /health/liveness` — dependency-free JSON liveness probe.
- `GET /health/readiness` — JSON readiness probe for surface dependencies.
- `GET /health/startup` — JSON startup probe for boot-time checks.

All of these inherit from `BareController` with no authentication, no IP allowlist, and no rate
limit. `docs/operations/health-check.md` describes them as "public health endpoints."

These endpoints exist to serve orchestrators and monitoring probes, not end users. Exposing raw
probe JSON or the HTML snapshot to the public has three problems:

1. It blurs the single source of truth (SSoT) for availability — users may treat a per-surface probe
   as the authoritative service status.
2. Partial internal state (one surface degraded, a database probe failing) confuses users who have
   no context for interpreting it.
3. It widens the reconnaissance surface by advertising surface topology and dependency shape.

The edge in front of the Rails origin is Cloudflare Tunnel (`cloudflare-tunnel` service in
`compose.yaml`, `tunnel` profile). There is no in-repo reverse proxy, WAF, or ingress configuration; edge access rules
are managed on the Cloudflare side. Orchestrator and container probes
(`liveness`/`readiness`/`startup`) reach the origin internally, not through the public edge, so an
edge-level block on public traffic does not affect internal probing.

## Decision

1. `/health` and every path beneath it (`/health/liveness`, `/health/readiness`, `/health/startup`),
   on every surface, are defined as **internal-only checkpoints**. They are not a user-facing
   contract.
2. Public traffic to these paths is blocked at the Cloudflare edge (the CDN/load-balancer layer).
   Internal probes that reach the origin directly are not in scope of the block and continue to
   function.
3. User-facing availability and incident information is communicated through a single integrated
   status page, hosted as an external service outside this repository. That status page — not the
   `/health` endpoints — is the SSoT users are directed to. No user-facing status surface is added
   inside this application.
4. The edge block is configured and owned on the Cloudflare side. This repository does not hold the
   edge configuration; the operations documentation records the blocked paths and the intended rule
   so the policy stays traceable.

## Consequences

- Because the edge configuration lives outside the repository, the block rule is not covered by code
  review. `docs/operations/health-check.md` records the blocked path set and the intended Cloudflare
  rule to keep the policy discoverable and auditable.
- No application-layer enforcement (defense-in-depth guard) is added now. This relies on the origin
  being unreachable publicly behind the tunnel, so the edge block alone is sufficient. If a future
  topology adds a publicly reachable path straight to the origin, a Rails-layer guard for `/health*`
  should be reconsidered; that assumption is recorded for follow-up.
- `docs/operations/health-check.md` and `docs/reference/health-endpoints.md` are updated to describe
  these endpoints as internal-only rather than public.
- The integrated status page (external service) and the Cloudflare rule itself are tracked as
  separate work, out of scope for this decision.

## Related

- `docs/operations/health-check.md`
- `docs/reference/health-endpoints.md`
- `docs/security/observability-boundary.md`
- `app/controllers/concerns/health_check_rendering.rb`
- `app/services/health.rb`
