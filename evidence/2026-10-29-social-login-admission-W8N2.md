# Social login admission test progress

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Extensive uncommitted worktree changes affected the result.
- Updated `SocialAuthLoginTest` setup to follow current automatic Visa/Auth admission redirects with browser navigation headers. The setup now reaches the Auth page; it no longer fails while looking for the removed Visa confirmation form. Intermediate Jump payloads are unwrapped locally, so this does not independently test Jump signature verification.
- With `POSTGRESQL_TEST_PREPARE_DATABASES` set to the existing `.env` value and `PARALLEL_WORKERS=1`, `bin/rails test test/integration/social_auth_login_test.rb` ran 21 tests and 158 assertions: 10 failures, 6 errors and 0 skips. A representative unknown-Google sign-in reached the callback and received HTTP 400 where the test expects a redirect; other cases still contain outdated continuation assumptions. Further repair is needed.
- No full-suite rerun was performed. Test database preparation was used; no production persistence operation or external write was performed.
