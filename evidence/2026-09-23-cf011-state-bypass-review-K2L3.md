# CF-011 state-transition bypass review

Date: 2026-09-23
Repository HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
Worktree: already contained unrelated staged, unstaged, and untracked changes; none were reset or discarded.

## Scope

The processor-erasure notification state transitions were reviewed after the provider-neutral
implementation and integer-boundary corrections. The review searched production Ruby code for
notification status, delivery-generation, attempt, receipt, and retry mutations, then followed the
public job, receipt consumer, and manual-recovery operation paths.

## Findings

- Production state writes are concentrated in `ProcessorErasureNotificationState` public
  transitions and the existing notification creation path. The retry job only enqueues due rows;
  it does not mutate terminal state directly.
- `ProcessorErasureNotificationJob` reaches `NOTIFIED` only through
  `apply_verified_receipt!`, which requires a `ProcessorErasureVerifiedReceipt`, verifies the
  notification/generation/processor/idempotency binding under the notification lock, and rejects
  terminal or stale transitions.
- `ProcessorErasureNotificationReceiptConsumer` resolves the surface-specific notification class
  and requires a registered adapter to verify the raw receipt before applying it.
- Manual recovery is a separate operation. It uses the existing
  `ProcessorErasureNotificationRecoveryPolicy`, records the recovery occurrence, and advances the
  delivery generation rather than mutating the failed generation. No public controller or route
  currently invokes this operation.
- No production direct `update_columns`/status write was found that bypasses these state-transition
  methods. Direct low-level writes found by the search are confined to tests and migrations.

The review did not find an additional confirmed state-transition bypass. The precise authorization
scope for future operator-facing manual-recovery UI remains an existing contract boundary; this
review does not invent a role or permission model for it.

## Verification

Pure value-contract tests passed:

```text
bundle exec ruby -Itest test/values/processor_erasure_retry_policy_test.rb
4 runs, 15 assertions, 0 failures, 0 errors, 0 skips

bundle exec ruby -Itest test/values/processor_erasure_delivery_values_test.rb
6 runs, 24 assertions, 0 failures, 0 errors, 0 skips
```

The required preflight was also attempted with the explicit devcontainer environment and a
process-local debug disablement (no repository configuration change):

```text
bundle exec ruby -r ./lib/local_environment -e 'LocalEnvironment.load!; load "scripts/test-environment-check"'
PG::ConnectionBad: could not translate host name "primary" to address:
Temporary failure in name resolution
```

`getent hosts primary` and `getent hosts valkey-kvs` returned no records in the current process.
Therefore DB-backed CF-011 tests, migration execution, PostgreSQL constraints, and concurrent
state-transition acceptance remain unverified here. No application code, test, configuration,
database, or external service was changed to bypass that environment boundary.
