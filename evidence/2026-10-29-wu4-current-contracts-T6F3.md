# WU-4 current shared contract tests

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Extensive uncommitted changes affected all results. The inspected test files were already modified in the worktree at the start of this verification.
- The prior full-suite output contained removed Visitor references in these test areas. Current worktree tests use the surviving app/org cases.
- With `POSTGRESQL_TEST_PREPARE_DATABASES` set to the value already present in `.env` and `PARALLEL_WORKERS=1`, `bin/rails test test/operations/contact_registration_otp_verification_committer_test.rb` passed 34 runs and 532 assertions; `bin/rails test test/models/concerns/oidc_authorization_transactionable_test.rb` passed 13 runs and 145 assertions; `bin/rails test test/models/resource_grant_uniqueness_test.rb` passed 56 runs and 728 assertions. All three runs had 0 failures, errors and skips.
- These focused results do not replace a complete current-worktree suite run. Rails test database preparation was used; no production persistence operation or external write was performed.
