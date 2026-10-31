# Credential registration form referrer policy

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including the affected controllers and integration tests; these results apply to that worktree.

- The APP TOTP registration-start test passed before the new assertion (1 run, 35 assertions). Adding the expected `strict-origin` header assertion reproduced the existing `no-referrer` response (1 run, 1 failure).
- The Passkey registration-start action and APP TOTP registration-start action now set `Referrer-Policy: strict-origin` on their form responses. Their common header setup and POST actions remain otherwise unchanged.
- `PARALLEL_WORKERS=1 bin/rails test test/integration/app_passkey_secret_session_step_up_test.rb` passed: 3 runs, 56 assertions. It checks the APP TOTP and Passkey form headers and their existing POST flows.
- `PARALLEL_WORKERS=1 bin/rails test test/integration/org_step_up_verification_enforcer_test.rb:218` passed after adding the ORG Passkey header assertion: 1 run, 21 assertions.

These tests use the Rails integration client; actual browser behavior, cross-site and missing-token requests for these particular forms, and complete WU-A12 acceptance were not verified here.
