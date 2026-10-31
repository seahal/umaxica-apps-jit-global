# WU-7 com Preference schema change: draft execution ticket

Status: **not approved; do not execute**. This ticket covers a local/test database only. Production
and Neon are outside the requested scope. The exact migration and recovery rehearsal are not yet
prepared, so these observations are not an execution approval request.

## Proposed scope

Review the com-only before/after contract in `two.md` sections 4.3 and S. The proposed change
replaces the anonymous parent's legacy single-use/refresh/DBSC and nullable lifecycle shape with
explicit active/retired status and non-null issuance timestamps; replaces the cookie child's binding
digest with the separate browser-binding table; and moves nullable consent metadata to an explicit
receipt representation. Existing display children, adult-gate storage, Chronicle history and
account/other-realm data are not deletion targets. The concrete migration must identify every
column, constraint, reference row and dependent record before execution.

The untracked additive migrations are `20261030120000_create_com_preference_web_pushes.rb` and
`20261030164914_create_com_preference_browser_bindings.rb`. After the user's database reset and
requested full test run, both versions are recorded in the development and test com setting
databases. Neither is a substitute for the destructive shape review.

## Column-level shape to review

The following is a proposed target, not an executable migration or authorization to destroy data.
The column names and nullability were rechecked against both local databases on 2026-10-30.

| Object | Existing columns or records | Proposed treatment |
| --- | --- | --- |
| `com_preferences` | `binding_method_id`, `dbsc_status_id`, `dbsc_challenge`, `dbsc_challenge_issued_at`, `dbsc_public_key`, `dbsc_session_id`, `token_digest`, `used_at`, `replaced_by_id` | Remove legacy transport/single-use columns and their indexes and foreign keys after callers are replaced. Dropping `token_digest` destroys two non-null test values. |
| `com_preferences` | `discard_at`, `purge_eligible_at`, `explicit_fields` | Remove legacy lifecycle and anonymous explicit-state columns after the new lifecycle and retention checks exist. Existing retention/hold semantics and audit references must be accounted for before deletion. |
| `com_preferences` | nullable `jti`; existing `public_id`, `status_id`, timestamps | Retain unique public ID and jti, require jti NOT NULL, update the status reference to active/retired, and add NOT NULL `last_issued_at` and `last_issued_expires_at`. Both measured test rows have NULL jti and lack issuance snapshots: no safe backfill value has been established. |
| `com_preference_cookies` | NOT NULL consent/category booleans; nullable `consent_version`, `consented_at`, `browser_binding_digest` | Preserve the booleans. Replace the nullable consent metadata with a separate unique-per-preference consent receipt containing NOT NULL version and recorded time. Remove the legacy binding digest only after its data disposition is approved. Neither metadata nor digest is populated in the measured local rows. |
| `com_preference_binding_methods`, `com_preference_dbsc_statuses` | 3 and 5 reference rows respectively in both local databases | Remove only after their referencing columns and all remaining callers are removed. The exact reference-row deletion is subject to the same approval. |
| `com_preference_browser_bindings`, `com_preference_web_pushes` | Both additive tables exist and contain zero rows in each measured local database. | Retain; they are not deletion targets. The new binding table has a unique preference FK, while digest is not unique. |
| Display children/options and adult-content gate | Existing tables and references | Retain; verify uniqueness, foreign keys, and data before changing any constraint. Adult gate remains dormant. |

The two test parents and their consent children require an explicit owner decision. A subsequent
cross-database read found one Chronicle record referencing these parents, so deleting or recreating
the parents would also break an existing audit reference and is not proposed as an executable
operation. A trustworthy transformation that preserves parent identity and the audit relationship
has not been established. The measured NULLs do not authorize inventing a generation, issuance time
or consent receipt. `status_id` mappings and consent receipt behavior also need an exact reviewed
migration and matching runtime implementation before execution. The live development database has
no parent rows, but its reference rows and schema changes still require approval.

## Read-only measurement

Before the user's reset, a Rails runner on the writing connection identified the database as
`test_com_setting_db`. It used `SELECT COUNT(*)` and schema metadata only. These are test data,
not production estimates. Counts may change and must be repeated immediately before any approved
execution.

| Object | Rows |
| --- | ---: |
| `com_preferences` | 2 |
| `com_preference_cookies` | 2 |
| `com_preference_themes` | 1 |
| `com_preference_binding_methods` | 3 |
| `com_preference_dbsc_statuses` | 5 |
| `com_preference_web_pushes` | 0 |
| `com_preference_browser_bindings` | table absent |

