# Signup OTP cancellation before delivery

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checked implementation and tests.
- Added APP Email and telephone cases that issue an OTP, cancel the signup through `SignUpTermination`, and then invoke the original delivery guard. Both guards refuse and the delivery block is not called.
- The focused cancellation cases passed: 2 runs, 16 assertions. The signup delivery-guard and committed-retry files passed together with `PARALLEL_WORKERS=1`: 28 runs, 284 assertions, no failures or errors.
- RuboCop and `git diff --check` passed for the changed test file.
- These sequential local cases do not demonstrate a concurrent cancellation race, actual delivery, or the other XDB-14 failure points.
