# Secret management revocation ordering

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes, including the tested implementation.
- An OP failure injection observed the revoked timestamp before proof consumption in the previous order; the revised order left the credential and source audit unchanged on this failure.
- `PARALLEL_WORKERS=1 bin/rails test test/operations/client_secret_revocation_committer_test.rb` passed: 13 runs, 228 assertions, no failures or errors. Its source validation failure scenarios obtain fresh proof after each failed source write.
- This fixture-based test does not independently establish production commit durability. Dependency failure HTTP behavior is not yet verified.
- After adding dependency handling, `PARALLEL_WORKERS=1 bin/rails test test/integration/step_up_authentication_test.rb -n '/Secret revocation/'` passed: 1 run, 8 assertions. It exercised the 503 mapping and a successful target-bound HTTP revocation.
