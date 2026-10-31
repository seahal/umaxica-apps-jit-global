# WU-7 com issuance preparation

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; verification used prior and current
  uncommitted worktree changes.
- Split com JWT preparation from response cookie emission. The JWT, language, and experience
  cookies now use the same expiration timestamp as the signed JWT.
- `bin/rails test test/integration/anonymous_com_preference_write_journey_test.rb test/values/anonymous_com_preference_token_shape_test.rb`:
  14 runs, 93 assertions, 0 failures, 0 errors, 0 skips. The journey checks all three expiry values.
- `bin/rubocop app/controllers/concerns/preference_access_token_issuer.rb test/integration/anonymous_com_preference_write_journey_test.rb`:
  2 files inspected, no offenses after correcting test formatting.
- Existing callers still emit cookies immediately after preparation. Signing within the setting
  transaction and emission after commit are not yet wired; this is not WU-7 completion evidence.
