# Administrative cutoff against signed Access JWTs

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Substantial uncommitted worktree changes affected the test results.
- The OIDC Access authenticator was exercised with real signed Client and Operator tokens and actual account, root and grant records. For each surface, setting the account cutoff one microsecond before or exactly at the token's integer `iat` allowed authentication; setting it one microsecond after refused the token as invalid.
- `PARALLEL_WORKERS=1 bin/rails test test/services/oidc_access_token_authenticator_test.rb test/models/concerns/administrative_access_lockable_test.rb test/services/administrative_access_lock_test.rb test/concurrency/administrative_access_lock_clock_test.rb`: 28 runs, 146 assertions, no failures, errors or skips. Scoped RuboCop passed after formatting fixes.
- The cutoff was directly assigned to isolate the authenticator boundary. It does not demonstrate an end-to-end lock/unlock and new-session journey, clock synchronization, real OP delivery or a full suite.
