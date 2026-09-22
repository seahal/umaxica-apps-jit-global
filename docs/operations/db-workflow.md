# Database Operations Workflow

This application uses approximately 25 PostgreSQL databases. Follow these development and test
environment rules to avoid schema-change incidents.

## Schema Authority

**Migrations are the reconstruction authority** for development and test databases.

Every configured `migrations_paths` directory under `db/` must exist. Reserved databases (`search`,
`storage`) keep empty directories so Rails cannot skip an owner silently.

Committed `db/*_structure.sql` files are schema-only PostgreSQL dumps generated from the isolated
test database fleet. They contain schema metadata (including `schema_migrations`) but no business
rows. `schema_format` remains `:sql` and `dump_schema_after_migration` is `false` in every
environment. The dumps are a reproducibility artifact, not a replacement for applying migrations
to a clean database.

`bin/rails db:verify_no_schema_drift` regenerates the configured dumps and compares them with the
committed files. A worktree with intentionally regenerated but uncommitted dumps is expected to
report those files as drift until the artifact changes are reviewed and committed. The migration
path and clean-database reconstruction are verified separately before the artifacts are accepted.

The former `db/initial_schemas/*.rb` loaders for app/com/org settings and Chronicle have been
removed. Their initial table, extension, index, and foreign-key definitions now live directly in
the owning migration. `db/migration_support/publishing_schema.rb` remains an explicit migration
builder for the publishing family matrix; it is not a schema dump and is covered by the publishing
reconstruction contract.

## Global / Regional Split (planned)

`adr/global-regional-database-ownership.md` fixes which databases this repository keeps and which
are duplicated into the future `umaxica-apps-regional` repository. After that repository is created:

- Global keeps every currently-populated database (`*_zenith`, `*_ticket`, `*_setting`, `*_signal`,
  `avatar`, `publishing`) plus its own `chronicle`, `occurrence`, `primary`, and `queue`.
- `chronicle`, `occurrence`, `primary`, and `queue` exist independently on both sides — same
  starting schema, **separate databases, separate data, separate migration history**. The two
  histories are not synchronized after the split.
- Regional gets a new application database and does not run any Global-only migration path.
- `search` and `storage` (zero migrations) and `db/audit_schema.rb` (orphan) are deletion candidates
  for the split; no deletion has been performed yet.

Until the split happens, this repository still prepares the full fleet as one unit.

## Principles

1. **Do not use incremental `bin/rails db:migrate` on a branch with in-progress table-rename
   migrations.** Use `bin/rails db:migrate:reset` so every database is rebuilt from migrations.
2. **Do not write silent-skip helpers such as `rename_table_if_present`.** Use
   `rename_table_strict`, provided by `MigrationHelpers::SafeTableRename`.
3. **Do not treat `db/*_structure.sql` files as proof of migration reconstruction.** Apply migrations
   to a clean database and compare the resulting schema with the dump instead.

## Why Incremental `db:migrate` Is Unsafe During Renames

`db:migrate` assumes that every earlier migration was applied correctly. A branch that renames
tables across roughly 25 databases frequently violates that assumption:

- After switching branches, some databases may reflect the new schema dump while others retain the
  old schema, causing a missing-table failure.
- Adding a `rename_table_if_present` silent skip to avoid the failure can record a successful
  migration against a partially renamed schema. The intermediate schema is then dumped, committed,
  and propagated to other environments.
- Fixtures use current table names and cannot load into a partially renamed database, causing broad
  test failures.

`bin/rails db:migrate:reset` performs drop, create, and migrate on every run, so intermediate state
does not accumulate.

## Commands

```bash
bin/rails db:migrate:reset
RAILS_ENV=test bin/rails db:migrate:reset

bin/rails db:verify_no_schema_drift
# Applies migrations to clean test databases and succeeds when the result matches
# the committed db/*_structure.sql files. Reports schema drift and exits 1 otherwise.
```

## Stop the Server Before Resetting Databases

The `app_setting` database initializes preference reference rows through `insert_missing_fixed_ids!`
on demand. If the server remains active during a reset, an incoming request can arrive while
databases are being dropped and recreated. Connection-pool checkout then blocks until the socket
timeout, approximately ten seconds, and produces a `Rack::Timeout::RequestTimeoutException` with an
HTTP 500 response.

```bash
# Correct procedure
# 1. Stop Puma, Foreman, and docker compose.
# 2. Reset the databases.
bin/rails db:migrate:reset
# 3. Restart the server. Startup pre-seeds all preference reference tables.
```

`config/initializers/preference_reference_defaults.rb` seeds every preference reference table in
`after_initialize`, so the first request after restart sees populated databases.

## Writing Table-Rename Migrations

```ruby
class RenameUsersToClients < ActiveRecord::Migration[8.2]
  def up
    rename_table_strict :users, :clients
  end

  def down
    rename_table_strict :clients, :users
  end
end
```

`rename_table_strict` behaves as follows:

| Old table | New table | Behavior                                                                         |
| --------- | --------- | -------------------------------------------------------------------------------- |
| Present   | Absent    | Rename the table                                                                 |
| Absent    | Present   | Skip as an idempotent rerun                                                      |
| Present   | Present   | **Raise** because the schema is partially renamed and requires manual resolution |
| Absent    | Absent    | **Raise** because the schema does not match the expected state                   |

The former `rename_table_if_present` silently skipped whenever either side was missing. That hid
partial renames and produced schema drift. `rename_table_strict` raises for every state requiring
manual resolution.

## Recommended Schema-Drift CI Check

Add the following step to the repository's schema-drift job in
`.github/workflows/integration.yml` when enabling schema-drift enforcement:

```yaml
- name: Verify no schema drift
  run: bin/rails db:verify_no_schema_drift
```

The check fails when the branch's committed schema dumps differ from applying migrations to clean
databases. The retired `database_consistency` gem is not a runtime or CI dependency; historical
documents that describe its earlier findings remain historical records.

## Verified targeted database safeguards

The app and com sign-up-flow token foreign keys use `ON DELETE RESTRICT`. A token purge therefore
cannot delete a child flow whose own retention window has not completed. Rails associations use
`restrict_with_exception` as the application-side counterpart. The approved all-rows
`idx_avatar_ownership_periods_avatar_id_all_rows` index exists alongside, rather than replacing,
the current-row partial unique index.

The seven approved administrative and enforcement reason-note columns use non-deterministic Active
Record Encryption. The corresponding focused test verifies both round-trip decryption and that a
newly persisted database value does not contain the plaintext. Populated structure dumps have been
generated from the isolated test databases and are deterministic on repeat dump. On 2026-09-21,
the isolated test fleet was rebuilt from migrations, seeded twice, and dumped twice; all configured
database versions reached their expected current migration and the two dump sets matched. The
reconstruction verification is recorded in `evidence/2026-09-21-phase-09-reconstruction-X4Y5.md`.
