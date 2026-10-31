# WU-9 Preference shape migration execution ticket

**Status:** owner approval required before any destructive migration runs. This ticket is limited to
the local APP/ORG development and test databases named below. Production and Neon are excluded.

**Worktree basis:** `336811e5072a93c0523e484f905082635b28f48f`; the worktree had extensive
pre-existing staged, unstaged, and untracked changes. No commit was created. The original counts
and snapshots below predate the WU-9 supplemental-state migrations, which have since been applied
additively to local development and test APP/ORG setting databases. No destructive WU-9 migration
has run. Re-measure all rows and NULLs and refresh the snapshots immediately before any future
destructive execution; the original snapshots are no longer a current recovery point.

## Target and destructive operations

The eight local databases are `development_app_setting_db`, `development_org_setting_db`,
`development_app_zenith_db`, `development_org_zenith_db`, `test_app_setting_db`,
`test_org_setting_db`, `test_app_zenith_db`, and `test_org_zenith_db`. Setting and Zenith migrations
remain separate as required by `two.md` §12.8.

The approved shape in `two.md` Appendix S removes these existing APP/ORG setting-parent columns:
`binding_method_id`, `dbsc_status_id`, `dbsc_challenge`, `dbsc_challenge_issued_at`,
`dbsc_public_key`, `dbsc_session_id`, `token_digest`, `used_at`, `replaced_by_id`,
`discard_at`, `purge_eligible_at`, and anonymous `explicit_fields`. The `*_preference_binding_methods`
and `*_preference_dbsc_statuses` reference tables are removed after their foreign keys and code
references are retired. Status references become `active`/`retired`; APP keeps id `0` as active and
id `1` as retired and removes its unused legacy id `2`; ORG keeps id `2` as active and id `1` as
retired.

The existing APP/ORG cookie tables retain their four non-null decision booleans. Their nullable
`consent_version` and `consented_at` columns are removed after the consent receipt tables are in
place. New receipt, browser-binding, Web Push option, and Web Push child tables are additive; Web
Push remains an option reference with the existing two-id check, not a boolean.

In `client_preferences` and `operator_preferences`, `user_id`/`staff_id` are renamed to
`client_id`/`operator_id`. Direct display snapshots, parent consent fields, and legacy explicit
metadata are removed in favor of the existing option child records and new explicit state. A
status reference and active-only actor uniqueness are added. The existing child and option tables,
including dormant `adult_content_gate` tables, are retained.

The APP/ORG supplemental receipt, binding, Web Push option, and Web Push child migrations have
been applied additively to the configured local development and test setting databases. Test rows
remain intact. No destructive WU-9 migration has been run. This ticket does not approve any
production/Neon operation.

## Measured local state

Read-only inventory commands were `bin/rails runner -` with the local development environment and
`RAILS_ENV=test bin/rails runner -` with the local test environment. They counted every table
matching each realm prefix and counted NULL values in affected legacy columns. All four development
parent tables and display/cookie child tables had zero rows:

| Database | Preference parent | Existing display/cookie children | Retired reference rows | Retained option/reference rows |
| --- | ---: | ---: | ---: | ---: |
| `development_app_setting_db` | `app_preferences`: 0 | 0 | binding methods: 3; DBSC statuses: 5; status references: 3 | option rows: 39 |
| `development_org_setting_db` | `org_preferences`: 0 | 0 | binding methods: 3; DBSC statuses: 5; status references: 2 | option rows: 34 |
| `development_app_zenith_db` | `client_preferences`: 0 | 0 | none | option rows: 39 |
| `development_org_zenith_db` | `operator_preferences`: 0 | 0 | none | option rows: 39 |
| `test_app_setting_db` | `app_preferences`: 2 | `app_preference_themes`: 1 | binding methods: 3; DBSC statuses: 5; status references: 3 | option rows: 40 |
| `test_org_setting_db` | `org_preferences`: 2 | cookies: 2; themes: 1 | binding methods: 3; DBSC statuses: 5; status references: 2 | option rows: 15 |
| `test_app_zenith_db` | `client_preferences`: 2 | language, region, theme, timezone: 2 each | none | option rows: 39 |
| `test_org_zenith_db` | `operator_preferences`: 2 | language, region, theme, timezone: 2 each | none | option rows: 17 |

