# ORG lifecycle stop delivery after actor commit

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had substantial uncommitted changes affecting the implementation and tests.
- Before the change, two non-transactional suspension cases observed an OP receipt while the enclosing actor transaction was still open: 2 runs, 6 assertions, 2 failures.
- The lifecycle executor now registers its existing OP stop deliveries on the org_zenith transaction's commit. Non-transactional cases cover withdraw, suspend and terminate, each with outer commit/rollback and ordinary/savepoint nesting; rollback leaves no OP receipt or root revocation.
- `PARALLEL_WORKERS=1 bin/rails test test/concurrency/org_operator_lifecycle_outer_transaction_test.rb test/services/org_operator_lifecycle_execute_test.rb test/concurrency/operator_availability_serialization_test.rb test/operations/op_identity_event_invalidator_test.rb test/jobs/op_identity_event_sweep_job_test.rb`: 52 runs, 315 assertions, no failures, errors or skips. Scoped RuboCop passed.
- The operator lifecycle and withdrawal diagrams and transition inventory were updated. An old code comment claiming separate actor and Entra databases was corrected after checking both inherit the consolidated org_zenith connection owner.
- Indeterminate commit, process death, actual remote RP delivery, other stop callers and the full suite were not verified.
