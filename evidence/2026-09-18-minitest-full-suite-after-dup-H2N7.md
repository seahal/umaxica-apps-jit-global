# Full Minitest after duplicate OTP example removal

Date: 2026-09-18.

Removed the second identical `test "deliver forwards a non-secret purpose to the mailer"` from
`test/adapters/otp_email_adapter_test.rb` (Minitest 6 rejects a second definition of the same
method).

Command (same isolated Valkey URLs as the previous env run; password not recorded):

```
CACHE_REDIS_URL=redis://valkey:6379/3
RATE_LIMIT_REDIS_URL=redis://valkey:6379/4
AUTH_STATE_REDIS_URL=redis://valkey:6379/5
VALKEY_TEST_HOST=valkey
VALKEY_TEST_PORT=6379
scripts/test-isolated bin/rails test
```

Result: exit 1. Duration 396.61s. Seed 26752. 16 processes. 13231 tests loaded.

`13231 runs, 80451 assertions, 0 failures, 2 errors, 3 skips`.

Both errors are `ObservabilityGatewayContractTest` (`Minitest::Test`, not
`ActiveSupport::TestCase`):

- `undefined method 'assert_not_empty'` at `test/tooling/observability_gateway_contract_test.rb:68`
- `undefined method 'assert_not_includes'` at the same file line 84

Valkey cleanup: `deleted=32 prefixes=3`.
