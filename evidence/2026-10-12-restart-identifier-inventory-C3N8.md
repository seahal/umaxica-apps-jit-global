# Restart identifier catalog inventory — 2026-10-12

This is a read-only catalog check performed after the required Section 5.3, Section 16 and Section
14.2 restart sequence. It records current database facts only; it does not classify every candidate
column or constitute ID-1 acceptance.

- Repository: `/home/global/workspace`
- Branch: `feature`
- HEAD during the check: `01ee05268aa09bec42cc89db8e38d7de99d3f574`
- Rails environment: `test`
- Database scope: the existing run-owned manifest
  `tmp/acceptance-isolated-20261010p8b-primary.json`, twenty configured non-replica writers,
  PostgreSQL 17.7 at the manifest host, and no shared or production database.
- Preparation guard: `PARALLEL_WORKERS=4`, the manifest run ID and absolute manifest path, and the
  twenty manifest database names were supplied. The inventory performs catalog-only reads and wrote
  only the ignored report `tmp/identifier-contract/restart-inventory.json`.

Command:

```text
RAILS_ENV=test PARALLEL_WORKERS=4 POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b \
POSTGRESQL_ISOLATED_TEST_MANIFEST=/home/global/workspace/tmp/acceptance-isolated-20261010p8b-primary.json \
POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres \
POSTGRESQL_TEST_PREPARE_DATABASES=<the twenty names recorded in the manifest> \
REPORT=tmp/identifier-contract/restart-inventory.json \
bundle exec rails identifiers:inventory
```

Observed result: `20` connections and `892` tables scanned. Every connection reported zero missing
primary keys, zero composite primary keys, zero Hash indexes, zero invalid indexes and zero unready
indexes. The two non-bigint primary keys reported per connection are the Rails-owned
`schema_migrations` and `ar_internal_metadata` tables; no application-owned non-bigint primary key
was reported by this catalog inventory. Candidate-column counts are hints only and do not replace
the semantic owner/consumer review required by ID-1 through ID-8.

No migration, schema dump, role change, reset, drop, CI, Podman, production or shared-database
operation was performed. The two retained legacy public-ID tables and all other semantic exceptions
remain governed by their existing review holds.
