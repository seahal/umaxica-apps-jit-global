# Historical A02-13: retired Base paths over HTTP

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including routes and tests; this result applies to that worktree.

The new request test checks APP and ORG Base hosts for GET `/oauth/user_info`, `/auth/acme`, `/auth/acme/callback`, `/oidc/authorization`, and `/sign/callback`. Each returned 404 without a Location header. `PARALLEL_WORKERS=1 bin/rails test test/integration/routes/base_authority_route_contract_test.rb -n '/retired_Base_authority_and_RP_paths/'` passed: 1 run, 20 assertions.

The earlier route-recognition cases are recorded in `evidence/2026-10-31-wux2-base-op-route-scope-V7K2.md`. This request test does not establish the complete retained exception list, non-GET methods, or deployed routing; historical A02-13 remains partial.
