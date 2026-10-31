# RP logout retry response

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had extensive uncommitted changes, including the code tested here.
- The Core APP missing-ID-token-hint test first failed the new `strict-origin` response assertion (1 run, 2 assertions, 1 failure).
- After setting response headers on the server-rendered retry page, `PARALLEL_WORKERS=1 bin/rails test test/controllers/core/app/sign/outs_controller_test.rb test/controllers/warp/app/sign/outs_controller_test.rb test/controllers/tech/org/sign/outs_controller_test.rb` passed: 23 runs, 196 assertions, 0 failures, 0 errors, 0 skips. The Core APP case checks the header, no-store, refusal, active session and POST form.
- Inertia has a separate unavailable renderer; its header was not established by this assertion. No real-browser or full-suite run was performed.
