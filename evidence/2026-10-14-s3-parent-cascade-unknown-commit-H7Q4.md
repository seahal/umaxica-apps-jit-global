# S3 parent cascade and unknown commit slice

Recorded 2026-10-14 UTC against full Git HEAD `aa92265b7e63bf874fddd0aa8f278d5ed19de6b5` on
`feature`. The worktree had 1,012 status entries before this record; unrelated staged, unstaged
and untracked changes were preserved. The isolated-run ID was unset for every Rails command. Only
the standard Rails test databases were used; no migration, schema reset, isolated database,
production database or external service was used by this slice.

## TDD changes

- `AuthenticationLogoutCurrentSession` now encloses SignOutFlow creation, Device Session
  revocation, current-root/lineage revocation and every unrevoked RP row in one realm Ticket
  writer transaction. Device-session or SignOutFlow failures raise and roll back; the old
  token-only success fallback is gone.
- A lost writer response is checked through a fresh writer connection. A persisted revoked parent
  is treated as confirmed; an unreadable or non-revoked parent raises
  `AuthenticationLogoutCurrentSession::CommitOutcomeUnknown` and controller boundaries return a
  no-store 503 indeterminate response.
- `AuthenticationLogoutAllSessions`, session-list/account/administrative/lifecycle/risk,
  DBSC-refresh, OIDC-connection and session-limit callers now use the same primitive. Restricted
  session expiry uses it as well. `RpSessionRevoker` sweeps all unrevoked RP rows, including
  expired rows, under Device Session → current root locking.
- Browser RP DELETE cancellation routes were removed from Warp and Edit, the shared Browser RP
  confirmation UI no longer renders a DELETE form, and route/UI contracts cover the absence.

## Verification

The first fail-fast change was red at 28 runs / 87 assertions / 4 failures and green at 28 runs /
91 assertions. The rollback and unknown-outcome cases then passed through red-to-green additions.
The Browser RP DELETE contract was red at 3 runs / 63 assertions / 1 failure and green at 3 runs /
68 assertions. The restricted-expiry parent assertion was red at 8 runs / 69 assertions / 1
failure and green at 8 runs / 81 assertions.

Current targeted Rails regression:

```text
env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test \
  <logout, OIDC/RP, DBSC, lifecycle, session-limit, route and restricted-session selections>
461 runs, 2794 assertions, 0 failures, 0 errors, 0 skips
```

Additional checks passed:

- `bun run test`: 100 files / 1,156 tests passed.
- `bun run typecheck`: passed.
- RuboCop on 24 changed Ruby/test files: no offenses.
- `git diff --check`: passed.

## Remaining boundary

No `AcmeLogoutTransaction` schema change was made. The version-1 authority binding fields required
by one.md still need a Before/After persistent-shape proposal and explicit user approval under the
repository data-shape rule before a migration or producer changes are edited. BCL removal remains
dependent on the unresolved external-consumer/production queue map. The full Rails suite and Avatar
committed-history checks remain outside this slice because their worker-receipt guard requires an
isolated run-owned database, which the current standard-database-only constraint forbids.
