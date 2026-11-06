# Preference JWT focused verification

- Commit: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree had uncommitted changes before this check; this check also left it uncommitted.
- Extracted realm keyset setup from `registry_input_env` in the JWT registry test helper and
  corrected nine autocorrectable RuboCop findings in six files.
- Updated `docs/architecture/current_context.md`, `docs/architecture/controller-lifecycle.md`, and
  `docs/architecture/preference.md` to remove stale Preference JWT refresh/record-read claims and
  describe the current Base read-repair and read-only host boundaries.
- `bundle exec rubocop app/values/security_jwt_preference_token_codec.rb app/controllers/concerns/preference_access_token_transport.rb test/test_helper.rb test/unit/jit/security/jwt/registry_test.rb test/controllers/concerns/preference/base_test.rb test/values/jwt_temporal_validation_test.rb`:
  6 files inspected, no offenses.
- `git diff --check` on the changed Ruby and Preference architecture documentation files passed.
- `bin/rails test test/unit/jit/security/jwt/registry_test.rb test/unit/jit/security/jwt/local_keyset_installer_test.rb`
  initially stopped during Rails initialization because the shell lacked `PREFERENCE_COM_JWT_ISSUER`
  and `PREFERENCE_COM_JWT_AUDIENCE`. It did not reach test execution.
- Re-ran the same focused tests with `PREFERENCE_COM_JWT_ISSUER=https://www.umaxica.com`,
  `PREFERENCE_COM_JWT_AUDIENCE=com`, and an explicitly empty `PREFERENCE_COM_JWT_REVOKED_KIDS`: 40
  runs, 334 assertions, 0 failures, 0 errors, 0 skips.
- Full suite and broader WU-9 acceptance remain unverified by this check.
