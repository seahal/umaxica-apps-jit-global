# APP signup page admission tests

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had uncommitted changes affecting application code and tests.

Before the edit, `PARALLEL_WORKERS=1 bin/rails test test/controllers/auth/app/sign_ups_controller_test.rb` reported 13 runs, 32 assertions and 9 failures. The affected tests used an obsolete multi-form relay and expected an Auth page before the current confirmed Admission flow had completed.

The nine tests now issue the existing OIDC transaction and Admission, follow the two current redirects, confirm the binding using its existing production API, and enter Auth with navigation headers. Their page-content assertions remain. After the edit, the whole file passed twice (13 runs, 85 assertions each). The final subsequent edit changed only formatting to satisfy RuboCop; RuboCop and `git diff --check` then passed. The test confirms the binding directly rather than completing the Base browser confirmation, so it does not establish that end-to-end boundary or complete WU-A1. No production code changed.

The temporary raw test logs were removed after recording the results.
