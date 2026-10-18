# Current schema-drift verification — 2026-10-12

This is a read-only schema-dump comparison performed after the required Section 5.3, Section 16 and
Section 14.2 restart sequence. It verifies the current run-owned disposable databases against the
tracked dumps; it is not production migration or acceptance evidence.

- Repository: `/home/global/workspace`
- Branch: `feature`
- HEAD during the check: `3c6dfb7f2c246a05edb67eb9353373f5e0a11982`
- Rails environment: `test`
- Database scope: `tmp/acceptance-isolated-20261010p8b-primary.json`, all twenty non-replica writer
  databases, PostgreSQL 17.7 at the manifest host.
- Guard: `PARALLEL_WORKERS=4`, the manifest run ID and absolute manifest path, and the twenty
  manifest database names were supplied. The task writes schema dumps only to a temporary directory.

Command:

```text
RAILS_ENV=test PARALLEL_WORKERS=4 POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b \
POSTGRESQL_ISOLATED_TEST_MANIFEST=/home/global/workspace/tmp/acceptance-isolated-20261010p8b-primary.json \
POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres \
POSTGRESQL_TEST_PREPARE_DATABASES=<the twenty names recorded in the manifest> \
bundle exec rails db:verify_no_schema_drift
```

Observed result: `No schema drift detected in 20 schema dump file(s).` No migration, reset, drop,
role change, CI, Podman, production or shared-database operation was performed. Earlier evidence
recorded intended dirty dumps while a prior migration slice was still uncommitted; that historical
state does not describe this current checked-out commit and run-owned database pair.
