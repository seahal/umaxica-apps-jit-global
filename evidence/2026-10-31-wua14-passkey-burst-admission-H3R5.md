# APP Passkey burst limiter admission

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checked implementation and tests.
- The targeted burst test initially errored while looking for an obsolete admission form. Updated that test to use the current confirmed GET admission and assert the first five requests are neither bad requests nor rate limited before the sixth returns 429.
- With `PARALLEL_WORKERS=1`, ran the burst test and the related authentication rate-limit test together: 2 runs, 26 assertions, no failures or errors.
- RuboCop on the edited test file and `git diff --check` passed. Other cases in the burst test file and a full suite were not run in this check.
