# Identifier contract catalog inventory

This record captures a read-only catalog observation for the P2/P6 implementation slices. It is
not an acceptance result and does not replace semantic producer/consumer review.

## Execution context

- Repository: `/home/global/workspace`
- Branch: `feature`
- HEAD: `a1ec83a7384a424c97671356268ec5c4ad8347d4`
- Worktree: already contained unrelated staged, unstaged, and untracked changes; they were
  preserved. No reset, clean, stash, migration, DDL, or application-row write was performed.
- Database target: run-owned disposable PostgreSQL databases from
  `tmp/acceptance-isolated-20261010p3d2-primary.json`.
- Isolation: `RAILS_ENV=test`, `PARALLEL_WORKERS=1`, and the manifest's database names were passed
  through `POSTGRESQL_TEST_PREPARE_DATABASES`.

## Command and result

The executed command was:

```text
RAILS_ENV=test PARALLEL_WORKERS=1 \
POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p3d2 \
POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p3d2-primary.json \
POSTGRESQL_TEST_PREPARE_DATABASES="<all database names from the manifest>" \
REPORT=tmp/identifier-contract/inventory-20261012.json \
bundle exec rails identifiers:inventory
```

The command completed successfully. It scanned 20 writer connections and 891 catalog tables. The
report contains only catalog metadata: table/schema/owner names, primary-key shape, identity or
owned-sequence metadata, candidate-name hints, and index access/uniqueness/predicate/validity
metadata. It does not contain application rows, identifiers, credentials, or secret values.

No Hash indexes, invalid indexes, or unready indexes were reported in the scanned catalogs.

## Findings requiring continued implementation review

- `org_zenith.public.staff_identity_audit_events` has a single `varchar` primary key. The existing
  identifier reference already records this as an unresolved application-owned PK violation; this
  inventory confirms it in the current isolated catalog. It is not classified as a framework
  exception.
- `avatar.public.avatar_ownership_cutovers` has a required `bigint id` and a valid unique B-tree
  index, but no PostgreSQL primary-key constraint. It is a singleton cutover marker and therefore
  needs an explicit contract disposition before the global single-bigint-PK criterion can be
  called complete. This observation does not authorize an unreviewed schema change.
- The remaining non-bigint primary-key counts are attributable to Rails metadata/reference tables
  in the report and still require the owning-table classification to be checked when the inventory
  is reconciled. The report intentionally does not declare any table compliant solely from its
  name.

## Limitations

The task provides the catalog half of the identifier inventory. It does not determine whether a
column is an owner ID, reference ID, protocol value, shared correlation ID, secret, or human-facing
code; nor does it discover all producers, readers, writers, API exposure, or cross-database
contracts. Those classifications remain P2/P6 work. The generated JSON under `tmp/` is ephemeral
and is not treated as a committed acceptance artifact.
