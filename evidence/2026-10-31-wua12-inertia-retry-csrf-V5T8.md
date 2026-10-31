# Inertia logout retry CSRF

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had extensive uncommitted changes, including the test and implementation exercised here.
- With forgery protection enabled, the Warp ORG integration case checks rejection without a token and two same-origin form submissions with tokens from the rendered pages; the missing logout hint keeps the RP session active and returns the unavailable page.
- `PARALLEL_WORKERS=1 bin/rails test test/controllers/warp/org/sign/outs_controller_test.rb test/controllers/warp/app/sign/outs_controller_test.rb`: 14 runs, 136 assertions, 0 failures, 0 errors, 0 skips.
- The test supplies the Origin header itself. Actual browser navigation and cross-site retry were not checked. A first test run errored because the test attempted to call `fetch` on a Nokogiri element; its token extraction was corrected. No full-suite run was performed.
