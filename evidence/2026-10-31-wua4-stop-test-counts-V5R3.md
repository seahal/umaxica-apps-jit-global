# Authority stop test counts

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had uncommitted changes affecting this check.

Six outside-baseline full-suite failures were reproduced together: four authority-stop operation cases and APP/ORG logout confirmation cases assumed the entire stop table was empty. The current local test databases contained other stop records. The tests now compare the count before and after each refusal or replay, and replay participant assertions are scoped to the returned stop. The first operation remains checked, and the replay or refused request is still asserted to add no stop.

The six focused cases passed (34 assertions). `PARALLEL_WORKERS=1 bin/rails test test/operations/op_authority_stop_committer_test.rb test/controllers/base/app/oidc/logouts_controller_test.rb test/controllers/base/org/oidc/logouts_controller_test.rb` passed: 65 runs, 396 assertions, no failures or errors. Scoped RuboCop passed. No stop records were deleted, and the full suite has not been rerun.
