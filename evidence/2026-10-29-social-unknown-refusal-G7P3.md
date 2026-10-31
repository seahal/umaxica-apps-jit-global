# Social sign-in unknown-subject refusal

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Extensive uncommitted worktree changes affected the result.
- The existing D-47 admission coverage compares sign-in unknown and sign-up already-registered responses. Updated the older Google and Apple unknown-subject tests to expect the current uniform invalid-request HTTP 400 rather than the retired redirect, while retaining the no-account, no-identity, no-flow and no-session creation assertions.
- With `POSTGRESQL_TEST_PREPARE_DATABASES` set to the existing `.env` value and `PARALLEL_WORKERS=1`, `bin/rails test test/integration/social_auth_login_test.rb -n '/unknown_(Google|Apple)_sign-in/'` passed 2 runs and 30 assertions, with no failures, errors or skips.
- The rest of `SocialAuthLoginTest` was not rerun after this change; the other failures and errors recorded in `2026-10-29-social-login-admission-W8N2.md` remain unverified. Test database preparation was used; no production persistence operation or external write was performed.
