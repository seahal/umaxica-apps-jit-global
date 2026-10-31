# Identity-stop sweep unexpected-event isolation

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Substantial uncommitted worktree changes affected the implementation and tests.
- A test placed an unsupported APP event before valid APP and ORG events. Before the change the job raised before applying the later APP event: 1 run, 3 assertions, 1 failure.
- Unexpected per-event errors are now reported as unhandled, the event remains without a receipt, later events and realms are processed, and the first unexpected error is raised after the scan. The retained error list is bounded to one; each failure is still reported. Existing Active Record dependency-error reporting remains handled as before.
- `PARALLEL_WORKERS=1 bin/rails test test/jobs/op_identity_event_sweep_job_test.rb test/operations/op_identity_event_invalidator_test.rb test/services/administrative_access_lock_test.rb test/services/oidc_access_token_authenticator_test.rb`: 35 runs, 193 assertions, no failures, errors or skips. Scoped RuboCop passed; after bounding retained errors, the sweep and invalidator files passed again: 14 runs, 65 assertions.
- The case uses transactional fixtures and a synthetic unsupported reason. Actual scheduler behavior, concurrent sweep workers, other malformed events, production DB failures and the full suite were not verified.
