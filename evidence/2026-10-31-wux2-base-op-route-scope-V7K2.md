# Historical A02-13: retired Base routes

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including route files and tests; this result applies to that worktree.

`PARALLEL_WORKERS=1 bin/rails test test/integration/routes/base_authority_route_contract_test.rb test/integration/oidc_rp_browser_flow_test.rb -n '/(base_authority_retired_routes_do_not_resolve|legacy_RP_authorize_and_callback_paths_are_unroutable)/'` passed: 2 runs, 7 assertions. These route-recognition tests cover the named retired APP Base authority paths and the legacy APP/ORG RP authorization and callback paths.

The current Base route test lists APP/ORG JWKS and RP callback routes; `config/routes/base.rb` declares APP/ORG binding-confirmation GET and POST. This source inventory does not establish an exhaustive exception list or host-constrained HTTP responses, and the existing test comments warn that route recognition does not enforce all host constraints. A02-13 remains partial.
