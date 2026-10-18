# CSRF receiver and Base callback verification

- Commit: `6fa6867d44b5499632079775cb0fb22cbfddd339`, with inherited and task uncommitted changes affecting results.
- Scope: existing disposable TEST manifest, one Rails worker. No migrations or historical data changes.
- Initial seven-file targets failed two inherited COM/ORG tests expecting Base /oidc/callback to be unroutable (10 runs / 58 assertions / two failures, seed 59004). Canonical Task 13.2 requires that self-RP callback; app already asserted concrete ownership. COM/ORG tests now assert their precise Base callback show routes and continue rejecting retired /oidc/authorization. No production route or security control changed. These failures were not reproduced against Phase 0 and are not classified as baseline failures.
- GREEN: `bin/rails test test/integration/social_completion_cross_host_csrf_test.rb test/controllers/protocol_controller_csrf_boundary_test.rb test/controllers/auth/token_csrf_test.rb test/controllers/security/csrf_route_coverage_test.rb test/controllers/base/app/oidc/callbacks_controller_test.rb test/controllers/base/com/oidc/callbacks_controller_test.rb test/controllers/base/org/oidc/callbacks_controller_test.rb`: 10 runs / 64 assertions, zero failures/errors/skips (seed 37431).
- Scoped RuboCop: two changed callback route tests, no offenses.
- The social receiver test uses an invalid result reference. It does not certify successful provider callback staging/commit boundaries, the full Task 16.1 inventory, the broader attack matrix or real-browser behavior. No Task checkbox was completed.
