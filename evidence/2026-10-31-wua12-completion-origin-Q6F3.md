# Base Step-Up completion referrer policy

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting this result.
- A local Chromium headless probe posted a form to the same loopback HTTP origin: `no-referrer` produced `Origin: null` and no Referer; `strict-origin` produced the loopback origin in both Origin and Referer, with no path or query. This isolated probe was not an end-to-end Rails or HTTPS browser test.
- A targeted app completion HTTP test initially found `no-referrer` instead of the required `strict-origin` (1 run, 4 assertions, 1 failure). The successful Base Step-Up completion page now sends the matching response header and HTML meta policy; other callers of the shared no-referrer header method were not changed.
- The app completion, app missing-CSRF/cross-site refusal, org completion and controller CSRF-protection tests passed together: 4 runs, 32 assertions, 0 failures, 0 errors, 0 skips. Scoped `git diff --check` passed.
- Actual browser navigation through deployed app/org surfaces, cancellation and non-Base continuations remain unverified; WU-A12 is incomplete.
