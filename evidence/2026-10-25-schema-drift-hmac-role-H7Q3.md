# Schema drift verification: HMAC definer role suffix

- Commit: `bde2346c17e2aa911acc95de1f6035f80498f2da`. The worktree had hundreds of uncommitted
  changes by others, including new migrations under `db/*_migrate/` that affect the dumps.

## Root cause

- The APP, COM and ORG identifier HMAC migrations name roles
  `umaxica_<realm>_<channel>_hmac_<kind>_<sha256(current_database())[0,12]>` and embed the definer
  name as a string literal in trigger and function bodies.
- `SchemaDriftVerification.normalize_roles` requires the suffix in a fresh dump to equal the hash of
  the dumped database name. That matches the migration code.
- The tracked zenith dumps carried `269d72da14b2` (COM), `5d2e3f6bb4ae` (APP) and `6dc846a24801`
  (ORG). Earlier evidence (`2026-10-19-rails-standard-credentials-and-fixed-dev-db-C7R2.md`)
  identifies `269d72da14b2` as the hash of the isolated database
  `codex_integrity_20261017c1a2_com_zenith`. The dumps were produced from an isolated fleet, not
  the development fleet.
- `db:reset` loads `structure.sql`, so the reset database kept the foreign suffix in its function
  bodies, and the verifier's strict check rejected it. The tool and the migrations were correct; the
  dumped files were the defect. No code was changed.

## Commands and observations

- `bin/rails db:migrate:reset` (development) exited 0. It dropped and recreated 32 development and
  32 test databases. In this Rails version the task also runs `db:schema:dump` after `db:create`,
  so it overwrote every tracked `db/*structure.sql` with 18-line empty dumps at 15:53:09-11 UTC.
  The uncommitted working-tree versions of these files were lost (staged index versions of the
  `MM` files remain in the index).
- `bin/rails db:schema:dump` (development, fully migrated) regenerated all dump files. The zenith
  dumps now carry the development suffixes (`00d920046b15` for COM).
- An in-process run of `SchemaDriftVerification.dump_matches?` for every development configuration
  reported no mismatches between the fresh dumps and the files.
- `bin/rails db:verify_no_schema_drift` exited 1 without the `ArgumentError`. It still lists 26
  files because its final step also fails on any `git diff --name-only` output for dump files, and
  the regenerated dumps are uncommitted.
- Migration-built dumps differ from HEAD in ways that are not formatting only. For example,
  `app_setting`, `com_setting`, `org_setting` and `occurrence` foreign keys are `NOT VALID`.
  `search` and `storage` no longer contain `schema_migrations`. The `op_base_*` and `rp_*` dumps
  reflect uncommitted migrations.
- `RAILS_ENV=test bin/rails db:prepare` and `bin/rails db:test:prepare` failed with
  `PG::DuplicateTable: relation "operators" already exists` against the recreated empty test
  databases. `RAILS_ENV=test bin/rails db:drop db:create db:schema:load` succeeded. Then
  `RAILS_ENV=test bin/rails db:abort_if_pending_migrations` exited 0.

## Open

- A database loaded from `structure.sql` gets function bodies that name another database's
  definer role, and no role ownership, because dumps omit owners. Rotation functions in loaded
  databases (test included) do not match the migration-built design.
- The regenerated dumps need review and an intentional commit by the owner before the verifier's
  git-diff step can pass.
