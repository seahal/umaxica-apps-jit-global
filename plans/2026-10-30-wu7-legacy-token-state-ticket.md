# WU-7 com legacy token-state removal ticket

The owner authorized destructive migration and rebuilding non-production databases. This ticket
covers only local `test_com_setting_db`; production and Neon are excluded. The migration removes
`com_preferences.token_digest`, `used_at`, `replaced_by_id`, their indexes, and the replacement
foreign key. It refuses populated legacy state rather than silently discarding it. To apply it,
the test com setting database will be reset and rebuilt from migrations; all its rows are removed.

Immediately before preparation, the test database had 32 tables and 52 rows: 2 preferences,
2 consent children, 1 theme child, 3 binding-method references, 5 DBSC-status references,
2 language options, 2 region options, 2 statuses, 3 theme options, 8 timezone options,
2 internal metadata rows and 20 schema migration rows. Both preferences had token digests;
neither had a consumed timestamp or replacement ID. These test values are destroyed by the reset.
The migration acquires an exclusive table lock; lock and recovery durations are not yet measured.

Pre-reset dumps were made separately under the test process lock; they are not a cross-database
atomic snapshot and are transient local files containing test data:

- `/tmp/wu7-token-columns-20261030/test_com_setting_db.dump`: SHA-256
  `ee3876fe2fd53151fd7efb19ca1e7004a706b83968420b30af3faf434b7f1457`.
- `/tmp/wu7-token-columns-20261030/test_chronicle_db.dump`: SHA-256
  `cf8731c4e4a01806b3bea4543b750d9d90d4db18f8a2215e6fa602da140a00df`.

`pg_restore --list` succeeded for both; a database restore has not been rehearsed for these dumps.
Recovery requires stopping writers, restoring each archive into separate local databases with
`pg_restore --no-owner --no-acl`, checking schema and parent/audit relationships, and replacing
the target only with owner authorization. A down migration cannot recover removed values.
