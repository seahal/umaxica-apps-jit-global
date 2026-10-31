# Local Jump return and sign-in tests

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes affecting this result.
- Ran `PARALLEL_WORKERS=1 bin/rails test` with `test/values/jump_rt_return_url_value_test.rb`, `test/integration/edit_org_jump_rt_sign_in_test.rb`, `test/integration/jump_rt_return_verification_test.rb`, `test/integration/palm_jump_sign_entry_test.rb`, `test/integration/jump_rt_issuer_jwks_authority_test.rb`, and the receiver contract, return policy, return verifier, issuer and surface identity tests under `test/services/jump_rt/`: 269 runs, 1,411 assertions, no failures, errors or skips.
- These local tests do not establish that the separately inspected Jump registry and deployed revisions accept the Rails graph, or cover every RP end to end. WU-A11 remains incomplete.
