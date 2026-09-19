# Isolated Rails test environment

Rails tests use explicit test-only PostgreSQL databases and Valkey logical databases declared in
`config/valkey.yml`. A test process must not inherit the development host or the development Valkey
databases.

Canonical Compose services are `valkey-cache` and `valkey-kvs`. Test cache does not connect to
Valkey; it uses `ActiveSupport::Cache::MemoryStore`. Rate-limit and auth-state use `valkey-kvs`
logical DBs 4 and 6.

Inside a Dev Container the supported entry point is:

```bash
bundle exec rails test
bun vitest run
```

Orchestration supplies `POSTGRESQL_TEST_HOST` and `VALKEY_KVS_HOST`. Do not export
`VALKEY_TEST_HOST`, `CACHE_REDIS_URL`, `RATE_LIMIT_REDIS_URL`, `AUTH_STATE_REDIS_URL`, or a run
namespace before those commands. Rails generates `VALKEY_NAMESPACE_RUN_ID` when it is absent.

`scripts/test-isolated` is an optional helper that claims a run id and deletes that run's
namespaced keys on exit. It is not required to boot the suite.

`POSTGRESQL_TEST_HOST` is required by `config/database.yml`; it does not fall back to
`POSTGRESQL_HOST`. Rails validates every effective test database configuration before opening
Active Record connections. `DATABASE_URL` and other database URL overrides cannot silently redirect
a test connection to a non-test database.

Application auth-state and rate-limit keys include the run and worker identifiers. Parallel
Minitest workers share logical DBs 4 and 6 and isolate keys by namespace
(`<run-id>:<worker-id>:…`). Cleanup uses prefix SCAN + DEL. `FLUSHDB` and `FLUSHALL` are
forbidden.

The test boundary prevents provider delivery: Action Mailer uses the `:test` delivery method, the
SMS provider is `test`, and Turnstile is replaced by `TurnstileVerifierStub`. An unstubbed Turnstile
call raises a test-boundary error rather than invoking Cloudflare. Faraday requests are blocked
unless the test uses `OutboundHttpStub` (or another explicit test adapter) for the duration of the
request.
