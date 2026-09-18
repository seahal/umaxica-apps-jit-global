# RP-session refresh lock-order verification

- Date: 2026-09-18 UTC
- Branch: `feature`
- Base commit for this slice: `9bfe558c40`
- Pre-existing working-tree changes were preserved and were not staged.

## Finding and change

`RpSession#record_access_token_expiry!` already used the parent-before-child lock order, but the
public `issue_refresh_token!` model method could write the initial refresh digest after the RP
Session had been revoked. `rotate_refresh_token!` and direct `revoke!` callers also did not enforce
that order at the model boundary. The three methods now lock the parent Browser Session before the
RP Session; initial issuance rechecks `active?` under the locks and raises
`RpSession::IssuanceRejected` before writing a digest when the session is inactive.

## Verification

- Ruby syntax checks for the production and model-test files: passed.
- RuboCop for the changed model and related lock-order tests: passed; 4 files inspected, no
  offenses.
- Focused Rails command:
  `VALKEY_TEST_HOST=127.0.0.1 VALKEY_TEST_PORT=6379 CACHE_REDIS_URL=redis://127.0.0.1:6379/3 RATE_LIMIT_REDIS_URL=redis://127.0.0.1:6379/4 AUTH_STATE_REDIS_URL=redis://127.0.0.1:6379/5 VALKEY_NAMESPACE_RUN_ID=rp-lock-order-20260918 POSTGRESQL_TEST_HOST=127.0.0.1 POSTGRESQL_PORT=5432 bundle exec bin/rails test test/models/rp_session_test.rb test/operations/rp_session_revoker_test.rb test/services/oidc_refresh_token_issuer_surface_test.rb`
  was blocked during Rails schema boot because PostgreSQL at `127.0.0.1:5432` is unavailable. No
  non-test datastore fallback was used.

## Remaining verification

The independent-connection race and SQL lock-order assertions remain unverified until the isolated
PostgreSQL test service is available. No production or shared database was touched.
