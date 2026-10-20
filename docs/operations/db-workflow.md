# Database Operations Workflow

This application uses multiple PostgreSQL databases. Follow these development and test environment
rules to avoid schema-change incidents.

## Schema Authority

**Migrations are the reconstruction authority** for development and test databases.

Every configured `migrations_paths` directory under `db/` must exist. Reserved databases (`search`,
`storage`) keep empty directories so Rails cannot skip an owner silently.

Committed `db/*_structure.sql` files are schema-only PostgreSQL dumps generated from the test
databases. They contain schema metadata (including `schema_migrations`) but no business rows.
`schema_format` remains `:sql` and `dump_schema_after_migration` is `false` in every environment.
The dumps are a reproducibility artifact, not a replacement for applying migrations to a clean
database.

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
   migrations.** Prepare the configured test databases with
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
The repository's `db:test:prepare` verifies the configured test database catalog and selected
database names, then invokes `DatabaseTasks.migrate(skip_initialize: true)` for each selected
writer. This executes migrations without importing dump receipts. Existing database contents are not
reset.

## Commands

```bash
# The configured test databases must exist. POSTGRESQL_TEST_PREPARE_DATABASES
# lists the writable test databases; the Dev Container environment supplies it.
RAILS_ENV=test bin/rails db:test:prepare

bin/rails db:verify_no_schema_drift
# Applies migrations to clean test databases and succeeds when the result matches
# the committed db/*_structure.sql files. Reports schema drift and exits 1 otherwise.
```

## Ordinary test databases and parallel workers

Tests use the fixed `test_*` databases in `config/database.yml`. There is no per-run PostgreSQL
fleet, manifest file, OID receipt or isolated-run environment variable. `db:test:prepare` checks the
configured test catalog and the explicit preparation list, then applies migrations without resetting
existing data. It does not create an additional database fleet.

Rails forks the test processes. The existing `ParallelTestDatabaseCloner` retains the ordinary
schema-stamped `test_*_<worker>` copies and explicitly selects the primary connection. Its SQL
TEMPLATE copies preserve migration-created reference rows and function ownership; Rails' default
schema-loading preparation still cannot reproduce these. See the
[reference-data backlog](../../plans/backlog/2026-10-20-reference-data-outside-migrations.md).
`PARALLEL_WORKERS=1` uses the configured base test databases directly and needs no worker receipt.

Avatar COMMIT and independent-connection tests use the same ordinary test database path. Their real
constraints, commits and concurrency assertions remain enabled. Committed rows are not undone by
transactional fixture rollback; tests retain their existing scoped synthetic-principal cleanup. The
ordinary clone cache checks schema freshness, not data cleanliness. Preparing migrations alone does
not reset committed rows. A dirty test database needs an explicitly authorized reset; do not
silently delete history or introduce a second database mode to hide contamination.

Minitest and browser E2E acquire `tmp/parallel-test-databases.lock` and refuse another owning
process. Do not run database preparation or reset concurrently with either command. E2E uses the
configured base test databases; it creates and drops no PostgreSQL databases.

The former isolated-fleet implementation and rebuild command are retired. Existing databases,
cluster roles, manifests and receipts are not deleted or adopted by this change. Any future cleanup
requires a separately reviewed inventory, risk and recovery plan. Historical evidence continues to
refer to the retired workflow and is not an instruction to execute it.

See the [replacement decision](../../adr/ordinary-test-databases-without-isolated-fleet.md).

## Setting preference public-ID capacity transition

The app, com and org setting databases enforce the standard storage ceiling for their owned
preference identities with separate, named PostgreSQL checks:

- `app_preferences_public_id_max_length`
- `com_preferences_public_id_max_length`
- `org_preferences_public_id_max_length`

Each pair of migrations first adds `char_length(public_id) <= 25` as `NOT VALID`, then validates the
check in a non-transactional migration. Existing identifiers are not shortened or regenerated;
normal issuance remains NanoID-21. A direct or bulk writer that bypasses Rails validation must still
be rejected by PostgreSQL, and the focused contract test exercises that boundary inside a savepoint.
The validation migration's down path restores the unvalidated check so reversing the additive
migration remains explicit and ordered.

