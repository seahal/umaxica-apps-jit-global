# WU-7 local issuance snapshot migration ticket

The owner authorized destructive migration and rebuilding non-production databases. Scope is the
local `test_com_setting_db` only; production and Neon are excluded. A test database reset deletes
all rows in that database. Immediately before preparation it contained two preference parents,
two cookie children, zero browser bindings and zero web-push rows. Other tables are also reset.

The migration adds NOT NULL `last_issued_at` and `last_issued_expires_at` without fabricated
backfill, refusing to run when a preference parent exists. Rebuilding the test database first
replays existing migrations on an empty database. The reset also discards any other local test
setting rows. A read-only count before reset found 32 tables, 49 rows total, and 12 nonempty tables:
2 `ar_internal_metadata`, 3 binding methods, 2 cookies, 5 DBSC statuses, 2 language options,
2 region options, 2 statuses, 3 theme options, 1 theme, 8 timezone options, 2 preference parents,
and 17 `schema_migrations`. Do not run this reset against development,
production, or Neon. An exclusive table lock is taken during the new migration; lock duration has
not been measured.

Before reset, `/tmp/wu7-issuance-20261030/test_com_setting_db.dump` was created, SHA-256
`480ed01cdd116ad1ba8380f7695046a9b4a103246ac2e940f4f3327357cc608d`; `pg_restore --list`
succeeded. The snapshot is transient and contains local test data. It was not restored in this
slice. Recovery requires stopping test writers, restoring that archive using `pg_restore --no-owner
--no-acl` into a separate local database, validating the restored schema and data, and replacing
the test target only under owner authorization. The corresponding pre-reset Chronicle database
was not captured in this snapshot; cross-database consistency is not established. Restore time
has not been measured.
