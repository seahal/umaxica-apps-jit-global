# APP and ORG token/device ownership constraints

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting this check.
- While reviewing Passkey rename authorization, a temporary APP probe attempted to reassign a token's existing device to another Client; PostgreSQL refused the update with the composite token/device owner foreign key. The temporary test was removed. Both APP and ORG migration histories declare and validate the corresponding composite owner foreign keys.
- Added public model-boundary cases attempting to bind each realm's token to a different owner's device, inside rolled-back test transactions. Both were refused by the named composite foreign key and each token retained its original device. The two existing reverse current-token/session ownership cases also passed.
- `PARALLEL_WORKERS=1 bin/rails test test/models/client_token_test.rb test/models/operator_token_test.rb -n '/token_cannot_bind_a_device_session_belonging_to_another|device_session_rejects_a_current_token_owned_by_another_session/'`: 4 runs, 12 assertions, 0 failures, 0 errors. RuboCop and scoped `git diff --check` passed.
- These test-database results do not establish deployed schema state, behavior with constraints disabled or missing, or repair the separately documented outer Ticket transaction defects. No production code or database schema was changed.
