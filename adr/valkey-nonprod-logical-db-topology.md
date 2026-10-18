# Valkey Nonprod Logical DB Topology

## Status

Accepted (2026-09-13). Partially superseded (2026-09-19) for **physical service
topology** and **application configuration**: nonprod runs `valkey-cache` and
`valkey-kvs` as separate Compose services (plus a compatibility `valkey` for
rails_performance / Coverband). Development vs test isolation remains logical
DBs on those shared instances; this ADR is not authorization to create
per-environment or per-worker Valkey services. Canonical logical DB indexes
live in Rails `config/valkey.yml` and must not be re-canonicalized in Compose.

Supersedes the **development/test physical-service isolation** claims in
`adr/valkey-cache-and-rate-limit-stores.md` and
`adr/solid-cache-removal-and-valkey-cache-separation.md`. Production continues to use separate
responsibility URLs; logical DB indexes are not a security or failure-domain boundary.

## Context

Auth-boundary consolidation needs a third Valkey responsibility (`AUTH_STATE_REDIS_URL`) for
short-lived authorization codes and sign-out presentation markers. Running three Compose services
locally for cache, rate-limit, and auth-state over-fits nonprod and conflicts with the integrated
plan's one-service / six-logical-DB layout.

## Decision

**Development and test share one Valkey service and one volume.** Responsibilities stay named in
URLs (never a generic `REDIS_URL`):

| Responsibility          | Dev DB | Test DB |
| ----------------------- | ------ | ------- |
| `CACHE_REDIS_URL`       | 0      | 3       |
| `RATE_LIMIT_REDIS_URL`  | 1      | 4       |
| `AUTH_STATE_REDIS_URL`  | 2      | 5       |
| `PERFORMANCE_REDIS_URL` | 12     | 14      |
| `COVERBAND_REDIS_URL`   | 13     | 15      |

Amended 2026-09-17: `PERFORMANCE_REDIS_URL` and `COVERBAND_REDIS_URL` back the development-only
diagnostic dashboards (`adr/diagnostic-surfaces-performance-coverband-swagger.md`). They get their
own logical DBs rather than a namespace inside an existing one because `rails_performance` reads
with `redis.keys("performance|*")`, an O(keyspace) blocking scan; confined to its own DB it cannot
stall cache, rate-limit, or auth-state. The test rows are declared so `assert_nonprod_db!` has an
expected index to validate against, but nothing connects to them — both gems are
`group :development` — and they are deliberately absent from
`Umaxica::Valkey::TestTarget::URL_NAMES` so test boot does not demand variables it will never use.

Both are resolved by `Umaxica::Valkey::ResponsibilityUrls.require_url`, which uses one-argument
`ENV.fetch`. That matters more here than elsewhere: handed no URL, both gems fall back to
`redis://127.0.0.1:6379/0` — DB 0, the application cache — so a missing variable would not fail, it
would quietly write observability data into `Rails.cache`.

Application code talks only through `Umaxica::Valkey::Connection` for auth-state and through the
existing Rails cache / rate-limit stores for the other two contracts. Auth-state keys are namespaced
(`auth_state:*`) and further isolated in tests with `suite_run_id` / `worker_id` / `test_id`.
Cleanup uses prefix SCAN + DEL; tests never call `FLUSHALL` / `FLUSHDB`.

The Redis client uses `hiredis-client` (`driver: :hiredis`) on the locked `redis-client` version.
Driver selection is verified in tests.

**Production** keeps independently configured responsibility URLs and may still use separate hosts;
this ADR does not force logical DBs in production.

## Amendment (2026-09-19)

Application configuration is `config/valkey.yml`, loaded by
`Umaxica::Valkey::Settings`. Consumers read cache / rate-limit / auth-state;
they do not branch on `Rails.env` to pick a host.

The nonprod application DB pairs are now adjacent odd/even indexes:

| Responsibility | Development | Test                         |
| -------------- | ----------- | ---------------------------- |
| cache          | DB 1        | DB 2 reserved; MemoryStore   |
| rate-limit     | DB 3        | DB 4                         |
| auth-state     | DB 5        | DB 6                         |

`valkey-cache` serves development cache. The ordinary test suite does not
connect to cache Valkey. Rate-limit and auth-state use `valkey-kvs`.

`VALKEY_TEST_HOST` / `VALKEY_TEST_PORT` and hand-exported
`CACHE_REDIS_URL` / `RATE_LIMIT_REDIS_URL` / `AUTH_STATE_REDIS_URL` are no
longer part of the test boot contract. Production still uses those URL names
as `url_key` values and fails fast when they are missing.

Parallel Minitest workers share the test logical DBs. Isolation is
`<run-id>:<worker-id>` key namespaces, not extra DBs or extra services.
`scripts/test-isolated` is optional; `bundle exec rails test` is the entry
point.

The 2026-09-13 table above remains the historical mapping (cache 0/3,
rate-limit 1/4, auth-state 2/5).

## Consequences

- Local Compose exposes one Valkey port; cache maintenance can affect rate-limit and auth-state only
  if operators point tools at the wrong DB index — document the table above and prefer
  responsibility URLs over ad-hoc `valkey-cli -n`.
- Losing the single nonprod volume loses all three stores together; that is acceptable for
  reconstructible cache/rate-limit/auth-state ephemeral data.
