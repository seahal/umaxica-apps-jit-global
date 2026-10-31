# WU-7 com language and timezone screen writes

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; prior and current worktree changes were
  uncommitted during verification.
- The com language and timezone screens now use the shared preference transaction, reject unknown
  options before writing and return 303 after a successful save. Their selected values appear in
  the issued JWT.
- `bin/rails test test/integration/anonymous_com_preference_write_journey_test.rb test/controllers/base/com test/integration/preference_web_csrf_test.rb`:
  49 runs, 260 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rubocop app/controllers/concerns/com_selectable_preference_screen.rb app/controllers/base/com/preference/{languages,timezones}_controller.rb test/integration/anonymous_com_preference_write_journey_test.rb`:
  4 files inspected, no offenses.
- Region and reset remain on the previous write path. Option-boundary and concurrent transaction
  coverage, commit-failure behavior and separate Chronicle audit atomicity remain incomplete.
