# Visa OIDC logout confirmation referrer policy

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checked implementation and tests.
- OIDC logout now marks the response when rendering an active confirmation form; the shared sign-out headers use `strict-origin` for that response. Other `show` responses, including protocol errors, retain `no-referrer`.
- Focused APP/ORG initial and repeated confirmation and invalid-hint JSON cases passed: 4 runs, 38 assertions. With `PARALLEL_WORKERS=1`, the full current-device logout integration file and both CSRF invariant files passed: 63 runs, 661 assertions, no failures or errors.
- RuboCop on both changed concerns and the integration test passed; `git diff --check` passed. The check did not use a real browser or exercise every RP/OP deployment; it does not complete WU-A8 or WU-A12.
