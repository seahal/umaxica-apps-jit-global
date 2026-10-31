# WU-7 com DBSC state-column removal ticket

The owner authorized destructive migration. This execution is limited to local
`test_com_setting_db`, excluding production and Neon. The migration removes the com preference
DBSC challenge, challenge timestamp, public key and session ID columns, including the dependent
session index. Immediately before preparation, the table contained two rows and each of the four
columns had zero non-null values. The migration locks the table and refuses any populated value.
The exclusive lock duration has not been measured.

The pre-change custom dump `/tmp/wu7-dbsc-fields-20261030/test_com_setting_db.dump` has SHA-256
`9a4d9eae85f7e8c3681b9e55e33c0df8adf185fb903f046d2be69f8c1b35df5f`; `pg_restore --list` succeeded.
The dump is transient and contains local test data. Restore has not been rehearsed. Recovery
requires stopping test writers, using `pg_restore --no-owner --no-acl` to restore the archive into
a separate local test database and validating its data and schema before any authorized target
replacement. The separate Chronicle database is not included. Restore duration is not measured.
