# Email OTP admission test update

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Extensive uncommitted worktree changes affected these results.
- Updated the app email controller security and enumeration parity tests to use the current automatic Auth entry redirects. They attach the Auth session through HTTP, confirm the binding through the existing coordinator, and reach the clean entry page; they do not independently verify the cross-host confirmation HTTP journey.
- With `POSTGRESQL_TEST_PREPARE_DATABASES` set to the existing `.env` value and `PARALLEL_WORKERS=1`, `bin/rails test test/controllers/auth/app/in/emails_controller_security_test.rb` passed 14 runs and 74 assertions; `bin/rails test test/integration/email_sign_in_enumeration_parity_test.rb` passed 3 runs and 79 assertions. Both had no failures, errors or skips.
- No full-suite rerun was performed after these changes. Test database preparation was used; no production persistence operation or external write was performed.
