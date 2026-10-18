# Full verification gate after Group grant authorization slice

- Date: 2026-10-10
- Repository HEAD: `2a1644f73238839ed7ed513bd4681ea393a86682`
- Worktree: pre-existing staged, unstaged, and untracked changes were preserved; no reset, clean, stash, commit, push, or production operation was performed.
- Test fleet: disposable PostgreSQL databases described by `tmp/acceptance-isolated-20261010p8b-ip.json`, server `10.89.2.2`, run ID `20261010p8b`.
- Isolation setting: `PARALLEL_WORKERS=1` was retained because `Umaxica::TestEnvironment::DatabaseSafety` rejects an isolated run with another worker count. This is a harness safety requirement, not a claim that the application cannot run parallel tests.

## Rails

The complete explicit 42-batch Rails test inventory (`/tmp/umaxica-rails-batch-000.list` through `041.list`) was run against the p8b fleet after the Group slice. The batch output was independently aggregated from the individual logs and the recorded summary for batch 022.

- 14,966 runs
- 127,109 assertions
- 3 failures
- 0 errors
- 0 skips

All three failures are the pre-existing `DatabaseReconstructionAuthorityTest` checks for tracked empty `db/*structure.sql` dumps. They are not attributed to the Group authorization change. No other batch reported a failure or error.

Focused Group and adjacent checks after the slice:

```text
bin/rails test test/services/group_avatar_memberships_test.rb test/policies/group_avatar_membership_policy_test.rb test/services/avatar_access_grants_test.rb test/resolvers/avatar_permission_resolver_test.rb
24 runs, 83 assertions, 0 failures, 0 errors, 0 skips

bin/rails test test/services/group_avatar_membership_authorization_test.rb test/operations/avatar_ownership_transfers_concurrency_test.rb
17 runs, 52 assertions, 0 failures, 0 errors, 0 skips

bin/rails test test/security/invariants/flat_ruby_source_layout_invariant_test.rb test/security/invariants/umaxica_architecture_guard_test.rb test/security/invariants/lifecycle_direct_state_write_invariant_test.rb
12 runs, 24 assertions, 0 failures, 0 errors, 0 skips
```

## Vitest

```text
bun run test
99 test files passed; 1,140 tests passed.
```

The three structure-dump failures remain a Gate 4 issue until the tracked dumps are repaired by the authorized migration/database recovery work. The Group slice itself has no observed Rails or Vitest regression in this gate.
