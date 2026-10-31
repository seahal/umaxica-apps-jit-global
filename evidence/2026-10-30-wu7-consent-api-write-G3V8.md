# WU-7 com consent API write

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; prior and current uncommitted worktree
  changes were present.
- Base com no longer writes legacy display cookies from localization/theme callbacks. The com
  consent API checks the presented JWT, locks the current row, rotates its jti, stores the binding
  digest and prepares the signed result in a setting transaction; it emits cookies after that
  transaction returns. Stale credentials create a new preference without changing the old row.
- `bin/rails test test/integration/anonymous_com_preference_write_journey_test.rb test/integration/preference_web_csrf_test.rb`:
  24 runs, 134 assertions, 0 failures, 0 errors, 0 skips. Coverage includes an injected signing
  failure, rollback of the preference row, no preference cookies on that failure, and stale-token
  recovery.
- `bin/rails test test/integration/preference_browser_api_contract_test.rb`: after updating its
  com success expectation from the former 204 to the planned 200, 16 runs, 2,517 assertions,
  0 failures, 0 errors, 0 skips. The initial run reported two failures for the old 204 expectation.
- RuboCop on the eight changed Ruby files passed with no offenses.
- This does not establish concurrency, commit-failure, DB clock, audit atomicity or other WU-7
  acceptance. The existing creation path writes Chronicle separately from the setting transaction.
