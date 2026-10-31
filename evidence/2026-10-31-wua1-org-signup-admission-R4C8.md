# ORG signup information page admission tests

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had uncommitted changes affecting application code and tests.

Before the edit, `PARALLEL_WORKERS=1 bin/rails test test/controllers/auth/org/sign_ups_controller_test.rb` reported 10 runs, 22 assertions and 5 failures. The five page tests used an obsolete multi-form Admission relay. They now issue the existing OIDC transaction and Admission, follow the current redirects, confirm the binding through its production API, and enter Auth with navigation headers. The existing page assertions and the legacy-flag test's scope were retained; no application code or invitation-provisioning behavior was changed.

The focused first case passed (1 run, 12 assertions); the complete file then passed twice (10 runs, 51 assertions each). RuboCop and `git diff --check` passed after removing unused old setup methods and an extra blank line. These tests confirm the binding directly, not through the full Base browser journey, and do not establish ORG invitation provisioning or WU-A1 completion. Temporary raw test logs were removed.
