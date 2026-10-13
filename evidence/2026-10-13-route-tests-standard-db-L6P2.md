# Routing Acceptance Follow-up on Standard Rails Test Databases

## Revision and worktree

- Full commit: `45ed455caa35c0efc2139c1969f541b5b3fc2242` on branch `feature`.
- The worktree was dirty before this check. The affected route test file was clean before the first
  run and was modified after that run exposed an expectation contradicting the accepted Step 3
  contract. Other in-progress plan changes remained uncommitted and were not staged by this check.
- `one.md` and `two.md` retain their frozen SHA-256 hashes.

## Checks performed

- `RAILS_ENV=test bin/rails db:migrate:status` exited 0: 20 database configurations, all named
  `test_*`; 1,429 migrations `up`, none `down` or `unknown`.
- `RAILS_ENV=test bin/rails db:verify_no_schema_drift` exited 0: no drift in 20 schema dump files.
- Initial route-test command returned one error because
  `test/integration/routes/auth_sign_ceremony_route_contract_test.rb` expected the retired
  `GET /sign/in/device` route to exist. Step 3's accepted contract requires the route to be absent.
  The test now checks that GET is unrecognized, preserving its existing checks for mutating verbs
  and the other Auth hosts.
- Final command passed:

  ```text
  PARALLEL_WORKERS=1 bin/rails test test/config/acme_public_resource_routes_test.rb test/config/routes_public_id_param_test.rb test/config/routing_entrypoints_test.rb test/controllers/auth/route_naming_test.rb test/integration/routes
  154 runs, 2766 assertions, 0 failures, 0 errors, 0 skips
  ```

- `bin/rubocop test/integration/routes/auth_sign_ceremony_route_contract_test.rb` exited 0 with no
  offenses.

## Limits

- The checks used only the standard Rails test database configurations. `PARALLEL_WORKERS=1` avoided
  creating parallel worker databases.
- No database reset or migration was run. The from-scratch migration acceptance remains unverified.
- No full Minitest or Vitest suite was run.
