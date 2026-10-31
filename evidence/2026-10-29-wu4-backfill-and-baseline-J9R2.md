# WU-4 backfill regression and baseline cleanup

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Extensive uncommitted worktree changes affected the results.
- The owner backfill operation rejected `Bureau`, a surviving org collective, while resolving direct resource identities. Like `Enterprise`, a `Bureau` has no account identity association; handling it as such restores the four surviving app/org resource-family cases.
- Removed a trailing comma in the dashboard Passkey journey's fixture declaration, which had caused the next class expression to be interpreted as a fixture name.
- With `POSTGRESQL_TEST_PREPARE_DATABASES` set to the existing `.env` value and `PARALLEL_WORKERS=1`, `bin/rails test test/operations/authority_owner_predeployment_backfill_operation_test.rb test/integration/base_dashboard_passkey_login_journey_test.rb` passed 5 runs and 70 assertions, with no failures, errors or skips.
- Removed the resolved `app/models/company.rb` explicit-visibility entry from both architecture baseline files. The first check exposed that the matching RuboCop todo entry also needed removal; after that correction, `bin/rails test test/tooling/architecture_baseline_test.rb` passed 3 runs and 2,342 assertions, with no failures, errors or skips.
- No full-suite rerun was performed after these changes. Test database preparation was used; no production persistence operation or external write was performed.
