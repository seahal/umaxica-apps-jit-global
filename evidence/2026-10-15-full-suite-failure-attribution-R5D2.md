# Attribution of the remaining full-suite failures

- Commit: `fef6f6fb32dd4b8fae22df62e0c3daff2c0b747e` on `feature`; clean worktree apart from the
  gitignored `three.md`/`four.md`. Actor: Claude Opus 5.5 (claude-opus-5-5).

## 14 errors — Avatar `committed tests require run-owned worker receipts`: not caused by this plan

- The five test files that call `ParallelTestDatabaseCloner.verify_owned_worker_execution!` and the
  guard itself already existed at the plan baseline `9c6a0fcae`. Since then the only change in those
  files is a Strict Loading adjustment in `avatar_moniker_writer_operation_test.rb`, which is in a
  non-guarded test.
- Before the plan, full runs used the isolated fleet with run-owned workers and reported 0 errors
  (for example 15,149 runs in `evidence/2026-10-12-*`). The errors appear because the user
  restricted this work to the standard test database, where the guard refuses by design. Left as is;
  verifying them needs the isolated fleet.

## 3 failures — `DatabaseReconstructionAuthorityTest`: caused by the plan work, fixed

- All 20 `db/*structure.sql` files were 448-byte empty dumps, all written 2026-10-14 08:09:21 and
  first committed in checkpoint `7d4e2d941`. At `aa92265b7` and every earlier plan commit they were
  complete.
- Fix (`fef6f6fb3`): `RAILS_ENV=development bin/rails db:schema:dump` from the local development
  databases (all 20 on the private test host, 0 pending migrations). The output was then reduced to
  the real DDL change against `aa92265b7`: the `20261014120000` logout binding columns and
  constraints in `app_ticket`, and the `20261013184127` `tech.access` capability constraint in
  `org_zenith`. Environment-specific HMAC definer role suffixes were kept at their committed values,
  and the search, storage, app_zenith and com_zenith files were restored unchanged.
- `bin/rails test test/tooling/database_reconstruction_authority_test.rb`: 6 runs, 0 failures.
- `RAILS_ENV=development bin/rails db:verify_no_schema_drift` now reports only search and storage.
  Their committed dumps are identical to the baseline; the development databases lack a
  `schema_migrations` table. This is local database state unrelated to the plan, and was not
  changed.
- The full suite was not rerun after this fix.
