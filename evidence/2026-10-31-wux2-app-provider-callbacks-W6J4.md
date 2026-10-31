# Historical A02-15: APP Google and Apple authorization callbacks

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including OmniAuth configuration and the integration test; the result applies to that worktree.

The APP social-start tests now require redirects to the real Google or Apple authorization host, rather than also accepting an OmniAuth failure redirect. Each checks that `redirect_uri` uses HTTPS, the configured public Auth APP host and the matching provider callback path. The tests explicitly disable OmniAuth test mode for each case and restore its previous value. `PARALLEL_WORKERS=1 bin/rails test test/integration/app_social_login_works_test.rb` passed: 3 runs, 11 assertions. Redirects were inspected locally and not followed over the network.

ORG Entra authorization coverage is recorded in `evidence/2026-10-31-wux2-entra-authorize-callback-B9H3.md`. The historic pre-unit values and actual deployed provider registrations were not compared, so A02-15 remains partial.
