# Historical A10-2: ORG sibling grant

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including the refresh issuer and test; the results apply to that worktree.

Before the additional assertions, the focused ORG replay test passed (1 run, 10 assertions). It now also creates a separate Warp ORG grant on the same Root, then verifies that immediate-predecessor replay revokes the Core grant while leaving the Root active and the sibling unrevoked and able to rotate. `PARALLEL_WORKERS=1 bin/rails test test/services/oidc_refresh_token_issuer_surface_test.rb` passed: 4 runs, 29 assertions.

This is a local issuer-level check, not an HTTP or deployed test. Older predecessor replay, other sibling clients and the ORG unknown-token case remain unverified.
