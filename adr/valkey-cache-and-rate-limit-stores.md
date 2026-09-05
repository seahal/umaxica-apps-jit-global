# Valkey Cache and Rate-Limit Stores; Solid Cache Removed

## Status

Accepted.

Supersedes the cache half of `adr/four-app-solid-cache-and-solid-queue.md` (already marked obsolete
for the four-app split) and `adr/distributor-solid-cache-queue-placement.md` (already superseded).
Those records stay as written; they describe an architecture that existed.

## Context

`Rails.cache` was Solid Cache, backed by a dedicated PostgreSQL database (`cache` / `cache_replica`,
`production_cache_db`, `db/caches_migrate`). Solid Queue was configured the same way, on its own
`queue` databases.

The two look symmetrical but are not. Job state is durable workflow state; a lost job is a lost unit
of work, so PostgreSQL is the right substrate. Cache entries are supposed to be reconstructible,
which is a weaker guarantee than the one Solid Cache actually provides.

That gap was the problem. A database-backed cache never evicts under memory pressure and survives
restarts, so at the call site `Rails.cache.write` is indistinguishable from durable storage — and
state accumulated in it that no cache should hold. `OidcClientAssertionJwt` tracked consumed
client-assertion JTIs in `Rails.cache`: replay prevention resting on a store whose contract permits
eviction, and which only worked because the implementation happened to be a table. The audit in
`plans/audit-all-rails-cache-write-usage-logical-popcorn.md` records the same pattern elsewhere.

Rate limiting had already been moved to a Valkey store of its own (`RATE_LIMIT_REDIS_URL`) precisely
because counters are disposable.

## Decision

**Solid Cache is removed.** The gem, `config/cache.yml`, `db/caches_migrate/`, `db/cache_structure.sql`,
and the `cache` / `cache_replica` database connections are deleted in every environment. No
cache-only PostgreSQL database remains.

**Solid Queue stays**, unchanged, on its own PostgreSQL databases. The two decisions are independent
and are deliberately not taken together.

**Valkey backs two stores, not one.** They are separate application contracts:

| Contract               | Store                       | Contents                          | Loss means            |
| ---------------------- | --------------------------- | --------------------------------- | --------------------- |
| `CACHE_REDIS_URL`      | `Rails.cache`               | reconstructible application cache | refetch from source   |
| `RATE_LIMIT_REDIS_URL` | `config.x.rate_limit.store` | rate-limit counters               | current windows reset |

Both are namespaced by environment (`cache:<env>`, `rate_limit:<env>`), with an optional configurable
suffix. Both use one-argument `ENV.fetch`, so a missing URL stops the boot.

The isolation boundary is the **service**, not a Redis logical database index. Development runs
`valkey-cache` and `valkey-rate-limit` as separate Compose services, so flushing the cache to
reproduce a stale-JWKS bug cannot also reset every open rate-limit window, and restarting either
cannot take the other down. `/0` and `/1` on one container would give neither property.

No generic `VALKEY_URL` or `REDIS_URL` is reintroduced. Configuration names describe the
responsibility, not the backend.

**Every application cache entry declares an explicit TTL.** TTL follows the semantics of the data,
not a blanket preference for short values:

| Entry                  | TTL        | Why                                                            |
| ---------------------- | ---------- | -------------------------------------------------------------- |
| JWKS (Google, Entra, Apple, Jump RT) | 1 hour / 5 min | bounded staleness against provider key rotation      |
| Jump RT stale JWKS fallback          | 1 hour     | deliberately outlives the fresh entry; it exists to survive a temporary IdP outage |
| unknown-`kid` negative cache         | 30 seconds | suppresses refetch storms without outliving a real rotation |
| one-time reveal payload              | 15 minutes | matches the reveal token's own lifetime                    |

`test/security/invariants/cache_boundary_invariant_test.rb` enforces the TTL rule statically.

**Replay-prevention state moves to PostgreSQL.** `OidcClientAssertionJwt` records consumed JTIs in
`security_consumed_jtis` under the `oidc_client_assertion` purpose, alongside the OIDC logout and
Jump RT return guards. The unique index on `(purpose, issuer, jti_digest)` provides the atomicity the
cache's `unless_exist:` provided, and the record cannot be evicted. It fails closed: a database error
rejects the assertion.

**Tests persist neither store by default.** `Rails.cache` and the rate-limit store are both
`NullStore` in the test environment. A test that passes only because an earlier test warmed the cache
does not describe the behaviour it claims to, and rate-limit counters are keyed by request IP —
identical for every test — so a shared counting store makes unrelated tests 429 depending on suite
order. Tests whose subject is caching or rate limiting opt into a deterministic `MemoryStore`.

## Consequences

- Cache loss is now a real, expected event rather than a theoretical one. Every consumer must
  reconstruct from source on a miss; the JWKS caches already do, and the Jump RT verifier keeps its
  bounded stale fallback for upstream outages.
- Rails' `rate_limit` DSL captures its `store:` argument in a `before_action` closure when the
  controller class body runs. Swapping `config.x.rate_limit.store` afterwards does not reach loaded
  controllers, so the test environment wraps its store in `SwappableCacheStore`
  (`test/support/swappable_cache_store.rb`). Development and production assign the real store
  directly, with no indirection.
- Production needs one more configuration value (`CACHE_REDIS_URL`) and one fewer database.
- `security_consumed_jtis` takes client-assertion traffic in addition to logout and return-token
  traffic. Rows carry `expires_at` and an index on it; no purge job exists yet for that table.

## Alternatives rejected

**One Valkey service with `/0` and `/1`.** Cheaper locally, but a logical database index is not an
isolation boundary: `FLUSHALL`, a restart, an OOM, or a bad `maxmemory-policy` hits both stores at
once, and development would not exercise the shape production is meant to have.

**Leaving client-assertion replay state on `Rails.cache`.** This is what made the migration
necessary. On Valkey the guard would be correct only until the first eviction, and the failure would
be silent and indistinguishable from normal operation.

**Keeping Solid Cache "just for the durable cases."** The durable cases are the bug. A cache that can
be relied on for durability will be, and there is no way to tell at the call site which is intended.
