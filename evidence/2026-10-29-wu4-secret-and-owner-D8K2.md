# WU-4 secret credential and owner policy cleanup

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Extensive uncommitted worktree changes affected these results.
- Removed the deleted corporate secret-credential creator branch from the shared settings concern; unsupported surfaces retain the existing explicit error. Removed obsolete Visitor owner branches from `ApplicationPolicy`.
- `PARALLEL_WORKERS=1 bin/rails test test/services/staff_secret_credentials/create_test.rb test/integration/sign/org/credential_removal_constraints_test.rb`: 9 runs, 33 assertions, no failures, errors or skips. These exercise org credential service and removal constraints, not the entire settings registration HTTP flow.
- `PARALLEL_WORKERS=1 bin/rails test test/policies/application_policy_test.rb`: 10 runs, 11 assertions, no failures, errors or skips.
- `PARALLEL_WORKERS=1 bin/rails test test/security/invariants/auth_base_authority_boundary_test.rb test/security/invariants/controller_lifecycle_order_invariant_test.rb test/unit/security/authentication_mode_inventory_test.rb`: 14 runs, 81 assertions, no failures, errors or skips.
- No full-suite rerun was performed after these changes. Rails test database preparation was used; no production persistence operation or external write was performed.
