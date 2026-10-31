# Rails full test after database reset

Commit: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting the result.

`bin/rails test` prepared the test schemas and ran with 16 workers. Result: 16,240 runs, 158,162 assertions, 150 failures, 141 errors, 0 skips. The command exited nonzero. The run output is temporarily available at `/tmp/wu7-rails-test-20261030.log`.

Comparing test names extracted from failure/error output with `plans/2026-10-28-baseline-failing-tests.md` found 33 distinct names absent from the baseline. This comparison is based on names, not a diagnosis of whether each failure is a regression. Examples include the new `ComPreferenceBrowserBinding` NOT NULL validation, five `ComPreferenceTest` dependent-destruction cases, several com Preference journey and credential-recovery cases, database reconstruction authority checks, route coverage and the architecture baseline. The full failure details remain in the run output. Baseline-outside failures are not zero.

The test startup applied the pending com Web Push and browser-binding migrations to the test database. This was part of the explicitly requested test command, not a production or Neon deployment.
