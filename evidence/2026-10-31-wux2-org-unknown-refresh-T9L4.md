# Historical A10-3: ORG unknown refresh credentials

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including the refresh issuer and test; the result applies to that worktree.

The ORG issuer test now submits a forged verifier for a Core grant and a malformed token, checks that Core and a separate Warp grant remain unrevoked and that the Root is active, then rotates each valid grant credential. `PARALLEL_WORKERS=1 bin/rails test test/services/oidc_refresh_token_issuer_surface_test.rb` passed: 5 runs, 41 assertions.

This is local issuer-level coverage of two invalid inputs and two sibling grants. It does not exercise an HTTP endpoint, deployed services, or every other client and invalid token form.
