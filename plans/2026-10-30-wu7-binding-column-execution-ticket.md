# WU-7 legacy com cookie binding column execution ticket

The owner explicitly requested execution of the destructive migration. This ticket covers only
`test_com_setting_db` on the local `primary` PostgreSQL service; production and Neon are excluded.

- Target: remove `com_preference_cookies.browser_binding_digest` and its dependent unique index
  `idx_com_pref_cookies_on_binding_digest`. The separate `com_preference_browser_bindings` table is
  retained. Other section 4.3 columns and data are outside this slice.
- Immediately before preparation, the test database contained two cookie rows, zero non-null old
  digests and zero separate binding rows. The migration explicitly stops if old digests exist.
- A custom-format pre-change test database dump is at
  `/tmp/wu7-binding-column-20261030/test_com_setting_db.dump`, SHA-256
  `0c171412acceff8d2decc3634a7bb1ad1d0430cfa9b3b153665270f641d8dc6c`.
  `pg_restore --list` succeeded; restoration has not been rehearsed. The file is transient and
  contains local test data.
- Risk: dropping the column takes a table lock, discards any values inserted after the check if
  concurrent writes are permitted, and cannot reconstruct their contents with a down migration.
  Hold the test process lock and stop concurrent writers. Lock duration and restore duration are
  not yet measured. The development and production databases are not affected by this execution.
- Recovery: stop database users; restore the dump to a separate local test database with
  `pg_restore --dbname <isolated-test-database> /tmp/wu7-binding-column-20261030/test_com_setting_db.dump`,
  verify schema and counts, then rebuild or replace the intended test target only under the owner's
  authorization. Restore the corresponding code version as needed. This procedure has not been
  exercised at the time of migration execution; see the later rehearsal below.

## Recovery rehearsal after execution

On 2026-10-30 the dump was restored with `pg_restore --no-owner --no-acl` into a newly created
local `test_wu7_binding_recovery_db`, under the test process lock. The combined create and restore
command took approximately 0.12 seconds. Read-only checks found two cookie rows, zero non-null
legacy digests, zero browser-binding rows, and the legacy index present; selecting the digest
column succeeded. This verifies these specific properties of the restored snapshot, not a full
application recovery or restoration of the separate Chronicle database. The recovery database
was left in place. The original test database was not replaced.
