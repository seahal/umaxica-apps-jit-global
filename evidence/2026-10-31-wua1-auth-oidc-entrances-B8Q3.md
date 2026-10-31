# APP Auth OIDC entrance tests

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had uncommitted changes affecting application code and tests.

Before the change, `PARALLEL_WORKERS=1 bin/rails test test/controllers/auth/oidc_entrances_test.rb` had 4 runs, 10 assertions and 2 failures. The valid sign-in and sign-up tests used an obsolete Admission form relay.

Both tests now issue the existing OIDC transaction and Admission, follow the current redirects, confirm the binding through its production API, and enter Auth with navigation headers. Existing assertions for the admitted ceremony, parent transaction reference and absence of session challenge state remain. The sign-in case first passed alone (1 run, 8 assertions); the complete file then passed twice (4 runs, 22 assertions). RuboCop and `git diff --check` passed. The test confirms the binding directly, so it does not establish the full Base browser confirmation path. No application code changed and the full suite was not rerun.

Temporary raw test logs were removed after recording the results.
