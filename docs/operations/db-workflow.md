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
environment. The dumps are a reproducibility artifact, not a replacement for applying migrations to
a clean database.

`bin/rails db:verify_no_schema_drift` regenerates the configured dumps and compares them with the
committed files. A worktree with intentionally regenerated but uncommitted dumps is expected to
report those files as drift until the artifact changes are reviewed and committed. The migration
path and clean-database reconstruction are verified separately before the artifacts are accepted.

The former `db/initial_schemas/*.rb` loaders for app/com/org settings and Chronicle have been
removed. Their initial table, extension, index, and foreign-key definitions now live directly in the
owning migration. `db/migration_support/publishing_schema.rb` remains an explicit migration builder
for the publishing family matrix; it is not a schema dump and is covered by the publishing
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
   migrations.** Prepare a newly created, owned isolated fleet with
   `RAILS_ENV=test bin/rails db:test:prepare` so every database is rebuilt from migrations.
2. **Do not write silent-skip helpers such as `rename_table_if_present`.** Use
   `rename_table_strict`, provided by `MigrationHelpers::SafeTableRename`.
3. **Do not treat `db/*_structure.sql` files as proof of migration reconstruction.** Apply
   migrations to a clean database and compare the resulting schema with the dump instead.

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

The installed Rails `db:migrate` initializes an empty database from an available structure dump.
That also imports migration version receipts without the business/reference rows produced by data
migrations. Consequently, drop/create followed by ordinary migrate is not proof of reconstruction.
The repository's `db:test:prepare` verifies the isolated database manifest and selected database
names, then invokes `DatabaseTasks.migrate(skip_initialize: true)` for each selected writer. This
executes migrations without importing dump receipts. Existing database contents are not reset.

## Commands

```bash
# First create and register a new owned isolated fleet using the isolation tooling.
# Supply POSTGRESQL_ISOLATED_TEST_MANIFEST and POSTGRESQL_TEST_PREPARE_DATABASES.
RAILS_ENV=test bin/rails db:test:prepare

bin/rails db:verify_no_schema_drift
# Applies migrations to clean test databases and succeeds when the result matches
# the committed db/*_structure.sql files. Reports schema drift and exits 1 otherwise.
```

For an existing manifest-verified disposable fleet that must be rebuilt under the same database
names, run `bundle exec scripts/postgresql-rebuild-isolated-test-fleet` with `RAILS_ENV=test`,
`PARALLEL_WORKERS=1`, `POSTGRESQL_ISOLATED_TEST_RUN_ID`, `POSTGRESQL_ISOLATED_TEST_MANIFEST`,
`POSTGRESQL_TEST_PREPARE_DATABASES`, and the required PostgreSQL test connection variables set. This
explicit destructive command validates all 20 database identities and refuses active sessions before
dropping them. Identifier HMAC maintenance roles are cluster-wide and survive database drop; the
command derives only this fleet's twelve realm/channel caller and definer names, rejects unexpected
role authority, memberships and dependencies outside their owning database, and drops the orphaned
roles only after the databases are gone. It then recreates and re-identifies the fleet, runs
migration files with `db:test:prepare`'s `skip_initialize` path, and checks `db:migrate`. Missing
roles from a migration that was never reached are expected; unrelated and shared roles are not
selected. A failed role preflight stops before database drop. Do not use this command for shared,
development or production databases.

Use the same command with `--verify-only` to run the database/role preflight without deletion,
recreation or migrations. Unknown arguments fail explicitly. A run-specific PostgreSQL advisory lock
prevents two instances of this rebuild command from operating on the same fleet concurrently; active
database sessions still prevent rebuild.

## Cluster role creation evidence

Database ownership does not prove PostgreSQL role creation ownership. Before the isolated rebuild
command deletes existing fleet HMAC roles, the manifest must contain `created_roles` entries with
exact `name` and `oid` values, plus `role_creation_log_sha256` for the successful creation record.
Keep the actual record at `role_creation_log_path` in the manifest. For an older manifest with an
already recorded checksum but no path, explicitly supply `POSTGRESQL_ISOLATED_ROLE_CREATION_LOG`.
The command verifies the file checksum and exact CREATE ROLE names before any database drop;
supplying another file or reconstructing a receipt from current names is insufficient. The actual
role set and OIDs must match; missing metadata, duplicate entries or changed identities stop before
database drop. Role attribute, membership and foreign-dependency checks still apply. This is not
permission to adopt or delete an unknown cluster role.

