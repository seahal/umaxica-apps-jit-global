# Palm callback replay preserves established credentials

Recorded on 2026-10-15 UTC against commit `7d4e2d941f4eb576eb77076c2c2a4e54badfa847`, with
uncommitted tests and documentation in the worktree.

Extended the real positive Palm callback sequence for AT-078 with reuse of its consumed code/state.
The replay returns 422 before another token exchange and preserves both established RP cookie
values, the active candidate RP row and the usable parent. Existing explicit external token and
UserInfo doubles remain; production-issued credentials, callback validation and persistence run. No
application behavior change was necessary.

Executed:

```text
env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/controllers/palm/app/oidc/callbacks_controller_test.rb test/controllers/palm/app/oidc_boundary_test.rb test/integration/base_palm_auth_entrypoints_test.rb
```

Result: 11 runs, 90 assertions, 0 failures, 0 errors, 0 skips. The selection also retains native
client code/refresh refusal and retired endpoint coverage. Targeted RuboCop inspected one file
without offenses; scoped diff check passed. Only ordinary Rails test databases were used. This does
not establish all Palm acceptance or external/manual browser results.
