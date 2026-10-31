# Secret signup journey through current admission

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Extensive uncommitted worktree changes affected the result.
- Replaced the obsolete hand-expanded admission sequence in the telephone signup journey with the current browser redirect and confirmation path. Browser navigation headers permit Visa's automatic confirmation. The test continues through telephone verification, passkey registration and Secret handling.
- With `POSTGRESQL_TEST_PREPARE_DATABASES` set to the existing `.env` value and `PARALLEL_WORKERS=1`, `bin/rails test test/integration/app_secret_signup_journey_test.rb` passed 24 runs and 1,421 assertions, with no failures, errors or skips. This supersedes the failed intermediate run in `2026-10-29-secret-signup-redirect-F8C4.md`.
- The journey unwraps intermediate Jump payloads locally; it is not an independent verification of Jump signature enforcement. No full-suite rerun was performed after this change. Test database preparation was used; no production persistence operation or external write was performed.
