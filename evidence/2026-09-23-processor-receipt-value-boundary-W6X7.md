# Processor receipt value boundary verification

- Date: 2026-09-23
- HEAD before this local change: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: pre-existing local changes were preserved. No external service, provider, production
  database, or GitHub write was used.

The provider-neutral receipt and dispatch value objects now have pure public-contract coverage for
missing/empty security bindings, zero generation, invalid digest format, success without a verified
receipt, and failure without an error code. String/integer normalization is covered only for values
that the contract permits.

```text
bundle exec ruby -Itest test/values/processor_erasure_delivery_values_test.rb
3 runs, 14 assertions, 0 failures, 0 errors, 0 skips

bundle exec rubocop test/values/processor_erasure_delivery_values_test.rb \
  app/values/processor_erasure_dispatch_result.rb \
  app/values/processor_erasure_verified_receipt.rb
3 files inspected, no offenses detected

git diff --check
passed
```

This verifies value-object input boundaries only. It does not replace the PostgreSQL-backed receipt
application, concurrency, or migration checks, which remain unrun in this process because the
configured `primary` service is unavailable.
