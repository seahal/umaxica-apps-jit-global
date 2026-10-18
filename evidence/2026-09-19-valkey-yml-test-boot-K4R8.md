# Valkey yml test boot

Date: 2026-09-19

## Commands

Dev Container env already contained `VALKEY_KVS_HOST=valkey-kvs`,
`VALKEY_KVS_PORT=6379`, `VALKEY_CACHE_HOST=valkey-cache`,
`POSTGRESQL_TEST_HOST=primary`. No `VALKEY_TEST_*`, Redis URL, or namespace
variable was added to the commands.

```bash
bundle exec rails test test/lib/umaxica/valkey/settings_test.rb \
  test/lib/umaxica/valkey/responsibility_urls_test.rb \
  test/lib/umaxica/valkey/connection_and_cleanup_test.rb \
  test/config/test_environment_isolation_contract_test.rb \
  test/config/test_environment_edge_contract_test.rb \
  test/security/invariants/cache_boundary_invariant_test.rb
```

Result: 47 runs, 216 assertions, 0 failures, 0 errors, 0 skips.

```bash
PARALLEL_WORKERS=2 bundle exec rails test \
  test/lib/umaxica/valkey/settings_test.rb \
  test/lib/umaxica/valkey/connection_and_cleanup_test.rb \
  test/services/valkey/auth_state/authorization_code_store_test.rb
```

Result: 19 runs, 85 assertions, 0 failures, 0 errors, 0 skips; two processes.

```bash
bundle exec rails test
```

Result: 13345 runs, 80860 assertions, 13 failures, 7 errors, 4 skips.
Failures owned by this change (SolidInfrastructure NullStore assertion,
architecture visibility on `settings.rb`) were fixed and re-checked:

```bash
bundle exec rails test test/integration/solid_infrastructure_test.rb \
  test/tooling/architecture_baseline_test.rb \
  test/lib/umaxica/valkey/settings_test.rb
```

Result: 17 runs, 3126 assertions, 0 failures, 0 errors, 0 skips.

Remaining full-suite failures after that fix were not re-run as a 13345-test
pass in this session. Observed unrelated clusters: `McpEndpointTest` /
`McpForgeryProtectionTest` 404s, `OidcAccessTokenAuthenticatorNoRpSessionLookupTest`
source assertion, `ObservabilityGatewayContractTest` missing Minitest
assertions.

```bash
bun vitest run
```

Result: 85 files, 1064 tests passed. Duration 15.00s. No Valkey configuration
was added for Vitest.

## Topology observed

Test boot connected rate-limit and auth-state through `VALKEY_KVS_HOST` DBs 4
and 6. `Rails.cache` was `ActiveSupport::Cache::MemoryStore`. No `FLUSHDB` /
`FLUSHALL` was issued by the application cleanup path.
