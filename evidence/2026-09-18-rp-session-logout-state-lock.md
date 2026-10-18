# RP Session Logout State Lock

Date: 2026-09-18 Branch: `feature` Baseline HEAD before this slice: `a458842d8`

## Finding and change

`RpSession#mark_logout_status!` is a public state mutation that can set `revoked_at` on a successful
logout. The other RP-session issuance, rotation, expiry, and revoke methods already serialize on the
Base Browser Session before the RP Session. The method now uses the same parent-before-child lock
helper, so a direct caller cannot update logout state outside that boundary.

## Verification

- `ruby -c app/models/concerns/rp_session.rb` — passed.
- `bundle exec rubocop app/models/concerns/rp_session.rb` — passed.
- `git diff --check` — passed.
- Focused Rails tests were attempted with explicit loopback PostgreSQL and Valkey test endpoints:
  `POSTGRESQL_TEST_HOST=127.0.0.1 POSTGRESQL_PORT=5432 POSTGRESQL_USER=root POSTGRESQL_PASSWORD=test-only POSTGRESQL_DATABASE=db CACHE_REDIS_URL=redis://127.0.0.1:6379/3 RATE_LIMIT_REDIS_URL=redis://127.0.0.1:6379/4 AUTH_STATE_REDIS_URL=redis://127.0.0.1:6379/5 VALKEY_TEST_HOST=127.0.0.1 VALKEY_TEST_PORT=6379 VALKEY_NAMESPACE_RUN_ID=rp-status-lock-20260918 PARALLEL_WORKERS=1 scripts/test-isolated bin/rails test test/models/rp_session_test.rb test/operations/rp_session_revoker_test.rb`.
  The command stopped before assertions because PostgreSQL and Valkey were not listening on the
  explicit loopback ports. No fallback datastore was used.

The database concurrency and rollback behavior remain unverified until the isolated services are
available.
