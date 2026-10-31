# Withdrawal termination delivery boundary

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had uncommitted changes affecting this check.

Four non-transactional cases exercised APP withdrawal termination inside ordinary and savepoint nesting, with outer commit and rollback. Before the change each failed because an OP receipt existed before outer commit. After the change all four passed (40 assertions); the actor stop delivery, notification and termination occurrence are registered after actor commit.

`PARALLEL_WORKERS=1 bin/rails test test/concurrency/withdrawal_outer_transaction_test.rb test/services/withdrawal_lifecycle_test.rb test/integration/withdrawal_lifecycle_security_test.rb test/operations/op_identity_event_invalidator_test.rb test/jobs/op_identity_event_sweep_job_test.rb` passed: 62 runs, 333 assertions, no failures or errors. Scoped RuboCop for the service and concurrency test reported no offenses. Formatting of the test was applied after that test run.

The test uses synthetic actors and checks that their IDs have no existing cross-database child records before termination. The existing termination anonymizer can purge child records in other databases before the actor transaction commits; atomicity and recovery of that purge remain unresolved. Process failure after actor commit, real downstream delivery, and other withdrawal transitions were not established by this check.
