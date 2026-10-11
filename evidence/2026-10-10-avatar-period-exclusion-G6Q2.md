# Avatar ownership-period interval exclusion slice

Date: 2026-10-10
Commit under test: `2a1644f73238839ed7ed513bd4681ea393a86682`
Worktree: `feature`, with pre-existing and current uncommitted changes preserved.
Test database: disposable PostgreSQL manifest `tmp/acceptance-isolated-20261009social3.json`.
Test execution used `PARALLEL_WORKERS=1`; CI, Podman, production databases and external services
were not used.

## Change

The Avatar database now has a two-step migration for the local temporal interval invariant:

- `20261010120000_add_avatar_ownership_period_temporal_exclusion.rb` enables `btree_gist`, adds a
  `valid_from < valid_to` CHECK as `NOT VALID`, and adds the approved GiST exclusion constraint on
  `avatar_id` and `[valid_from, valid_to)`.
- `20261010120001_validate_avatar_ownership_period_temporal_exclusion.rb` validates the CHECK.

`test/models/avatar_ownership_period_test.rb` adds public persistence tests for an overlapping
historical period and an empty period. The tests assert PostgreSQL exclusion/check violations and
preservation of the existing period. Cross-family continuity, closed-history immutability, and
exactly-one-owner-at-commit remain unimplemented acceptance obligations.

## Verification

Focused Red before the migrations: `6 runs, 24 assertions, 2 failures, 0 errors, 0 skips`.
The failures showed that the existing schema accepted both invalid intervals.

Focused Green after the migrations:

```text
bundle exec rails test test/models/avatar_ownership_period_test.rb
6 runs, 27 assertions, 0 failures, 0 errors, 0 skips
```

Avatar adjacent regression selection:

```text
bundle exec rails test test/models/avatar_ownership_period_test.rb test/models/avatar_group_ownership_period_test.rb test/models/avatar_ownership_transfer_test.rb test/operations/avatar_ownership_transfers_test.rb test/operations/avatar_ownership_transfers_concurrency_test.rb test/controllers/base/app/avatar_ownership_transfers_controller_test.rb test/controllers/base/org/avatar_ownership_transfers_controller_test.rb
33 runs, 150 assertions, 0 failures, 0 errors, 0 skips
```

Rails Gate 2 used 42 sequential worker-1 shards from `/tmp/umaxica-rails-batch-000.list` through
`041.list`:

```text
14962 runs, 127053 assertions, 3 failures, 0 errors, 0 skips
```

The three failures are the known `DatabaseReconstructionAuthorityTest` failures caused by the
twenty empty/incomplete `structure.sql` files already present in the working tree. No new failure
appeared in the other 41 shards.

Vitest Gate 2:

```text
bun run test -- --maxWorkers=1
99 files passed, 1140 tests passed
```

An attempted `--minWorkers=1` option was rejected by the installed Vitest CLI as unknown; the
successful command used the supported `--maxWorkers=1` option.

The full Rails/Vitest results are not a pure-green Gate 2 because the pre-existing structure-dump
failures remain. This evidence does not claim final nine.md acceptance.
