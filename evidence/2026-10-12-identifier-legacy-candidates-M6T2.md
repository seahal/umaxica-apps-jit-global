# P12a legacy identifier candidate review

Date: 2026-10-12

Repository: `/home/global/workspace`

Branch: `feature`

Code HEAD: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`

The worktree was already dirty and was preserved. This is a read-only P12a inventory and semantic
review; no application rows, identifier values, migrations or schema objects were changed.

## Inventory evidence

The command below was run against the 20 database entries in
`tmp/acceptance-isolated-20261010p8b-primary.json`:

```text
POSTGRESQL_TEST_PREPARE_DATABASES=<the 20 manifest database names> \
POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b \
POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json \
POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres RAILS_ENV=test PARALLEL_WORKERS=4 \
REPORT=tmp/identifier-contract/resume-20261012.json \
bundle exec rails identifiers:inventory
```

The report inspected 20 connections and 892 tables without reading application rows. It found 52
unbounded `public_id` columns. The current P12a `CAPACITY_TABLES` inventory and the already
reviewed target migrations cover 50 of them; the two remaining candidates are:

- `app_zenith.legacy_replaced_clients.public_id`
- `org_zenith.legacy_operator_department_accounts.public_id`

The disposable catalog reports both columns as required, unbounded `character varying` values with
existing unique B-tree indexes. It does not authorize a type change or a new check by itself.

## Ownership and consumer review

The current migration history identifies `legacy_replaced_clients` as the pre-consolidation table
renamed while `clients` became the current model table. Its schema still has foreign keys from the
retained `user_client_*` tables, but no current application model or runtime consumer was found in
the searched `app/`, `lib/`, `config/` and `test/` paths. The run-owned database had zero rows in
`legacy_replaced_clients` and its retained child tables.

`legacy_operator_department_accounts` is the pre-consolidation department-shaped operator table.
The migration comments state that current responsibilities moved to
`operator_workspace_accounts` and `operator_workspace_account_memberships`; the current
`OperatorWorkspaceAccountMembership` model uses the latter table. The schema still contains the
legacy `staff_operators` table and a foreign key to the legacy account table, so the legacy boundary
cannot be dropped or narrowed from this inventory alone. The run-owned database had zero rows in
the legacy account and `staff_operators` tables.

## Disposition

Both candidates remain outside ID-4f. They are retained legacy schema, not new issuance authority
and not an approval to issue arbitrary identifiers. No capacity migration was added because the
consumer, retained foreign-key and retention meaning are not sufficiently resolved. Adding a check,
renaming or dropping either table would require a separate bounded consumer/retention decision and
recovery plan. Empty disposable rows do not prove that shared or historical data has no obligation.

The durable references are [ID-4f](../docs/checklists/identifier-contracts.md#id-4f--classified-self-controlled-identifiers-have-bounded-database-capacity),
the identifier conventions reference and the current database workflow. This evidence closes the
inventory observation for the two remaining names but does not close P12a, ID-1 or any shared-data
cutover requirement.
