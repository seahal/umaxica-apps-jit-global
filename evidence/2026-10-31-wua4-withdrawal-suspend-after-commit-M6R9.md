# Withdrawal suspension after actor commit

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Substantial uncommitted worktree changes affected the implementation and tests.
- Four non-transactional APP cases showed that `WithdrawalLifecycle.suspend!` created an OP receipt before the enclosing actor transaction committed: 4 runs, 4 assertions, 4 failures before the change.
- Suspension now registers the existing OP stop delivery, notification and suspension occurrence on the actor transaction's commit. Tests cover outer commit/rollback and ordinary/savepoint nesting, verifying no OP receipt, root revocation or suspension occurrence before commit or after rollback.
- `PARALLEL_WORKERS=1 bin/rails test test/concurrency/withdrawal_outer_transaction_test.rb test/services/withdrawal_lifecycle_test.rb test/integration/withdrawal_lifecycle_security_test.rb test/operations/op_identity_event_invalidator_test.rb test/jobs/op_identity_event_sweep_job_test.rb`: 58 runs, 293 assertions, no failures, errors or skips. Scoped RuboCop passed.
- The Client withdrawal diagrams and inventory were updated. A prior operator-specific note accidentally placed in the Client inventory was corrected and added to the Operator section.
- Termination, start, recovery, privacy-cancellation occurrence, actor-commit/occurrence failure recovery, actual remote delivery and the full suite were not tested here.
