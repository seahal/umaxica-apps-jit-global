# Enforcement tests with existing principals

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had uncommitted changes affecting this check.

The full suite showed two outside-baseline errors in enforcement tests. A focused run of those cases plus the related APP/ORG identifier attachment cases reproduced five `RecordNotFound` errors: their Cases named synthetic nonexistent principals, while the current apply path explicitly requires the principal to exist. The tests now use existing fixture principals. Identifier attachment is still tested against a different principal from the requester, and the method-effect replacement assertions remain unchanged.

The five focused cases passed (14 assertions). `PARALLEL_WORKERS=1 bin/rails test test/integration/enforcement_identifier_attachment_gate_test.rb test/models/app_enforcement_case_test.rb test/operations/enforcement_case_apply_failure_test.rb` passed: 31 runs, 110 assertions, no failures or errors. Scoped RuboCop passed. The full suite has not been rerun after this change.
