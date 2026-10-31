# WU-7 com theme screen write

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; prior and current uncommitted worktree
  changes were present.
- The com theme screen validates supported option IDs and names, writes via the common com
  preference transaction, and returns 303 on successful HTML saves. Invalid options return 422;
  an injected signing failure returns 503 and leaves no new preference or JWT cookie.
- `bin/rails test test/integration/anonymous_com_preference_write_journey_test.rb test/controllers/base/com test/integration/preference_web_csrf_test.rb`:
  42 runs, 222 assertions, 0 failures, 0 errors, 0 skips. After a case-normalization adjustment,
  the focused journey ran 21 tests, 149 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rubocop app/controllers/base/com/preference/themes_controller.rb test/integration/anonymous_com_preference_write_journey_test.rb`:
  2 files inspected, no offenses.
- Other settings screens and reset remain on the previous write path; transaction concurrency,
  commit failure, and separate Chronicle audit behavior remain unverified.
