# Recent targeted regression checks

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including the affected routes, refresh code and tests; the results apply to that worktree.

`git diff --check` passed for the recently modified root instruction and the four listed test files. The following focused run passed: 8 runs, 86 assertions, 0 failures, 0 errors, 0 skips.

```sh
PARALLEL_WORKERS=1 bin/rails test test/integration/routes/base_authority_route_contract_test.rb test/services/oidc/token_exchange_service_test.rb test/services/oidc_refresh_token_issuer_surface_test.rb test/security/invariants/base_org_translation_namespace_invariant_test.rb -n '/(retired_Base_authority_and_RP_paths|retain_their_own_JWKS|D-25.*(reuse|unknown)|unknown_staff_refresh|replaying_a_staff_refresh|Base_(com|org)_controllers)/'
```

The selected cases cover the recent old/retained Base route checks, APP and ORG refresh-scope cases and Base COM/ORG translation guards. They do not replace a full suite or prove the remaining implementation requirements.
