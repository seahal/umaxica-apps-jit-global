# Auth Step-Up cancellation tests

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes affecting the checks.
- The focused Auth APP/ORG cancellation file initially had 5 runs, 11 assertions and 3 errors: its tests attempted to extract a token from an obsolete admission form after a GET that now redirects.
- Updated the three affected tests to use the existing attached and confirmed binding with HTTPS GET admission and assert the redirect before cancellation. The original APP/ORG fixed Base destination, transaction and freshness assertions, as well as the hostile return target and Referer checks, remain.
- The full file passed after the edit: 5 runs, 107 assertions, no failures, errors or skips. RuboCop and scoped `git diff --check` passed. These are Rails integration tests with the default test-mode forgery setting; this run does not establish CSRF enforcement or actual browser Origin behavior.
- The full-suite record `2026-10-31-two-full-suite-after-corrections-N5R8.md` predates this test change. The separate Auth admission navigation-metadata gap remains open.
