# Reference Data Lives Only in Migrations

Recorded 2026-10-20. Status: backlog, direction to be decided with the user.

## Problem

About 106 of 1645 migrations write data, including reference rows the application needs to run (for
example `OpAppProtocolEpoch` id 1). Those rows exist only in databases built by replaying
migrations. A database built from `db/*_structure.sql`, the standard Rails schema load used by
`db:prepare` and `db:test:prepare`, lacks them, and hundreds of tests fail. The committed dumps also
drift from a migrations-only build (`bin/rails db:verify_no_schema_drift` fails), so schema load is
not trustworthy either. See the troubleshooting section of `docs/operations/db-workflow.md`.

## Constraints from the user (2026-10-20)

- Develop the Rails way.
- Running seeds in production is a concern; production reference data should be managed by
  migrations.
- `structure.sql` stays: triggers, functions and complex constraints cannot be expressed in
  `schema.rb`, and neither format carries data.

## Directions discussed

1. Rails way (preferred so far): reference data in idempotent `db/seeds.rb` for development and new
   environments (`db:prepare` seeds only on create) and in fixtures for tests. Changes to existing
   production reference rows go through migrations, with seeds and fixtures updated in the same
   change. A test keeps seeds and fixtures in agreement.
2. Appending reference-table data to the dumps by extending `db:schema:dump`. This gives a single
   source, but it customizes Rails, so it moves away from the Rails way.

## Order of work

1. Inventory the data each migration writes and decide which tables are reference data.
2. Choose and apply the direction above.
3. Remove the schema drift: rebuild from migrations only and regenerate every dump in a separate
   change.
4. Confirm `bin/rails db:test:prepare` alone produces a passing fleet.
5. Record the rule for reference data in the harness rules.
