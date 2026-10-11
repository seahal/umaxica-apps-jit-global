# P9 source-generation idempotency and full gate

- Repository HEAD: `2a1644f73238839ed7ed513bd4681ea393a86682`
- Worktree: dirty before and after this slice; 137 status entries were present at capture. Existing changes were preserved. No reset, clean, stash, commit, push, or worktree operation was used.
- Scope: ensure an idempotency replay with the same key but a different source ownership generation is rejected.

## TDD slice

The new public service contract test was added to `test/models/avatar_transfer_reservation_test.rb`.

Red command (existing disposable manifest `tmp/acceptance-isolated-20261010p8b-ip.json`):

```text
RAILS_ENV=test PARALLEL_WORKERS=1 POSTGRESQL_TEST_HOST=10.89.2.2 POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-ip.json POSTGRESQL_TEST_PREPARE_DATABASES=<manifest database names> bundle exec rails test test/models/avatar_transfer_reservation_test.rb
```

Red result: `AvatarOwnershipTransfers::InvalidTransfer expected but nothing was raised` for the changed source-generation replay.

The minimal implementation adds `source_ownership_period_id` to `ReservationCreator#assert_same_request!`'s immutable request comparison.

Green result: `12 runs, 38 assertions, 0 failures, 0 errors, 0 skips`.

Static checks after the change:

- RuboCop on the three touched Ruby files: no offenses.
- `git diff --check`: clean.

## Full gate after the slice

Rails:

```text
/tmp/run-p9-full.sh
```

Result: `14,973 runs, 127,161 assertions, 3 failures, 0 errors, 0 skips` across 42 batches. Batches 000–037 and 039–041 passed. Batch 038 contains only the known `test/tooling/database_reconstruction_authority_test.rb` failures for the 20 tracked empty `db/*structure.sql` dumps; no new failure was observed in the changed reservation code or elsewhere.

Vitest:

```text
/tmp/run-p9-vitest.sh
```

Result: `99 files passed; 1,140 tests passed`.

The Rails isolated-fleet guard intentionally keeps this owned disposable run at one worker. A separate normal-database `PARALLEL_WORKERS=4` probe remains blocked before tests by stale `test_org_ticket_db` state (`organization_invitations` exists without its migration receipt); no shared test database was dropped or recreated.
