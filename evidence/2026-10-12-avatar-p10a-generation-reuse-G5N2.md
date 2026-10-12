# P10a historical Grant non-reactivation and Gate 2

- Repository: `/home/global/workspace`
- Branch: `feature`
- HEAD before and after this check: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`
- The worktree already contained unrelated staged, unstaged and untracked changes. They were
  preserved. No reset, cleanup, commit, push, production operation or shared-data operation was
  performed.
- PostgreSQL execution used the run-owned manifest
  `tmp/acceptance-isolated-20261010p8b-primary.json`, four Rails workers and no production or
  shared database.

## Focused red-to-green slice

The added public-operation regression starts with a Grant on ownership generation O1, performs
O1 → O2 → O1 through the concrete transfer registry, proves the historical O1 Grant is not
effective for either the closed O1 period or the new O1 owner period, and then proves that a fresh
authorized Grant is required. The first run exposed a stale Active Record object allowing the
closed period to be treated as current. `AvatarAccessGrantResolver` now reloads the current
period from the database before resolving a Grant.

Command:

```text
bundle exec rails test test/operations/avatar_ownership_transfers_test.rb test/services/avatar_access_grants_test.rb
```

Result after the fix:

`33 runs, 172 assertions, 0 failures, 0 errors, 0 skips` in `3.148` seconds.

## Full gates after the behavior change

Rails command:

```text
bundle exec rails test
```

Result: `15155 runs, 128324 assertions, 0 failures, 0 errors, 0 skips` in `351.294` seconds.

Vitest command:

```text
bun run test
```

Result: `99 files passed, 1140 tests passed` in `13.77` seconds.

A read-only Rails catalog follow-up reported `manifest_databases=20`, `worker_db_count=0` and
`active_worker_sessions=0`.

This evidence closes only the stale-period non-reactivation subcondition and records the current
full Rails/Vitest gate. It does not close P10b Group account semantics, writer quiescence,
operational backfill, the P12b marker/cutover, or the remaining full O1 → O2 → O1/client
transition and cross-connection failure-injection criteria.
