# Sign-out parent-child repair

Date: 2026-10-14 UTC  
Commit: `aa92265b7e63bf874fddd0aa8f278d5ed19de6b5`  
Branch: `feature`  
Worktree: extensively dirty before and after the check; the two files listed below were part of the uncommitted implementation.

The standard Rails test configuration was used. `POSTGRESQL_ISOLATED_TEST_RUN_ID` was unset and no database reset, isolated database, migration, cleanup or guard bypass was performed.

## Change

`AuthenticationLogoutCurrentSession#revoke_device_session!` no longer returns before inspecting the parent Device Session when the supplied root token is already revoked. A previously revoked parent can therefore still sweep every unrevoked RP Session row under its current root while preserving the existing writer transaction and lock order. The recent-completed-flow shortcut now also checks the writer for remaining unrevoked RP rows; an old completed flow with a stale child is repaired by the same public service path instead of being reported as an idempotent success. These changes close reachable partial-state gaps in REQ-003 without reviving the parent or touching another Device Session.

## TDD evidence

The new regression case was first run before the implementation change:

```text
env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 \
  bin/rails test test/controllers/concerns/authentication/logout_current_session_test.rb
```

Result: 34 runs, 122 assertions, 1 failure, 0 errors, 0 skips. The failing case left an unrevoked RP Session after its parent token had already been revoked.

After removing the early return, the same file passed with 34 runs, 123 assertions, 0 failures, 0 errors and 0 skips. A second red case then reproduced a recent completed flow with an unrevoked child (35 runs, 129 assertions, 1 failure); after the writer-side residual-child check, the file passed with 35 runs, 129 assertions, 0 failures, 0 errors and 0 skips.

The broader sign-out and RP authority selection passed:

```text
env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 \
  bin/rails test \
  test/controllers/concerns/authentication/logout_current_session_test.rb \
  test/operations/rp_session_revoker_test.rb \
  test/services/oidc_rp_session_logout_test.rb \
  test/integration/identity_session_revocation_test.rb \
  test/controllers/base/app/oidc/logouts_controller_test.rb \
  test/services/oidc/end_session_request_test.rb \
  test/integration/oidc_rp_authority_first_logout_test.rb \
  test/controllers/tech/org/sign/out/completions_controller_test.rb \
  test/integration/routes/tech_route_contract_test.rb
```

Result before the second residual-child check: 120 runs, 764 assertions, 0 failures, 0 errors, 0 skips. After the second check, the same broad selection was rerun and passed 121 runs, 770 assertions, 0 failures, 0 errors and 0 skips.

`bin/rubocop app/controllers/concerns/authentication_logout_current_session.rb test/controllers/concerns/authentication/logout_current_session_test.rb` reported no offenses. Both files returned `Syntax OK` from `ruby -c`, and scoped `git diff --check` passed.

The full Rails suite was not rerun for this local repair. Its latest recorded result remains non-clean because the standard-database run cannot satisfy the committed Avatar worker-receipt gate; that limitation is recorded in the existing Step 20 evidence.
