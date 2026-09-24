# Processor delivery migration rollback correction

- Date: 2026-09-23
- HEAD before this local change: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: pre-existing changes were preserved. No external service, provider, production
  database, or GitHub write was used.

## Finding

The `down` methods of the client and visitor delivery-contract validation migrations attempted to
remove a helper CHECK constraint name that their `up` methods never created. The defect was hidden
from the normal suite because migration rollback is not part of ordinary application test boot.

## TDD evidence

The focused rollback-contract test was first run against the old migration code and failed for both
surface migrations with an unknown helper-constraint name. The migrations now share the exact
helper-constraint constant between `up` and `down`.

```text
bundle exec ruby -Itest test/migrations/processor_erasure_delivery_contract_rollback_test.rb
2 runs, 2 assertions, 0 failures, 0 errors, 0 skips
```

The focused migration files and regression test also pass RuboCop, and `git diff --check` passes.

## Verification boundary

An actual Rails migration rollback/reapply was attempted with the required explicit test
environment, but this process could not resolve the configured PostgreSQL service name `primary`
and stopped during Rails boot with `PG::ConnectionBad`. No localhost fallback or configuration
change was used. Real PostgreSQL `down`/`up` execution remains unverified and must be rerun inside
the Compose core service before claiming database-level rollback evidence.
