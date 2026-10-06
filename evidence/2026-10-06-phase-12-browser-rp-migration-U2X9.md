# Phase 12 Browser RP migration evidence

Commit under test: `bfe569a162078df62e8e3b3011367840780e3078`.

The worktree was dirty before this phase and remains dirty. Unrelated staged, unstaged, and
untracked changes were preserved. Verification used the owned isolated test manifest
`tmp/auth-boundary-isolated-20261003auth6f3.json` with one worker and the explicit database
environment required by the repository test harness.

Implemented the shared Browser RP migration for Warp app/com/org, Edit org, and Core app/com/org.
The surface application controllers no longer include the generic client/visitor/operator
authentication concerns. Restricted-session and verification gates consume
`BrowserSessionSecurityContext`; Edit sign-out uses `edit-org`; Core browser refresh remains a
cookie-only shared-coordinator wrapper, and root/Bearer credentials are not accepted by the RP
surfaces.

Commands and observed results:

```text
bin/rails test test/controllers/edit/org/dashboards_controller_test.rb test/controllers/core/app/sign/outs_controller_test.rb test/controllers/warp/app/sign/outs_controller_test.rb test/controllers/warp/com/sign/outs_controller_test.rb test/controllers/warp/org/sign/outs_controller_test.rb
28 runs, 204 assertions, 0 failures, 0 errors, 0 skips

bin/rails test test/controllers/core/auth_boundary_test.rb
4 runs, 51 assertions, 0 failures, 0 errors, 0 skips

bin/rails test test/controllers/core/auth_boundary_test.rb test/controllers/core/app/sign/outs_controller_test.rb test/controllers/warp/app/sign/outs_controller_test.rb test/controllers/warp/com/sign/outs_controller_test.rb test/controllers/warp/org/sign/outs_controller_test.rb test/integration/core_browser_api_boundary_test.rb test/integration/core_browser_origin_boundary_test.rb test/unit/security/authentication_mode_inventory_test.rb test/integration/routes/route_target_contract_test.rb
66 runs, 511 assertions, 0 failures, 0 errors, 0 skips
```

`bin/rails zeitwerk:check` was also green after the Phase 12 controller and concern changes.
