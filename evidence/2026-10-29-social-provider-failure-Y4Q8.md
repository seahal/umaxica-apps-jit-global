# Social provider failure response

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Extensive uncommitted worktree changes affected the result.
- Updated the existing sign-in and sign-up provider failure tests to assert the current uniform invalid-request HTTP 400 and removal of social state, consistent with the D-198 admission coverage. The prior tests expected redirects to retired sign URLs.
- With `POSTGRESQL_TEST_PREPARE_DATABASES` set to the existing `.env` value and `PARALLEL_WORKERS=1`, `bin/rails test test/integration/social_auth_login_test.rb -n '/provider_failure_ends_social_auth/'` passed 2 runs and 10 assertions, with no failures, errors or skips.
- Other social login tests and the full suite were not rerun after this change; unresolved failures remain from the earlier full file run. Test database preparation was used; no production persistence operation or external write was performed.
