# WU-7 com JWT header validation

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree included uncommitted prior
  changes and the changes tested here.
- Anonymous com JWT decoding validates its header and resolves the verification key using the
  presented `kid`, rejecting an unknown key identifier instead of verifying with the active key.
- `bin/rails test test/values/anonymous_com_preference_token_shape_test.rb test/integration/anonymous_com_preference_write_journey_test.rb`:
  9 runs, 58 assertions, 0 failures, 0 errors, 0 skips. The tests include signed tokens with an
  unknown `kid` and an invalid `typ`.
- RuboCop initially reported two alignment offenses in the new tests; `bin/rubocop -a
  test/values/anonymous_com_preference_token_shape_test.rb` corrected both. The application file
  had no reported offenses in the initial two-file check.
- This check does not establish realm-specific key distribution, key rotation, or the rest of
  WU-7's acceptance criteria.
