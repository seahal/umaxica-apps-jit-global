# Targeted security invariants

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes, including the implementation under test.
- `PARALLEL_WORKERS=1 bin/rails test test/security/invariants/lifecycle_direct_state_write_invariant_test.rb test/security/invariants/csrf_verification_strategy_invariant_test.rb test/unit/security/standard_csrf_invariant_test.rb test/unit/security/identity_authority_inversion_guard_test.rb test/unit/security/webauthn_invariants_test.rb` produced 24 runs, 117 assertions, 1 failure, no errors.
- The failure was `IdentityAuthorityInversionGuardTest#test_route_sources_use_noun_lifecycle_resources_for_edge_and_preference_routes`, which is present in the baseline failing-test list. This check did not establish the cause or whether the same assertion failed in the baseline.