This is a per-column P12a capacity slice. It does not authorize a global `change_column`, identify
the remaining unbounded columns as safe, or apply anything to shared or production data. Rebuild a
run-owned disposable database from migrations and run the focused contract plus the applicable
setting-model tests before relying on the check; include both full suites at the normal Gate 2.

The same staged method applies to the clearly owned app/com principal identities
`app_zenith.clients.public_id` and `com_zenith.visitors.public_id`. Migrations `20261012091000` add
the unvalidated named checks and `20261012091001` validates them. The direct SQL contract test
attempts an oversized update inside a savepoint, so a bypass writer cannot silently store a value
beyond the 25-character capacity. The checks preserve the existing string type and issued values;
`org_zenith.operators.public_id` is a separate 16-character human code and is not included. Rebuild
and rehearse these migrations only on an owned disposable database before any future retained-data
application.

The next P12a capacity slice applies the same staged method to the explicitly classified
self-controlled tables in `CAPACITY_TABLES` in
[`test/models/public_id_capacity_contract_test.rb`](../../test/models/public_id_capacity_contract_test.rb).
The owning database migrations are the paired
`202610120920xx_add_owned_public_id_capacity_checks_to_*.rb` and
`202610120921xx_validate_owned_public_id_capacity_checks_to_*.rb` files under
`db/app_zenith_migrate`, `db/com_zenith_migrate`, `db/org_zenith_migrate`, `db/op_base_app_migrate`,
`db/app_signals_migrate`, `db/com_signals_migrate`, `db/org_signals_migrate` and
`db/avatars_migrate`. The first migration adds each named `char_length(public_id) <= 25` check as
`NOT VALID`; the second validates it without a migration transaction. A direct/bulk oversized write
must be rejected by PostgreSQL, and the down path must return to the explicitly unvalidated state
before the additive check is removed. Rebuild a run-owned disposable database, run the
metadata/direct-write contract, rehearse every pair down and up, and regenerate each affected
structure dump before relying on this slice. Do not narrow a column, rewrite an issued value, or
include a provider/protocol ID, the ORG human code, or an unclassified inventory candidate by
analogy. The current disposable focused and Gate 2 result is recorded in
[`N9K4`](../../evidence/2026-10-12-public-id-capacity-gate-N9K4.md).

The same P12a boundary also covers the four remaining clearly self-controlled unbounded columns
selected by the semantic inventory: `app_zenith.members.public_id`,
`op_base_app.logout_transactions.public_id`, and `avatar.post_versions.public_id` plus
`avatar.posts.public_id`. Migrations `20261012093000`/`20261012093100`,
`20261012093001`/`20261012093101` and `20261012093002`/`20261012093102` add and validate the named
checks. The app-principal pair runs through the `app_zenith` database task because
`db/app_principals_migrate` is one of its migration paths. Rehearse those pairs on the same owned
disposable database and run the applicable Member/LogoutTransaction model coverage; do not include
the retired `legacy_replaced_clients` and `legacy_operator_department_accounts` tables until their
consumer and retention meaning is reviewed. Their empty disposable-run row counts do not prove that
retained foreign-key or historical-data obligations are absent. The focused and full-gate result for
this extension is recorded in
[`V2J6`](../../evidence/2026-10-12-public-id-capacity-extension-V2J6.md).

## Cluster role ownership

Identifier-HMAC maintenance roles are cluster-wide. Dropping a database does not establish ownership
of the roles left behind. Historical maintenance migration `down` methods contain unconditional
`DROP ROLE` operations; do not use them as a shared-cluster cleanup path. Removal requires explicit
risk/recovery approval and independently verified ownership, authority and dependencies. The retired
isolated-fleet rebuild command is no longer available.

## Troubleshooting a broken test database

Symptoms observed on 2026-10-20 explain why migration preparation and database reset are different
operations. Reset requires explicit risk/recovery approval.

