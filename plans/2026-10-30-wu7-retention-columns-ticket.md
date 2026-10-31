# WU-7 com legacy retention columns ticket

The owner authorized destructive migration and rebuilding non-production databases. The target
is only local `test_com_setting_db`; production and Neon are excluded. The migration removes
`discard_at`, `purge_eligible_at` and the dependent index from `com_preferences`, and refuses to
run with any existing preference row rather than inventing a disposition for retention or holds.
Applying it locally therefore requires resetting and rebuilding the test database, deleting all
its data. Lock and restore durations have not been measured.

Immediately before preparation, the target had 30 tables and 47 rows: 2 metadata, 2 consent,
2 language options, 2 region options, 2 status, 3 theme options, 1 theme, 8 timezone options,
2 preference parents and 23 schema migration rows. Both preference retention values were finite.
The separate `test_chronicle_db` held one com preference Chronicle; resetting the setting database
does not reset that audit database, and no cross-database consistency is assumed.

Pre-reset custom dumps, captured separately under the test process lock, are transient local files
containing test data. Their table of contents passed `pg_restore --list`; restoration has not been
rehearsed. They are not a cross-database atomic snapshot.

- `/tmp/wu7-retention-columns-20261030/test_com_setting_db.dump`: SHA-256
  `356cf3e34816c9a3ab4683986a0978c9d8cda1c9f5b9e9a0c65f16b5ebdaeb12`.
- `/tmp/wu7-retention-columns-20261030/test_chronicle_db.dump`: SHA-256
  `8b9293a3b06bc14d75531da111a80b12f3781199433b0a00428f29497b5f6e48`.

Recovery requires stopping writers, restoring both dumps into separate local databases with
`pg_restore --no-owner --no-acl`, validating the parent/audit relationship, and replacing a test
target only with owner authorization. A down migration cannot recover removed values.
