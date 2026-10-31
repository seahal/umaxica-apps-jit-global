# WU-7 region selection test

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting the result.
- The cross-surface region-selection test failed before the change because the com preference cookie is Secure but the test used HTTP. It now uses HTTPS and reads its required host with one-argument `ENV.fetch`.
- The test passed across app, com and org: 1 run, 21 assertions, zero failures, errors or skips. Full-suite comparison was not re-run in this slice.
