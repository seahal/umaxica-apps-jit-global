# P3d focused test preparation: second migration blocker

Date: 2026-10-10 UTC  
HEAD: `2a1644f73238839ed7ed513bd4681ea393a86682`  
Worktree: existing dirty work was preserved; no source reset or checkout was performed.

## Check

After the stale `10.89.2.2` endpoint was replaced with the current `primary` hostname, the
focused test was retried with migration preparation limited to the three realm Zenith databases
used by the OTP model slice:

```text
RAILS_ENV=test PARALLEL_WORKERS=1 POSTGRESQL_TEST_HOST=primary \
POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b \
POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json \
POSTGRESQL_TEST_PREPARE_DATABASES=codex_integrity_20261010p8b_app_zenith,codex_integrity_20261010p8b_com_zenith,codex_integrity_20261010p8b_org_zenith \
timeout 300s bundle exec rails test test/models/otp_failure_retention_test.rb
```

The run did not reach Minitest. Migration preparation stopped in
`codex_integrity_20261010p8b_com_zenith` at
`20260513130000 RenameCustomerActorToVisitor` with the repository's intentional
`MigrationHelpersSafeTableRename::InconsistentState` error: both `customer_statuses` and
`visitor_statuses` exist.

Read-only inspection after the failed preparation found 28 recorded migrations in that database,
including `20260513121500`, but not the failing migration. The app and org Zenith databases still
have their pre-existing dump tables with no recorded migration versions. The earlier full-scope
attempt also showed `publishing_media_files` existing with an empty `schema_migrations` table.

The preparation command changed only the manifest-verified disposable targets by applying the
migrations that committed before the guarded failure. No shared, development, or production
database was targeted, and no manual table drop, rename, migration receipt insertion, or role
operation was performed.

The read-only safety probe was then run with the corrected `primary` host and accepted all 38
configured isolated roles while rejecting its six unsafe configuration probes. This confirms that
the existing manifest and role guard are usable for a later, explicitly authorized rebuild.

## Interpretation

The fleet is not a coherent migration baseline. Applying more migrations, adding a skip/fallback
to the strict rename, or manually inserting receipts would conceal schema drift. The guarded
isolated-fleet rebuild is the smallest coherent recovery, but it drops and recreates the exact
manifest-verified disposable databases and therefore remains a destructive operation requiring
explicit authorization. The OTP test is `BLOCKED`, not passing.
