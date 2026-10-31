# Warp ORG logout retry cross-origin refusal

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained extensive uncommitted changes, including the tested implementation.
- With Rails forgery protection enabled, a cross-origin POST carrying the rendered retry form token returned 422 without the Inertia unavailable page and left the RP session active. The subsequent same-origin retry reached the unavailable page with the session still active.
- `PARALLEL_WORKERS=1 bin/rails test test/controllers/warp/org/sign/outs_controller_test.rb test/controllers/warp/app/sign/outs_controller_test.rb`: 14 runs, 141 assertions, 0 failures, 0 errors, 0 skips.
- The test sets Origin and Fetch Metadata itself; an actual browser, other surfaces and the full suite were not checked.
