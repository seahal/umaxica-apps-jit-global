# WU-7 com consent screen write

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; prior and current worktree changes were
  uncommitted during verification.
- The com consent screen now validates submitted boolean fields and writes through the same
  setting transaction and issuance path as the com consent API. It does not bootstrap a preference
  in inherited pre-action callbacks and redirects successful HTML writes with 303.
- `bin/rails test test/integration/anonymous_com_preference_write_journey_test.rb test/integration/preference_web_csrf_test.rb`:
  32 runs, 175 assertions, 0 failures, 0 errors, 0 skips. The cases include invalid input and an
  injected signing failure, with no new preference or JWT cookie on those failures.
- `bin/rails test test/controllers/base/com`: 8 runs, 36 assertions, 0 failures, 0 errors, 0 skips.
- RuboCop on the three changed Ruby files passed with no offenses.
- Other HTML preference screens and reset still use the legacy path. Concurrency, transaction
  commit failure and separate Chronicle audit atomicity remain unverified.