Development database parent/cookie rows were empty. Test databases contain two parent rows in each
realm, plus the children above. In test APP setting, the two `app_preferences` rows have non-null
token digests and NULL DBSC challenge/key/session, replacement, and used-at fields. In test ORG
setting, the two preference cookies have NULL consent metadata, and the two parent rows have
non-null token digests. The test Zenith parent rows have non-NULL `explicit_fields`, consent metadata
and direct display values; each has four existing display children. These are existing test records,
not evidence of production data. Dropping their legacy columns will discard test values; the owner
decision says no existing-user migration is needed, but does not itself approve that destructive
operation. The option rows above are retained. Re-measure all rows and NULLs immediately before
execution; stop and resubmit this ticket if counts or affected columns differ. Do not classify or
infer any legacy `explicit_fields IS NULL` row.

### Post-additive-migration inventory (2026-10-31)

After the supplemental-state migrations were applied, a separate read-only query confirmed that the
new APP/ORG consent receipt, browser binding, Web Push option, and Web Push child tables each had
zero rows in both local development and test databases. Parent/selected child counts at that query:

| Database | Parent rows | Cookie children | Selected actor display children |
| --- | ---: | ---: | ---: |
| `development_app_setting_db` | 0 | 0 | n/a |
| `development_org_setting_db` | 0 | 0 | n/a |
| `test_app_setting_db` | 2 | 0 | n/a |
| `test_org_setting_db` | 2 | 2 | n/a |
| `test_app_zenith_db` | 2 | n/a | language/region/theme/timezone: 2 each |
| `test_org_zenith_db` | 2 | n/a | language/region/theme/timezone: 2 each |

These are local observations only. This query did not inspect or classify `explicit_fields`
provenance. The additive migration and focused-test
results are recorded in `evidence/2026-10-31-wu9-app-org-supplemental-state-W9P4.md`. Because the
original snapshots predate the new tables, they must be refreshed before any destructive migration.

## Recovery snapshot and rehearsal

Private local custom-format snapshots were created with `pg_dump --format=custom --no-owner
--no-privileges --host=primary --username=root` in
`/tmp/wu9-preference-shape-20261031/`:

| Database | Snapshot file SHA-256 | Size |
| --- | --- | ---: |
| `development_app_setting_db` | `ba80a0635ddd72ad7233058735f0dae97b92eb1e3ec63eb1edf9b3f05d3d8649` | 95,618 bytes |
| `development_org_setting_db` | `495351dcaec2ea2d26026ef96253e3e4bdcb3ad44165a223b078d86f2f99d7ec` | 95,651 bytes |
| `development_app_zenith_db` | `afdb961c0e1d9e17c560b57dc3114f78889400afb70186fdba95fb3d1183b4fa` | 550,397 bytes |
| `development_org_zenith_db` | `6aa7bc8b005f838f341c5645e5c7d7f6c065ef82495f473d93435968476f1ae5` | 444,463 bytes |
| `test_app_setting_db` | `0150e4100c7d6f596bb1e3b2e9a653e3a5620caf2434f741b0d80e042f2175ee` | 96,200 bytes |
| `test_org_setting_db` | `eb9f793a7017ba59b7e43cfc441ad4d3611e6202e0be4c3cb66d457c0ba853fe` | 96,226 bytes |
| `test_app_zenith_db` | `85c1d29ba3e66c003b619172ea3406bbe141129a63b18605e406f19d5658eae7` | 566,264 bytes |
| `test_org_zenith_db` | `80b8ba285129824f9e6400892e41b042a41677d90f86423f2ea62abad7199d51` | 451,733 bytes |

`pg_restore --list` succeeded for all eight dumps. Each dump was restored into a separate temporary
local database with `pg_restore --no-owner --no-acl`, checked for public base tables, then the
temporary database was removed:

| Snapshot | Restore target | Measured restore time | Public base tables after restore |
| --- | --- | ---: | ---: |
| APP setting | `wu9_restore_app_setting_db` | 130 ms | 29 |
| ORG setting | `wu9_restore_org_setting_db` | 128 ms | 29 |
| APP Zenith | `wu9_restore_app_zenith_db` | 629 ms | 125 |
| ORG Zenith | `wu9_restore_org_zenith_db` | 575 ms | 110 |
| APP setting test | `wu9_restore_app_setting_db` (reused after development target removal) | 131 ms | 29 |
| ORG setting test | `wu9_restore_org_setting_db` (reused after development target removal) | 139 ms | 29 |
| APP Zenith test | `wu9_restore_app_zenith_db` (reused after development target removal) | 704 ms | 125 |
| ORG Zenith test | `wu9_restore_org_zenith_db` (reused after development target removal) | 597 ms | 110 |

