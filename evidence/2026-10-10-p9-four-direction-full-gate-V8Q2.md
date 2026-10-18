# P9 four-direction transfer coverage and full gate

- Repository HEAD: `2a1644f73238839ed7ed513bd4681ea393a86682`
- Worktree: already dirty before this slice; 136 status entries were present at capture. Existing changes were preserved and no reset, clean, stash, commit, push, or worktree operation was used.
- Scope: add public-operation coverage for a Bureau-owned Avatar accepted into an Enterprise and verify the complete current test state before the next implementation slice.

## Focused verification

Command (against the existing disposable manifest `tmp/acceptance-isolated-20261010p8b-ip.json`):

```text
RAILS_ENV=test PARALLEL_WORKERS=1 POSTGRESQL_TEST_HOST=10.89.2.2 POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-ip.json POSTGRESQL_TEST_PREPARE_DATABASES=<manifest database names> bundle exec rails test test/operations/avatar_ownership_transfers_test.rb
```

Result: `16 runs, 99 assertions, 0 failures, 0 errors, 0 skips`.

The first attempt exposed only an invalid test fixture (`moniker` exceeded the model's 16-character limit); the fixture was corrected to a contract-valid value and the test was rerun. No production behavior was changed for that correction.

## Full verification before the next slice

The required full Vitest command was run:

```text
/tmp/run-p9-vitest.sh
```

Result: `99 files passed; 1,140 tests passed`.

The complete Rails suite was run through the repository's 42-batch isolated-fleet gate:

```text
/tmp/run-p9-full.sh
```

The isolated catalog was `codex_integrity_20261010p8b_*` on PostgreSQL 17.7. Its safety guard requires one worker for an owned isolated run; that guard was not bypassed.

Aggregate result: `14,973 runs, 127,163 assertions, 3 failures, 0 errors, 0 skips`.

All batches except batch 038 exited successfully. Batch 038 contains the known `test/tooling/database_reconstruction_authority_test.rb` failures asserting that the 20 tracked `db/*structure.sql` files are empty. The three failures are the pre-existing schema-dump condition; no new failure appeared in the changed transfer slice or other batches.

## Parallel normal-database probe

Before the isolated gate, the requested parallel form was attempted with `PARALLEL_WORKERS=4`:

```text
RAILS_ENV=test PARALLEL_WORKERS=4 POSTGRESQL_TEST_HOST=primary bundle exec rails test
```

It did not reach application tests. `db:test:prepare` stopped on `test_org_ticket_db` with `PG::DuplicateTable: relation "organization_invitations" already exists`. A read-only catalog check confirmed the table exists while the selected migration receipts were absent. No normal test database was dropped, recreated, or altered during this verification.

This is an environment preparation blocker for parallel normal-database execution, separate from the isolated full-gate result above. Repairing that shared test database requires an explicitly approved recovery operation.
