# ORG Secret bootstrap session checks

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- `PARALLEL_WORKERS=1 bin/rails test test/services/staff_secret_credentials/create_test.rb`: 9 runs, 35 assertions, no failures or errors. New cases verify that an eligible operator with a current session can bootstrap a Secret and that the same operation refuses a revoked device without creating a Secret or Chronicle event.
- RuboCop passed for the changed test file.
- These tests use transactional fixtures. Concurrent revocation, supersession during bootstrap and cross-database commit failures were not independently tested.
