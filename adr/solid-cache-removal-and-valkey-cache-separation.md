# ADR: Solid Cache removal and two-store Valkey separation (2026-09-05)

> **Topology supersession (2026-09-13):** Development/test Valkey service topology is superseded by
> `adr/base-auth-ceremony-and-seven-rp-boundary.md`. Cache vs rate-limit separation semantics
> remain.

## Status

Accepted; partially superseded (2026-09-13).

Supersedes the Solid Cache portions of `adr/four-app-solid-cache-and-solid-queue.md`,
`adr/distributor-solid-cache-queue-placement.md`, and
`adr/identity-db-scope-reduction-and-solid-setup.md`. Those documents remain historically correct
about the architecture at the time they were written.

## Context

Solid Cache put the application cache in PostgreSQL, behind a dedicated `cache` connection and a
`production_cache_db` / `development_cache_db` / `test_cache_db` inventory. That coupling had two
costs. A database-backed cache is easy to repurpose as an ad-hoc durable store, which blurs the line
between reconstructible cache and authoritative state; and it added a PostgreSQL database whose only
job was to hold data whose loss is by definition harmless.

Rate limiting already used a separate Valkey store (`RATE_LIMIT_REDIS_URL`), so the runtime already
depended on a Redis-compatible service. Cache and rate-limit state were nonetheless being reasoned
about as one "Valkey" concern, and in development they shared one container separated only by
logical DB index.

## Decision

**PostgreSQL** stores authoritative, durable, and security-sensitive state: accounts, identities and
authorities, authorization codes, refresh-token families and reuse detection, DPoP replay
protection, OTP and ceremony state, credential mutation idempotency, durable feature flags, risk and
audit records, and Solid Queue.

**Solid Queue stays.** Active Job is not migrated to Valkey. `Solid Cache -> REMOVE` and
`Solid Queue -> KEEP` are separate decisions that happen to touch two components sharing a name.

**Solid Cache is removed** from the runtime architecture, along with its PostgreSQL databases,
`config/cache.yml`, `db/caches_migrate/`, and `db/cache_structure.sql`. No unused cache database is
retained for compatibility.

**Valkey has exactly two application-facing responsibilities**, expressed as two purpose-specific
contracts rather than one generic Redis URL:

| Responsibility      | Contract               | Namespace              | TTL policy                           |
| ------------------- | ---------------------- | ---------------------- | ------------------------------------ |
| Application cache   | `CACHE_REDIS_URL`      | `cache:<env>:...`      | Explicit TTL required on every entry |
| Rate-limit counters | `RATE_LIMIT_REDIS_URL` | `rate_limit:<env>:...` | Follows the rate-limit window        |

The rate-limit store never falls back to `Rails.cache`.

**Isolation is physical, not a logical DB index.** Development runs two Compose services,
`valkey-cache` and `valkey-rate-limit`, each on DB 0. Production-shaped environments provide both
purpose-specific URLs. They may name separate managed resources or a deployment may deliberately
bind both contracts to one provider resource; Rails does not make that provider-specific decision.
Namespaces remain mandatory defense in depth, not the architectural isolation boundary.

**Test persists neither store.** `Rails.cache` and the rate-limit store are both `NullStore` by
default, so ordinary tests cannot depend on cached state or accumulate counters into a surprise 429.
Tests whose subject _is_ cache or rate-limit behavior opt into a deterministic `MemoryStore`. CI
depends on no external Redis/Valkey service.

**No provider-specific code.** The application depends only on `redis://` and `rediss://` URLs. No
Upstash SDK, REST API, or endpoint handling belongs in application code; provider choice is a
deployment concern.

## Consequences

- The production PostgreSQL inventory loses one database. Cache loss now means a cache miss and a
  refetch, never a schema or migration concern.
- Cache and rate-limit state can be flushed independently, in every environment.
- `Rails.cache` is a real cache in development, so the cache path is exercised rather than skipped.
- The two non-cache consumers formerly hidden behind `Rails.cache` remain PostgreSQL-backed:
  `OidcClientAssertionJwt` records consumed JTIs through `SecurityConsumedJti`, and
  `IdentityOneTimeReveal` stores its encrypted single-consume payload in `SecurityOneTimeReveal`.
  Their short lifetime does not make loss semantically safe.
- Rate-limit fail-open/fail-closed semantics are unchanged. This decision is not authorization to
  weaken abuse protection.
