# HMAC role dependency recovery preflight

- Revision: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`; extensive pre-existing uncommitted changes
  affect the application. No application source was changed in this preflight.
- `bin/dev` exited 1 during `db:prepare`, before starting Web, Vite or jobs. Migration
  `20261008025001` rejected the APP email HMAC definer's foreign dependency on
  `leak_template_test_app_zenith_db`.
- Read-only `pg_database`, `pg_stat_activity` and `pg_shdepend` inspection confirmed foreign HMAC
  dependencies in both `leak_template_test_app_zenith_db` (OID 282878947) and
  `leak_template_test_org_zenith_db` (OID 282878956). Both are owned by `root`, have no database
  comment, and had no active connections. Their creation provenance remains unknown.
- Exact `count(*)` queries over public tables found 126 tables / 511 rows in APP and 111 tables /
  368 rows in ORG, including migration/reference metadata. No row values were printed. These totals
  do not establish that the databases are disposable.
- `pg_dump -Fc` completed for both databases. Restricted local backups are under
  `/tmp/umaxica-hmac-recovery-20261103/`; directory mode 0700, dump mode 0600. `pg_restore --list`
  read both archives successfully. An actual restore has not been rehearsed; recovery duration is
  unmeasured. These temporary backups do not provide durable storage beyond this environment.
- APP archive: `leak_template_test_app_zenith_db.dump`, SHA-256
  `7301e0777972e1e644b309d07ea632bea5883b8e6fd2cb05f66c0f5757b51180`.
- ORG archive: `leak_template_test_org_zenith_db.dump`, SHA-256
  `3f0eeef6bc192cb11a8752b282206cd17cecc3103a26b5b9e73a783e1d3cf5cb`.
- Proposed operation, pending explicit risk/recovery approval: recheck database OIDs, connections
  and counts; refresh archives if contents changed; drop only these two databases without forced
  connection termination. Preserve all roles, configured development/test databases, worker
  databases and other `leak_template_*` databases. Dropping these databases removes their data and
  foreign role dependencies and needs exclusive database locks; abort if connections appear rather
  than terminating them. No application notifications are involved in database deletion.
- Recovery: verify archive hashes, recreate each original database name owned by `root`, and restore
  its archive with ownership and ACLs preserved using `pg_restore --exit-on-error`. Required HMAC
  roles must remain intact. Recovery intentionally recreates the original foreign dependencies, so
  it also restores the startup blocker. No schema edits outside the existing recovery workflow are
  proposed.
- No databases, roles or application records were deleted, and no isolation checks were weakened. No
  Minitest/Vitest setup tests were added. Startup remains blocked pending the cleanup decision;
  subsequent migrations may reveal additional independent failures.
