# Processor dispatch error-code and constructor boundary

- Date: 2026-09-23
- Repository: `seahal/umaxica-apps-jit-global`
- HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: pre-existing staged, unstaged, and untracked changes were preserved.
- External activity: no provider, production database, AWS, Cloudflare, or GitHub write was used.

## Finding and RED

The public dispatch-result constructor accepted an arbitrary failure `error_code`. A provider-like
value containing a token marker could therefore be treated as categorical metadata and reach the
notification error-code field. The value-boundary regression reproduced this before the correction:

```text
bundle exec ruby -Itest test/values/processor_erasure_delivery_values_test.rb
4 runs, 20 assertions, 1 failure, 0 errors, 0 skips

Failure: ArgumentError was expected for a token-shaped failure code, but no exception was raised.
```

## Correction and GREEN

`ProcessorErasureDispatchResult` now accepts only the repository's safe categorical error-code form
and rejects malformed or secret-shaped values with `ArgumentError`. Its constructor also applies the
existing `ChronicleRecordPolicy.sanitize_text` boundary, so direct construction cannot bypass failure
message sanitization.

```text
bundle exec ruby -Itest test/values/processor_erasure_delivery_values_test.rb
5 runs, 23 assertions, 0 failures, 0 errors, 0 skips

bundle exec rubocop app/values/processor_erasure_dispatch_result.rb \
  test/values/processor_erasure_delivery_values_test.rb
2 files inspected, no offenses detected

bundle exec rubocop
4773 files inspected, no offenses detected

bundle exec brakeman -q
0 errors, 0 security warnings

git diff --check
passed
```

This is a provider-neutral value-contract correction. It does not claim PostgreSQL migration,
concurrency, queue, or provider acceptance; those require the isolated runtime or later deployment
gates described by the Frozen Plan.
