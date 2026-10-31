# Base Step-Up cancellation referrer policy

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting this result.
- The app cancellation GET initially returned `no-referrer` instead of `strict-origin` (1 run, 3 assertions, 1 failure). The successful cancellation continuation now sends `strict-origin` in its response and HTML meta tag.
- App cancellation GET/POST, org cancellation POST, app completion and missing-CSRF/cross-site refusal passed together: 4 runs, 46 assertions, 0 failures, 0 errors, 0 skips. The GET check confirms it does not cancel the transaction.
- RuboCop passed on the two changed concerns and scoped `git diff --check` passed. Org cancellation GET, deployed HTTPS browser behavior and other RP continuations were not verified in this slice.
