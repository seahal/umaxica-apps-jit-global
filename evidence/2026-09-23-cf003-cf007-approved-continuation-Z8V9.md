# CF-003/CF-004 and CF-007 approved-decision continuation

- Date: 2026-09-23
- HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: pre-existing uncommitted changes were present; no commit, push, or GitHub write was performed.
- External access: no production, provider, AWS, Cloudflare, Base registry, or shared service write was attempted.

## Changes inspected and added

- `AuthorityOwnerMigrationInventory` now reads administrator-grant public identifiers only after
  the authority schema is present and classifies an administrator-only organization as
  `administrator_only`. Administrator relations remain manual-review evidence and are never used
  as owner authority.
- `RegionalRpClientMatrix.expected_registry_contract` now exposes the approved 13-cell expected
  registry shape from `AuthBoundaryAuthorityMap`. It records actor, region, logical key namespace,
  RP-session client binding, and canonical host/audience source without inventing values or
  activating the compatibility registry.
- `auth:regional_rp_contract` includes that expected contract in its local report.
- Frozen Plan, decision-input status, conflict dispositions, and the regional RP ADR describe the
  approved decision and the remaining fail-closed inputs.

## Static verification

The following checks passed:

```text
ruby -c app/queries/authority_owner_migration_inventory.rb
ruby -c app/values/regional_rp_client_matrix.rb
ruby -c lib/tasks/regional_rp_contract.rake
ruby -c test/queries/authority_owner_migration_inventory_test.rb
ruby -c test/values/regional_rp_client_matrix_test.rb
bundle exec rubocop app/queries/authority_owner_migration_inventory.rb \
  app/values/regional_rp_client_matrix.rb lib/tasks/regional_rp_contract.rake \
  test/queries/authority_owner_migration_inventory_test.rb \
  test/values/regional_rp_client_matrix_test.rb
git diff --check
```

RuboCop result: 5 files inspected, no offenses detected.

The full Brakeman scan passed with 0 errors and 0 security warnings. A dependency-light Ruby
runtime check instantiated the expected registry contract and confirmed 13 unique cells without
booting Rails or contacting a database.

## Environment and test verification

`config/credentials/test.key` was present. After `LocalEnvironment.load!`, all required PostgreSQL,
Valkey, and test-database-list variables were present; their values were not printed.

The required preflight command failed before application checks because the current process cannot
resolve the Compose service name:

```text
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

`getent hosts primary` and `getent hosts valkey-kvs` returned no records. No `podman` or `docker`
executable and no `/var/run/podman/podman.sock` were available in this process.

Per the test-environment rule, the focused Rails tests and full Rails suite were not started after
preflight failure. No test was deleted, skipped, mocked, or weakened.

## Current dispositions

- CF-003/CF-004: `OPEN — EVIDENCE REQUIRED`; the repository slice is present, but isolated
  PostgreSQL acceptance remains unverified in this process.
- CF-007: `OPEN — DECISION REQUIRED`; the logical matrix and expected contract are present, but an
  authoritative Side US host source and regional audience SSOT are still absent. No client was
  activated and no value was guessed.
