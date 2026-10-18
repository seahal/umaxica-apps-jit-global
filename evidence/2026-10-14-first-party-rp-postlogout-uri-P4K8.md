# First-Party RP Post-Logout URI Contract

- Commit: `aa92265b7e63bf874fddd0aa8f278d5ed19de6b5`
- Worktree: dirty; 844 changed or untracked entries were present around the test run. The registry test was uncommitted; the documentation reconciliation followed the test.
- Scope: verify that all registered first-party RP post-logout destinations use `/sign/out/completion`, reject the old direct `/sign/out` return URI, and match Coordinator destinations.
- Command: `env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/values/oidc_client_registry_test.rb test/values/oidc_seven_first_party_rp_clients_test.rb test/services/acme_logout_transaction_coordinator_test.rb`
- Result: 14 runs, 254 assertions, 0 failures, 0 errors, 0 skips.
- Database boundary: standard Rails `test` configuration only; no isolated database, reset or migration was used.
- Additional checks: `bundle exec rubocop test/values/oidc_client_registry_test.rb` inspected 1 file with no offenses; `git diff --check` passed after the test and current-document updates.
- Limits: this verifies local registrations and Coordinator destinations. It does not verify a full IdP authority round trip, production registrations, or real-browser behavior. The global parent-and-RP transaction and first-party BCL removal remain open.
