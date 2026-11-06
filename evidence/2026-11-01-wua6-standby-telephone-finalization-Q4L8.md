# WU-A6 ORG Standby Telephone registration finalization

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had 579 staged, unstaged or
  untracked paths before this evidence file was added; no commit was created.
- A fixture-free public HTTP test starts Telephone registration in Normal, then changes the same
  authenticated session to Standby and submits the issued SMS OTP. Standby returns 403; the
  Telephone remains unverified, the registration transaction remains unconsumed, the
  `settings_telephone` Step-Up timestamp stays unchanged, the token remains Standby, and no Step-Up
  ceremony is added. The same browser then returns to Normal and successfully submits the same OTP;
  the Telephone becomes verified, the transaction is consumed, and the registration session is
  cleared.
- The focused case passed: 1 run, 20 assertions, 0 failures, 0 errors, 0 skips. The enclosing
  fixture-free Standby test file passed: 3 runs, 45 assertions, 0 failures, 0 errors, 0 skips.
  Scoped RuboCop reported no offenses; Ruby syntax and `git diff --check` passed.
- Verification commands:
  `PREFERENCE_COM_JWT_ISSUER=https://www.umaxica.com PREFERENCE_COM_JWT_AUDIENCE=com PREFERENCE_COM_JWT_REVOKED_KIDS= bin/rails test test/controllers/base/org/support/standby_enforcement_cases_controller_test.rb`;
  focused case after formatting: the same command ending in `:460`;
  `bundle exec rubocop test/controllers/base/org/support/standby_enforcement_cases_controller_test.rb`.
- An earlier attempt in the fixture-heavy Telephone test class did not reach its body because Rails
  fixture setup failed on `bureau_ownerships.operator_id`; this record supersedes that attempt with
  a successful fixture-free public flow. No production behavior, schema, production database or Neon
  data was changed in this slice; the full suite was not run.
- This verifies one operation under Normal and Standby sessions only. The complete policy-derived
  AC-41 matrix and real Standby Root issuance remain open.
