# WU-7 com anonymous explicit-fields removal ticket

The owner authorized destructive migration. This execution covers local `test_com_setting_db`
only, excluding production and Neon. It removes `com_preferences.explicit_fields`; actor-local
explicit metadata in other databases remains outside this operation. Before preparation the test
table held two rows, both containing an empty array. The migration locks the parent table and
refuses nonempty arrays; populated metadata requires a separate data disposition. Lock duration
has not been measured.

The pre-change custom dump `/tmp/wu7-explicit-fields-20261030/test_com_setting_db.dump` has SHA-256
`bdc149286a2b4aeb45cc3c060fad30874115532a690c17a668bb04247e52cfd0`; `pg_restore --list` succeeded.
The file is transient and contains local test data. Restore has not been rehearsed. To recover,
stop writers, restore it into a separate local test database with `pg_restore --no-owner --no-acl`,
verify schema and data, then replace the target only under owner authorization. Chronicle is a
separate database and is not included in this dump; restore duration has not been measured.
