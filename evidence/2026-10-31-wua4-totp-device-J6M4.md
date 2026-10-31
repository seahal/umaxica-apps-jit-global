# TOTP rename device session check

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes, including the implementation and tests.
- A revoked device with otherwise valid target-bound Step-Up could rename a TOTP credential before the fix. The revised writer denied the request without changing the title or consuming proof.
- `PARALLEL_WORKERS=1 bin/rails test test/operations/identity_totp_name_committer_test.rb` passed: 6 runs, 32 assertions, no failures or errors.
- A superseded-but-still-active token also succeeded before the current-token check. With the check, the full operation file passed with 7 runs and 36 assertions, no failures or errors.
