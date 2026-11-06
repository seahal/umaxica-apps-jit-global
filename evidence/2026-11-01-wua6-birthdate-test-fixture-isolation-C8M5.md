# WU-A6 ORG birthdate HTTP test fixture isolation

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had 582 staged, unstaged or
  untracked paths while this check ran; no commit was created.
- The first run of `test/controllers/base/org/identity/birthdates_controller_test.rb` stopped during
  global fixture setup with three `bureau_ownerships` foreign-key errors, before assertions. This
  did not exercise the endpoint.
- The test class creates its Operator and Passkeys in setup, so it now sets
  `fixture_table_names = []`. The focused file then passed: 3 runs, 17 assertions, 0 failures, 0
  errors, 0 skips. Its cases include Normal display with matching Step-Up evidence and Standby
  refusal without exposing the birthdate.
- Verification:
  `PREFERENCE_COM_JWT_ISSUER=https://www.umaxica.com PREFERENCE_COM_JWT_AUDIENCE=com PREFERENCE_COM_JWT_REVOKED_KIDS= bin/rails test test/controllers/base/org/identity/birthdates_controller_test.rb`;
  scoped RuboCop reported no offenses; `ruby -c` and `git diff --check` passed.
- This corrects one test's fixture isolation. It does not establish the complete AC-41
  policy-derived matrix, real Standby Root issuance, or the cause of the broader fixture foreign-key
  failures. No application behavior or schema changed; no full suite was run.
