# WU-7 Base display-cookie error logging

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had uncommitted changes,
including the implementation and tests exercised here.

- The focused read-repair test initially failed because the malformed duplicate-key experience
  cookie did not produce an error event.
- After the change, the focused read-repair and stale-JWT checks passed: 2 runs, 34 assertions,
  no failures or errors. The malformed-cookie check also verified that the logged messages did
  not contain the presented JWT or experience cookie.
- `PARALLEL_WORKERS=1 bin/rails test test/integration/anonymous_com_web_push_initialization_test.rb
  test/controllers/warp/com/roots_controller_test.rb` passed: 41 runs, 581 assertions, no failures,
  errors, or skips. This includes a valid experience snapshot from another revision, which is
  repaired without an invalid-cookie event.
- A subsequent `PARALLEL_WORKERS=1 bin/rails test` with the required test database and com JWT
  configuration exited 1: 16,324 runs, 156,430 assertions, 133 failures, 205 errors and no skips.
  Comparing full test names against `plans/2026-10-28-baseline-failing-tests.md` found 23 distinct
  candidate names outside the baseline. This is a name comparison, not a regression diagnosis;
  candidates include signup, social, admission, passkey and database reconstruction cases. The
  zero-baseline-external-failures closure condition is not established. No production or Neon
  database was targeted.
- Inspection of the 23 candidate result headers and immediate error messages found 17
  `NoMethodError` results on `[]` for `nil`, three database reconstruction assertions, and three
  other authentication/signup response or state assertions. This classification does not establish
  their root causes or whether any candidate is caused by WU-7.
- `PARALLEL_WORKERS=1 bin/rails test test/integration/social_login_admission_test.rb:461` passed
  independently (1 run, 9 assertions). In the full suite this test failed while reading the
  CSRF meta tag after the Auth app root request. The isolated pass does not explain the full-suite
  failure or establish that the remaining candidates pass independently.
- After the full run, the display-cookie logging was extracted into a smaller method to address
  RuboCop's complexity and formatting findings. The two focused repair and valid-other-revision
  cases passed again (2 runs, 26 assertions); RuboCop reported no offenses in the controller and
  integration test. The full suite has not been rerun after this refactor.
