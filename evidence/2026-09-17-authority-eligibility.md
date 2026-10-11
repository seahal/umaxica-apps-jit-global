# Authority creation eligibility verification

- Date: 2026-09-17 UTC
- Branch: `feature`
- Source HEAD at this verification: `4c5c0364c`
- Working tree: pre-existing `README.md` modification, `misc.md`/`refactor.md` deletions, and
  browser-block notification files were preserved and were not included in this slice.

## Change under verification

The six surface-local resource creators now require the locked concrete principal to have the fixed
surface status `ACTIVE`, `login_allowed?`, and `access_enabled?`. This prevents an inactive or
administratively locked principal from creating a new Persona or Organization authority row. The
regression tests also use collision-safe synthetic client IDs because the available isolated test
database retained rows from an interrupted earlier run; they do not delete or reset that database.
The creators remain unexposed until authority migration and current-data cutover gates pass.

## Checks performed

- Focused creator tests:
  `PARALLEL_WORKERS=1 VALKEY_TEST_HOST=127.0.0.1 VALKEY_TEST_PORT=6379 CACHE_REDIS_URL=redis://127.0.0.1:6379/3 RATE_LIMIT_REDIS_URL=redis://127.0.0.1:6379/4 AUTH_STATE_REDIS_URL=redis://127.0.0.1:6379/5 VALKEY_NAMESPACE_RUN_ID=codex-20260917-creator-fix-4 bundle exec bin/rails test test/operations/client_persona_creator_test.rb test/operations/enterprise_creator_test.rb test/operations/surface_resource_creators_test.rb`
  — passed, 16 runs / 85 assertions.
- Independent-connection creation race:
  `timeout 45s ... bundle exec bin/rails test test/operations/client_persona_creator_concurrency_test.rb`
  — passed, 1 run / 4 assertions.
- Authority vocabulary regression — passed, 3 runs / 11 assertions.
- Authority schema contract — passed, 3 runs / 36 assertions.
- Bundled RuboCop for the six creators, affected authority tests, and `test/test_helper.rb` — passed
  with no offenses.
- Ruby syntax checks for the changed Ruby files — passed.
- No migration, reset, destructive cleanup, external delivery, or production/shared database access
  was performed. The application used only the configured isolated test database and loopback test
  Valkey URLs for these commands.

## Remaining limits

These tests prove the fixed eligibility checks, creator rollback/validation behavior, and the
app-surface creation race only. They do not prove migration application, existing-data owner
mapping, transfer/lifecycle policy, or production cutover. The test database remains an incomplete
environment for the full suite, and the hostname-based Valkey service is still not an operational
worker-runtime proof.
