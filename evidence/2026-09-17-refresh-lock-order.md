# Refresh Rotation Lock-Order Verification

- Date: 2026-09-17
- Branch: `feature`
- Commit before this slice: `074f5b353`
- Scope: align refresh-token rotation with the existing parent-before-child lock order used by
  RP-session revocation and authorization-code exchange.

## Change verified statically

`OidcRefreshTokenIssuer` now locks the surface-local Base Browser Session before locking its RP
Session. Replay, activity, digest, rotation, and connection-touch operations run while both row
locks are held. The new regression test records the SQL row-lock order and requires the parent lock
to precede the RP child lock.

## Commands and results

- `ruby -c app/operations/oidc_refresh_token_issuer.rb` — passed.
- `ruby -c test/services/oidc_refresh_token_issuer_surface_test.rb` — passed.
- `bundle exec rubocop app/operations/oidc_refresh_token_issuer.rb test/services/oidc_refresh_token_issuer_surface_test.rb`
  — passed; 2 files inspected, no offenses.
- `git diff --check` for the slice — passed.
- `VALKEY_TEST_HOST=127.0.0.1 VALKEY_TEST_PORT=6379 CACHE_REDIS_URL=redis://127.0.0.1:6379/3 RATE_LIMIT_REDIS_URL=redis://127.0.0.1:6379/4 AUTH_STATE_REDIS_URL=redis://127.0.0.1:6379/5 VALKEY_NAMESPACE_RUN_ID=oidc-refresh-lock-20260917 bin/rails test test/services/oidc_refresh_token_issuer_surface_test.rb`
  — blocked before test execution because the configured PostgreSQL host `primary` could not be
  resolved.
- `pg_isready -h 127.0.0.1 -p 5432` — no response.

The database-dependent lock-order assertion remains unverified until an isolated PostgreSQL test
service using the repository's configured test namespace is available. No development, staging, or
production database was used.

## Follow-up verification

- Date: 2026-09-17 UTC
- The repository's available isolated surface databases were used with explicit loopback test Valkey
  URLs; no migration, reset, or non-test datastore was used.
- `bundle exec bin/rails test test/services/oidc_refresh_token_issuer_surface_test.rb` — passed, 4
  runs / 35 assertions.
- The broader focused authentication regression set, including refresh rotation, RP revocation,
  token lookup, logout, and writer-connection checks — passed, 42 runs / 210 assertions.
- The initial SQL observer matcher expected `FOR UPDATE` to be the final SQL text. Rails appends its
  application comment after the lock clause, so the matcher was corrected to recognize the lock
  clause without requiring end-of-string. The production lock order was not changed by this
  test-only correction.

The tests verify parent-before-child observation for refresh rotation. They do not prove production
worker execution, external-provider behavior, or immediate invalidation of already-issued access
JWTs; the latter remains bounded by natural `exp` plus verifier leeway.
