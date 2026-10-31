# Historical A02-13: Base binding confirmation POST route

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including routes and tests; the result applies to that worktree.

The retained-route test now explicitly checks that Base APP and ORG binding confirmation POST paths resolve to their surface-local `create` actions. Together with its earlier JWKS, callback and confirmation GET checks, `PARALLEL_WORKERS=1 bin/rails test test/integration/routes/base_authority_route_contract_test.rb -n '/retain_their_own_JWKS/'` passed: 1 run, 12 assertions.

This is route recognition, not a CSRF or HTTP completion test. Host-constrained callback/confirmation behavior and the complete retained exception list remain unverified.
