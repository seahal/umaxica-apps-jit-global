# ORG Telephone missing-identity backfill

HEAD: `7514f5e1012a4f51337f58ddad88281552554b6f`; application, tests and task code are uncommitted
alongside pre-existing changes. This is observed TDD evidence, not independent/global acceptance.
All test/CLI execution used owned fleet `20261010p3d2`, workers 1 and the complete twenty-database
preparation list. No shared/production data was modified.

The initial new operation tests reported a missing constant (3 runs, one failure/two errors). That
interface/bootstrap failure is not the behavioral Red. After establishing the explicit
scope/mode/batch interface and readonly count, behavioral Red was observed: 3 runs, 17 assertions,
one failure, zero errors/skips; apply assigned 0 instead of 1. First Green passed 3 runs, 27
assertions. The source test also retains a synthetic old numeric-bound ceremony and confirms its
attributes and deliverability remain unchanged after source-ID assignment/repeat.

Collision Red used the real unique B-tree index and controlled Nanoid output: 5 runs, 31 assertions,
one failure/one error. The first collision propagated and the exhausted case tried once rather than
the required finite bound. Bounded exact-constraint retry uses savepoints and allows three retries
after the initial attempt. Exhaustion preserves the source and raises. Only the dependency's
generated output is controlled; the actual DB uniqueness/rollback is not mocked. Unknown constraint
failures propagate in code; complete negative/concurrent coverage remains an acceptance requirement,
not claimed here.

Final focused command, rerun after formatting:

```
bundle exec rails test test/operations/operator_telephone_public_id_backfill_operation_test.rb test/operations/telephone_credential_registration_otp_issuer_test.rb test/models/operator_telephone_test.rb
```

Exit 0: 28 runs, 147 assertions, zero failures/errors/skips, 1.508318 seconds. The new five tests
cover missing-only assignment, source/ceremony preservation, repeat, readonly inventory, explicit
scope/mode/batch input boundaries and real constraint collision/saturation. Existing IDs remain
unchanged. Rows are processed in bounded batches with per-row locks/commit; no bulk rewrite,
request-time repair or schema-migration data backfill is introduced.

RuboCop's first run reported formatting and validation-bypass findings. Formatting was corrected;
one tightly scoped Rails/SkipsModelValidations exception explains why the NULL-only maintenance
write must preserve timestamps/callback/proof facts rather than use ordinary identity mutation. No
global lint rule or acceptance threshold changed. Final RuboCop: three files, zero offenses, exit 0.
Oxfmt formatted the checklist/runbook; `git diff --check` passed.

Direct CLI checks (not Minitest/Vitest environment-construction tests):

- `bundle exec rake 'org_telephone_public_ids:inventory[1]'` exited 0, aggregate assigned 0/missing
  0; no generated IDs or writes. This fixture-time count is not a production inventory.
- `bundle exec rake 'org_telephone_public_ids:backfill[wrong-target,1]'` exited 1 with explicit
  target mismatch before write. No positive CLI apply/cutover is claimed; real domain writes are
  exercised only in synthetic rollback tests.

ID-3c and the DB workflow contain the explicit task interfaces, bounded retry, resume/recovery and
separate source-backfill/proof-drain/cutover steps. Their added paragraphs belong to this task.
Final NOT NULL/check validation, DB immutability, actual writer quiescence and executable legacy
proof admission/cutover checks remain incomplete.

Full `bundle exec rails test` and `bun run test` Gate 2 completed with exit 0 for both commands.
Rails: 15,021 runs, 127,411 assertions, zero failures/errors/skips, 970.892912 seconds. Vitest: 99
files, 1,140 tests, 13.28 seconds. Relative to the preceding public-link gate's 15,016 runs and
127,373 assertions, this run adds five backfill tests and 38 assertions without a failed-test set.
The start HEAD was `e091786d132176d2957a2db7b81a2439818a7208`; finish HEAD was
`0f46fa6857978de59f82c836581c62797d73ac25`. Intervening commits contained only catalog evidence and
identifier decision documentation, not application/test changes. The owned fleet and uncommitted
backfill code remained the tested target; these document commits are not complete application
snapshots. No next feature edits began while the gate was pending. No production/shared access,
external sending, application-code commit or push occurred.
