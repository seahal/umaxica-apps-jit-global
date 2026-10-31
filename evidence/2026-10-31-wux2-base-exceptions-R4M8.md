# Historical A02-13: retained Base route exceptions

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including Base routes and tests; this result applies to that worktree.

A new route test explicitly lists the APP and ORG Base JWKS, RP callback, and binding-confirmation GET exceptions. Rails route recognition found the expected controller for each, and real integration GET requests to both JWKS endpoints returned success with `application/json`. `PARALLEL_WORKERS=1 bin/rails test test/integration/routes/base_authority_route_contract_test.rb -n '/retain_their_own_JWKS/'` passed: 1 run, 10 assertions.

Route recognition does not establish all host constraints. This check does not exercise callback or confirmation HTTP completion, the POST confirmation route, an exhaustive list of RP endpoints, or deployed behavior. A02-13 remains partial; retired-path HTTP evidence is in `evidence/2026-10-31-wux2-base-old-http-X7C5.md`.
