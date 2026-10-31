# Withdrawal start delivery boundary

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had uncommitted changes affecting this check.

`PARALLEL_WORKERS=1 bin/rails test test/concurrency/withdrawal_outer_transaction_test.rb test/services/withdrawal_lifecycle_test.rb` initially passed (28 runs, 144 assertions). Four new ordinary/savepoint commit/rollback cases then reproduced a premature `withdrawal.requested` occurrence before the actor transaction committed. Start now schedules its existing notification and occurrence after commit.

`PARALLEL_WORKERS=1 bin/rails test test/concurrency/withdrawal_outer_transaction_test.rb test/services/withdrawal_lifecycle_test.rb test/integration/withdrawal_lifecycle_security_test.rb` passed (34 runs, 179 assertions). Scoped RuboCop for the service and concurrency test passed.

An initial test version raised a strict-loading error in cleanup and may have left four synthetic Client rows in the local test database. The test cleanup was corrected; no bulk cleanup or database reset was attempted. Failure or process termination after actor commit and before occurrence creation remains unresolved. This check does not establish recovery or termination cross-database atomicity.
