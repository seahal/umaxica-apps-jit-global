# WU-7 com consent decision clock

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; verification included prior and current
  uncommitted worktree changes.
- After locking a candidate preference, the consent API reads the owner database clock and
  rechecks both the preference retention deadline and JWT expiry before changing that row. The
  same instant is used for a new consent timestamp.
- `bin/rails test test/integration/anonymous_com_preference_write_journey_test.rb`: 12 runs,
  101 assertions, 0 failures, 0 errors, 0 skips. A controlled database clock at JWT expiry checks
  that the original row is unchanged and a new row is created.
- `bin/rubocop app/controllers/concerns/preference_web_cookie_endpoint.rb test/integration/anonymous_com_preference_write_journey_test.rb`:
  2 files inspected, no offenses.
- Concurrent lock waits and database commit failures were not tested. JWT issuance still uses the
  application clock, and Chronicle creation remains outside the setting transaction.
