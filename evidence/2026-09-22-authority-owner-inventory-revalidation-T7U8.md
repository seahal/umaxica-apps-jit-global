# Authority owner inventory revalidation

- Date: 2026-09-22 UTC
- HEAD: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
- Worktree: pre-existing changes were preserved; the connection-owner correction is uncommitted.
- Scope: restore the read-only owner-inventory command under Rails 8.2 deprecation-as-error and
  verify its public query contract.
- External writes: none. No migration, backfill, production/shared database, provider, AWS, or
  Cloudflare operation was performed.

## Red

The first read-only `authority:owner_inventory` invocation stopped during boot of the inventory
query with:

`ActiveSupport::DeprecationException: DEPRECATION WARNING: Called deprecated
ActiveRecord::Base.connection method.`

The failure originated in `AuthorityOwnerMigrationInventory#authority_schema_state`, which used
the deprecated connection accessor while test/development deprecations are configured to raise.

## Green

The query now uses the repository-supported `lease_connection` accessor. Verification completed
with:

- `test/queries/authority_owner_migration_inventory_test.rb`: 3 runs, 51 assertions, 0 failures,
  0 errors, 0 skips.
- `bundle exec rails authority:owner_inventory` against the isolated test environment: completed
  without a deprecation exception and wrote only `/tmp/umaxica-owner-inventory-20260922.json`.
- Task summary: `authority_schema_state: applied`, `resources_scanned: 0`, no classifications.
- Ruby syntax, targeted RuboCop, and `git diff --check`: passed.

## Boundary and remaining limitation

The task is read-only and does not apply the authored authority migrations or change owner data.
`resources_scanned: 0` means the isolated test databases contained no concrete Persona,
Organization, membership, or equivalent rows for the inventory to classify. Therefore this result
proves command execution and schema-state handling only; it does not prove owner mapping,
ambiguity resolution, backfill safety, or authorization cutover. `CF-003` remains open until a
reviewed representative data inventory and the separate migration/rollback/cutover gates pass.
