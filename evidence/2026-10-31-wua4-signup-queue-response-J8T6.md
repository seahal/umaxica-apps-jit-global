# Signup OTP queue refusal checks

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes, including the changes checked here.
- Initial and resend queue-refusal request tests for APP Email and Telephone passed: 4 runs, 30 assertions.
- After replacing nonexistent enforcement principals in two registration-block tests with actual test principals, those cases and the four queue-refusal cases passed together: 6 runs, 43 assertions.
- The preceding broader run had 122 runs, 1,210 assertions, no failures and two missing-principal errors; those fixtures were subsequently corrected. The broader rerun is recorded separately once complete.
- The existing signup OTP page has a cancel action but no resend button. Actual external transport failure and other dependency failures were not tested by these checks.
- The subsequent full run of both affected controller test files passed: 122 runs, 1,222 assertions, no failures, errors or skips.
- Scoped RuboCop on the four changed controllers and two test files passed after correcting 11 formatting offenses; scoped `git diff --check` also passed. The worktree-wide check reported pre-existing whitespace in `Gemfile`, outside this slice.
