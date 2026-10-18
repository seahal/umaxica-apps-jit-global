# P3d focused test preparation blocked

Date: 2026-10-10 UTC  
HEAD: `2a1644f73238839ed7ed513bd4681ea393a86682`  
Working tree: existing dirty tree preserved; 160 status entries were present before this check.

## Check

The focused Minitest command was run against the manifest-verified disposable fleet after
switching the effective test host from the stale `10.89.2.2` value to the current `primary`
hostname. The PostgreSQL server accepted the connection at `10.89.2.3:5432`, and the catalog
identity (database names, OIDs, owners, and disposable comments) matched the existing manifest.

The command was:

```text
RAILS_ENV=test PARALLEL_WORKERS=1 POSTGRESQL_TEST_HOST=primary \
POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b \
POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json \
POSTGRESQL_TEST_PREPARE_DATABASES=<the 20 databases listed by the manifest> \
timeout 240s bundle exec rails test test/models/otp_failure_retention_test.rb
```

The test did not reach Minitest. `db:test:prepare` attempted to replay
`20260716180000 CreatePublishingSchema` in `codex_integrity_20261010p8b_publishing` and
failed with `PG::DuplicateTable` because `publishing_media_files` already exists while that
database's `schema_migrations` table has no recorded versions. The same existing-table/empty-
migration-receipt shape is present in the inspected disposable publishing databases.

## Interpretation

This is a test-fleet schema/migration-receipt inconsistency, not a failure of the OTP test or
the P3d production change. No drop, create, migration repair, role change, or other database
mutation was performed. The focused test is `BLOCKED`, not passing.

The smallest recovery is to use the repository's guarded isolated-fleet rebuild procedure only
after explicit authorization for that destructive operation against the manifest-verified,
disposable fleet. The procedure must verify ownership, exact database identity, no active target
sessions, and scoped HMAC-role dependencies before drop/recreate. Until then, application
implementation slices that require Rails tests must not accumulate beyond the current slice.
