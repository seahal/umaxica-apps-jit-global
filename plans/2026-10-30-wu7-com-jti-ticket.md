# WU-7 com generation constraint ticket

The owner authorized destructive migration and rebuilding non-production databases. This ticket
covers local `test_com_setting_db` only; production and Neon are excluded. The migration makes
`com_preferences.jti` NOT NULL while preserving the existing unique index. It locks the table and
refuses NULL generations rather than inventing them. Local application requires resetting the
test database and deleting its data; lock and recovery durations have not been measured.

Before preparation, the database had 30 tables and 48 rows: 2 internal metadata, 2 consent,
2 language options, 2 region options, 2 statuses, 3 theme options, 1 theme, 8 timezone options,
2 preference parents and 24 migration rows. Both preference generations were NULL. The separate
test Chronicle database was dumped but its exact row count was not measured in this slice.

Pre-reset custom dumps were captured separately under the test process lock, are transient local
files containing test data, and are not a cross-database atomic snapshot. `pg_restore --list`
succeeded; restoration has not been rehearsed.

- `/tmp/wu7-jti-20261030/test_com_setting_db.dump`: SHA-256
  `617a87f5f905ba851d4296e226d967ba406bb441db8544092a675327c4511639`.
- `/tmp/wu7-jti-20261030/test_chronicle_db.dump`: SHA-256
  `5f4c31ad78b2b51c22f860e0677c4916f70ca13113cc155515ad2247e4c1e7a5`.

Recovery requires stopping writers, restoring each dump to a separate local database using
`pg_restore --no-owner --no-acl`, checking schema and parent/audit relationships, and replacing
the target only under owner authorization. A down migration cannot recover data lost by reset.
