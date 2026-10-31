# Concurrent identity-stop delivery

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Substantial uncommitted worktree changes affected the tested implementation.
- A non-transactional APP test paused the first worker after receipt insertion and observed the second worker blocked in PostgreSQL. Before the change, the first returned applied and the second raised a receipt unique-constraint error: 1 run, 2 assertions, 1 failure.
- The invalidator now acquires a transaction advisory lock derived from the fixed sender and event ID before checking the receipt. In the same race the workers returned applied and duplicate, with one receipt and one authority stop; the test root and grant were revoked.
- `PARALLEL_WORKERS=1 bin/rails test test/concurrency/op_authority_stop_concurrency_test.rb test/operations/op_identity_event_invalidator_test.rb test/jobs/op_identity_event_sweep_job_test.rb test/models/op_inbound_receipt_uniqueness_test.rb`: 35 runs, 167 assertions, no failures, errors or skips. After formatting, the focused race passed again: 1 run, 8 assertions. Scoped RuboCop passed.
- The race used an APP event and a successful first worker; ORG, lock timeout, first-worker failure, actual remote logout delivery and the full suite were not verified.
