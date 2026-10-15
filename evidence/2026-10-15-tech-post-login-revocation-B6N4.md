# Tech revocation after successful browser callback

Recorded against commit `aa92265b7e63bf874fddd0aa8f278d5ed19de6b5` on 2026-10-15 UTC. The worktree
has extensive pre-existing uncommitted changes.

Added missing AT-050 request-sequence coverage to the existing integration-test class: complete the
Tech callback, successfully render the dashboard, revoke the current tech.access grant, then request
the dashboard again with the established browser cookies. The final response is 403/no-store,
contains the no-access heading and sign-out form, and omits protected tools content. The RP refresh
generation is unchanged, the parent remains usable, and the RP row is not revoked. Existing callback
transport doubles are retained: token and UserInfo HTTP responses are supplied from the production
coordinator's issued credentials. This is not live external-provider evidence.

Executed with the standard Rails test databases and the isolated-run identifier unset:

```text
env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/controllers/tech/org/oidc/callbacks_controller_test.rb test/controllers/tech/org/dashboards_controller_test.rb test/controllers/tech/org/sign/outs_controller_test.rb test/services/oidc/tech_operator_capability_exchange_test.rb
```

Result: 11 runs, 110 assertions, 0 failures, 0 errors, 0 skips. The callback file alone passed 3
runs and 50 assertions. The behavior already satisfied the new coverage; no production change was
required. Scoped diff checking passed. Browser/manual acceptance remains unverified.

Added AT-048 consumed-callback replay coverage in the same integration class. After a successful
callback, presenting the same code/state again returns 422 before a second token-client call; the
established RP and parent stay active and the dashboard remains accessible. The callback file then
passed 4 runs / 61 assertions / 0 failures / 0 errors / 0 skips. Targeted RuboCop reported no
offenses. The token-client call counter instruments the existing external transport double; protocol
validation and persistence run through the real controller and production owners.