Recovery command template (restore to a separate target, verify schema/data, then direct traffic only
after restoring the matching pre-migration code):

```sh
PGPASSWORD=development pg_restore --host=primary --username=root \
  --dbname=<separate-target-db> --no-owner --no-acl \
  /tmp/wu9-preference-shape-20261031/<snapshot-file>.dump
```

The execution-day ticket must refresh all eight dumps and their hashes immediately before migration,
and preserve the exact pre-migration checkout together with the database snapshots. Restore the old
code and all eight matching databases as one recovery action. A migration `down` path is not claimed
to recover removed data. The timings above measure only this local restore rehearsal and do not
predict another environment's duration.

## Risks and gate

- Column/table drops take locks on the affected tables; local empty-table timings do not estimate
  production lock impact.
- If the rows change from the measured zero counts, the current no-data-loss assessment no longer
  applies. The execution must stop until a new inventory and owner-approved recovery plan exist.
- Existing account `explicit_fields = NULL` provenance is never inferred. If any account preference
  row or any such NULL row exists at execution time, stop and resubmit the ticket with a preservation
  plan that keeps those rows read-only; this ticket does not authorize classification or rewriting.
- Destructive DDL, row deletion, status-reference removal, and any value-clearing backfill require
  an explicit owner approval that identifies this ticket. Approval of the P0 ADR revisions does not
  approve these operations.

### Current local inventory and recovery snapshots (2026-10-31)

This refresh supersedes the row counts and snapshot hashes above for a future local execution review.
The read-only inventory used `bin/rails runner -` under `RAILS_ENV=development` and `RAILS_ENV=test`
against the four setting/Zenith databases in each environment. The test configuration supplied
local Preference COM issuer metadata on the runner command because the current local environment
does not define it. No migration or row mutation was performed by either inventory command.

| Database | Parent rows | Existing nullable or removable parent values | Consent cookie rows and nullable metadata |
| --- | ---: | --- | --- |
| `development_app_setting_db` | `app_preferences`: 0 | all inspected legacy columns: 0 NULL rows | `app_preference_cookies`: 0 |
| `development_org_setting_db` | `org_preferences`: 0 | all inspected legacy columns: 0 NULL rows | `org_preference_cookies`: 0 |
| `development_app_zenith_db` | `client_preferences`: 0 | all inspected actor columns: 0 NULL rows | n/a |
| `development_org_zenith_db` | `operator_preferences`: 0 | all inspected actor columns: 0 NULL rows | n/a |
| `test_app_setting_db` | `app_preferences`: 2 | each row has `token_digest`, `discard_at`, and `purge_eligible_at`; both have NULL DBSC challenge/key/session, `used_at`, and `replaced_by_id` | `app_preference_cookies`: 0 |
| `test_org_setting_db` | `org_preferences`: 2 | each row has `token_digest`, `discard_at`, and `purge_eligible_at`; both have NULL DBSC challenge/key/session, `used_at`, and `replaced_by_id` | `org_preference_cookies`: 2; both `consent_version` and `consented_at` values are NULL |
| `test_app_zenith_db` | `client_preferences`: 2 | `explicit_fields`, `user_id`, consent booleans, and direct display fields are non-NULL in both rows | n/a |
| `test_org_zenith_db` | `operator_preferences`: 2 | `explicit_fields`, `staff_id`, consent booleans, and direct display fields are non-NULL in both rows | n/a |

The setting reference counts remain APP binding methods 3 / DBSC statuses 5 / preference statuses 3,
and ORG binding methods 3 / DBSC statuses 5 / preference statuses 2. These test rows are local test
data. Removing the listed legacy values would discard them; the approved no-user-migration decision
does not itself approve dropping those test values.

Fresh private custom-format dumps for all eight databases are in
`/tmp/wu9-preference-shape-owner-approval-20261031/` (directory mode `0700`, file mode `0600`).
`pg_restore --list` succeeded for every dump. Their SHA-256 hashes and sizes are:

