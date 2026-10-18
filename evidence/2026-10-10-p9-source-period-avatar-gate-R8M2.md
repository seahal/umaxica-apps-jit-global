# P9 source-period Avatar integrity gate

- **Commit under test:** `2a1644f73238839ed7ed513bd4681ea393a86682`
- **Worktree:** dirty before and after the checks; 139 status entries were present at capture. Existing changes were preserved.
- **Scope:** The Avatar transfer registry now has a deferred PostgreSQL integrity guard requiring each concrete detail's source ownership period to belong to the reservation's Avatar. The guard is installed by `db/avatars_migrate/20261010180000_enforce_avatar_transfer_source_period_avatar.rb` and the trigger inventory was updated.

## TDD evidence

- Red: `test/models/avatar_transfer_reservation_test.rb` failed with `ActiveRecord::StatementInvalid expected but nothing was raised` for a direct SQL detail using a source period from another Avatar (`13 runs, 39 assertions, 1 failure, 0 errors, 0 skips`).
- Green: the same test together with `test/models/enforcement_triggers_test.rb` passed after the migration and inventory update (`19 runs, 53 assertions, 0 failures, 0 errors, 0 skips`).
- Focused RuboCop passed for the migration and the two test files. `git diff --check` passed.

## Full gates after the slice

- Rails: `/tmp/run-p9-full.sh`, 42 isolated batches using the repository safety configuration (`PARALLEL_WORKERS=1`). Aggregate: `14,973 runs, 127,165 assertions, 3 failures, 0 errors, 0 skips`. All application batches passed. Batch 038 retained the known three failures in `test/tooling/database_reconstruction_authority_test.rb` because tracked `db/*_structure.sql` files are empty; this is unrelated to the Avatar trigger change. No new application failure was observed.
- Vitest: `/tmp/run-p9-vitest.sh` — `99` test files and `1,140` tests passed.

The normal shared test database was not repaired or modified. Its earlier parallel preparation conflict remains a separate environment issue; the isolated catalog was used for this gate because the repository's safety guard rejects parallel workers for an owned isolated run.
