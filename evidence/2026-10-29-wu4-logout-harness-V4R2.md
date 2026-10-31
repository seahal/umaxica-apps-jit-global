# WU-4 logout and bootstrap test repair

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Extensive uncommitted worktree changes affected the results.
- A prior `bin/rails test` finished with 17,024 runs, 128,622 assertions, 155 failures, 1,451 errors and 0 skips. Test files were changed while it ran, so static file-reading tests could observe a changing worktree and the result is not a clean snapshot of the current tree.
- Removed the deleted `OpComGrant` branch from the shared RP logout test setup. The earlier app-only bootstrap test adjustment was verified alongside surviving org logout cases.
- An ordinary focused run stopped before execution because the inherited `POSTGRESQL_TEST_PREPARE_DATABASES` included six databases no longer present in the current test database configuration. The repository-local `.env` already contained an updated list; selecting that existing value for this command allowed safety validation to pass.
- `POSTGRESQL_TEST_PREPARE_DATABASES="$(sed -n 's/^POSTGRESQL_TEST_PREPARE_DATABASES=//p' .env)" PARALLEL_WORKERS=1 bin/rails test test/operations/contact_registration_otp_bootstrap_finalizer_test.rb test/controllers/tech/org/sign/outs_controller_test.rb test/integration/oidc_logout_realm_acceptance_test.rb`: 22 runs, 520 assertions, no failures, errors or skips.
- No production persistence operation or external write was performed; Rails test database preparation used the configured test databases.
