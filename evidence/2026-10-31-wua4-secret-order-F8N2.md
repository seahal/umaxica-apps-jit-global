# Secret rename ordering check

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- Worktree contained uncommitted changes, including the changes under test.
- `PARALLEL_WORKERS=1 bin/rails test test/operations/client_secret_name_committer_test.rb`: 10 runs, 135 assertions, no failures or errors.
- The added OP failure injection failed against the previous ordering because it observed the new name before consumption, then passed with OP consumption before the name and audit writes.
- The test is transactional and does not independently prove actual cross-database commit behavior. Resource-bound proof, dependency failure HTTP handling, and real separate-connection partial-commit verification remain incomplete.
- After adding a Zenith failure injection and dependency failure mapping, the same test file passed with 11 runs and 140 assertions. It observed the original name and no rename event, with Step-Up spent. These fixture-based tests do not establish the independently committed production behavior.
- The controller now maps the operation's storage dependency failure to 503; the HTTP response itself has not been integration-tested.
- After binding rename and revocation Step-Up to the Secret and connecting signed verification return paths, `PARALLEL_WORKERS=1 bin/rails test test/operations/client_secret_revocation_committer_test.rb test/operations/client_secret_name_committer_test.rb test/integration/step_up_authentication_test.rb` passed: 51 runs, 481 assertions, no failures or errors. This includes target mismatch, foreign signed target, and rename HTTP 503 coverage.
- `PARALLEL_WORKERS=1 bin/rails test test/integration/app_secret_login_journey_test.rb:653` failed with 401 at line 773, before its management rename/revocation steps. The cause and baseline status were not determined.
- `PARALLEL_WORKERS=1 bin/rails test test/operations/client_secret_storage_confirmation_concurrency_test.rb -n '/source audit failures/'` passed: 1 run, 14 assertions. With transactional wrapping disabled, it observed an OP commit before separately injected source audit failures in rename and revocation; each left proof spent and rolled back the name/revocation and audit. This verifies those particular failure points, not every XDB-05/07 window.
