# WU-5 convergence: post-removal suite results (run5) and the fix cycle

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; full uncommitted WU-3/4/5 worktree, nothing
  committed. Suite run5 was executed after the WU-5 removals with the rebuilt test databases
  (evidence/2026-10-29-wu5-test-db-rebuild-Q4X8.md).
- run5: `bin/rails test` — 16,071 runs, 130,560 assertions, 129 failures, 204 errors, 0 skips.
  Failing-identifier comparison against the WU-0 baseline
  (`plans/2026-10-28-baseline-failing-tests.md`): 267 identifiers, of which **5 were new**:

    - ArchitectureBaselineTest#test_baseline_does_not_list_resolved_files (company.rb listed after model deletion)
    - AuthorityOwnerPredeploymentBackfillOperationTest#test_applies_the_same_reviewed_contract_to_all_four_surface-local_resource_families
    - DatabasePasswordConfigTest#test_production_database_connections_require_the_shared_Neon_connection_settings
    - SocialLoginAdmissionTest#test_D-198 / #test_a_Social_start_without_a_redeemed_Auth_admission (2 failures sharing one cause)

  Base 719 of 981 baseline identifiers now pass; the remaining 262 are the standing baseline set.

## Fixes applied to the five

- `app/operations/authority_owner_direct_binding_backfill_operation.rb`: restored the retained
  `when Enterprise, Bureau then nil` arm of `resource_identity` (Bureau is an org resource; only the
  com-realm `Individual`/`Company` arms were removed). File passes `ruby -c`; the operation's own test
  now 9 runs/0 failures.
- `test/unit/database_password_config_test.rb`: updated the shared-Neon connection count contract from
  20/18 to 17/15 (three com writers removed) with the reason recorded at the assertion.
- `bin/rails architecture:baseline` run: `Umaxica/ExplicitMethodVisibility` now 2,468 offenses in
  1,079 files (company.rb dropped); ArchitectureBaselineTest 3 runs / 0 failures.
- SocialLoginAdmissionTest: the nil-`[]` errors came from the shell inheritance of the stale
  `POSTGRESQL_TEST_PREPARE_DATABASES` listing com databases, not a product change; `.env` and
  `.env.container.devcontainer` were regenerated from `config/ci.rb`'s fragment list and the file
  passes clean: 11 runs, 234 assertions, 0 failures, 0 errors.

## Not verified

- Run6 (full-suite rerun after the fixes) is in progress when this record was written; its
  comparison output lands in the session log, not in this record.
