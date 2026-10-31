# WU-7 com theme API write

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; prior and current uncommitted worktree
  changes were present during verification.
- The com theme and consent APIs now use a shared setting transaction and issuance path. The theme
  API writes the selected option, signs before transaction completion, emits cookies afterward,
  and ignores the legacy theme cookie on reads. A signing failure returns 503 and rolls back the
  newly created preference in the exercised path.
- `bin/rails test test/integration/anonymous_com_preference_write_journey_test.rb test/integration/preference_web_csrf_test.rb test/integration/preference_browser_api_contract_test.rb`:
  44 runs, 2,671 assertions, 0 failures, 0 errors, 0 skips. A further focused run after adding the
  legacy-cookie read case: 16 runs, 119 assertions, 0 failures, 0 errors, 0 skips.
- RuboCop on seven affected Ruby files passed before the final test-only addition.
- The HTML screen writers, reset, database issuance snapshot, Chronicle atomicity and concurrency
  checks remain incomplete. The current audit creation uses a separate database.