For a fresh run, first verify that its unique database and role names are absent, create its owned
databases, and record their OIDs/owner/comment. Run normal migrations from source, retain the actual
successful CREATE ROLE record, and record the resulting role OIDs. Never reconstruct creation
ownership solely from current names or dependencies. A failed manifest write can be recovered by
read-only identity checks on resources whose creation was observed; it does not justify recreation.

Rebuilding creates new database and role identities. The command captures the normal
`bundle exec rails db:test:prepare` and `bundle exec rails db:migrate` output in a private local
file under `tmp/`, then replaces the manifest's creation-record path, checksum and role OIDs with
the actual replacement objects. Preserve this file locally; do not commit raw migration logs.
Migration failure remains failure even when receipts for partially created resources are retained.
Missing or mismatched creation evidence stops further cleanup rather than adopting unknown roles.
The previous role OIDs are not ownership metadata for replacement objects. Only run-owned disposable
resources are eligible; shared/production resources remain excluded. This reconstruction does not
prove Avatar ownership COMMIT or concurrency behavior; those require their own dynamic checks.

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

Add the following step to the repository's schema-drift job in `.github/workflows/ci.yml` when
enabling schema-drift enforcement:

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
`idx_avatar_ownership_periods_avatar_id_all_rows` index exists alongside, rather than replacing, the
current-row partial unique index.

The seven approved administrative and enforcement reason-note columns use non-deterministic Active
Record Encryption. The corresponding focused test verifies both round-trip decryption and that a
newly persisted database value does not contain the plaintext. Populated structure dumps have been
generated from the isolated test databases and are deterministic on repeat dump. On 2026-09-21, the
isolated test fleet was rebuilt from migrations, seeded twice, and dumped twice; all configured
database versions reached their expected current migration and the two dump sets matched. The
reconstruction verification is recorded in `evidence/2026-09-21-phase-09-reconstruction-X4Y5.md`.

## ORG Telephone public-identity transition

This is an additive ID-3a/ID-3c transition, not authorization to change production/shared data. Use
only a separately permitted target; verify the actual connection/owner and preserve other work. The
first schema expansion adds nullable public_id without changing source values or issued proof.
Before consumer deployment, complete the following controlled sequence:

1. Run `bundle exec rake 'org_telephone_public_ids:inventory[100]'` against the permitted target. It
   returns aggregate assigned/missing counts and writes nothing. Batch size must be explicit,
   1–1000. Existing malformed/non-NULL identities require separate review; they are not overwritten.
2. With a verified target and recovery approval, run
   `bundle exec rake 'org_telephone_public_ids:backfill[EXACT_DATABASE_NAME,100]'`. The exact
   physical database name must match the model's current connection. Each missing row is locked and
   assigned one NanoID-21; existing identities and source timestamps/proof facts remain unchanged.
   Work is committed per row and is resumable; rerun after an interruption rather than regenerating
   IDs. A public-ID collision has three retries after the first attempt; other failures propagate.
3. Control all old numeric-reference writers, web workers and queued delivery producers. Let their
   valid proof and bounded original-operation receipts finish through the old authorized consumer
   before switching consumers. Confirm aggregate legacy-reference admission and queued work are
   drained. `bundle exec rake org_telephone_public_ids:legacy_references` reports pending legacy
   registrations, deliverable proof and unexpired receipts using database time without writing or
   revealing proof values. Consumed receipts still count through their exclusive result deadline,
   even after the OTP challenge deadline. Zero counts do not prove worker/queue quiescence or a
   distributed cutover snapshot; check those prerequisites separately. Do not rewrite
   telephone_candidate_ref: it is part of the keyed verifier input. No weaker proof fallback or
   forced session invalidation is part of this transition.
4. Reconcile zero missing source identities and preservation of source/candidate relationships. Only
   after writer/drain verification deploy consumers generating public-ID links and bindings.
   Existing numeric management URLs have the bounded owner-scoped ID-3b contract; new links do not
   expose PKs. A failed public lookup never retries by PK.
5. Validate nonblank/NOT NULL and the approved DB immutability mechanism in separate reviewed
   migrations after those preconditions. These final constraints and executable cutover admission
   checks remain planned/not yet implemented; neither an inventory count nor this runbook proves
   them complete.

Pre-cutover failure leaves the additive column and assigned IDs intact; stop and resume the
operational task after fixing the cause. Post-cutover recovery must preserve assigned IDs and proof
semantics rather than clearing the column or restoring a numeric proof fallback. There is no
automatic production application, legacy-table deletion or shared-cluster operation in these tasks.
See [identifier acceptance](../checklists/identifier-contracts.md) and separate per-run evidence.
