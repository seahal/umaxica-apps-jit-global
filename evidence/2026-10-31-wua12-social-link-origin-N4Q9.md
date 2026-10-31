# Social link completion referrer policy

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting this result.
- The Google social-link callback returned `no-referrer` on a same-origin POST continuation; the targeted HTTP test initially failed its `strict-origin` assertion (1 run, 5 assertions, 1 failure).
- The staging response and its HTML meta tag now use `strict-origin`; the link POST retains its existing CSRF and device checks. Google callback/POST with CSRF refusal and Apple link tests passed: 2 runs, 38 assertions, 0 failures, 0 errors, 0 skips. Scoped `git diff --check` passed.
- A separate local Chromium probe is documented in `evidence/2026-10-31-wua12-completion-origin-Q6F3.md`. Full deployed HTTPS browser and all non-Base RP continuation checks remain unverified.
