# OIDC logout confirmation referrer policy

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting the code and tests.

With the configured local test environment, `PARALLEL_WORKERS=1 bin/rails test test/integration/oidc_current_device_logout_test.rb -n '/logout_confirmation_posts_to_its_separate_confirmation_endpoint|invalid_hint_preserves_the_protocol_error_in_JSON/'` passed: 4 runs, 38 assertions, 0 failures and 0 errors. The APP and ORG confirmation cases assert `strict-origin` for initial and repeated confirmation GETs, and the invalid-hint JSON cases assert `no-referrer`.

The current `SignOidcLogout` marks the confirmation render, and `SignOutNotice` selects `strict-origin` for that marked response. This is an HTTP integration check, not a browser-origin or full logout acceptance test. No application code was changed in this check.
