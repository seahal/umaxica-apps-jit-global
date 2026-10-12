# Setting preference public-ID capacity slice

Date: 2026-10-12

Repository: `/home/global/workspace`

Branch: `feature`

Code HEAD: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`

The worktree already contained 122 staged, unstaged or untracked paths before this slice. Those
changes were preserved; no reset, clean, stash, worktree, push, production operation or shared-
database operation was performed.

## Scope and Red

The slice covers only `app_preferences.public_id`, `com_preferences.public_id` and
`org_preferences.public_id`. All three models already issue NanoID-21 values and validate the
ordinary 21-character contract, but the disposable catalog showed unbounded PostgreSQL strings
with no capacity check. The new public contract test failed before the migrations were added:

```text
3 runs, 3 assertions, 3 failures, 0 errors, 0 skips
```

## Green implementation

The six migrations are:

- `db/app_settings_migrate/20261012090000_add_app_preference_public_id_capacity_check.rb`
- `db/app_settings_migrate/20261012090001_validate_app_preference_public_id_capacity_check.rb`
- `db/com_settings_migrate/20261012090000_add_com_preference_public_id_capacity_check.rb`
- `db/com_settings_migrate/20261012090001_validate_com_preference_public_id_capacity_check.rb`
- `db/org_settings_migrate/20261012090000_add_org_preference_public_id_capacity_check.rb`
- `db/org_settings_migrate/20261012090001_validate_org_preference_public_id_capacity_check.rb`

Each first adds a named `NOT VALID` `char_length(public_id) <= 25` check. The second validates it
outside a migration transaction and retains the database constraint. Its down path restores the
unvalidated form, and the additive migration's down path removes it. No value is truncated,
regenerated or rewritten.

The focused command was:

```text
RAILS_ENV=test PARALLEL_WORKERS=4 POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b \
POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json \
POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres \
POSTGRESQL_TEST_PREPARE_DATABASES=<the 20 names recorded in the manifest> \
bundle exec rails test test/models/public_id_capacity_contract_test.rb \
test/models/app_preference_test.rb test/models/com_preference_test.rb \
test/models/org_preference_test.rb
```

Observed result: `59 runs, 148 assertions, 0 failures, 0 errors, 0 skips`.

The contract test inspected the named constraints and attempted a 26-character direct SQL update
inside a savepoint for each table; PostgreSQL rejected every oversized write. Each migration pair
was run down and up in the run-owned setting databases, and the app/com/org setting structure
dumps were regenerated successfully.

The slice proves only this disposable-schema boundary. It does not close the remaining unbounded
identifier inventory, authorize a global column narrowing, validate shared/production rows or
establish all-table identifier acceptance.

## Gate 2 after the slice

The required full gates were run against the same twenty-database run-owned manifest after the
focused Green result. Rails used four workers and completed with:

```text
15099 runs, 128124 assertions, 0 failures, 0 errors, 0 skips
```

All four worker receipts recorded completed cleanup. `bun run test` completed with `99 files
passed` and `1140 tests passed`. These are current disposable-environment results and do not claim
completion of the remaining P12a inventory, production/shared data application or any unrelated
phase acceptance.
