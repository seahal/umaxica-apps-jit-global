# Rails test environment

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

Orchestration supplies `VALKEY_KVS_HOST`. Do not export `VALKEY_TEST_HOST`, `CACHE_REDIS_URL`,
`RATE_LIMIT_REDIS_URL`, `AUTH_STATE_REDIS_URL`, or a run namespace before those commands. Rails
generates `VALKEY_NAMESPACE_RUN_ID` when it is absent.

`config/database.yml` fixes every test database to `primary:5432` as `root` (password
`development`); no environment variable selects the test PostgreSQL target, so an exported variable
cannot redirect a destructive preparation. `Umaxica::TestEnvironment::DatabaseSafety` holds the same
fixed values and validates every effective test database configuration before opening Active Record
connections. `DATABASE_URL` and other database URL overrides cannot silently redirect a test
connection to a non-test database.

Application auth-state and rate-limit keys include the run and worker identifiers. Parallel Minitest
workers share logical DBs 4 and 6 and isolate keys by namespace (`<run-id>:<worker-id>:…`). Cleanup
uses prefix SCAN + DEL. `FLUSHDB` and `FLUSHALL` are forbidden.

The test boundary prevents provider delivery: Action Mailer uses the `:test` delivery method, the
SMS provider is `test`, and Turnstile is replaced by `TurnstileVerifierStub`. An unstubbed Turnstile
call raises a test-boundary error rather than invoking Cloudflare. Faraday requests are blocked
unless the test uses `OutboundHttpStub` (or another explicit test adapter) for the duration of the
request.

For a standalone Puma server exercised by TypeScript Playwright and Chromium, see
[Rails browser E2E](rails-browser-e2e.md). That command uses the ordinary configured test databases
and enables real CSRF only in its browser-server process. Neither command requires a PostgreSQL
manifest or per-run database fleet. Both share a process lock and must not run concurrently.
