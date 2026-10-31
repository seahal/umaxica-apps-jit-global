# ORG Step-Up cancellation GET

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting this check.
- The existing ORG cancellation test passed before the added assertions (1 run, 7 assertions). Extended it to make the cancellation GET before its existing POST and assert a successful response with `strict-origin` in the response header and HTML meta tag, and that the transaction remains uncanceled. The existing subsequent POST asserts cancellation and no new Step-Up freshness.
- The extended ORG test passed (1 run, 13 assertions); running it with the corresponding APP cancellation case passed (2 runs, 32 assertions). RuboCop and scoped `git diff --check` passed for the edited file.
- This uses Rails integration requests; it does not verify actual browser Origin behavior, deployed HTTPS, all possible database writes during GET, or every non-Base continuation. The full-suite record `2026-10-31-two-full-suite-after-corrections-N5R8.md` predates this test change.
