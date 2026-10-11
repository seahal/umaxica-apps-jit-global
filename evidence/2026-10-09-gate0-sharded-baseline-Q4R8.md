# Gate 0 Sharded Baseline

- Date: 2026-10-09
- HEAD: `2a1644f73238839ed7ed513bd4681ea393a86682`
- Worktree: pre-existing staged/unstaged/untracked changes were preserved; the
  application and migration changes listed by `git status --short` were not
  modified by this baseline run.
- Test environment: isolated PostgreSQL fleet identified by
  `POSTGRESQL_ISOLATED_TEST_RUN_ID=20261009social3`, manifest
  `tmp/acceptance-isolated-20261009social3.json`, and
  `PARALLEL_WORKERS=1`.
- CI, Podman, production services, and external services were not used.

## Rails

The complete discovered Rails test-file inventory was split into 42
non-overlapping file lists (`/tmp/umaxica-rails-batch-000.list` through
`/tmp/umaxica-rails-batch-041.list`). Each list was run sequentially with the
isolated database scope and `bundle exec rails test`, using one worker. The
aggregate result was:

```text
14,954 runs, 126,994 assertions, 3 failures, 0 errors, 0 skips
```

The three failures were all from
`test/tooling/database_reconstruction_authority_test.rb`. They report that the
20 repository `structure.sql` files currently present in the pre-existing
working-tree diff contain no table definitions. No application test failure or
error was observed in the other 41 shards. These known structure-dump failures
remain unverified until the migration/schema-dump work is reconciled; they are
not treated as a new feature regression for this run.

An initial monolithic `bundle exec rails test` invocation was terminated with
exit 137 before producing a summary. The non-overlapping shard execution above
covered the complete test-file inventory and is the usable local Gate 0 record.

## Vitest

Command: `bun run test`

```text
Test Files 99 passed (99)
Tests       1,140 passed (1,140)
```

## Other checks

- `db:abort_if_pending_migrations` exited 0 for the isolated scope.
- Focused Minitest samples passed before the baseline: 5 runs/33 assertions,
  then 23 runs/216 assertions.
- `git diff --check` passed.

No application implementation was changed as part of this baseline.
