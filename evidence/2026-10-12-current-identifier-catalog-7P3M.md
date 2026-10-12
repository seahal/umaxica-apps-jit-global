# Current identifier catalog after the restart

Date: 2026-10-12  
Repository: `/home/global/workspace`  
Branch: `feature`  
HEAD: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`  
Scope: the run-owned twenty-database PostgreSQL manifest `tmp/acceptance-isolated-20261010p8b-primary.json`.

## Command

```text
RAILS_ENV=test PARALLEL_WORKERS=4 \
POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b \
POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json \
POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres \
POSTGRESQL_TEST_PREPARE_DATABASES=<the twenty manifest database names> \
REPORT=tmp/identifier-contract/resume-20261012-current.json \
bundle exec rails identifiers:inventory
```

The command completed successfully and scanned 20 writer connections and 892 catalog tables. It
reads PostgreSQL catalog metadata only; it does not read application rows or secret values.

The focused marker/barrier regression was then run against the same manifest:

```text
bundle exec rails test \
  test/models/avatar_ownership_cutover_barrier_test.rb \
  test/operations/avatar_ownership_cutover_operation_test.rb
```

Result: `5 runs, 74 assertions, 0 failures, 0 errors, 0 skips`.

## Observed facts

- Every scanned catalog reports zero missing primary keys and zero composite primary keys.
- The only non-bigint primary keys are the two Rails metadata tables, `ar_internal_metadata` and
  `schema_migrations`, which the inventory classifies as `framework:rails` on each connection.
- The previously reported `avatar_ownership_cutovers` primary-key observation is stale for the
  current tree. The additive migration `db/avatars_migrate/20261012130000_promote_avatar_ownership_cutover_key.rb`
  is present, and the current Avatar structure dump contains
  `avatar_ownership_cutovers_pkey` on its bigint `id` column.
- No Hash, invalid or unready indexes were reported.
- The inventory still contains the two reviewed unbounded legacy `public_id` candidates:
  `app_zenith.legacy_replaced_clients` and
  `org_zenith.legacy_operator_department_accounts`. Their retained foreign keys and historical
  ownership/retention meaning remain unresolved; no check, drop or rename was applied.
- The existing Group consumer evidence is consistent with the current D-2 specification: `account_surface`
  and `account_public_id` are selected-account context, while concrete organization ownership is
  resolved through ownership-period records. The semantic meaning is therefore not an open design
  choice; data reconciliation, writer quiescence and cutover remain operational work.

This catalog refresh corrects the old marker-key observation. It does not close semantic
identifier classification, permanent-ID immutability, the two legacy-table dispositions, or any
shared/production data transition. No database row, shared resource or production resource was
modified. The six Avatar migration drafts were also reconciled against the owning specification's
exact historical disposition table; they remain quarantined outside migration discovery, with no
new application or deletion action required.
