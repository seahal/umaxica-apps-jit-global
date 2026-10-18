# Full Minitest and Vitest baseline before the large refactor

- Commit: `8e302ed42b45e45dcc73225b52fe08357432c9db` on `feature`. The worktree had the user's
  uncommitted Jump/sign-entry controller and test changes (about 50 files). This session's edits
  are listed below.
- Actor: Claude Opus 5.5 (claude-opus-5-5).

## Vitest

- `bun run test`: 100 files, 1,156 tests, all passed, exit 0.

## Minitest

- `bin/rails test` (standard compose PostgreSQL test databases, default parallel workers):
  15,361 runs, 130,168 assertions, 7 failures, 28 errors, 0 skips, 298 s.

### Caused by code or tests, fixed in this session

- `AvatarOwnershipCutoverOperationTest` (3 errors, `Avatar cutover requires a bounded nonempty
  avatar_ids array`): checkpoint `58d2d80c5` removed the `avatars` fixtures, so `Avatar` was empty.
  The test's own `avatar` helper was never called; setup now creates it. 3 runs, 0 failures.
- `ArchitectureBaselineTest` (1 failure): `app/operations/oidc_connection_revoker.rb` had no
  remaining `Umaxica/ExplicitMethodVisibility` offense. `bin/rails architecture:baseline` dropped it
  from `.rubocop_todo.yml` and `.rubocop/architecture_baseline.yml` (one line each).
- `SignUpPhaseRegressionComTest` (2 failures, a 404 from the birthdate PATCH): the request raised
  `RecordNotFound` for `VisitorSecretCredentialKind` id 3 and then `VisitorSecretCredentialStatus`
  id 1. Those reference tables are empty in `test_com_zenith_db` and `test_com_zenith_db_0`
  (`development_com_zenith_db` has 1, 3, 4). Setup now seeds both `DEFAULTS` with
  `find_or_create_by!`, as the other com sign-up integration tests already do. The file together
  with the baseline test: 15 runs, 0 failures, 0 errors.

### Caused by the environment, not fixed

- 14 errors, `committed tests require run-owned worker receipts` (Avatar committed-history
  tests). The guard refuses to run outside an isolated fleet with run-owned workers
  (`POSTGRESQL_ISOLATED_TEST_RUN_ID`).
- 15 HMAC cases (11 `RealmIdentifierHmacRotationTest`/`IdentifierHmacEmergencyRotationTest`
  errors `identifier rotation function owner is invalid`, 4 `IdentifierHmacMaintenanceBoundaryTest`
  failures expecting `umaxica_<realm>_<channel>_hmac_definer_*` but getting `root`). In
  `test_app_zenith_db`, `test_app_zenith_db_0` and `development_app_zenith_db`, every
  `rotate_*_hmac` function is owned by `root`, although migration `20261008025001` runs
  `ALTER FUNCTION ... OWNER TO` the definer role. The definer roles for `test_app_zenith_db`
  (suffix `f2889e81e3d6`) exist in the cluster. The databases therefore look like they were built
  from the owner-less `db/*_structure.sql` dumps rather than from migrations. That was not
  confirmed.

## Isolated fleet run (approved by the user)

- New fleet `20261016w6n2`: the absence of all 20 `codex_integrity_20261016w6n2_*` names and their
  derived HMAC role suffixes was checked first. The 20 databases were created owned by the test
  user with the comment that `DatabaseSafety` expects, and the manifest is
  `tmp/acceptance-isolated-20261016w6n2.json`. The removed `scripts/` tooling (`45ed455caa`) was
  not restored; a scratch script did the same creation and receipt steps.
- `RAILS_ENV=test PARALLEL_WORKERS=1 ... bundle exec rails db:test:prepare` and then
  `db:migrate` both exited 0. The migration log is local in `tmp/`, and its sha256 and the 12
  created role names and OIDs were added to the manifest. Afterwards the `rotate_*_hmac`
  functions were owned by the fleet's definer roles, and `visitor_secret_credential_kinds` held
  1, 3 and 4.
- First full run (`PARALLEL_WORKERS=8`): 15,361 runs, 0 failures, 7,536 errors. 7,451 of them were
  `fk_rails_11d7aa8bc0` (`avatars.active_handle_id` → `handles`). Committed-history tests leave a
  committed Avatar and its committed Handle in the worker. The next fixture reload deletes
  `handles`, and re-enforcing the foreign key then fails, so every later test on that worker
  errored. Worker cleanup stopped after worker 0, leaving 140 worker databases.
- Fix: `test/fixtures/handles.yml` was removed (by the user) for the same reason `58d2d80c5`
  removed the Avatar fixtures. The four users of `handles(:one)` now call
  `AvatarTestFactory.create_handle!`. On the standard databases those four files gave 36 runs,
  0 failures and 1 error, the expected receipt guard.
- With the user's approval, the 140 leftover worker databases were dropped through
  `ParallelTestDatabaseCloner.cleanup_isolated_worker_manifest!` using their run receipts. After
  that, 0 worker databases remained.
- Second full run (`PARALLEL_WORKERS=8`, same fleet): **15,361 runs, 130,520 assertions,
  0 failures, 0 errors, 0 skips**, 342.8 s, exit 0. 0 worker databases remained afterwards.
- RuboCop on the seven changed test files reported no offenses after one line wrap.

## Remaining state

- The parent fleet (20 databases) and its 12 HMAC roles are kept for later runs.
- On the standard `test_*` databases the receipt guard still refuses the committed-history cases
  by design, and the HMAC function owners there are still `root`.
- Vitest was not rerun after these changes because no JavaScript changed.
