# WU-7 com region screen write

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; prior and current worktree changes were
  uncommitted during verification.
- The com region screen updates the region and its language, date format, time format and currency
  defaults through one shared preference transaction. It rejects unknown values and returns 503 on
  the injected signing failure without retaining the new preference.
- `bin/rails test test/integration/anonymous_com_preference_write_journey_test.rb test/controllers/base/com test/integration/preference_web_csrf_test.rb`:
  52 runs, 276 assertions, 0 failures, 0 errors, 0 skips. After adding the second supported region,
  the focused journey ran 31 tests, 208 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rubocop app/controllers/base/com/preference/regions_controller.rb test/integration/anonymous_com_preference_write_journey_test.rb`:
  2 files inspected, no offenses.
- Reset, DB issuance snapshot, concurrent saves, commit failure, and separate Chronicle audit
  behavior remain incomplete or unverified.
