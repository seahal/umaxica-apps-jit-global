# WU-4 public surface and health verification

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Extensive uncommitted changes in the worktree affected the results.
- With `POSTGRESQL_TEST_PREPARE_DATABASES` set to the existing `.env` value and `PARALLEL_WORKERS=1`, `bin/rails test test/integration/routes/com_social_boundary_test.rb test/controllers/base/com test/controllers/warp/com test/integration/routes/base_authority_route_contract_test.rb test/integration/routes/warp_route_contract_test.rb test/integration/routes/preference_api_route_contract_test.rb` passed 43 runs and 570 assertions, with no failures, errors or skips.
- With the same environment settings, `bin/rails test test/integration/health_endpoints_test.rb test/integration/preference_web_csrf_test.rb` passed 38 runs and 2,257 assertions, with no failures, errors or skips.
- These checks do not cover all WU-3/WU-4 acceptance, the full suite, or external deployment. The existing database configuration test still expects the previous number of production connections and also includes TLS/required-setting assertions; it was not removed or weakened as part of this check.
- Rails test database preparation was used; no production persistence operation or external write was performed.
