# Schema dump verification before commit

- Commit: `bde2346c17e2aa911acc95de1f6035f80498f2da`. Worktree had uncommitted changes: 26 modified
  `db/*structure.sql` files and untracked or staged migrations under `db/op_base_*_migrate`,
  `db/rp_*_migrate` and `db/com_zenith_migrate`. They are the subject of this check.
- Tooling: PostgreSQL client 18.6. Throwaway databases were named
  `<development database>_roundtrip_check`, created and dropped per configuration. None remained
  at the end (`pg_database` query returned no rows). Scripts lived in the session scratchpad.

## Checks

1. Version inventory. For every development configuration, the migration file versions on disk equal
   the `schema_migrations` versions in its structure file (no missing, no extra).
2. Round trip (load file with `psql -v ON_ERROR_STOP=1 -q -X -f`, dump with
   `ActiveRecord::Tasks::DatabaseTasks.dump_schema` on a copied config). 23 of 32 files are
   byte-identical. The other 9 (`publishing`, three `zenith`, three `op_base_*`, `chronicle`,
   `avatar`) differ only in how PostgreSQL re-renders `IN (...)` CHECK expressions after a reparse:
   `(ARRAY['a'::character varying, ...])::text[]` becomes `ARRAY[('a'::character varying)::text, ...]`.
   They are equal after canonicalizing that one form. `publishing` is unchanged from HEAD and shows
   the same difference, so it predates this change. HMAC definer suffixes in the zenith files equal
   `sha256(development_<realm>_zenith_db)[0,12]` (for example `8cacbbcb7884` for APP).
3. Fresh migrate from an empty throwaway database, then dump. The result is byte-identical to the
   file for `app_setting`, `com_setting`, `org_setting`, `occurrence`, `avatar`, `chronicle`,
   `op_base_app`, `op_base_com`, `op_base_org` and `rp_base_app`. Zenith databases were not
   fresh-migrated, because their HMAC migrations create cluster-wide roles named after the database.
4. Counterfactual: load the HEAD file, run the pending migrations, dump, normalize. The result equals
   the new file for all 12 `rp_*`. For the other files, the only remaining differences are:
   - `NOT VALID` foreign keys and checks. The new files have them and HEAD did not (for example
     `app_setting` 0 to 9, `occurrence` 0 to 63). The migrations add them with `validate: false`
     (for example `20260518030000_load_initial_app_setting_schema.rb`) and never validate them.
     Fresh migration reproduces exactly this state (check 3).
   - Zenith `*_security_modes`: the new files add an `id` sequence and a `nextval` default, and put
     `security_mode_id` last in `clients`, `visitors` and `operators`. `t.bigint(:id, primary_key:
     true)` in `20261023140000_create_*_security_modes.rb` creates a serial key. That migration
     runs after `20261016210000`, which adds the earlier columns. The HEAD dump was built from
     another database lineage (see `2026-10-25-schema-drift-hmac-role-H7Q3.md`).
   - `search` and `storage`: `schema_migrations` is absent.
   - The HEAD files for `op_base_app` and `op_base_com` were missing committed migrations
     `20261023194737/38` and `20261023194743/44`.
5. `search` and `storage` behavior. Both `migrations_paths` directories (`db/searches_migrate`,
   `db/storages_migrate`) contain only a README. Multi-database `db:migrate` skips configurations
   with no versions, so the tables were absent after `db:migrate:reset`. A database loaded from the
   new file has no `schema_migrations` table and reports 0 pending migrations. But opening a
   migration context creates the table. `bin/rails db:abort_if_pending_migrations:search` and
   `:storage` (exit 0) created it in `development_search_db` and `development_storage_db` during
   this check, which was not intended. Afterwards, a fresh dump of both development databases
   equals HEAD byte for byte and no longer matches the worktree file.

## Result

- All dumps faithfully represent their migrations, except `search_structure.sql` and
  `storage_structure.sql`. Their table-less form is transient: the first migration-context task
  recreates the table, and the drift verifier then reports them again. Keep the HEAD versions of
  those two files.
- The `NOT VALID` state is correct for a freshly migrated database. Whether the migrations should
  validate those constraints is a separate migration decision, not a dump defect.
- Not done: no zenith fresh migrate, no test-environment check.
