# Authority owner inventory verification

Date: 2026-09-18 UTC Branch: `feature` HEAD: `0b0e014d1510b4790346bc4fa1bfe09252c44678` Working
tree: pre-existing staged/unstaged/untracked changes were present; this record covers only the
uncommitted owner-inventory files and does not claim those unrelated changes.

## Implemented boundary

`AuthorityOwnerMigrationInventory` and the `authority:owner_inventory` task are read-only. The
inventory covers `ClientPersona`, `Enterprise`, `Individual`, `Company`, `Agent`, and `Bureau` on
their independent `app`, `com`, and `org` connections. It treats RP identity bindings and active
membership rows as migration candidates only, never as authoritative owners. The report emits public
identifiers and classification values rather than internal numeric IDs or sensitive names.

The query reads resources and memberships in bounded batches, preloads the required associations,
and performs principal lookup per batch. It raises when the explicit authority table set is only
partially present. The task has no write/apply mode and does not change ownership, grants, lifecycle
state, or authorization behavior.

## Checks performed

The following checks passed:

- `bundle exec rubocop app/queries/authority_owner_migration_inventory.rb lib/tasks/authority_owner_inventory.rake test/queries/authority_owner_migration_inventory_test.rb`
- `ruby -c app/queries/authority_owner_migration_inventory.rb`
- `ruby -c lib/tasks/authority_owner_inventory.rake`
- `ruby -c test/queries/authority_owner_migration_inventory_test.rb`
- `git diff --check`

The following test was attempted with explicit test-only endpoints and namespaces:

```text
RAILS_ENV=test POSTGRESQL_TEST_HOST=127.0.0.1 POSTGRESQL_PORT=5432 \
VALKEY_TEST_HOST=127.0.0.1 VALKEY_TEST_PORT=6379 \
VALKEY_NAMESPACE_RUN_ID=authority-inventory-20260918 \
CACHE_REDIS_URL=redis://127.0.0.1:6379/3 \
RATE_LIMIT_REDIS_URL=redis://127.0.0.1:6379/4 \
AUTH_STATE_REDIS_URL=redis://127.0.0.1:6379/5 \
bin/rails test test/queries/authority_owner_migration_inventory_test.rb
```

Rails test boot reached Active Record schema maintenance and then reported
`ActiveRecord::ConnectionNotEstablished` / `PG::ConnectionBad` because `127.0.0.1:5432` was not
listening. `pg_isready -h 127.0.0.1 -p 5432` reported `no response`. No development, staging, or
production datastore was used, and no migration or inventory query was executed against a live
database. Valkey and worker runtime were not started in this check.

## Result

Static implementation verification passed. The Rails test and actual inventory report remain
UNVERIFIED until disposable isolated PostgreSQL and Valkey services are available. The authority
owner mapping and cutover remain blocked under CF-003; this slice does not enable either.

## Adversarial review

The review found two correctness risks in the first implementation: membership candidates were
filtered by `revoked_at`/`ends_at` without the existing membership-state and `starts_at` semantics,
and a malformed membership whose concrete Persona/Individual/Agent lacked its identity binding could
disappear from the candidate report. The implementation now uses the existing active-state contract
plus both temporal bounds, and retains an opaque legacy-resource identifier for that malformed case.
It still never promotes a candidate to an owner.

The review also checked that the query's class selection is fixed configuration rather than user
input, that all three surfaces use their own concrete connection/model mapping, that numeric IDs are
not serialized, and that resource/membership reads are batch-preloaded rather than per-row lookups.
Scoped syntax and RuboCop were rerun after the correction and passed. Database-backed classification
and query-count behavior remain unverified under the PostgreSQL boundary above.
