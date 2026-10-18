# Minitest with explicit test Valkey URLs

Date: 2026-09-18. No Valkey boot-contract change. Process environment used Compose DNS (`valkey`,
`primary`). Loopback `127.0.0.1:6379`/`5432` refused connections in this container.

Exports for the run (password not recorded):

```
CACHE_REDIS_URL=redis://valkey:6379/3
RATE_LIMIT_REDIS_URL=redis://valkey:6379/4
AUTH_STATE_REDIS_URL=redis://valkey:6379/5
VALKEY_TEST_HOST=valkey
VALKEY_TEST_PORT=6379
```

`POSTGRESQL_TEST_HOST=primary`, `POSTGRESQL_PORT=5432`, `POSTGRESQL_USER=root`,
`POSTGRESQL_DATABASE=db` were already set.

## Smoke

`scripts/test-isolated bin/rails test test/lib/umaxica/valkey/responsibility_urls_test.rb`

Exit 0. Preflight: Postgres 17.7 at `10.89.0.3:5432`, Valkey 7.2.4 DBs 3/4/5 PONG.
`2 runs, 14 assertions, 0 failures, 0 errors, 0 skips`.

## Full suite

`scripts/test-isolated bin/rails test`

Exit 1 after 6.87s. Preflight succeeded (same Valkey/Postgres proof). Rails then failed while
loading tests:

`ActiveSupport::Testing::Declarative#test`:
`test_deliver_forwards_a_non-secret_purpose_to_the_mailer` is already defined in
`OtpEmailAdapterTest` (`test/adapters/otp_email_adapter_test.rb:107`).

The file declares that example twice (lines 85 and 107), identical bodies. Minitest 6.0.6 treats the
second definition as a hard error. No test assertions ran after load. Valkey cleanup reported
`deleted=0`.
