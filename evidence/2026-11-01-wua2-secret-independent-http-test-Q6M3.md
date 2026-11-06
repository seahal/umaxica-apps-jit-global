# WU-A2 APP Secret independent-commit HTTP test

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.

The worktree was already dirty with in-progress changes; those were preserved. No commit was
created.

The APP Secret HTTP test returned 503 before reaching its same-page GET assertion. The controller
rescued `ClientSecretClaimCommitter::TransactionConflict`: its source claim requires an independent
Zenith commit, while the default integration-test fixture transaction kept the Zenith connection
open. The test now runs outside fixture transactions and explicitly removes its created App, Auth,
Secret, Flow, and audit rows. No production behavior was changed.

The first non-transactional run reached all 18 assertions but teardown failed because cleanup used a
nonexistent `client_ref` column on `ClientContactAuditOutbox`. Cleanup now uses `owner_ref`; the one
App and email left by that failed teardown were identified by ID, checked for the expected single
email and no Secret rows, then removed from the local test database.

Verification:

- Before correction: `bin/rails test test/controllers/auth/app/in/secrets_controller_test.rb:134` —
  1 run, 4 assertions, 1 failure (expected 303, got 503).
- After correction: the T-SC-3 case — 1 run, 18 assertions, 0 failures, 0 errors, 0 skips.
- Whole file: `test/controllers/auth/app/in/secrets_controller_test.rb` — 18 runs, 172 assertions, 0
  failures, 0 errors, 0 skips.
- RuboCop on the test file: no offenses. `git diff --check`: passed.
- Post-run local Test database counts for the T-SC-3 credential and issuance query: both 0.
- The full suite was not run.
