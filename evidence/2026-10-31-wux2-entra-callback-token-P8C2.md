# Historical A02-15: ORG Entra callback in token request

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including the Entra strategy and its contract test; the result applies to that worktree.

The Entra strategy configures its redirect URI through `ExternalAuthenticationEntraRedirectUri`, which combines the configured Auth staff origin and `/social/entra/callback`. `PARALLEL_WORKERS=1 bin/rails test test/contracts/omniauth_entra_token_request_contract_test.rb:25` passed: 1 run, 8 assertions. Its stubbed network boundary captures the token request and checks the redirect URI; no provider network call was made.

This is a token request, not the provider authorization redirect requested by historical A02-15. Google/Apple request redirects, historical URI equivalence, deployed host configuration and the full case remain unverified.
