# Email removal target-bound Step-Up test

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained extensive uncommitted changes affecting this result.
- The full suite reported that the APP Email deletion test received 401 instead of 303. A focused rerun reproduced the failure (one run, one assertion, one failure). The test's otherwise fresh `settings_email` Step-Up did not identify the Email, while the current controller requires the owned Email public ID as the resource binding.
- Added that existing target to the test's Step-Up evidence. Ran `PARALLEL_WORKERS=1 bin/rails test test/controllers/base/app/identity/emails_controller_test.rb`: three runs, 11 assertions, no failures, errors or skips. No production code was changed in this slice.
- The full suite was not repeated after the test correction; this focused result does not eliminate the other baseline-external full-suite failures.
