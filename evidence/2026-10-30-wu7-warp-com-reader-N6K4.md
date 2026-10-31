# WU-7 Warp com preference reader

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; prior and current changes were uncommitted.
- Warp com now verifies the shared preference JWT without loading a setting row or writing
  preference cookies. Its layout uses the verified language and theme, duplicate shared cookie
  names return 400, and an invalid JWT renders the default theme without clearing the cookie.
- `bin/rails test test/controllers/warp/com/roots_controller_test.rb`: 9 runs, 46 assertions,
  0 failures, 0 errors, 0 skips. The signed-token case observes SQL notifications and checks for
  no com preference queries.
- `bin/rubocop app/controllers/warp/com/application_controller.rb test/controllers/warp/com/roots_controller_test.rb`:
  2 files inspected, no offenses.
- A prior combined run failed during inherited full-fixture loading with foreign-key violations in
  `client_auth_admission_bindings` before any test assertions. The Warp root test uses an empty
  fixture set because its cases do not require fixtures; the combined suite was not rerun.
- Reader-only key distribution, rendered browser behavior, other public pages and remaining WU-7
  acceptance are not established by these checks.