| Database | SHA-256 | Bytes |
| --- | --- | ---: |
| `development_app_setting_db` | `4ec8c832ab5b5e64696d5db900fd2fbc36f306a8957a2ca06167b0b331d4c266` | 109,206 |
| `development_org_setting_db` | `7fbf2405b16d34d92db05691c887fa6e177ad3037ea0a4effb405bdde9a06425` | 109,239 |
| `development_app_zenith_db` | `2cb3488b1734a64ef812055c7b52c14a9094c5fb7897472381e0f049c9c02a38` | 550,397 |
| `development_org_zenith_db` | `ca1417f2c0ab05ae2308f8dc098a65bb14363962e2c4ed67281e96c6d3266eaf` | 444,463 |
| `test_app_setting_db` | `90d4b657843696bc18ee7cbff74409261ea270acc5308ee03a72865673aeb9af` | 109,859 |
| `test_org_setting_db` | `577c545f0c17c9a09880a4fb9f182f1adaa9718a3b7ec935024109a2429ba645` | 109,885 |
| `test_app_zenith_db` | `d6d725b198863fad74d1935fddbf16ec38a4f0c175fb38640150120cab09f9b4` | 566,258 |
| `test_org_zenith_db` | `716fe46c63f9ded0edd69570fef4acd16fa88c70a646c875be359f565ce506b5` | 451,734 |

These dumps are approval-review recovery candidates, not permanent evidence and not an execution-day
backup guarantee. Immediately before any approved migration, repeat the row/NULL inventory, create
new dumps, verify their hashes and `pg_restore --list`, and stop if the inventory differs. Recovery
remains a coordinated restore of the matching pre-migration code and all eight affected databases
into separate local targets; production and Neon remain excluded. No destructive migration has been
run under this refresh.

### Refresh after focused WU-9 boundary tests (2026-10-31)

The read-only inventory and backups were refreshed after the latest focused APP/ORG, Visa, and logout
tests. Results are also recorded in
`evidence/2026-10-31-wu9-local-shape-preflight-refresh-N5L8.md`.

Development APP/ORG setting and Zenith Preference parents and child rows were all zero. In the test
databases, `app_preferences` and `org_preferences` each had 2 parent rows; APP had 1 theme child,
and ORG had 2 cookie children and 1 theme child. `client_preferences` and `operator_preferences`
each had 2 parent rows and 2 each of language, region, theme, and timezone children. Other Preference
child and new supplemental receipt/binding/Web Push rows were zero. Reference and option catalog
rows are excluded from destructive cleanup and must remain. The test `app_preferences` and
`org_preferences` each had NULL `jti` on both rows and NULL old `used_at`, `replaced_by_id`, and DBSC
fields. Both ORG cookie rows had NULL `consent_version` and `consented_at`. No test Client or Operator
row had NULL `explicit_fields`. If the approved operation clears these local test Preference records,
the values in those rows will be lost; they are not converted or inferred. Development databases
must be remeasured again immediately before execution.

Fresh custom-format snapshots were written under
`/tmp/wu9-preference-shape-approval-20261031-refresh/`. All eight passed `pg_restore --list`:

| Database | SHA-256 | Bytes |
| --- | --- | ---: |
| `development_app_setting_db` | `19c5e7af1e26d236c61853a37aabde63eed1c27def6d81d32126c2c6d355470d` | 109206 |
| `development_org_setting_db` | `5ba9d1b34b2684f1307c1eb2623e46071b7c406d9c9a52945ceb821f0fb86b98` | 109239 |
| `development_app_zenith_db` | `967423247c170121cf24b3fe8361f5e0441810789fe39e3c7ec0b037e724b03b` | 550397 |
| `development_org_zenith_db` | `5a876a7739d78f4df97ae476db29c006dba0dbea52c73c34926c10a52b223f81` | 444463 |
| `test_app_setting_db` | `d2956c1227a31b3a8934bdbc5d60158bb523aab012bccafafbc77943f473c17b` | 109849 |
| `test_org_setting_db` | `a4e342227c1657334b1abb5b630ba40e359402c55a337d919efe7744edc0d56c` | 109877 |
| `test_app_zenith_db` | `f9632b1a280affb1d559be55d79e261e6f9a1a05d7fdcc92c3f48efb43ee861c` | 566263 |
| `test_org_zenith_db` | `05e068f40124f15a85e1e403f97940426fb9f0332f5df051b8288371d1a89917` | 451736 |

No cleanup, destructive migration, database restore, or schema mutation has been performed. The
approval gate remains open. Before execution, repeat all affected counts; if they differ, stop and
refresh this ticket and its recovery plan. To recover, restore all eight matching snapshots into
separate local targets and restore the matching pre-migration checkout together; a migration `down`
is not a recovery path. Production and Neon remain excluded.
