# BL-19 outdated-browser route classification

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting this result.
- A combined candidate run produced 12 runs, 219 assertions, 2 failures and 0 errors. The browser allowlist failure requested `/oauth/token` at Base, although `config/routes/visa.rb` places the token endpoint on Visa; its test ID appears in the baseline. The other failure was the baseline-listed passkey options rate-limit case, which returned 400 rather than the expected 429; its cause was not established.
- After the allowlist test targeted Visa, `PARALLEL_WORKERS=1 bin/rails test test/integration/sign_in_path_browser_allowlist_test.rb` passed: 3 runs, 6 assertions, 0 failures, 0 errors, 0 skips. This confirms the tested Auth pages reject the outdated browser while the tested Visa token endpoint and Core logout receiver are not rejected with 404 or 406.
- The social and Passkey termination files in the combined run reported no failures in that execution. This does not resolve every BL-19 candidate or every token client configuration.
- The no-failure files in the combined run included the named A05-6 pending-social cancellation/expiry/halt test and A06-6b lock-wait/curfew test. They exercise those current cases, while the remaining signup completion-receipt contract is not established by them.
