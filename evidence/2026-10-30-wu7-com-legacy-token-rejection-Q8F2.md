# WU-7 com legacy token rejection

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- A signed legacy com-shaped token was accepted before the change. The com host now accepts only the anonymous com claim shape; app and org retain their existing token decoder.
- `bin/rails test test/values/anonymous_com_preference_token_shape_test.rb test/values/security_jwt_preference_token_codec_claims_test.rb test/services/preference_token_test.rb test/integration/anonymous_com_preference_write_journey_test.rb`: 74 runs, 526 assertions, 0 failures, 0 errors, 0 skips. Legacy tests using app-shaped tokens on com hosts were adjusted to exercise app and org hosts instead.
- RuboCop reported no offenses in the codec and the two changed token test files.
- This does not establish realm-specific key separation or WU-7 completion. No migration or full-suite run was performed in this slice.
