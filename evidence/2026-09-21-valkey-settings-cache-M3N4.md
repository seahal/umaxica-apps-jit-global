# Valkey settings cache concurrency cleanup

- Date: 2026-09-21 UTC
- Repository: `seahal/umaxica-apps-jit-global`
- Branch: `feature`
- External writes: none

## Change

`Umaxica::Valkey::Settings.current` and `reset_current!` now use an existing
`Concurrent::Map` cache with `compute_if_absent` instead of an unsynchronized class instance
variable. The cache key and public methods remain unchanged. Valkey hosts, ports, logical DB
assignments, TLS requirements, timeout/retry settings, and environment loading were not changed.

This closes the two `ThreadSafety/ClassInstanceVariable` offenses in `settings.rb` without
introducing request-scoped or global mutable state.

## Verification

Focused tests:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/lib/umaxica/valkey/settings_test.rb \
  test/config/test_environment_isolation_contract_test.rb \
  test/lib/umaxica/valkey/connection_and_cleanup_test.rb \
  test/integration/solid_infrastructure_test.rb
```

Result: `34 runs, 142 assertions, 0 failures, 0 errors, 0 skips`.

Targeted RuboCop for `lib/umaxica/valkey/settings.rb` and
`lib/umaxica/valkey/responsibility_urls.rb`: two files inspected, no offenses.
`git diff --check` passed.

Full Rails suite:

```text
bin/rails test
```

Result: `11483 tests, 73355 assertions, 0 failures, 0 errors, 6 skips`.
The six skips are existing suite skips; none was added by this change.

## Limits

This is a process-local configuration-cache cleanup. It does not claim cross-process cache
coordination or change Valkey availability/retry behavior. Live production Valkey TLS and
deployment configuration remain outside this repository-side verification.
