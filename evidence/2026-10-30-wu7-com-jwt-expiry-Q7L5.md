# WU-7 com JWT expiry

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree included earlier and current
  uncommitted changes.
- Com JWTs now carry a 400-day lifetime and decoding rejects expiration exactly at `exp` without
  applying the legacy expiry leeway. App and org JWT lifetime and decoding remain unchanged.
- `bin/rails test test/values/anonymous_com_preference_token_shape_test.rb test/integration/anonymous_com_preference_write_journey_test.rb`:
  13 runs, 82 assertions, 0 failures, 0 errors, 0 skips. The test exercises one second before, at,
  and one second after expiry.
- `bin/rubocop app/values/security_jwt_preference_token_codec.rb test/values/anonymous_com_preference_token_shape_test.rb`:
  2 files inspected, no offenses after correcting test time-zone style.
- Issuance still uses application time rather than the required database time and does not yet
  persist the issuance snapshot. The transaction and cookie emission contracts remain incomplete.
