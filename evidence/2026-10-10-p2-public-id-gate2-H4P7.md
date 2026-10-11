# P2 public identifier collision gate

Date: 2026-10-10

## Scope

This record covers the bounded collision-retry slice for the existing `PublicId` concern. It
does not claim completion of the wider identifier contract: database immutability, the 25-character
storage migration, identifier classification, bulk-write coverage, and consumer migration remain
separate P2/P6 work.

The test worker count was one. Tests used the disposable PostgreSQL run
`20261009social3` and its 20-database manifest. No CI, Podman, production database, external
service, or live observability sink was used.

The work was performed against commit
`2a1644f73238839ed7ed513bd4681ea393a86682`. The worktree contained unrelated staged, unstaged,
and untracked changes; they were preserved. The owned application changes in this slice are
`app/models/concerns/public_id.rb`, `config/database.yml`,
`test/models/client_bulletin_test.rb`, and `test/models/client_secret_issuance_test.rb`.

## Implemented behavior

- Internal NanoID generation remains 21 characters and records which value the concern generated.
- A create is retried only when PostgreSQL identifies an exact, non-partial unique B-tree index
  whose sole key is `public_id`.
- The retry is bounded by `PublicId::MAX_COLLISION_RETRIES` (three retries), uses a nested
  transaction savepoint, and propagates a different unique-constraint violation unchanged.
- A caller-supplied `public_id` is never replaced after a collision.
- Models without an exact `public_id` unique index do not pay the collision savepoint cost.
- The test database pool is three connections so a test thread retaining its lease and two real
  concurrent operation threads can run the committed-transaction concurrency tests with worker=1.

## Verification

Focused regression command:

```text
RAILS_ENV=test PARALLEL_WORKERS=1 POSTGRESQL_ISOLATED_TEST_RUN_ID=20261009social3 \
POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261009social3.json \
POSTGRESQL_TEST_PREPARE_DATABASES=<the 20 database names in that manifest> \
bundle exec rails test \
  test/models/client_bulletin_test.rb \
  test/models/client_secret_issuance_test.rb \
  test/models/concerns/public_id_test.rb \
  test/models/operator_coverage_test.rb \
  test/operations/publishing/promotion_concurrency_test.rb
```

Observed result: `40 runs, 193 assertions, 0 failures, 0 errors, 0 skips`.

The focused cases prove an internally generated collision is retried, the finite retry limit is
enforced, a different unique constraint is not treated as a public-ID collision, and a supplied
ID is not regenerated. The publishing committed-transaction concurrency tests also pass.

The final worker=1 Rails gate used 42 sequential shards covering the complete discovered Rails
test file inventory. Observed aggregate: `14,960 runs, 127,048 assertions, 3 failures, 0 errors,
0 skips` (Gate 0 before this slice was `14,954 runs, 126,994 assertions, 3 failures, 0 errors,
0 skips`; the difference is the added regression coverage). The three failures are the pre-existing
`DatabaseReconstructionAuthorityTest` checks for
21 empty or incomplete `structure.sql` dumps; no other shard failed. This is not a green full Rails
suite and is not claimed as one.

The final Vitest command was:

```text
bun run test
```

Observed result: `99` test files and `1,140` tests passed.

Additional checks:

- `bundle exec rubocop app/models/concerns/public_id.rb test/models/client_bulletin_test.rb test/models/client_secret_issuance_test.rb` passed with no offenses.
- Ruby syntax checks for the three Ruby files passed.
- `git diff --check` passed for the owned files.

The first full-gate attempt exposed a connection-pool timeout in the existing publishing
concurrency test because the test pool was two while the main test lease plus two real worker
connections were required. Raising only the test pool to three resolved it; the affected shard
then passed with `380 runs, 1,915 assertions, 0 failures, 0 errors, 0 skips`.

## Limits and next work

The structure-dump failures remain an environment/schema-dump issue outside this slice and must be
kept separate from new regressions. No migration, schema dump, production database, or destructive
operation was performed here. The broader identifier inventory and DB-level permanent-ID
immutability work remain for later P2/P6 slices.
