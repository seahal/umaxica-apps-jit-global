# Authority ownership-row retention verification

- Date: 2026-09-17
- Branch: `feature`
- Source HEAD at verification start: `e72d4e18c3f24fa6deffbda49300c659cbc314d1`
- Working tree: the ownership-retention slice plus pre-existing unrelated changes

## Change under verification

All six surface-local ownership models now reject direct `destroy` calls. Ownership transfer is
intended to update the existing ownership row and advance its revision; it must not delete the row
to create an ownerless interval. The model guard does not replace the database foreign keys or the
future transfer/lifecycle operation checks.

## Checks performed

- Ruby syntax checks for all six ownership models and
  `test/models/authority_schema_contract_test.rb` — passed.
- Targeted RuboCop over the six ownership models and the contract test — passed with no offenses.
- `git diff --check` — passed.

## Blocked or unverified

- `VALKEY_TEST_HOST=127.0.0.1 VALKEY_TEST_PORT=6379 CACHE_REDIS_URL=redis://127.0.0.1:6379/3 RATE_LIMIT_REDIS_URL=redis://127.0.0.1:6379/4 AUTH_STATE_REDIS_URL=redis://127.0.0.1:6379/5 VALKEY_NAMESPACE_RUN_ID=codex-20260917-authority bundle exec bin/rails test test/models/authority_schema_contract_test.rb`
  booted far enough to connect to the configured PostgreSQL host, but all three tests failed before
  assertions because the test surface schema is incomplete: PostgreSQL reported `PG::UndefinedTable`
  for `organizations`. The test Valkey service was not made available;
  `pg_isready -h valkey -p 6379` reported no response.
- The authority migrations have not been executed. Direct SQL `DELETE`/`delete_all` behavior and the
  complete transfer/lifecycle path remain unverified until the surface databases are provisioned.

## Follow-up verification: transfer identifier defaults

- Date: 2026-09-18 UTC
- The six transfer-request migrations no longer define an empty-string default for `public_id`. The
  existing `PublicId` model contract generates and validates the identifier at the model boundary;
  an empty database default is not needed and could create a fake identifier.
- `bundle exec ruby -c` over the three authority migrations and contract test — passed.
- `bundle exec rubocop` over the same four files — passed; no offenses.
- `VALKEY_TEST_HOST=127.0.0.1 VALKEY_TEST_PORT=6379 CACHE_REDIS_URL=redis://127.0.0.1:6379/3 RATE_LIMIT_REDIS_URL=redis://127.0.0.1:6379/4 AUTH_STATE_REDIS_URL=redis://127.0.0.1:6379/5 VALKEY_NAMESPACE_RUN_ID=codex-20260918-authority-schema PARALLEL_WORKERS=1 bundle exec bin/rails test test/models/authority_schema_contract_test.rb`
  — passed, 4 runs / 42 assertions / 0 failures / 0 errors / 0 skips.

The migrations remain unexecuted on populated or shared databases. This verifies authored schema
shape and model loading only; it does not prove migration execution, transfer behavior, or direct
SQL protection.
