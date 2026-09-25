# PostgreSQL test host recovery check

- Date: 2026-09-25
- HEAD: `2b027d5b38989d3068e4620262bfa6c6fde8df41`
- Worktree: 686 pre-existing uncommitted status entries; they affect the test results below. No
  application, configuration, container, or database change was made by this check.

## Environment

Earlier records (B5C6, H7J4) observed that hostname `primary` did not resolve. In this session it
resolved through Podman DNS without any intervention:

| Command | Result |
| --- | --- |
| `getent hosts primary` | `10.89.0.3 primary.dns.podman` |
| `getent hosts valkey-kvs` | `10.89.0.5 valkey-kvs.dns.podman` |
| `pg_isready -h primary -p 5432` | accepting connections |
| `bundle exec ruby -r ./lib/local_environment -e 'LocalEnvironment.load!; load "scripts/test-environment-check"'` | PostgreSQL 17.7 reachable (646 test databases); Valkey `rate_limit` and `auth_state` PONG, version 7.2.4 |

The earlier failure is therefore attributed to the database container not running at that time; the
exact cause was not observed.

## Previously blocked regressions

`RUBY_DEBUG_ENABLE=0 PARALLEL_WORKERS=1 bin/rails test test/controllers/base/app/avatars_controller_test.rb test/operations/avatar_ownership_transfers_concurrency_test.rb`

Result: 17 runs, 91 assertions, 0 failures, **4 errors**, 0 skips. All four errors are in
`AvatarOwnershipTransfersConcurrencyTest` (group creation racing owner-membership revocation and
app/org principal deactivation) and raise
`NotImplementedError: calling connected_to is only allowed on the abstract class that established the connection`
from the test's own `connected_to` calls on a non-abstract class (for example line 300). The
`AvatarOwnerMembershipLockService` concurrency guarantee therefore remains unverified.

## Full Rails suite

`RUBY_DEBUG_ENABLE=0 bin/rails test` against the same HEAD and 686-entry dirty worktree finished in
251.6 s: 11,695 runs, 74,422 assertions, **2 failures, 101 errors**, 8 skips; exit 1.

- 97 errors: `AvatarOwnerMembershipLockService::AuthorizationDenied: Avatar owner actor must be active`
  (`app/services/avatar_owner_membership_lock_service.rb:58`), reached from
  `BaseSelectorBootstrapAuthority#provision_avatar!` → `AvatarProvisioning::Create#call`. Affected
  classes are mainly Base app identity email/telephone registration, withdrawal, social/Apple sign-in,
  and sign-up flows. The Avatar provisioning path now requires an ACTIVE principal where these flows
  run before activation; the intended contract was not resolved in this check.
- 4 errors: `AvatarOwnershipTransfersConcurrencyTest` (three `connected_to` NotImplementedError, one
  `Timeout::Error` waiting for the principal row lock).
- 2 failures: `IdentityGraphRepairTest` output expectations (`failed=0/1` versus the emitted
  `checked=8/9 missing=8/9` summary).
