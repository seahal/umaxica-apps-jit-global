# Setting Preference permanent-ID protection

Date: 2026-10-13. Full HEAD: `4828aeedd141b54163236672890799b9b01128c2`. The worktree was already
dirty with the preceding nine acceptance changes. This implementation adds three generated
migrations and their generated schema dumps, strengthens the setting ID tests, extends the exact
trigger inventory, and records the approved scope in the ADR/current docs. Unrelated work was
retained. No commit, production migration or remote operation was performed.

## Approval and implementation

The user accepted all three recommendations: a narrowly scoped database trigger exception for
`AppPreference`, `ComPreference` and `OrgPreference`, no ordinary operational mutation exception,
and investigation before proposing additional tables. The exception was recorded in
`adr/database-trigger-usage-boundary.md` before migration implementation. It explicitly authorizes
the needed OLD/NEW raw SQL DDL under the Rails migration boundary; no column or API shape changes.

The generated migrations are:

- `db/app_settings_migrate/20261013035713_protect_app_preference_public_id.rb`
- `db/com_settings_migrate/20261013035716_protect_com_preference_public_id.rb`
- `db/org_settings_migrate/20261013035720_protect_org_preference_public_id.rb`

Each creates a dedicated function and BEFORE UPDATE OF public_id trigger in the same migration.
`NEW.public_id IS DISTINCT FROM OLD.public_id` rejects replacement, NULL and blank with SQLSTATE
23514 and a stable table-specific constraint name. It never includes identifier values in the error,
silently restores the old value, generates an identity, performs a secondary write or changes
another table. Same-ID assignment and unrelated mutable state remain permitted. Logical deletion
does not disable the guard. INSERT generation is unchanged.

DDL uses the repository's 10-second lock timeout; trigger installation needs a table DDL lock and
must fail/retry if unavailable. No table rewrite or backfill occurs. The row-local comparison adds
no extra locks or cross-database dependency. Down removes the trigger before its function, without
rewriting rows; it also removes the protection, so production rollback remains an operational
decision. Administrator-trigger disabling is outside the claimed guarantee.

## Red and focused Green

The preceding `R8D4` evidence recorded twelve failing cases, one for each of four writers across the
three setting models. All accepted a changed identity instead of raising. Those assertions were
retained and strengthened to check SQLSTATE and exact diagnostic constraint name.

Additional cases cover NULL/empty/whitespace, same-ID bypass and upsert updates, an unrelated
`used_at` update, and immutable identity after logical deletion. Exact inventory tests require one
approved trigger on each target table. No global test helper or application test bypass changed.

After applying migrations to the verified `20261010p8b` fleet, the focused command ran
`test/models/setting_preference_public_id_immutability_test.rb` and
`test/models/enforcement_triggers_test.rb`: **31 runs, 103 assertions, zero failures/errors/skips**.
Targeted RuboCop passed all five changed/new Ruby files. `bun run test` passed 99 files / 1,140
tests.

The full Minitest run completed **15,250 tests, 128,977 assertions, one failure, zero errors/skips**
in 332.72 seconds. The sole failure is the previously reproduced ORG normal-passkey durable halt
audit (expected one `SIGN_FLOW_HALTED` record, actual zero). All twelve prior setting-identity
failures are resolved and no additional failure appeared. This is not a globally passing suite. The
repository knowledge checker passed with 71 selected documents and this evidence record;
`git diff --check` passed.

## Reversibility and schema observation

The independently owned `20261013n9a` rehearsal fleet was verified against its manifest before
writes. For each of the three target databases, a synthetic preference was created and the new
migration executed up/down/up through the actual Rails migration tasks. After each step its public
ID was unchanged; both function and trigger were absent after down and restored after up. A final
replacement attempt raised SQLSTATE 23514 and preserved the original ID. All three passed. No
original parent fleet was reset and no existing data was rewritten. Synthetic rehearsal rows remain
confined to the disposable n9a fleet.

`bin/rails db:schema:dump` generated changes only in `db/app_setting_structure.sql`,
`db/com_setting_structure.sql` and `db/org_setting_structure.sql`. Each diff contains exactly the
function, trigger and migration version (17 added lines per file). Dumps were not edited by hand.

`bin/rails db:verify_no_schema_drift` **failed** for those three files. Its implementation also
treats any unstaged tracked schema diff as drift; the intended migration-generated changes remain
uncommitted. This failure is retained, not concealed by staging/committing or weakening the task.
The task's actual database-to-file comparison was independently executed through its public
`SchemaDriftVerification.dump_matches?` method against freshly generated temporary dumps: **all 20
databases matched the current worktree schema files**. Thus the remaining gate failure is the
intended uncommitted schema diff, not a mismatch between these local databases and files.

Rails commands used the same verified-manifest wrapper as `N6A2`: `RAILS_ENV=test`, explicit
`POSTGRESQL_TEST_HOST=primary`, `POSTGRESQL_DATABASE=postgres`, the selected run ID/manifest and all
20 manifest database names in `POSTGRESQL_TEST_PREPARE_DATABASES`. The focused run and schema
commands used one worker; the broader suite used four. Rehearsal runner `/tmp/nine-id-reversible.rb`
invoked only the three named migration versions on n9a. After the full test process exited with
status 1, the read-only postflight verified all 20 p8b parent identities and zero remaining worker
databases. No manual cleanup was needed.

This closes the reproduced three-setting-table mutation defect within the approved local scope. It
does not close ID-4 for every identifier table, the remaining identifier inventory, or the separate
ORG normal-sign-in durable halt audit failure. Avatar's scoped acceptance and the user's other
exclusions remain unchanged.
