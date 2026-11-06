# WU-A6 owner read-screen Step-Up boundary

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.

The worktree already contained broad uncommitted changes, and this change also remains uncommitted;
no paths were staged.

## Finding and change

The ORG support owner API's `GET /api/v0/support/app/accounts/:ref/revocation-screen` called
`with_owner_step_up`, which locked the Operator Root before checking proof. A fixture-free HTTP
request reached that action on a read-only database role and raised `ActiveRecord::ReadOnlyError` at
the lock query. A source inventory found the same pattern on the IAM grant-screen GET at
`/api/v0/iam/grant-screen`.

The owner API now has a read-only Step-Up path that performs the same `StepUpResolver` check without
acquiring a row lock. Both read-screen GETs use it. Existing mutation actions continue using the
row-locked path.

## Verification

- The initial fixture-backed line run stopped before the test body while loading unrelated
  `Enterprise` / `EnterpriseUnit` fixtures (`ActiveRecord::InvalidForeignKey`); it did not verify
  the action.
- The first fixture-free request reproduced the read-only lock error above.
- An intermediate test-data attempt created IAM bootstrap-only capabilities as delegated grants and
  failed model validation before making a request. After matching the bootstrap origin contract, a
  request-ordering attempt changed the same root to Normal before finishing both Standby cases and
  received 401; the test now completes all Standby requests before changing context.
- After both read-screen actions used the read-only Step-Up path,
  `test/integration/wua6_standby_support_revocation_screen_test.rb` passed: 1 run, 18 assertions, no
  failures, errors or skips. Standby with the required grants received `403 step_up_required`
  without a session count or grantable-capability list; Normal with fresh matching Step-Up received
  both screen responses. A final combined run of this test and the existing Avatar mutation test
  passed: 2 runs, 27 assertions, no failures, errors or skips.
- `test/controllers/base/org/avatar_ownership_transfers_controller_test.rb:354` passed: 1 run, 9
  assertions, no failures, errors or skips. This exercised the existing row-locked owner mutation
  path.
- The first scoped RuboCop run found a trailing-comma style offense in the new test array; after
  correcting it, scoped RuboCop inspected the concern, both controllers and new integration test
  with no offenses. Ruby syntax checks for the changed Ruby files and `git diff --check` passed.

At the recorded verification, `git status --porcelain=v1 --untracked-files=all` reported 543 changed
tracked paths, 264 untracked paths and 0 staged paths. This includes broad prior uncommitted work
and this evidence file. No full suite was run. The two owner read-screen boundaries and one existing
mutation path were verified; the policy-derived AC-41 matrix and WU-A6 remain open.
