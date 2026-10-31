# WU-7 com currency screen write

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; prior and current uncommitted changes were
  present during verification.
- The com currency screen accepts its supported options, writes through the shared com
  transaction, issues the signed currency value, and returns 303. Invalid input returns 422;
  an injected signing failure returns 503 without creating a preference or issuing its JWT.
- `bin/rails test test/integration/anonymous_com_preference_write_journey_test.rb test/controllers/base/com`:
  31 runs, 197 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rubocop app/controllers/base/com/preference/currencies_controller.rb test/integration/anonymous_com_preference_write_journey_test.rb`:
  2 files inspected, no offenses.
- Remaining screens, reset, transaction concurrency, commit failure, and separate Chronicle audit
  behavior are not covered by this result.
