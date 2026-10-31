# Sign-in resend tests with owned transactions

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had uncommitted changes affecting this check.

After the resend transaction-ownership precondition, the previously recorded service/controller group had 21 failures because fixture transactions enclosed Auth and occurrence DB calls. The affected service and HTTP test classes now retain their other fixture transactions while disabling fixture transactions for `op_base_app` and `occurrence`. The tests clean up their own admission bindings, Auth sessions, parent transactions and identified occurrence bodies; randomized addresses and preflight assertions avoid deleting existing occurrence rows.

The service file passed separately (29 runs, 149 assertions), and the controller file passed separately (15 runs, 106 assertions). The combined command `PARALLEL_WORKERS=1 bin/rails test test/services/sign/in/otp_resend_service_test.rb test/controllers/auth/app/web/v0/in/email/otps_controller_test.rb test/services/sign_in_otp_resender_failures_test.rb test/concurrency/sign_in_otp_resend_serialization_test.rb test/integration/sign_in_otp_resend_committed_http_test.rb` passed: 57 runs, 322 assertions, no failures or errors. Scoped RuboCop passed after whitespace formatting; the combined test ran before the whitespace-only formatting.

These results supersede the 21 failures for this specific group. They do not establish that every other test calling the HTTP endpoint avoids enclosing either database in a fixture transaction; the full suite was not run. Real email delivery, complete signup paths, and resend cooldown timestamp precision remain unverified or unresolved.
