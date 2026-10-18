# Processor delivery integer-boundary correction

Date: 2026-09-23
Repository: `seahal/umaxica-apps-jit-global`
HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
Worktree: pre-existing uncommitted changes were preserved.

## Adversarial finding

The processor delivery value boundaries used `Integer(value)` for retry-policy values and receipt
generation. Ruby converts fractional numeric values such as `1.5` to `1`, so the public integer
contracts accepted non-integral values. This could silently change retry limits, delay seconds, or
receipt generation bindings instead of rejecting malformed adapter data.

## RED

The new boundary tests failed before the implementation correction:

```text
ProcessorErasureRetryPolicyTest#test_policy_rejects_fractional_numeric_values_in_integer_contracts
ArgumentError expected but nothing was raised.
4 runs, 12 assertions, 1 failures, 0 errors, 0 skips

ProcessorErasureDeliveryValuesTest#test_verified_receipt_rejects_fractional_generation
ArgumentError expected but nothing was raised.
6 runs, 24 assertions, 1 failures, 0 errors, 0 skips
```

## Correction

Retry-policy integer inputs now accept actual integers and integer strings, while rejecting floats
and other non-integer types. Verified receipt generation applies the same type boundary before
numeric conversion. Existing positive-range and string normalization behavior remains unchanged.

## GREEN and static verification

```text
bundle exec ruby -Itest test/values/processor_erasure_retry_policy_test.rb
4 runs, 15 assertions, 0 failures, 0 errors, 0 skips

bundle exec ruby -Itest test/values/processor_erasure_delivery_values_test.rb
6 runs, 24 assertions, 0 failures, 0 errors, 0 skips

bundle exec rubocop app/values/processor_erasure_retry_policy.rb \
  app/values/processor_erasure_verified_receipt.rb \
  test/values/processor_erasure_retry_policy_test.rb \
  test/values/processor_erasure_delivery_values_test.rb
4 files inspected, no offenses detected

bundle exec brakeman -q
0 errors, 0 security warnings

git diff --check
passed
```

PostgreSQL-backed state, migration, and concurrency tests were not claimed here because the current
process cannot resolve the configured `primary` service. No provider, AWS, Cloudflare, database, or
Valkey service was contacted or changed.

The public retry-job regression was added but could not reach its assertions in this process:

```text
PARALLEL_WORKERS=1 bundle exec bin/rails test \
  test/jobs/processor_erasure_notification_retry_job_test.rb

ActiveRecord::DatabaseConnectionError: There is an issue connecting with your hostname: primary.
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

This test remains `UNVERIFIED` until it runs in the isolated PostgreSQL/Valkey topology. The
production correction itself is statically syntax-valid and RuboCop-clean.
