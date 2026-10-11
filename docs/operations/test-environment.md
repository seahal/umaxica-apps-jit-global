# Isolated Rails test environment

Rails tests use explicit test-only PostgreSQL databases and Valkey logical databases. A test process
must not inherit the development host or the development Valkey databases.

The supported host-native entry point is:

```bash
POSTGRESQL_TEST_HOST=primary.dns.podman \
POSTGRESQL_PORT=5432 \
POSTGRESQL_USER=root \
POSTGRESQL_PASSWORD='<test-service-password>' \
POSTGRESQL_DATABASE=db \
CACHE_REDIS_URL=redis://valkey.dns.podman:6379/3 \
RATE_LIMIT_REDIS_URL=redis://valkey.dns.podman:6379/4 \
AUTH_STATE_REDIS_URL=redis://valkey.dns.podman:6379/5 \
VALKEY_TEST_HOST=valkey.dns.podman \
VALKEY_TEST_PORT=6379 \
PARALLEL_WORKERS=1 \
scripts/test-isolated bin/rails test test/path/to/file_test.rb
```

The wrapper performs read-only identity checks before Rails boots. It verifies that PostgreSQL has
`test_*` databases on the selected server and that the three Valkey URLs use logical DBs 3, 4, and 5
on the explicitly selected Valkey host and port. Rails then validates every effective test database
configuration before opening Active Record connections. `DATABASE_URL` and other database URL
overrides cannot silently redirect a test connection to a non-test database. The wrapper never
creates or drops a database. Database preparation remains an explicit command against the same test
host, for example `scripts/test-isolated bin/rails db:prepare` after the test databases already
exist.

`POSTGRESQL_TEST_HOST` is required by `config/database.yml`; it does not fall back to
`POSTGRESQL_HOST`. `POSTGRESQL_PORT` is the same explicit port checked by the preflight and by
Rails. The test environment also requires all three Valkey URLs, `VALKEY_TEST_HOST`,
`VALKEY_TEST_PORT`, and a `VALKEY_NAMESPACE_RUN_ID`. Application auth-state stores add the run and
worker identifiers to their namespaces. A run claims its identifier in a local marker before writing
and refuses concurrent reuse. On exit, `scripts/test-isolated` deletes only that run's
authorization-code, admission, and sign-out-notice prefixes with cursor-complete `SCAN` and `DEL`,
then releases the marker. `FLUSHDB` and `FLUSHALL` are forbidden. An interrupted `INT`/`TERM` child
is waited for before cleanup; `SIGKILL` cannot run a trap, so its marker and keys require explicit
recovery after the process is known to be gone. Standalone cleanup refuses an active run marker
unless `VALKEY_CLEANUP_ALLOW_CLAIM=1` is set for deliberate recovery.

The test boundary prevents provider delivery: Action Mailer uses the `:test` delivery method, the
SMS provider is `test`, and Turnstile is replaced by `TurnstileVerifierStub`. An unstubbed Turnstile
call raises a test-boundary error rather than invoking Cloudflare. Faraday requests are blocked
unless the test uses `OutboundHttpStub` (or another explicit test adapter) for the duration of the
request. Application HTTP clients remain behind `OutboundHttp::Connection`; real verifier logic can
therefore be tested against a declared Faraday response without reaching the network. No real IdP,
email, SMS, Turnstile, or other provider request is part of this setup.

The wrapper is intentionally separate from `bin/rails test`: a bare invocation without explicit test
service variables must fail at boot rather than silently use development resources.
