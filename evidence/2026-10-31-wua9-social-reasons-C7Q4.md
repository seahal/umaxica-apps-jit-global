# Verified social subject internal reasons

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting this result.
- Added assertions initially showed the L1 and L2 internal reasons were absent (2 runs, 6 assertions, 2 failures).
- After adding distinct internal error-context reasons for unknown sign-in and active linked signup, `PARALLEL_WORKERS=1 bin/rails test test/services/social_auth_login_handler_test.rb test/integration/social_login_admission_test.rb` passed: 19 runs, 277 assertions, 0 failures, 0 errors, 0 skips. The tests also verify unfinished, inactive and concurrent-insert failures do not receive those reasons.
- RuboCop and scoped `git diff --check` passed for the two touched files. Public reason-specific responses, provider verification/old-state guards, fresh RP-start links and full WU-A9 acceptance remain unverified and unimplemented.
- A subsequent blocked-Client case showed the initial L2 classification also tagged an unavailable Client (1 run, 4 assertions, 1 failure). The handler now retains the generic conflict for that case; the handler and social-admission suites then passed with 19 runs, 279 assertions, 0 failures and 0 errors. Public reason-specific behavior remains unimplemented.
- After the blocked-Client follow-up, RuboCop passed on the handler and test plus the affected browser and Passkey tests (4 files, no offenses).
- The provider/state matrix was subsequently extended to assert L1/L2 reasons for both Google and Apple and absence of those reasons for unavailable, released, unfinished and revoked identities. Its first run failed because the test used `assert_equal` with a nil expectation; after changing that assertion to `assert_nil`, the matrix and handler tests passed: 10 runs, 509 assertions, 0 failures and 0 errors.
- RuboCop passed on the extended provider/state matrix test (1 file, no offenses).
