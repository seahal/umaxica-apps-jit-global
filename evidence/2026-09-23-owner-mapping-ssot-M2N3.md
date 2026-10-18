# Owner mapping SSOT slice

- Date: 2026-09-23
- HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: pre-existing uncommitted changes were present; no unrelated changes were reverted.
- Scope: make the approved six surface-local owner mapping the single Ruby-level source used by the quota policies as well as the migration inventory.

## Change

`AuthorityOwnerMigrationInventory::RESOURCE_KIND_BY_CATEGORY` now defines the approved account
and organization resource kind for each of `app`, `com`, and `org`. The account and organization
quota policies resolve their resource, ownership, lifecycle, and principal contracts from that
inventory instead of maintaining a second surface mapping.

The selector/switcher delegated-access graph was not changed. Membership, assignment, and avatar
relations remain separate from owner authority as required by the approved decision.

The public category/surface lookup rejects unknown inputs with `ArgumentError`, preserving the
repository's fail-fast unsupported-input convention rather than exposing a raw hash lookup error.

## Verification

Passed:

```text
ruby -c app/queries/authority_owner_migration_inventory.rb
ruby -c app/policies/acme/account_quota_policy.rb
ruby -c app/policies/acme/organization_quota_policy.rb
ruby -c test/queries/authority_owner_migration_inventory_test.rb
bundle exec rubocop app/queries/authority_owner_migration_inventory.rb app/policies/acme/account_quota_policy.rb app/policies/acme/organization_quota_policy.rb test/queries/authority_owner_migration_inventory_test.rb --format simple
4 files inspected, no offenses detected
```

The repository-wide Brakeman scan also passed with `0 errors` and `0 security warnings`.

The focused Rails test command was attempted with the repository test environment selected:

```text
UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db,test_app_zenith_db,test_com_zenith_db,test_org_zenith_db
PARALLEL_WORKERS=1 bin/rails test test/queries/authority_owner_migration_inventory_test.rb test/policies/acme/account_quota_policy_test.rb test/policies/acme/organization_quota_policy_test.rb test/policies/acme/owner_quota_surface_mapping_test.rb
```

It did not reach test assertions. Rails stopped while maintaining the test schema because the
current process could not resolve the PostgreSQL service name `primary`:

```text
ActiveRecord::DatabaseConnectionError: There is an issue connecting with your hostname: primary.
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

The full suite was not run after this focused-test failure. No application or test change was
made to bypass the database or substitute a localhost endpoint.
