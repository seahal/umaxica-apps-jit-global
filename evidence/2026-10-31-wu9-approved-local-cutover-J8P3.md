# WU-9 approved local cutover

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8` (checkpoint of the previously dirty worktree).
- The owner explicitly approved the named execution ticket and local test Preference cleanup in the
  conversation, then requested the checkpoint commit and resumption.
- The checkpoint commit used `LEFTHOOK=0`: the initial hook started automatic formatting/lint fixes
  and was stopped. Its unstaged changes were restored from the staged checkpoint snapshot. The
  checkpoint is not a passing acceptance result.
- This execution left uncommitted migration fixes, generated schema dumps, a concurrency-test
  correction, this record and the execution-ticket status update.

## Inventory and recovery

- Refreshed counts matched the latest ticket: development Preference parents/children were empty;
  each of four test parent tables had 2 rows. Test APP setting had 1 theme child; ORG setting had 2
  cookie and 1 theme child; each test principal database had 2 each of
  language/region/theme/timezone children.
- Counts of all matching Preference tables and parent NULLs were measured before mutation.
  Option/reference catalogs were excluded from cleanup. No NULL provenance was inferred.
- Private snapshots: `/tmp/wu9-approved-20261031T221244Z`. Each
  `pg_dump -Fc --no-owner --no-privileges` archive passed `pg_restore --list`. The checkpoint and
  all eight matching dumps are the recovery basis; destructive migration `down` cannot restore
  discarded values.

| Database                     | SHA-256                                                            |  Bytes |
| ---------------------------- | ------------------------------------------------------------------ | -----: |
| `development_app_setting_db` | `c67ba20dc114addbab0528f354e819e4fc8111ae70588567350bdf173e00b5a9` | 109206 |
| `development_org_setting_db` | `d2c1042a59f9e8a36fe91fdd8da55d692659b0fbf15feea1df56f5f666086dcb` | 109239 |
| `development_app_zenith_db`  | `12faf370c9052e77e463ae227a88be202848615de66aef959091b233c158bdcb` | 550397 |
| `development_org_zenith_db`  | `146aadc242b2a35a0f8d5b94c8f38c389f97675fefd347a512ed16cfebb9e803` | 444463 |
| `test_app_setting_db`        | `4e641af0e0ec87f65f5456ece7d112e7c67149e411315d61803a0b5766511c3e` | 109863 |
| `test_org_setting_db`        | `2257e4d323afd4c9bb60446e90ecfd9c32db97cf038b050dfb546d38256eba6a` | 109890 |
| `test_app_zenith_db`         | `7d0163bb91ea20d964630131fcc10513dfca11b36690bf04f6c82d084ab30e2a` | 566274 |
| `test_org_zenith_db`         | `e6e34ce73146624217796f48a9915ac2686c13cd5e1a57a131fc05ca4d8dd15c` | 451744 |

## Execution

- Cleared only approved test Preference parent/child rows in four local test databases, using one
  transaction per database, table locks and count assertions before deletion. Development had zero
  such rows.
- Ran `db:migrate:up:app_setting VERSION=20261031220000`, `org_setting` version `20261031220001`,
  `app_zenith` version `20261031220002`, and `org_zenith` version `20261031220003` under both
  development and test. All eight invocations succeeded after the fix below.
- Initial boot failed because the running shell lacked COM issuer metadata; subsequent commands
  supplied the checked-in local issuer, audience and empty revoked-kids environment values. No code
  defaults were added.
- First APP setting migration attempt timed out and rolled back: its nested Active Record reference
  model used another connection to read a table created in the still-open migration transaction.
  Fixed reference seeding in the APP setting, Client and Operator migrations to use the migration
  connection with quoted fixed IDs.
- Ran the four development `db:schema:dump:<connection>` tasks. Only the four target structure dumps
  changed at this point. Existing role-digest discrepancies are not claimed repaired.
- Production, Neon, DNS and external repositories were not accessed.

## Verification status

- Cutover migrations executed successfully; runtime acceptance, schema-drift check and closing
  full-suite comparison are not yet established by this record. Focused tests were started; their
  results will be appended after completion.
- WU-9 remains incomplete pending runtime acceptance.
