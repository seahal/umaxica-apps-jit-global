# Rails controller coverage batch 31

## Context

- Implementation date/time: 2026-07-18, UTC
- Scope: one short, test-only controller coverage cycle before the host shutdown window
- Starting controller line coverage: 21,860 / 24,933 (87.6750%)
- Starting full Rails line coverage: 45,468 / 49,152 (92.5049%)
- VP/Vitest: explicitly out of scope
- Relevant rules reviewed: controller boundaries, routing, surfaces, controller inheritance,
  testing, no-test-only-code, controller lifecycle, and implementation notes

## Selection and test addition

- Selected `app/controllers/concerns/sign_out_notice.rb` because its unexecuted route-helper
  variants are deterministic, use an existing concern test harness, require no application behavior
  changes, and can cover several lines with one focused test.
- Added one test to `test/controllers/concerns/sign_out_notice_test.rb` that verifies the generated
  path/URL helper names, preservation of `ri` and `logout_challenge`, optional host forwarding,
  removal of nil options, and the confirmation-form path delegation.
- Expected newly exercised application lines: 67, 71, 79, 87, 95, 103, and 107.
- Application, database, route, fixture, factory, configuration, and dependency changes: none.
- Dead-code changes: none.

## Verification and blocker

- Command attempted twice: `bin/rails test test/controllers/concerns/sign_out_notice_test.rb`
- Both attempts stopped during Rails initialization before loading the test because
  `config/initializers/mission_control_jobs.rb` referenced an unavailable `MissionControl` constant.
- This failure occurred before any added assertion ran and is not evidence of a failure in the added
  test.
- The runtime stack mentioned repository-vendored and external gem paths. They were treated only as
  runtime context and were not opened or diagnosed.
- Ending controller and full Rails coverage: not measured because Rails could not boot and the
  30-minute shutdown window made a full coverage run unsafe.
- Ending failures/errors: no test result was produced; both commands exited during boot with one
  `NameError`.

## Risk decisions

- No authentication, logout, OIDC, session, token, CSRF, or controller implementation was changed.
- No broader controller was selected after the repeated boot blocker.
- No configuration or dependency repair was attempted because those files and actions were outside
  the test-only scope.

## Follow-up

- Once Rails boots normally, run `bin/rails test test/controllers/concerns/sign_out_notice_test.rb`
  first.
- If it passes, include it in the next scheduled full Rails coverage run and confirm the expected
  seven-line gain in `sign_out_notice.rb`.
- If it fails, repair or remove only the newly added test; do not change controller implementation
  to accommodate it.
