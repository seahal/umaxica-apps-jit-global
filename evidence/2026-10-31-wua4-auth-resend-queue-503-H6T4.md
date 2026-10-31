# Auth Email resend queue refusal

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting the result.
- The APP Email OTP resend endpoint propagated an injected `ActiveJob::EnqueueError` after issuing the new Auth generation; a public request test errored before the change (1 run, 0 assertions, 1 error).
- The resend service now reports that specific queue error and returns `service_unavailable` using the endpoint's existing `resendable` Boolean and `retry_after` integer fields. The public test received 503 and no-store, observed no mail delivery, and confirmed the new generation remained. Existing UI code treats non-200/429 responses as delivery failure.
- `PARALLEL_WORKERS=1 bin/rails test test/controllers/auth/app/web/v0/in/email/otps_controller_test.rb test/services/sign/in/otp_resend_service_test.rb test/notifiers/notify/otp_notifiers_test.rb` passed: 36 runs, 201 assertions, no failures or errors. Scoped RuboCop passed on the service and controller test.
- The refusal was injected at the enqueue boundary. Real queue outages, Source/OP database failures, initial signup failure responses, cooldown parity for real and dummy addresses, and browser behavior were not verified by this test.
