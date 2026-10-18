# CF-011 provider permanent-failure regression

Date: 2026-09-23
Repository HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
Worktree: pre-existing changes were preserved.

## Change

The provider-neutral delivery contract test now exercises the public job path when an adapter
returns `PERMANENT_FAILURE`. It asserts that the notification and current attempt become terminal
and that a subsequent normal worker invocation cannot create another attempt or reopen the
notification. This complements the existing retry-exhaustion test without adding provider-specific
behavior.

## Verification

Ruby syntax, targeted RuboCop, and `git diff --check` passed. The Rails test command was attempted
with the explicit devcontainer environment, the declared disposable test database list, and one
parallel worker:

```text
bundle exec bin/rails test \
  test/models/processor_erasure_notification_delivery_contract_test.rb \
  test/models/processor_erasure_notification_state_test.rb \
  test/models/processor_erasure_notification_concurrency_test.rb
```

The command stopped before assertions because the current process cannot resolve the configured
PostgreSQL service:

```text
ActiveRecord::DatabaseConnectionError: There is an issue connecting with your hostname: primary.
PG::ConnectionBad: could not translate host name "primary" to address:
Temporary failure in name resolution
```

The new regression is therefore present but `UNVERIFIED` until it runs in the isolated PostgreSQL
and Valkey topology. No test was deleted, skipped, mocked, or weakened.

## Current-session recheck

The exact preflight was rerun with the required environment file and the disposable test database
list. The required variables were present without printing their values and
`config/credentials/test.key` was present without reading its contents. The preflight stopped at
the configured PostgreSQL service:

```text
PG::ConnectionBad: could not translate host name "primary" to address:
Temporary failure in name resolution
```

The focused delivery-contract test was rerun with `PARALLEL_WORKERS=1` and stopped before any
assertion for the same reason. `getent hosts primary` and `getent hosts valkey-kvs` returned no
records; the current process has no Podman/Docker client or Podman socket with which to enter the
Compose network. The newly added locked-operator, notified-terminal recovery, and
manual-recovery audit-event assertions are therefore also `UNVERIFIED`.

The DB-free checks were rerun successfully:

```text
processor_erasure_retry_policy_test.rb: 4 runs, 15 assertions, 0 failures, 0 errors, 0 skips
processor_erasure_delivery_values_test.rb: 6 runs, 24 assertions, 0 failures, 0 errors, 0 skips
repository-wide RuboCop: 4773 files inspected, no offenses
Brakeman: 0 errors, 0 security warnings
git diff --check: passed
```

This confirms the provider-neutral value and static boundaries only. It does not close the
pre-deployment CF-011 database-backed evidence gate.
