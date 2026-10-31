# Historical A10-3: unknown refresh grant identifier

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including the refresh issuer and tests; the results apply to that worktree.

The APP and ORG unknown-refresh cases now also construct a syntactically parseable refresh token with a generated public ID confirmed absent from that realm's grant table. The issuer refuses the token. The tests continue to check the existing Core and sibling Warp grant remain unrevoked and their valid refresh credentials rotate.

`PARALLEL_WORKERS=1 bin/rails test test/services/oidc/token_exchange_service_test.rb test/services/oidc_refresh_token_issuer_surface_test.rb -n '/(unknown_verifier|unknown_staff_refresh)/'` passed: 2 runs, 26 assertions. The unknown-ID refusal is checked at the issuer, not through HTTP; other clients and deployed environments remain unverified.
