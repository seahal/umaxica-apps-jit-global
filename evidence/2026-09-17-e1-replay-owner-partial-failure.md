# 2026-09-17 E1 replay-owner and family-link fail-closed tests

Command (isolated wrapper, Valkey logical DBs 3/4/5, `VALKEY_TEST_HOST=valkey`):

```text
PARALLEL_WORKERS=1 scripts/test-isolated bin/rails test \
  test/services/oidc/token_exchange_service_test.rb \
  test/services/valkey/auth_state/authorization_code_store_test.rb
```

Result: exit 0. 86 runs, 357 assertions, 0 failures, 0 errors, 0 skips. Seed 58487. Cleanup deleted 77 run-scoped keys.

Focused subset first: three new coordinator cases (invalid_state link, Valkey unavailable on link, same-realm client B replaying A's consumed code) then the full two-file suite.

PostgreSQL test target identity: `primary:5432` administration database `db`, PostgreSQL 17.7. Valkey `valkey:6379` DBs 3/4/5 each returned `PONG` (Valkey 7.2.4). No development or production database was reset or flushed.

Not run: full Rails suite, Ruby SimpleCov gate, canonical `bin/ci`, public HTTP token-endpoint matrix, concurrent consume race, link-timeout-after-mutation, HTTP response-loss recovery.
