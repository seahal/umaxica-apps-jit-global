# Owner inventory classification contract

- Date: 2026-09-23
- HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: pre-existing changes were preserved. This slice changed only the inventory regression
  test and documentation/evidence; no migration, backfill, authority cutover, or external service
  was changed.

## Change

The public `AuthorityOwnerMigrationInventory` contract now has regression coverage for all three
direct surface bindings. The test creates isolated app, com, and org resources with inactive
identity bindings and with missing principals, then verifies the classifications
`inactive_identity_binding` and `missing_principal`. It also verifies that inventory output does
not expose database-local identifiers; only public identifiers are allowed in the report. Additional
cases create two active app organization memberships and one active membership on each com/org
surface. They verify that each result remains `membership_not_ownership`, retains its candidates,
and requires `manual_review` rather than selecting an owner.

This test data is disposable and does not represent production ownership. No owner is promoted and
no authority row is written.

## Verification

```text
PARALLEL_WORKERS=1 bin/rails test test/queries/authority_owner_migration_inventory_test.rb
```

Result: `6 runs, 85 assertions, 0 failures, 0 errors, 0 skips`.

The contract was extended with direct app/com/org cases whose identity binding is active but whose
principal is inactive. Each remains `inactive_principal`, `manual_review`, and
`source_is_authoritative_owner: false`. The extended focused test passed with
`7 runs, 97 assertions, 0 failures, 0 errors, 0 skips`.

`bin/rubocop test/queries/authority_owner_migration_inventory_test.rb` passed with no offenses,
and `git diff --check` passed.

The related authority/schema/model regression set was also run:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/queries/authority_owner_migration_inventory_test.rb \
  test/models/authority_schema_contract_test.rb \
  test/models/authority_vocabulary_test.rb \
  test/models/persona_enterprise_model_layer_test.rb \
  test/models/individual_company_model_layer_test.rb \
  test/models/agent_bureau_model_layer_test.rb
```

Result: `50 runs, 448 assertions, 0 failures, 0 errors, 0 skips`.

After the extension, the related authority/schema/model regression set passed with
`51 runs, 460 assertions, 0 failures, 0 errors, 0 skips`.

The full Rails suite was revalidated after this slice:

```text
set -a && . /home/global/workspace/.env.devcontainer.example && set +a && \
export UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example && \
export POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db,test_app_zenith_db && \
bin/rails test
```

Result: `11539 runs, 73460 assertions, 0 failures, 0 errors, 8 skips`.

After the inactive-principal regression addition, the full Rails suite was rerun and passed with
`11540 runs, 73472 assertions, 0 failures, 0 errors, 8 skips`.

The suite completed without changing application code to bypass the environment and without
contacting or modifying external services.

The real read-only inventory remains empty in the disposable test topology
(`authority_schema_state=applied`, `resources_scanned=0`). This test therefore strengthens the
classification behavior without closing the authoritative source-data, migration, or cutover
gate.

## Environment-scoped recheck

An initial manual invocation without an explicit `RAILS_ENV` was not used as authority evidence;
it observed four development-topology rows. The command was rerun with `RAILS_ENV=test` and the
explicit Compose-backed test environment:

```text
set -a && . /home/global/workspace/.env.devcontainer.example && set +a && \
export UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example && \
export POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db,test_app_zenith_db && \
export RAILS_ENV=test && bin/rails authority:owner_inventory
```

Result: `authority_schema_state=applied`, `resources_scanned=0`, and an empty classification set.
The non-test observation was not used for owner mapping, backfill, or cutover decisions.
