# Withdrawal start clock under contention

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had uncommitted changes affecting this check.

The concurrency test file initially passed (16 runs, 132 assertions). A new independent-connection case held the Client lock, verified that the start worker was blocked through PostgreSQL, and sampled the database clock before releasing the lock. Before the change the created flow's `began_at` preceded that sample (1 run, 1 failure). Start now obtains the actor database clock after acquiring the actor lock.

`PARALLEL_WORKERS=1 bin/rails test test/concurrency/withdrawal_outer_transaction_test.rb test/services/withdrawal_lifecycle_test.rb test/integration/withdrawal_lifecycle_security_test.rb` passed (39 runs, 213 assertions). The concurrency test was formatted with scoped RuboCop after the test run. This check does not establish crash recovery of occurrence records or repair sign-in OTP outer-transaction ordering.
