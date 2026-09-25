# Full Rails suite regression repair

- Date: 2026-09-25
- HEAD: `47312b92081a6a88a8ec1d27d3786d1a10063ce2`
- Worktree: 105 modified entries on top of HEAD, including the changes below; they affect every
  result in this record. Other post-commit changes (RuboCop auto-correct formatting) were present
  and are not attributable to this work.

## Starting point

`RUBY_DEBUG_ENABLE=0 bin/rails test` against `2b027d5b3` plus the dirty worktree reported 11,695 runs,
2 failures, 101 errors, 8 skips (see `2026-09-25-postgresql-test-host-recovery-P3K9.md`).

## Root causes and changes

| Symptom | Cause | Change |
| --- | --- | --- |
| 97 errors `Avatar owner actor must be active` | `AvatarOwnerMembershipLockService` required `status_id == ACTIVE`; sign-up completes principals as `VERIFIED_WITH_SIGN_UP` and no path sets `ACTIVE` | Activity now uses `login_allowed? && access_enabled?` (withdrawn, suspended, RESERVED, and admin-locked principals stay denied). Tests added for VERIFIED_WITH_SIGN_UP allowed and RESERVED denied. The resolver's now-unused `actor_status` config key was left in place because the edit was blocked by the auto-mode classifier. |
| Sign-up for a login-blocked principal raised instead of returning 422 | Graph provisioning ran before the sign-in handoff | `SignUpSequenceControllerSupport` provisions only principals that can sign in; others fail through the existing handoff failure path. |
| 4 concurrency test errors | Test used non-connection-owning abstract classes for `connected_to`, recorded a non-writing backend PID, and polled with an identical statement answered from the Active Record query cache | Uses `AppZenithRecord`/`OrgZenithRecord`, captures the writing-role PID, detects the wait from `pg_locks`, and polls `uncached`. Org cleanup also deletes the bootstrap `OperatorAccount` it previously leaked. |
| 2 `IdentityGraphRepairTest` failures | Fixture RESERVED client counted as a repair failure | Repair skips principals that cannot sign in and reports `ineligible=N`; test added. |
| 6 skipped `BaseAuthAdmissionCoordinatorTest` | Skip keyed on production-only `AUTH_STATE_REDIS_URL`, always unset in nonprod | Skip removed; tests run against Valkey `valkey-kvs` db 6; stub assertion fixed to the production digest function. |
| `Set#merge!` / `BaseSelectorAuthority.select!` NoMethodError | `rubocop -a` `Lint/Void` rewrites void `merge`/`select` to bang forms | `locked_ids |= new_ids`; test asserts the `select` result. |
| WithdrawalGateTest errors | Graph bootstrapped after withdrawal had started | Setup bootstraps before withdrawal begins. |

Six orphan `OperatorAccount` rows (ids 212–217) created by this session's failing concurrency runs
were deleted from `test_org_zenith_db`.

## Verification

| Command | Result |
| --- | --- |
| `RUBY_DEBUG_ENABLE=0 PARALLEL_WORKERS=1 bin/rails test` | 11,698 runs, 74,934 assertions, 0 failures, 0 errors, 2 skips; 657.9 s. |
| `RUBY_DEBUG_ENABLE=0 bin/rails test` (parallel, before the `Lint/Void` fix) | 11,698 runs, 3 failures, 9 errors. Remaining non-`Lint/Void` errors are leaked rows in the persistent parallel worker clone databases (`test_org_zenith_db_N`, replicas) from earlier failing concurrency runs. |
| Concurrency test file, 3 consecutive runs | 17 runs, 0 failures/errors each. |
| `bundle exec rubocop` on the changed files | No offenses. |

## Parallel clone rebuild

- The user ran `scratchpad/drop.rb`, which dropped 99 app/org Zenith and Avatar clone databases,
  including the three base replicas (`test_{app_zenith,avatar,org_zenith}_replica_db`) because the
  script's pattern also matched them. The next `bin/rails test` stopped at the test database
  manifest check, after Rails test-schema maintenance had recreated the base test databases empty
  at 13:14:43 UTC.
- Recovery: the three base replicas were recreated from their primaries with `CREATE DATABASE ...
  TEMPLATE`, then `RAILS_ENV=test bin/rails db:migrate` applied the 230 pending migrations (exit 0).
  No `db/*_structure.sql` file changed.
- `RUBY_DEBUG_ENABLE=0 bin/rails test` (parallel): 11,698 runs, 74,934 assertions, 0 failures,
  0 errors, 2 skips; 239.5 s.
- The unused `actor_status: ClientStatus` key was removed from `AvatarPermissionResolver::SURFACES`;
  removing `actor_status: OperatorStatus` was blocked by the auto-mode classifier and remains.

## Open

- Items requiring decisions or external access (Avatar image delivery contract, Emergency Credential
  acknowledgement, real Turnstile, populated-data cutover, production work) were not attempted.
