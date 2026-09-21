# Phase 05 OIDC transaction state verification

Date: 2026-09-20

Repository HEAD at verification: `52efa31df2a28763ad405f604bb3ef0c416b3b93`

This slice strengthened the existing surface-local Base OIDC transaction state machine. Result
registration now accepts only a pending, unexpired transaction while holding the transaction row
lock. An authenticated transaction cannot be overwritten with another actor, session reference,
authentication method, or authentication event. The change did not add a second authority or
change the transaction table shape.

## TDD and verification

The new overwrite regression was first run against the old implementation and failed because no
exception was raised. After the pending-state guard was added, the public model API tests passed:

```text
RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test \
  test/models/concerns/oidc_authorization_transactionable_test.rb
8 runs, 44 assertions, 0 failures, 0 errors, 0 skips
```

The test includes two independent concurrent PostgreSQL-backed registration attempts and observes
exactly one winner. The focused transaction/admission group also passed with 36 runs, 191
assertions, 0 failures, 0 errors, and 2 skips.

The full Rails suite was rerun after the state-machine change:

```text
11360 runs, 72523 assertions, 0 failures, 0 errors, 5 skips
```

Targeted RuboCop and `git diff --check` passed for the changed model and test. No tests were
deleted, skipped, weakened, or replaced with mocks.

## Remaining scope

This evidence covers only the transaction registration state guard. It does not claim completion
of the later authorization-code/session commit ordering, bounded Valkey timeout contract, callback
credential migration, or replay-cleanup work. Those remain separate execution slices.
