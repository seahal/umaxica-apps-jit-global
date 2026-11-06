# WU-9 Preference display and invalid-cookie contract recheck

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had 540 changed or untracked paths
  before this evidence file was added; the tests ran against that uncommitted worktree. No commit
  was created.
- The initial focused run of the four affected cases reported 4 runs, 23 assertions and 4 failures.
  Two COM page tests requested `ri=jp` while expecting the JWT's `en` language; the request-region
  overlay correctly selects `ja` while the verified JWT still supplies the dark theme. The tests now
  assert that contract.
- The APP-to-ORG and malformed-JWT recovery cases supplied only the Preference JWT but expected
  deletion headers for all three shared cookies. Base clears only invalid shared cookies that were
  present. The tests now check that only the presented JWT is expired. Malformed-cookie requests
  send an explicit Cookie header per host so the APP-to-ORG host change does not affect the input.
- Ran with `.env.container.devcontainer` sourced:
  `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/integration/anonymous_com_preference_write_journey_test.rb test/integration/preference_credential_recovery_matrix_test.rb`
  Result: 47 runs, 746 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rubocop test/integration/anonymous_com_preference_write_journey_test.rb test/integration/preference_credential_recovery_matrix_test.rb`
  inspected 2 files with no offenses.
- `git diff --check` passed for both changed test files. No application behavior or persistent data
  changed in this slice. This focused result does not establish WU-9 closure or the full-suite
  baseline comparison.
- A subsequent 15-file WU-9 Preference-focused group, including the two changed files, passed: 103
  runs, 2,379 assertions, 0 failures, 0 errors, 0 skips. The run used one worker and a unique local
  Valkey namespace. It did not run the full suite.
