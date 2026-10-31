# WU-7 com JWT size limit

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; prior and current uncommitted worktree
  changes were present during verification.
- Com JWT encoding refuses tokens over 3,072 bytes; com-shaped token decoding also rejects them.
  The public codec test checks the nearest representable encoded sizes below, at or below, and
  above the limit; base64url cannot produce every adjacent byte length for a fixed header.
- `bin/rails test test/values/anonymous_com_preference_token_shape_test.rb test/integration/anonymous_com_preference_write_journey_test.rb`:
  46 runs, 387 assertions, 0 failures, 0 errors, 0 skips. After a style-only restructuring the
  focused codec suite ran 11 tests, 153 assertions, 0 failures, 0 errors, 0 skips.
- RuboCop on the codec and its test passed after formatting changes.
- The decoder currently inspects unverified claims to select the com format before applying the
  com-specific size check. A transport-level input size limit and the remaining WU-7 criteria
  are not established by this check.
