# Auth Email resend connection failures

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; uncommitted worktree changes affected the result.
- Injected `ActiveRecord::ConnectionNotEstablished` failures in the occurrence lookup and the enqueue boundary previously escaped the APP Email resend request (2 runs, 0 assertions, 2 errors before the change).
- The resend service now reports the existing specific connection-failure classes and returns its existing 503 JSON result. A public test observed no challenge change when lookup failed before issuance; another observed the new generation retained when the enqueue-side connection failed. Both made no mail delivery. A separate request test confirms a generic `ActiveRecord::StatementInvalid` remains an exception rather than being hidden as a dependency outage.
- `PARALLEL_WORKERS=1 bin/rails test test/controllers/auth/app/web/v0/in/email/otps_controller_test.rb test/services/sign/in/otp_resend_service_test.rb test/notifiers/notify/otp_notifiers_test.rb` passed: 39 runs, 211 assertions, no failures or errors. Scoped RuboCop passed.
- These were injected failures, not a real PostgreSQL outage. Wrapped connection exceptions, failures before the service is entered, signup endpoints, real/dummy cooldown parity and the complete cross-database fault matrix remain unverified.
