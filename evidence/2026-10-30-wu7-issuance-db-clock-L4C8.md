# WU-7 com issuance clock

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; verification included prior and current
  uncommitted worktree changes.
- The com issuance preparation accepts an owner database time. The consent API passes its
  post-lock decision time; other existing com issuance callers obtain the setting database clock.
  The codec still permits direct callers to omit the time, in which case it uses application time.
- `bin/rails test test/integration/anonymous_com_preference_write_journey_test.rb test/values/anonymous_com_preference_token_shape_test.rb test/services/preference_token_test.rb`:
  35 runs, 176 assertions, 0 failures, 0 errors, 0 skips. An integration case controls the database
  clock and checks both JWT timestamps.
- RuboCop on the five changed Ruby files passed after line-length fixes.
- The issuance snapshot is not persisted and the other screen writers do not yet place signing and
  cookie emission on opposite sides of their transaction. WU-7 remains incomplete.
