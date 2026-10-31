# Last enabled operator check

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; uncommitted worktree changes affected the result.
- In a transactional fixture test, all other Operators were administratively locked. The lifecycle executor still allowed withdrawal of the remaining access-enabled Operator because its last-active query counted locked Operators. A focused test failed before the change (1 run, 2 assertions, 1 failure).
- The existing query now counts only access-enabled, non-deactivated, non-withdrawn, non-discarded other Operators. It returns the existing failure when none remain; no database schema or response shape changed.
- `PARALLEL_WORKERS=1 bin/rails test test/services/org_operator_lifecycle_execute_test.rb test/services/org/operator_lifecycle/execute_test.rb test/services/administrative_access_lock_test.rb test/concurrency/enforcement_reconciliation_end_race_test.rb` passed: 32 runs, 173 assertions, no failures or errors. Scoped RuboCop passed on the service and changed test.
- The query does not serialize concurrent lifecycle or administrative-lock operations. This test does not establish the safety of simultaneous removal of different Operators, or the completeness of other availability predicates.
