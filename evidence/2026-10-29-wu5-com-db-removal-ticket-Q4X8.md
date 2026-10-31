# WU-5 execution ticket: retired com database removals (dev/test only)

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; worktree contains the full WU-3/4/5 uncommitted
  changes (nothing was committed). Scope: local Dev Container PostgreSQL at `primary` only; no
  production/external target exists in this session and none was touched.
- Reason: two.md WU-5 — remove every com connection except com_setting (retired com zenith / com
  signal / op_base_com / the three RP com cells), drop the retired shared-table families, and record
  the deliberate destructive dev/test database removal.

## Code/config side (before any drop)

- `config/database.yml`: deleted the `com_zenith`, `com_signal`, `op_base_com`, `rp_base_com`,
  `rp_core_com`, `rp_warp_com` entries (and replicas) in development/test/production and the three RP
  com cell rows in the `rp_cells` bootstrap list. Rendered YAML verified field-by-field: only
  `com_setting` + `com_setting_replica` remain as com entries in every environment.
- `config/ci.rb`: removed the com names from `POSTGRESQL_TEST_PREPARE_DATABASES`.
- `.env` and `.env.container.devcontainer`: the prepare list was rewritten to the `config/ci.rb`
  fragment set (identical names, no `_jp` suffixed variants).
- `.github/workflows/ci.yml`: NOT editable in this session — `/home/global/workspace/.github` is a
  read-only mount; the workflow's com database names remain stale and must be updated by the owner in
  an editable environment.
- Deleted migration directories and dump files for the retired connections: `db/com_zenith_migrate`,
  `db/com_principals_migrate`, `db/com_signals_migrate`, `db/op_base_com_migrate`,
  `db/rp_base_com_migrate`, `db/rp_core_com_migrate`, `db/rp_warp_com_migrate`, and
  `db/{com_zenith,com_signal,op_base_com,rp_base_com,rp_core_com,rp_warp_com}_structure.sql`.
  `db/com_settings_migrate` and `db/com_setting_structure.sql` are kept.
- Deleted application models: all `ComRpRecord` descendants (Company/Individual grant, ownership,
  membership, assignment, transfer-request and cutover tables), `ComZenithRecord`, `ComRpRecord`,
  `AvatarIndividualBinding`, and their fixtures/tests; removed the `Individual`/`Company` arms from
  `AuthorityOwnerDirectBindingBackfillOperation#resource_identity`, avatar provisioning/selector/backfill
  service branches, and the `AccountPolicy` consumer lists. `ComPreference` family under
  `ComSettingRecord` is retained (WU-7 keeps the anonymous com Preference surface).
- New migrations: `db/chronicle_migrate/20261029120000_drop_retired_com_chronicle_families.rb` (12
  com document/timeline tables in the shared chronicle DB) and
  `db/avatars_migrate/20261029120100_drop_retired_avatar_individual_bindings.rb`. Both irreversible;
  applied to the test databases with `db:test:prepare`, then
  `bin/rails db:schema:dump` for `db/avatar_structure.sql` and `db/chronicle_structure.sql`.
- `bin/rails zeitwerk:check` passes.
- `bin/rails db:verify_no_schema_drift` (RAILS_ENV=test): after regenerating every dump from the
  migration-built test databases, four reports remain pre-existing — app_zenith, avatar, chronicle,
  org_zenith — caused by HMAC-definer role digests in the live test databases (roles were created
  against development database-name digests through the ParallelTestDatabaseCloner template copies;
  e.g. `umaxica_app_email_hmac_definer_8cacbbcb7884` where the verifier expects
  `f2889e81e3d6`). This predates WU-5 (formerly the normalized dumps were 448-byte stubs) and is
  recorded, not silently "fixed".

## Destruction ticket (two.md §12.8) — observed before the drops

- Databases dropped: all `development_*` and `test_*` com databases other than `com_setting` /
  `com_setting_replica`, including `ParallelTestDatabaseCloner` worker clones and replicas:
  6 development databases (com_zenith 14 MB, com_signal 7.9 MB, op_base_com 12 MB,
  rp_base/rp_core/rp_warp_com 8.2 MB each) and 203 test databases (com_zenith 262 kB schema dump kept,
  clones ≤13-14 MB each).
- Row counts measured per live table before the drops: 0 user rows in every dropped development
  database (`pg_stat_user_tables` sums: com_zenith 0, com_signal 0, op_base_com 0, each rp cell 0).
  Test clones are chunk copies with no retained business data.
- Snapshots taken before the drops, retained under `tmp/wu5-snapshots/`:
  `development_com_zenith_db_schema.sql` (260 kB), `development_com_signal_db_schema.sql` (4 kB),
  `development_op_base_com_db_schema.sql` (156 kB), `test_com_zenith_db_schema.sql` (262 kB).
  Restore procedure after dropping: recreate the database by re-running the deleted migrations from a
  checkout before this change — the SQL snapshots only prove the dropped shape; no rollback path
  restores the (empty) data.
- Post-drop verification: 0 databases matching `development%com%` except
  `development_com_setting_db`, and 0 test com databases except `test_com_setting*` clones.
- Not performed: dropping `com_setting`/`com_setting_replica` (retained by design until WU-7), and any
  production/Neon action (no credentials or approval in this session).
