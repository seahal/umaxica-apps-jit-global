# Activity history read failure

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes, including the implementation and tests.
- Before the change the existing controller tests confirmed that both app and org concealed a Chronicle failure as an empty successful page. Both controllers now return HTTP 503 and a localized unavailable message instead.
- `PARALLEL_WORKERS=1 bin/rails test test/controllers/base/identity_activities_failure_test.rb test/controllers/base/identity_read_only_pages_test.rb` passed: 10 runs, 77 assertions, no failures or errors. The latter includes real HTTP requests with injected Chronicle read failures for both surfaces and normal activity-list assertions.
- This does not verify unrelated Passkey slot migration, backfill, or delivery contracts.
