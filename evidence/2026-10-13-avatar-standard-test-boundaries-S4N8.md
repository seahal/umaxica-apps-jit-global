# Avatar standard test database boundary follow-up

Date: 2026-10-13 UTC. Checks were performed against full HEAD
`aa92265b7e63bf874fddd0aa8f278d5ed19de6b5` with an extensively dirty worktree. No migrations,
database reset, backfill or cutover operation ran. `POSTGRESQL_ISOLATED_TEST_RUN_ID` was unset;
the Rails test task reported the repository's standard test database manifest.

## Verification

The first command below ran 135 tests and 672 assertions, with no assertion failures and six
errors. Five errors were independent-COMMIT cases in `AvatarConcreteOwnershipPeriodTest`; one was
the concurrent reservation case in `AvatarTransferReservationTest`. Each stopped at
`ParallelTestDatabaseCloner.verify_owned_worker_execution!`, which requires a run-owned worker
receipt. The receipt requirement was not bypassed.

```sh
env -u POSTGRESQL_ISOLATED_TEST_RUN_ID PARALLEL_WORKERS=1 RAILS_ENV=test bin/rails test \
  test/controllers/base/app/avatar_ownership_transfers_controller_test.rb \
  test/controllers/base/org/avatar_ownership_transfers_controller_test.rb \
  test/models/avatar_concrete_ownership_period_test.rb \
  test/models/avatar_group_concrete_ownership_period_test.rb \
  test/models/avatar_group_ownership_period_source_test.rb \
  test/models/avatar_group_ownership_period_test.rb \
  test/models/avatar_ownership_cutover_barrier_test.rb \
  test/models/avatar_ownership_period_source_test.rb \
  test/models/avatar_ownership_period_test.rb \
  test/models/avatar_ownership_status_test.rb \
  test/models/avatar_ownership_transfer_test.rb \
  test/models/avatar_transfer_reservation_test.rb \
  test/operations/avatar_concrete_ownership_backfill_operation_test.rb \
  test/operations/avatar_group_concrete_ownership_backfill_operation_test.rb \
  test/operations/avatar_ownership_cutover_operation_test.rb \
  test/operations/avatar_ownership_transfers_test.rb \
  test/operations/avatar_registry_transfer_failure_test.rb \
  test/policies/avatar_group_policy_test.rb \
  test/queries/avatar_group_ownership_transition_inventory_query_test.rb \
  test/queries/avatar_ownership_transition_inventory_query_test.rb \
  test/services/avatar_access_grants_test.rb
```

The same command without `avatar_concrete_ownership_period_test.rb` and
`avatar_transfer_reservation_test.rb` passed: 107 tests, 606 assertions, no failures, errors or
skips. The remaining Avatar controller, ownership, reservation, cutover-barrier, backfill, policy,
inventory and grant tests ran against the standard test databases.

```sh
env -u POSTGRESQL_ISOLATED_TEST_RUN_ID PARALLEL_WORKERS=1 RAILS_ENV=test bin/rails test \
  test/controllers/base/app/avatar_ownership_transfers_controller_test.rb \
  test/controllers/base/org/avatar_ownership_transfers_controller_test.rb \
  test/models/avatar_group_concrete_ownership_period_test.rb \
  test/models/avatar_group_ownership_period_source_test.rb \
  test/models/avatar_group_ownership_period_test.rb \
  test/models/avatar_ownership_cutover_barrier_test.rb \
  test/models/avatar_ownership_period_source_test.rb \
  test/models/avatar_ownership_period_test.rb \
  test/models/avatar_ownership_status_test.rb \
  test/models/avatar_ownership_transfer_test.rb \
  test/operations/avatar_concrete_ownership_backfill_operation_test.rb \
  test/operations/avatar_group_concrete_ownership_backfill_operation_test.rb \
  test/operations/avatar_ownership_cutover_operation_test.rb \
  test/operations/avatar_ownership_transfers_test.rb \
  test/operations/avatar_registry_transfer_failure_test.rb \
  test/policies/avatar_group_policy_test.rb \
  test/queries/avatar_group_ownership_transition_inventory_query_test.rb \
  test/queries/avatar_ownership_transition_inventory_query_test.rb \
  test/services/avatar_access_grants_test.rb
```

After changing `AvatarGroupConcreteOwnershipPeriodTest` to use Rails' default test transaction, its
separate rerun passed: 2 tests, 10 assertions, no failures, errors or skips. RuboCop reported no
offenses for that test file, and `git diff --check` passed.

## Test database state

Before the two broad commands, the standard `test_avatar_db` contained 1 Avatar and 4 AvatarGroups.
The broad commands each ran `AvatarGroupConcreteOwnershipPeriodTest`, whose class disabled Rails'
transactional tests despite not requiring a committed transaction. Each invocation left two
synthetic Groups behind. The test was changed to use Rails' default transaction rollback; its next
run left the count unchanged. The four Groups created by the earlier invocations remain in
`test_avatar_db`; no manual deletion was performed.

After the follow-up test, a read-only Rails runner confirmed `test_avatar_db`: 1 Avatar, 8
AvatarGroups, 0 legacy ownership periods, 1 concrete Enterprise ownership period, 0 concrete
Bureau ownership periods, 0 transfers, 0 reservations and 0 cutover markers. A deletion of the
four retained synthetic rows would mutate the persistent test database and was not performed.

## Remaining scope

AV-3/AV-6 and real-COMMIT migration/cutover acceptance remain unverified. The concurrency cases
require run-owned worker receipts. MIG-2/MIG-4 require an irreversible database rehearsal, and the
repository's required explicit approval and recovery plan have not been provided. No PASS is
claimed for Step 17 as a whole.
