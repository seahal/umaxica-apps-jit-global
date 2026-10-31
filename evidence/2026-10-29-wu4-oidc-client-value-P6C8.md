# WU-4 OIDC client configuration value

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Extensive uncommitted worktree changes affected this result.
- Renamed the shared `OidcClientRegistry::VisitorAccount` value to `ClientConfiguration` and updated its current application and test references. The value represents OIDC client configuration for surviving app and org clients, not a corporate visitor account. Its fields and methods were not changed.
- With `POSTGRESQL_TEST_PREPARE_DATABASES` set to the value already present in `.env` and `PARALLEL_WORKERS=1`, `bin/rails test test/services/oidc/client_registry_test.rb test/services/oidc/token_exchange_service_test.rb` passed 131 runs, 672 assertions, 0 failures, 0 errors and 0 skips.
- No full-suite rerun was performed after the rename. Rails test database preparation was used; no production persistence operation or external write was performed.