| Symptom in `bin/rails test`                                                                                                                    | Cause                                                                                                                                                                                                                                                    | Fix                                                                                                                            |
| ---------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Thousands of `ActiveRecord::InvalidForeignKey` errors while loading fixtures, for example `client_passkeys` referencing a missing `clients` id | A non-transactional test failed before cleanup and left committed rows. PostgreSQL 18 revalidates foreign keys when fixture loading re-enables them                                                                                                      | Reset the affected test databases after approval. `db:test:prepare` alone keeps the leftover rows when no migration is pending |
| Hundreds of `Couldn't find OpAppProtocolEpoch with 'id'=1` (also Com/Org) or `identifier rotation function owner is invalid`                   | The databases were built by loading `db/*_structure.sql` (`db:test:load_schema`, or `db:migrate` on an empty database without `skip_initialize`). Reference rows that migrations insert are not in the dumps, and loaded functions carry the wrong owner | Rebuild from migrations only. Do not use schema load for the test fleet                                                        |
| `undefined method 'internal_string_options_for_primary_key'` at boot                                                                           | Rails revision change; see `evidence/2026-10-20-rails-182206b-compatibility-R3K9.md`                                                                                                                                                                     | Already fixed in `config/initializers/schema_migration_if_not_exists.rb`                                                       |

The following destructive sequence was used on 2026-10-20. It is a recovery reference, not
authorized setup: obtain explicit risk/recovery approval before executing it.

```bash
# POSTGRESQL_TEST_PREPARE_DATABASES must list every current writable test database (32 on
# 2026-10-20). If .env.container.devcontainer is stale, export the current list explicitly.
RAILS_ENV=test bin/rails db:drop db:create
RAILS_ENV=test bin/rails runner '
  ActiveRecord::Tasks::DatabaseTasks.with_temporary_pool_for_each(env: "test") do |pool|
    next if pool.db_config.replica?
    ActiveRecord::Tasks::DatabaseTasks.migrate(skip_initialize: true)
  end'
bin/rails test
```

Run a database-heavy experiment (for example adding validations to many models at once) only against
test databases with an approved recovery plan. The failing tests leave committed rows behind.

The long-term fix is tracked in `plans/backlog/2026-10-20-reference-data-outside-migrations.md`.

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
generated from test databases and are deterministic on repeat dump. On 2026-09-21, the isolated test
fleet was rebuilt from migrations, seeded twice, and dumped twice; all configured database versions
reached their expected current migration and the two dump sets matched. The reconstruction
verification is recorded in `evidence/2026-09-21-phase-09-reconstruction-X4Y5.md`.

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
5. After the inventory, bounded backfill, proof drain, writer control and consumer-readiness checks,
   apply the reviewed final-constraint migrations
   `20261012081257_add_not_null_check_to_operator_telephone_public_ids.rb` and
   `20261012081301_validate_operator_telephone_public_id_not_null.rb`. The first adds a `NOT VALID`
   `public_id IS NOT NULL` check; the second validates the existing nonblank and not-null checks
   before changing the column metadata and removing the transitional checks. A stale NULL or
   whitespace value fails the transition; the migration never invents or rewrites an identifier. The
   current run-owned test schema has rehearsed this sequence, but no production or shared-data
   cutover is claimed. The approved immutability trigger remains in
   `20261011024019_protect_operator_telephone_public_id.rb`.

Pre-cutover failure leaves the additive column and assigned IDs intact; stop and resume the
operational task after fixing the cause. Post-cutover recovery must preserve assigned IDs and proof
semantics rather than clearing the column or restoring a numeric proof fallback. There is no
automatic production application, legacy-table deletion or shared-cluster operation in these tasks.
See [identifier acceptance](../checklists/identifier-contracts.md) and separate per-run evidence.

## Owned preference and Client Passkey public-ID transition

The P12a rehearsal for `client_preferences`, `visitor_preferences`, `operator_preferences`, and
`client_passkeys` is a schema/maintenance transition only. Before applying the final constraint to
any permitted target, inventory NULL, blank and duplicate values and verify that each column is an
owned management identity. Do not infer ownership from the column name alone, and do not include
provider `webauthn_id` or `external_id` values in this transition.

