# Revoke-others concurrency test cleanup

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained extensive uncommitted changes affecting this result.
- The nontransactional A44-10 test teardown now deletes session-limit resolution rows belonging to its own created sign-in Flow before deleting that Flow. This addresses the previously observed foreign-key teardown error; no application code was changed.
- Ran `PARALLEL_WORKERS=1 bin/rails test test/concurrency/root_revoke_others_concurrent_login_test.rb`: one run, one assertion, one failure, zero errors. The test still expected `:success` but received `:session_limit_pending` after creating two existing roots. Thus the teardown error did not recur, but the race case is not verified and the historical baseline test remains failing. Rows left by the earlier failed teardown were not manually deleted.
