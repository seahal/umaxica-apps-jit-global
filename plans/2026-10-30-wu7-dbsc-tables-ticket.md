# WU-7 com DBSC reference-table removal ticket

The owner authorized destructive migration. The target is local `test_com_setting_db` only;
production and Neon are excluded. The migration removes `com_preference_binding_methods` and
`com_preference_dbsc_statuses`. Read-only measurement found IDs `[0, 1, 2]` in the first table
and `[0, 1, 2, 3, 4]` in the second, with no incoming foreign keys in the target database. The
operation destroys those eight reference rows. It locks both tables and refuses unexpected IDs.
Exclusive lock and recovery durations have not been measured.

The pre-change custom dump `/tmp/wu7-dbsc-reference-tables-20261030/test_com_setting_db.dump` has
SHA-256 `bb2dacc9e439af41b73eda2b73e4eb75d3306192557aa42bebed2aa5314945de`; its table of
contents was readable by `pg_restore --list`. It is transient, contains test data, and has not
been restored in this slice. Recovery requires stopping writers, restoring the archive to a
separate local database with `pg_restore --no-owner --no-acl`, verifying it, and replacing the
target only with owner authorization. The separate Chronicle database is not included.
