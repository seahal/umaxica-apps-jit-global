# Identity-stop concurrent delivery after first-worker rollback

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had substantial uncommitted changes affecting the implementation and tests.
- The existing independent-connection APP duplicate-delivery case was extended with a second ordering: the first worker raises an injected error after its receipt insert while another worker waits on PostgreSQL. After rollback, the waiting worker returns applied; one receipt and authority stop remain, and the test root and grant are revoked. The original commit-first case continues to check applied/duplicate.
- `PARALLEL_WORKERS=1 bin/rails test test/concurrency/op_authority_stop_concurrency_test.rb test/operations/op_identity_event_invalidator_test.rb test/jobs/op_identity_event_sweep_job_test.rb test/models/op_inbound_receipt_uniqueness_test.rb`: 36 runs, 175 assertions, no failures, errors or skips. Scoped RuboCop passed after formatting.
- The failure was injected at receipt insertion for APP. ORG, other commit-failure boundaries, actual remote logout delivery and the full suite were not verified.
