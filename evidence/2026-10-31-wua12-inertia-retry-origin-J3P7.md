# Inertia RP logout retry response

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained extensive uncommitted changes, including the code exercised here.
- The Warp APP missing-ID-token-hint case first failed the `strict-origin` assertion (1 run, 2 assertions, 1 failure).
- After changing the Inertia unavailable renderer, `PARALLEL_WORKERS=1 bin/rails test test/controllers/warp/app/sign/outs_controller_test.rb test/controllers/warp/org/sign/outs_controller_test.rb test/controllers/core/app/sign/outs_controller_test.rb test/controllers/palm/app/sign/outs_controller_test.rb` passed: 28 runs, 230 assertions, 0 failures, 0 errors, 0 skips. The Warp APP/ORG missing-hint cases check the headers and retained sessions; ORG also checks the retry target.
- This tests Rails responses, not an actual browser's retained-document policy, CSRF retry or every surface. The full suite was not run.
