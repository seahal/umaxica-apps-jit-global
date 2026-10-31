# Withdrawal recovery delivery boundary

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had uncommitted changes affecting this check.

Before this change, the existing concurrency and service tests passed (32 runs, 164 assertions). Four new non-transactional cases then reproduced both privacy cancellation and recovery occurrences being written before the actor transaction committed. Recovery now schedules those existing occurrence writes and its notification after actor commit. The cases cover commit and rollback with ordinary nesting and a savepoint.

`PARALLEL_WORKERS=1 bin/rails test test/concurrency/withdrawal_outer_transaction_test.rb test/services/withdrawal_lifecycle_test.rb test/integration/withdrawal_lifecycle_security_test.rb` passed after cleanup: 38 runs, 211 assertions, no failures or errors. Scoped RuboCop for the service and concurrency test reported no offenses.

The initial version of the new test used a stale instance for cleanup, leaving four synthetic privacy requests and clients. A subsequent combined test run failed 22 cases during fixture initialization. The four known synthetic request and client pairs were removed by their exact client IDs in a local test database transaction; the corrected test cleans up its own rows, and the combined run then passed. Process termination or an occurrence-store failure after actor commit can still leave committed recovery without all corresponding occurrences; no durable retry was established.
