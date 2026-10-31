# WU-7 com DBSC reference-column removal ticket

The owner authorized destructive migration. This execution is scoped to local `test_com_setting_db`;
production and Neon are excluded. The migration removes `com_preferences.binding_method_id` and
`dbsc_status_id` and their dependent indexes and foreign keys. Reference tables are retained in
this slice. Before preparation the table contained two parent rows, both with zero-valued binding
and DBSC status; the reference tables contained three and five rows respectively. The migration
locks the parent table and refuses any nonzero value; such values need separate disposition.

The pre-change custom dump `/tmp/wu7-dbsc-columns-20261030/test_com_setting_db.dump` has SHA-256
`380e420e129a9c36f82b353a1dcc8252e17f89619a66318cb32a914b96cb9d0f`; `pg_restore --list` succeeded.
The file is transient and contains local test data. A restore has not been rehearsed for this
snapshot. To recover, stop writers and restore the archive into a separate local test database
using `pg_restore --no-owner --no-acl`, verify data and schema, then replace the test target only
under owner authorization. The Chronicle database is separate and was not captured in this dump.
The DDL takes an exclusive table lock; lock duration and recovery time have not been measured.
