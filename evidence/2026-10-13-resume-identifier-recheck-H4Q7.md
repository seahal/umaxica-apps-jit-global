# Resume identifier recheck

Date: 2026-10-13 Branch: `feature` Code HEAD: `7576ff7cbc6787f7f80f1f42bfa538914ace6de1`

The worktree was already dirty with preserved implementation, test, migration, documentation and
evidence changes. This check did not reset, clean, stash, switch worktrees, commit, push, access
production, or modify a shared database. No secret values or application rows were written to the
evidence.

## Resume checks

The current run-owned PostgreSQL manifest was used without schema reset or migration. The read-only
identifier inventory scanned 20 writer connections and 892 tables. It reported zero missing or
composite primary keys, zero Hash indexes, zero invalid indexes and zero unready indexes. The only
non-bigint primary keys were the Rails-owned `schema_migrations` and `ar_internal_metadata` tables.

The catalog contained 238 `public_id` columns: 183 `varchar(21)`, 52 unbounded `varchar`, one
`varchar(255)` app principal value, one `varchar(25)` ORG telephone value and one `varchar(16)` ORG
human code. The existing P12a capacity checks cover the classified unbounded candidates and the
preference/principal targets. The only two unbounded names outside that reviewed inventory remain
`app_zenith.legacy_replaced_clients.public_id` and
`org_zenith.legacy_operator_department_accounts.public_id`; their retained foreign-key and
historical ownership paths keep them held for a separate consumer/retention decision. No value was
truncated, regenerated, narrowed or reclassified by this check.

The focused local Minitest sample was:

```text
bundle exec rails test \
  test/models/public_id_capacity_contract_test.rb \
  test/models/otp_failure_retention_test.rb \
  test/operations/dead_identifier_purge_test.rb
```

It completed with `108 runs, 735 assertions, 0 failures, 0 errors, 0 skips` using four workers and
the run-owned 20-database manifest. The test run did not execute the independent acceptance
investigation and does not establish shared or production data readiness.

## Disposition

The current source and schema inventory did not identify another reversible application slice that
can be changed safely without inventing a domain meaning, widening the approved trigger/SQL
authority, narrowing a retained legacy identifier, or activating an operational cutover. The
remaining work is therefore held at its owning boundary: acceptance matrices and final evidence,
D-11 committed-transaction isolation, host Alloy recreation/runtime verification, P10b/P12b
writer-controlled cutover, privacy-retention policy, historical HMAC-role rollback, the two retained
legacy identifier tables, and the unauthorized all-table database-immutability map. No acceptance
condition is marked complete by this record.

## Gate recheck after the slice review

After the identifier recheck, the required local full gates were run against the same run-owned
manifest without schema reset, migration, production access, or shared-database cleanup. The Rails
command used four workers and the 20-database manifest recorded above:

```text
RAILS_ENV=test PARALLEL_WORKERS=4 \
POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b \
POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json \
POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres \
POSTGRESQL_TEST_PREPARE_DATABASES="<manifest database names>" \
bundle exec rails test
```

It completed with `15,204 runs, 128,522 assertions, 0 failures, 0 errors, 0 skips` in 331.21
seconds. Vitest was run with `bun run test` and completed with `99` files and `1,140` tests passing.
`bin/rubocop` inspected 5,380 files with no offenses. `git diff --check` and
`scripts/check-repository-knowledge` also passed. Brakeman was not available as a local command, so
no Brakeman result is claimed. These checks are implementation evidence only; they do not replace
the independent acceptance investigation or establish production/runtime-host readiness.

The additional JavaScript checks were run without CI or deployment infrastructure:
`bun run format:check`, `bun run lint`, `bun run typecheck`, `bun run deadcode` and
`bun run openapi:lint` all exited successfully. The dead-code check reported only its existing
configuration hints for `@inertiajs/core` and `.css`; it reported no failure. No OpenAPI bundle
verification, deployment, host recreation or external service check was performed.