Use the explicit `PublicIdNullOnlyBackfillOperation` with a bounded relation and batch size only
when a pre-cutover NULL row is genuinely present. It locks each row, assigns only when `public_id`
is NULL, preserves all other attributes and timestamps, retries only the named public-ID unique
constraint within its finite bound, and is safe to repeat. It is not a normal request-time repair
path. If inventory reports no missing rows, record the zero-row result and proceed without inventing
a backfill.

Apply the owning database's two migrations in order:

1. `20261012083817_add_not_null_checks_to_client_public_ids.rb` for APP, or the corresponding
   single-table migration for COM/ORG, which adds `NOT VALID` not-null and nonblank checks.
2. `20261012083823_validate_client_public_id_not_null.rb` for APP, or the corresponding single-table
   validation migration for COM/ORG, which validates both checks, changes the column to `NOT NULL`,
   and removes the temporary checks.

The validation migration deliberately uses `disable_ddl_transaction!`; Strong Migrations rejects
check validation inside a transaction that blocks writes. A down/up rehearsal must show that the
temporary checks are restored on down and the final `NOT NULL` metadata is restored on up. Generate
the affected structure dump from the same approved test database after the final state. This
procedure does not authorize production/shared-data changes, consumer cutover, or a broad identifier
reset.

## Staff identity audit-event bigint transition

The ORG identity-audit catalogue uses an identity-preserving staged mapping because its existing
event key is a string and `staff_identity_audits.event_id` references that string. Do not drop the
tables, truncate rows, force-cast the old key, or edit an applied migration. The additive migration
`20261012085039_convert_staff_identity_audit_events_to_bigint.rb` adds `legacy_id`, `id_bigint` and
`event_id_bigint`, together with the reviewed indexes. Before the final cutover, run the operation
in dry-run mode with an explicit bounded batch size, then run it only after its aggregate
missing/unresolved counts and ownership are understood:

```ruby
StaffIdentityAuditEventBigintBackfillOperation.call(dry_run: true, batch_size: 100)
StaffIdentityAuditEventBigintBackfillOperation.call(dry_run: false, batch_size: 100)
```

The operation locks each bounded batch, preserves the old code in `legacy_id`, assigns a bigint
mapping without reusing an existing mapping, and maps audit references only when the corresponding
event mapping exists. It raises on conflicting legacy values, missing event mappings, schema
incompleteness or bigint exhaustion. Repeating it after success is a no-op for already mapped rows;
a dry run writes nothing. Never use it as a request-time repair or against production/shared data.
Confirm the result from the catalog and aggregate counts without exporting event contents.

After mapping is complete, run the two cutover migrations in order:

```text
bundle exec rails db:migrate:org_zenith
```

`20261012100000_cut_over_staff_identity_audit_event_bigint_keys.rb` installs a staged bigint foreign
key, validates complete correspondence before swapping authority, retains the legacy code columns
and performs the narrow primary-key promotion. It then reattaches the foreign key to the new bigint
primary key. `20261012100100_validate_staff_identity_audit_event_bigint_foreign_key.rb` validates
the checks and FK, sets `legacy_id` and `event_id` non-null and removes the temporary checks. The
old string FK is not retained as a fallback.

For a disposable rollback rehearsal, run the validation migration down first, then the structural
migration down, and finally migrate back through both versions. Use the repository's versioned
multi-database task with `VERSION=20261012100000` and `VERSION=20261012092102` for the two down
targets, then `VERSION=20261012100100` for the final up. Insert one synthetic event/reference pair
before the rehearsal and verify that its bigint IDs and `legacy_id`/`legacy_event_id` values are
unchanged after the round trip. Never use this as a request-time repair or against production/shared
data.

The final schema has `staff_identity_audit_events.id` and `staff_identity_audits.event_id` as
non-null bigint keys, with the legacy codes retained as required correspondence values. The fixed
catalogue does not gain a sequence merely because its key is bigint; IDs come from the reviewed
mapping. In the final schema the retained backfill operation returns an explicit no-op.
