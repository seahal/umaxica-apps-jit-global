# SMS provider SNS client construction

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting application and test code.

Before the change, a local SDK construction with synthetic credentials, stubbed responses and the provider's `secret_credential_access_key` option raised `ArgumentError` for an invalid configuration option. The provider now passes `secret_access_key`, the option accepted by the installed SNS SDK. With synthetic credentials and stubbed responses, the SDK client constructed successfully. With the configured local test environment, `RAILS_ENV=test bin/rails runner` also constructed `OutboundSmsProvidersAwsSns` successfully; no message was published.

`PARALLEL_WORKERS=1 bin/rails test test/services/outbound/sms_providers/aws_sns_test.rb` passed before and after (5 runs, 12 assertions each). These existing tests substitute the SNS client and did not catch the option defect. `bundle exec rubocop app/services/outbound_sms_providers_aws_sns.rb --format simple` and `git diff --check` passed. No environment-construction test was added. Actual SMS delivery, deployed configuration and the XDB-14 total transport deadline remain unverified.
