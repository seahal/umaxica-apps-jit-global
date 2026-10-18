# Avatar P10a Grant authority slice

- Repository: `/home/global/workspace`
- Branch: `feature`
- Code HEAD at execution: `a1ec83a7384a424c97671356268ec5c4ad8347d4`
- Worktree: pre-existing staged, unstaged and untracked changes were preserved; the code was not
  committed or pushed.

## Delivered behavior

`AvatarAccessGrants::IssueOperation` now resolves the concrete app `Client` or org `Operator`
named by `granted_by_actor_public_id` and executes under `AvatarOwnerMembershipLockService` with the
explicit `avatar.grant.manage` authority. The locked ownership period is rechecked against the
collective that was authorized before the concrete generation-bound Grant is inserted. A missing,
foreign or non-owner actor is rejected without inserting a Grant. Existing Grant resolution remains
bound to the concrete ownership generation and does not grant management authority.

## Checks

Focused command:

```text
RAILS_ENV=test PARALLEL_WORKERS=1 POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p3d2 POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p3d2-primary.json POSTGRESQL_TEST_PREPARE_DATABASES=<the 20 manifest database names> bundle exec rails test test/services/avatar_access_grants_test.rb test/resolvers/avatar_permission_resolver_test.rb test/policies/group_avatar_membership_policy_test.rb test/services/group_avatar_memberships_test.rb
```

Result: 25 runs, 85 assertions, 0 failures, 0 errors, 0 skips.

The targeted RuboCop command for the six changed implementation/test files completed with no
offenses.

The required post-slice full gates were also run against the same run-owned 20-database manifest:

- `bundle exec rails test` with `PARALLEL_WORKERS=4`: 15,062 runs, 127,719 assertions, 1 failure,
  0 errors, 0 skips. The only failure is the pre-existing `Security::AcmeRenameInventoryTest`
  finding the phrase `Apex-scoped` in the unrelated untracked
  `adr/preference-tld-sharing-and-jwt-lifecycle-reassessment.md`.
- `bun run test`: 99 files, 1,140 tests passed.

The known unrelated inventory failure remains open and was not weakened or edited as part of this
slice.
