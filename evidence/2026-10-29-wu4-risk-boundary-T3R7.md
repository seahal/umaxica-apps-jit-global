# WU-4 risk actor boundary

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Extensive uncommitted worktree changes, including the edits below, affected the results.
- Removed visitor authentication dispatch from `SignRiskEngine` and `SignRiskEmitter`. Supplying the retired `visitor_id` is explicitly rejected; historical VisitorOccurrence data is retained. Client and operator occurrence paths remain covered, including HMAC context and refusal without writes.
- `PARALLEL_WORKERS=1 bin/rails test test/services/sign/risk/engine_comprehensive_test.rb test/services/sign/risk/emitter_test.rb test/services/surface_credential_mapping_and_key_decoding_test.rb`: 16 runs, 59 assertions, 0 failures, 0 errors, 0 skips.
- `PARALLEL_WORKERS=1 bin/rails test test/security/invariants/actor_context_invariant_test.rb test/unit/security/authentication_mode_inventory_test.rb`: 16 runs, 39 assertions, 1 failure, 0 errors, 0 skips. `ActorContextInvariantTest#test_Actor_read_paths_stay_shallow_except_configuration_namespaces` reports `Actor.authn.amr.first` in the app and org Visa authorization controllers. The same failure identifier appears in `plans/2026-10-28-baseline-failing-tests.md`; its cause was not investigated in this change.
- No full-suite run was performed after this change. Test database preparation was used; no production persistence operation or external write was performed.