After the reset and the full test run, a new read-only measurement on 2026-10-30 found both
additive tables present and both migration versions recorded. `test_com_setting_db` contained 2
preference parents, 2 consent rows, 3 binding-method references, 5 DBSC-status references, 0 Web
Push rows, and 0 browser-binding rows. Both parent token digests were non-null and both `jti`
values were null; the measured DBSC, consumed, replacement and consent metadata columns remained
null. `development_com_setting_db` contained no preference, consent, Web Push or browser-binding
rows, with 3 binding-method and 5 DBSC-status reference rows. These are local observations only;
the first table above is historical and counts must be remeasured before any approved operation.

Other present preference child tables have zero rows. Existing option/reference tables include
2 language, 2 region, 2 status, 3 theme and 8 timezone rows; other option tables have zero rows.
Both parent rows have a non-null legacy token digest and a null `jti`. Neither has non-null
`used_at`, DBSC challenge/key/session fields, or `replaced_by_id`. Both consent rows have null
`consent_version`, `consented_at`, and legacy browser-binding digest. This is not evidence that
their business data may be discarded.

The first measurement attempt stopped before querying because Rails rejected the deprecated
`connection` API. The successful retry used `connection_pool.with_connection`.

The measurement was repeated on 2026-10-30 using read-only counts and schema metadata. The current
`test_com_setting_db` still has 2 parents and 2 consent rows, 3 binding-method and 5 DBSC-status
references, and no browser-binding or Web Push rows. The current `development_com_setting_db` has
zero parents, consent, browser-binding and Web Push rows, and the same 3 and 5 reference rows.
All measured old DBSC, consumed, replacement, consent metadata and old binding digest fields are
NULL; both test parent token digests are non-NULL and both jtis are NULL. Counts must be repeated
immediately before an approved operation.

A further read-only test measurement found 2 consent children, 1 theme child and zero rows in the
other com Preference child tables containing `preference_id`. In the separate `test_chronicle_db`,
one `com_preference_chronicles` record references one of the measured parents. This check counts
that direct Chronicle association only; it does not establish the absence of other audit or hold
references. Any recovery plan must preserve or separately restore both setting and Chronicle data
and validate their cross-database association. No row or reference was changed by the measurement.

**Later incident:** The browser exercise and subsequent fixture test changed the test databases.
The parent count is now 5, with 3 Web Push and 3 browser-binding children; fixture loading failed
with foreign-key errors. Chronicle now contains one newly created audit row and the formerly
observed pre-existing audit row is no longer present. See
`evidence/2026-10-30-wu7-test-fixture-data-impact-X4R7.md`. Do not use the older counts above as
the current state. Recovery and test isolation must be resolved before any destructive schema work.
Sixteen worker Chronicle databases contain an older row associated with one of the original parents,
but their timestamps differ and the lost original's exact contents were not captured. Their records
are recovery candidates, not verified backups; see
`evidence/2026-10-30-wu7-chronicle-recovery-candidates-H7Q3.md`.
Post-incident custom-format snapshots of both current test databases and the 16 candidate Chronicle
tables have been retained locally; their location, checksum and limits are recorded in
`evidence/2026-10-30-wu7-recovery-snapshots-B7M4.md`. They do not contain a verified copy of the
lost original and have not been restored into a database.

The current worktree `db/com_setting_structure.sql` contains only 18 lines and does not describe
either measured schema. A read-only development schema dump to a temporary file produced 1,974
lines and includes both additive tables. The checked-in path has both staged and unstaged changes;
the dump was not copied over it. Schema-dump recovery and its interaction with existing work require
review before treating schema drift as resolved.

## Risk and recovery proposal

- Dropping or replacing columns can irreversibly discard token state and consent metadata; deleting
  parents or option rows can cascade to children or break foreign keys. A unique or NOT NULL
  constraint can reject existing data. A new status interpretation can change access decisions.
- Before execution, obtain the owner's approval of the exact migration, affected row counts, data
  treatment, expected lock duration, and chosen local/test target. Do not infer approval from this
  draft or from an empty column in the measured database.
- Before the approved operation, take a consistent PostgreSQL backup of the exact target and verify
  that it can be restored into a separate isolated database with matching schema and counts. Record
  the backup location, checksum, database identity, and restoration result without publishing
  credentials. Keep the backup under the owner's access and retention controls.
- Stop on any unexpected count, schema, dependency, or migration result. Restore the verified backup
  into an isolated database, validate the parent/child counts and representative data, and obtain
  approval before replacing or otherwise modifying the original target. Do not rely on a down
  migration to reconstruct discarded data.
- After an approved migration, generate the schema dump through the repository workflow, inspect
  its diff, run schema-drift verification and the scoped public behavior checks, and record actual
  results. No such execution or recovery rehearsal has occurred in this ticket.
