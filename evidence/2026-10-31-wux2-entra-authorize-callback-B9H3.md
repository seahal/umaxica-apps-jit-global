# Historical A02-15: ORG Entra authorization callback

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including the Entra strategy and test; the result applies to that worktree.

The existing real request-phase test now checks the returned Microsoft authorization URL's `redirect_uri` against the configured Auth staff host, HTTPS, and `/social/entra/callback`, as well as the shared redirect URI builder. `PARALLEL_WORKERS=1 bin/rails test test/controllers/auth/org/omniauth/omniauth_callbacks_controller_test.rb:67` passed: 1 run, 13 assertions. The provider redirect was inspected locally and not followed over the network.

The separate token-request check is recorded in `evidence/2026-10-31-wux2-entra-callback-token-P8C2.md`. Google/Apple authorization redirects, comparison with the historical pre-unit configuration, and deployed provider registrations remain unverified; A02-15 is partial.
