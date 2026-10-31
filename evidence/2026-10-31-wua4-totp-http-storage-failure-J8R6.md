# TOTP rename HTTP storage failure

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checked implementation and tests.
- Added an authenticated, target-bound TOTP rename request that raises a database connection error at the Zenith credential update. The actual committer and controller return HTTP 503, the title remains unchanged and the Step-Up timestamp is cleared. No external service was contacted.
- The focused test passed: 1 run, 4 assertions. With `PARALLEL_WORKERS=1`, the integration, name committer and independent commit-order files passed together: 46 runs, 209 assertions, no failures or errors.
- RuboCop and `git diff --check` passed for the changed integration test. This check does not add the required same-Zenith audit record or verify every XDB-04 race.
