# Avatar transfer registry Gate 2

Verified on 2026-10-10 against commit `2a1644f73238839ed7ed513bd4681ea393a86682` with the
working tree containing uncommitted application, migration, documentation, and evidence changes.
Those changes were preserved. CI, Podman, shared databases, production systems, and external
services were not used. All Rails and Vitest runs used one worker.

The disposable PostgreSQL manifest was `tmp/acceptance-isolated-20261009social3.json` and the
Avatar migrations, including `20261010150000_create_avatar_transfer_reservations.rb`, were applied
to its owned catalogs.

## Focused checks

- `bundle exec rails test test/models/avatar_transfer_reservation_test.rb`: `7 runs, 21 assertions,
  0 failures, 0 errors, 0 skips`.
- `bundle exec rails test test/models/enforcement_triggers_test.rb`: `6 runs, 12 assertions,
  0 failures, 0 errors, 0 skips`.
- The shard containing `test/models/enforcement_triggers_test.rb`: `250 runs, 2223 assertions,
  0 failures, 0 errors, 0 skips`.
- `bundle exec rails zeitwerk:check`: passed (`all is good`; the sandbox-only first attempt was
  retried with the permitted isolated execution because the debugger socket could not bind).
- Targeted RuboCop for the registry models, operation, migration, and tests: no offenses.

## Rails whole-suite gate

The repository's 2,078 Ruby test files were divided into 42 sequential explicit file-list shards,
with no Rails test process running concurrently. Shards 1–38 and 40–42 completed with zero failures,
errors, and skips. Shard 39 reported the three pre-existing empty-`structure.sql` failures in
`DatabaseReconstructionAuthorityTest` and no other failure. The aggregate is `14,969 runs,
127,086 assertions, 3 known failures, 0 errors, 0 skips`; the seven additional runs and 21
assertions are the registry test slice. The known failures are retained as the previously authorized
schema-reset baseline and are not treated as P9 regressions.

A single unsharded `bundle exec rails test` was also attempted and was interrupted after 3,084
runs with no failures; it is not counted as a passing gate. The complete result above comes from the
42 sequential shards.

## Vitest whole-suite gate

`bun run test -- --maxWorkers=1` completed with 99 test files and 1,140 tests passed.

This gate establishes the registry schema/cardinality/replay slice only. Legacy Request/Accept/Cancel
writer cutover, concrete four-direction period transitions, Grants, Group semantics, and Avatar
P12b cutover remain incomplete by design.
