# Sign-in resend transaction ownership

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had uncommitted changes affecting these checks.

The existing non-transactional serialization file initially passed (4 runs, 15 assertions). Four new cases exercised real and fake contacts under an outer Auth or occurrence transaction. Before the change the fake cases returned success and the real cases attempted to invoke the delivery adapter. The resender now returns its existing dependency-unavailable result before issuing when either connection is already in a transaction. The expanded serialization file passed (8 runs, 35 assertions); scoped RuboCop passed.

The broader command `PARALLEL_WORKERS=1 bin/rails test test/services/sign/in/otp_resend_service_test.rb test/controllers/auth/app/web/v0/in/email/otps_controller_test.rb test/services/sign_in_otp_resender_failures_test.rb` failed: 46 runs, 154 assertions, 21 failures. Existing tests run valid resend calls inside fixture transactions and now encounter the new precondition; their transaction setup and cleanup require repair. No production HTTP request, real delivery, other OTP paths, or full suite was verified. The check does not resolve cooldown timestamp precision or guarantee completion of resends inside a transaction: such calls are explicitly refused.
