# WU-A4 XDB-14 SNS transport timeouts

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The repository already had extensive uncommitted work; this slice adds two modified paths and this
  evidence file. There are no staged changes and no commit was created.
- Before the change, `OutboundSmsProvidersAwsSns` did not pass HTTP timeout options to the AWS SNS
  client. The installed `aws-sdk-core` is version 3.261.0; the earlier local SDK inspection recorded
  15-second open and 60-second read defaults
  (`evidence/2026-10-31-wua4-otp-transport-timeout-audit-Q7S3.md`).
- The provider now supplies an explicit 5-second connection-open timeout and 10-second read timeout.
  The existing `Outbound::SmsDeliveryJob` 15-second overall timeout remains unchanged, as do its
  retry rules. No SMS was sent to AWS.
- Before the edit, the provider test passed: 5 runs, 12 assertions, no failures/errors/skips.
- After the edit,
  `bin/rails test test/services/outbound/sms_providers/aws_sns_test.rb test/jobs/outbound/sms_delivery_job_test.rb`
  passed: 14 runs, 44 assertions, no failures/errors/skips.
- Scoped RuboCop inspected both changed Ruby files with no offenses. Ruby syntax checks and scoped
  `git diff --check` passed.
- This verifies configured client options only. AWS network behavior, deployed SNS configuration,
  and an end-to-end timeout against the real provider remain unverified; this slice does not close
  XDB-14 or WU-A4.
