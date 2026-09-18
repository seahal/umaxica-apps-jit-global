# OIDC Back-Channel Logout HTTPS Boundary

Date: 2026-09-18 Branch: `feature` Baseline HEAD before this slice: `b4fdbb9fb`

## Scope

The back-channel logout delivery job continues to require an exact URI match from
`OidcClientRegistry`, uses the shared outbound HTTP connection, and does not follow redirects. This
slice adds an execution-time HTTPS requirement in production. Local development registrations may
still use the existing loopback HTTP endpoints; production cannot send a logout token over cleartext
transport even if a registration is accidentally misconfigured.

## Checks performed

- `ruby -c app/jobs/oidc_backchannel_logout_delivery_job.rb` — passed.
- `ruby -c test/jobs/oidc_backchannel_logout_delivery_job_test.rb` — passed.
- `bundle exec rubocop app/jobs/oidc_backchannel_logout_delivery_job.rb test/jobs/oidc_backchannel_logout_delivery_job_test.rb`
  — passed.
- `git diff --check` — passed.
- The focused Rails test was attempted with explicit loopback PostgreSQL and Valkey test endpoints:
  `POSTGRESQL_TEST_HOST=127.0.0.1 POSTGRESQL_PORT=5432 POSTGRESQL_USER=root POSTGRESQL_PASSWORD=test-only POSTGRESQL_DATABASE=db CACHE_REDIS_URL=redis://127.0.0.1:6379/3 RATE_LIMIT_REDIS_URL=redis://127.0.0.1:6379/4 AUTH_STATE_REDIS_URL=redis://127.0.0.1:6379/5 VALKEY_TEST_HOST=127.0.0.1 VALKEY_TEST_PORT=6379 VALKEY_NAMESPACE_RUN_ID=oidc-logout-https-20260918 PARALLEL_WORKERS=1 scripts/test-isolated bin/rails test test/jobs/oidc_backchannel_logout_delivery_job_test.rb`.
  It stopped before assertions because PostgreSQL and Valkey were not listening on the explicit
  loopback ports. No fallback datastore was used and no external endpoint was contacted.

## Security result

The new regression case verifies that a production HTTP destination is rejected by
`OutboundHttp::Connection` before transport. HTTP remains available only for the existing local
development registration convention. The test suite result is **unverified** until the isolated
PostgreSQL and Valkey services are available.
