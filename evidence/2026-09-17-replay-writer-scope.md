# Authorization-Code Replay Revocation Writer Scope

- Date: 2026-09-17
- Branch: `feature`
- Previous committed slice: `6c3dcd3a7`
- Scope: ensure replay-linked RP Session lookup and revoke use the fixed realm's writing connection.

## Change verified statically

`OidcTokenExchangeCoordinator#revoke_linked_family!` now resolves the concrete surface-local RP
Session class, enters that class's connection owner with `role: :writing`, and performs both the
lookup and `RpSessionRevoker` call in that context. Unsupported resource types return without
dispatch. The existing fixed class mapping and replay-owner checks remain in place.

A regression test records the connection role requested by the replay cleanup boundary and requires
`:writing` before the session lookup/revoke dispatch.

## Commands and results

- `ruby -c app/services/oidc_token_exchange_coordinator.rb` — passed.
- `ruby -c test/services/oidc/realm_binding_test.rb` — passed.
- `bundle exec rubocop app/services/oidc_token_exchange_coordinator.rb test/services/oidc/realm_binding_test.rb`
  — passed; 2 files inspected, no offenses.
- `git diff --check` — passed.
- `VALKEY_TEST_HOST=127.0.0.1 VALKEY_TEST_PORT=6379 CACHE_REDIS_URL=redis://127.0.0.1:6379/3 RATE_LIMIT_REDIS_URL=redis://127.0.0.1:6379/4 AUTH_STATE_REDIS_URL=redis://127.0.0.1:6379/5 VALKEY_NAMESPACE_RUN_ID=oidc-replay-writer-20260917 bin/rails test test/services/oidc/realm_binding_test.rb`
  — blocked before test execution because PostgreSQL host `primary` could not be resolved.

The database-backed replay/revoke behavior remains unverified until the isolated PostgreSQL test
service is available. No non-test datastore was used.
