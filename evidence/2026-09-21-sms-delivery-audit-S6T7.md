# SMS delivery audit boundary

Date: 2026-09-21 UTC

This slice stays inside the existing SMS provider and Chronicle boundaries. It does not contact
AWS SNS, send SMS, add a table, change provider configuration, or expose recipient/message data.

## Change

`OutboundSms` now records three repository-known lifecycle facts through existing Chronicle rows:

- enqueue accepted;
- provider accepted, including provider name and provider reference;
- enqueue/provider failure, retaining only the exception class as the reason.

The recipient, title, message body, OTP, and provider credentials are not placed in the Chronicle
metadata. Provider acceptance is not represented as end-user delivery completion. Existing retry and
exception behavior is preserved. If the audit write is unavailable after the provider call, the
delivery result is not retried a second time solely because the audit write failed; an operational
audit-failure log is emitted instead.

## TDD and verification

The new public-service tests were run before the production change and failed for the expected
reason: the three new Chronicle lifecycle facts were absent. After the minimal implementation:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/services/outbound_sms_audit_test.rb \
  test/jobs/outbound/sms_delivery_job_test.rb
8 runs, 36 assertions, 0 failures, 0 errors, 0 skips
```

The first full-suite run then exposed one compatibility regression in the existing public
`OutboundSms.deliver_now` test: its provider double returns `true` rather than a structured
provider response. The audit metadata path was narrowed to enrich structured responses only, while
preserving the existing truthy-success contract. The regression reproduced and passed after the
fix:

```text
PARALLEL_WORKERS=1 bin/rails test test/services/outbound/sms_test.rb test/services/outbound_sms_audit_test.rb
8 runs, 56 assertions, 0 failures, 0 errors, 0 skips

PARALLEL_WORKERS=1 bin/rails test \
  test/services/outbound_sms_audit_test.rb \
  test/services/outbound/sms_test.rb \
  test/jobs/outbound/sms_delivery_job_test.rb \
  test/services/outbound_provider_response_test.rb \
  test/services/outbound_result_test.rb \
  test/services/authentication_security_event_emitter_test.rb \
  test/policies/chronicle_record_policy_test.rb \
  test/jobs/retention_purge_job_test.rb \
  test/jobs/retention_purge_legal_hold_test.rb \
  test/subscribers/jwt_anomaly_subscriber_test.rb
74 runs, 339 assertions, 0 failures, 0 errors, 0 skips

bin/rails test
11434 runs, 73121 assertions, 0 failures, 0 errors, 5 skips
```

Targeted RuboCop for `app/services/outbound_sms.rb` and
`test/services/outbound_sms_audit_test.rb` passed with no offenses.

The test suite uses a local provider double only; no external provider was contacted. The five
skips are existing suite skips; none were added by this slice.

## Remaining boundary

Email provider acceptance/delivery receipts, provider callbacks, and provider retry/permanent-failure
contracts remain unimplemented because no approved provider contract exists in the repository. The
existing processor-erasure path continues to refuse to claim notification success without a concrete
processor adapter. Those are explicit follow-ups, not silently inferred completion.
