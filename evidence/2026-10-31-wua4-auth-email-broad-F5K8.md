# Auth Email OTP broader regression run

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had extensive uncommitted changes, including the code under test.
- `PARALLEL_WORKERS=1 bin/rails test test/mailers/email/auth_email_otp_delivery_binding_test.rb test/controllers/auth/app/in/emails_controller_test.rb test/controllers/auth/app/in/emails_controller_extra_test.rb test/controllers/auth/app/in/emails_controller_security_test.rb test/controllers/auth/app/in/emails_controller_enumeration_test.rb test/controllers/auth/app/web/v0/in/email/otps_controller_test.rb` produced 94 runs, 757 assertions, 0 failures, 8 errors, 0 skips.
- Both `Auth::App::In::EmailsControllerEnumerationTest` error IDs and all six `Auth::App::Sign::In::EmailsControllerExtraTest` error IDs are listed in `plans/2026-10-28-baseline-failing-tests.md`. No baseline-external error ID appeared in this run.
- The causes of these baseline errors, actual SMTP, full-suite status and total transport deadline were not established here.
