# ORG concurrent identity-stop delivery

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Substantial uncommitted worktree changes affected the tests and implementation.
- The independent-connection duplicate-delivery test now runs for APP and ORG. The first worker pauses after the receipt insert and PostgreSQL shows the second waiting. With first-worker commit, the results are applied/duplicate; with an injected first-worker failure and rollback, the second applies. Both ORG cases leave one receipt and authority stop and revoke their synthetic root and grant.
- `PARALLEL_WORKERS=1 bin/rails test test/concurrency/op_authority_stop_concurrency_test.rb test/operations/op_identity_event_invalidator_test.rb test/jobs/op_identity_event_sweep_job_test.rb test/models/op_inbound_receipt_uniqueness_test.rb`: 38 runs, 191 assertions, no failures, errors or skips. After improving synthetic-operator cleanup, the two ORG cases passed again: 2 runs, 16 assertions. Scoped RuboCop passed before the cleanup-only edit.
- The failure is injected after receipt insertion. Other failure points, lock timeout, actual remote logout, production scheduling and the full suite were not verified.
