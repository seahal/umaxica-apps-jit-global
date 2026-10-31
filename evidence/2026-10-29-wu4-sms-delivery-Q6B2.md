# WU-4 SMS delivery retirement

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Extensive uncommitted worktree changes, including corporate authentication removal and the changes below, affected the result.
- Removed deleted corporate model dispatch from `Outbound::SmsDeliveryJob`. Existing encrypted corporate signup and credential-registration payloads now reach its unsupported-realm `ArgumentError`, which the job reports and discards without sending. The existing payload value format was not changed.
- `PARALLEL_WORKERS=1 bin/rails test test/jobs/outbound/sms_delivery_job_test.rb`: 8 runs, 30 assertions, no failures, errors, or skips, including both retired delivery purposes.
- `PARALLEL_WORKERS=1 bin/rails test test/integration/telephone_credential_registration_otp_delivery_test.rb`: 9 runs, 80 assertions, no failures, errors, or skips after removing deleted corporate-only cases; the remaining cases exercise current and stale registration proof handling.
- An initial run of the job test failed because the new test supplied a message that the payload contract rejects; after using the valid message the run above passed. An initial integration run produced 8 errors from deleted corporate models; those retired cases were removed before the passing run.
- No full-suite run was performed after this change. Test database preparation was used; no production persistence operation or external write was performed.
