# WU-9 Auth admission browser helper check

- `test/support/oidc_auth_admission_test_helper.rb` now follows the Base ceremony-binding
  confirmation form by posting its existing CSRF-protected fields with same-origin navigation
  headers before continuing the redirect chain. The failure message reports the browser host and
  response status.
- `ruby -c test/support/oidc_auth_admission_test_helper.rb` passed.
- `bundle exec rubocop test/support/oidc_auth_admission_test_helper.rb` passed with no offenses.
- `PREFERENCE_COM_JWT_ISSUER=https://www.umaxica.com PREFERENCE_COM_JWT_AUDIENCE=com PREFERENCE_COM_JWT_REVOKED_KIDS= VALKEY_NAMESPACE_RUN_ID=codex-auth-admission-helper-20261101 PARALLEL_WORKERS=1 bin/rails test test/integration/auth_base_browser_authority_test.rb`
  passed: 1 run, 7 assertions, 0 failures, 0 errors, 0 skips.
- `git diff --check` passed.
- This check covers the Base-to-Visa-to-Auth browser admission test only; it does not establish the
  complete WU-9 acceptance matrix. WU-9 remains open.
- Work was performed at HEAD `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had
  uncommitted changes: 363 tracked paths changed and 69 untracked paths. No commit was created.
