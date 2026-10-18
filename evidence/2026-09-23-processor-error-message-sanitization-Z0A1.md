# Processor error-message secret boundary

- Date: 2026-09-23
- Repository: `seahal/umaxica-apps-jit-global`
- HEAD before this local change: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: pre-existing staged, unstaged, and untracked changes were preserved.
- External activity: no provider, production database, AWS, Cloudflare, or GitHub write was used.

## Finding and RED

The provider-neutral dispatch result accepted arbitrary failure messages and passed them toward the
notification and attempt error columns unchanged. A token-shaped diagnostic could therefore be
persisted if a future adapter included it in an error message.

The public value-boundary regression was run before the correction:

```text
bundle exec ruby -Itest test/values/processor_erasure_delivery_values_test.rb
4 runs, 18 assertions, 1 failure, 0 errors, 0 skips

Failure: the raw 40-character token remained in the retryable error message.
```

## Correction and GREEN

`ProcessorErasureDispatchResult.retryable` and `.permanent` now pass failure messages through the
existing `ChronicleRecordPolicy.sanitize_text` boundary before they can reach persistent state.
The correction does not change outcome classification, error codes, receipt validation, or retry
semantics.

```text
bundle exec ruby -Itest test/values/processor_erasure_delivery_values_test.rb
4 runs, 19 assertions, 0 failures, 0 errors, 0 skips

bundle exec rubocop app/values/processor_erasure_dispatch_result.rb \
  test/values/processor_erasure_delivery_values_test.rb
2 files inspected, no offenses detected

git diff --check
passed
```

The provider-neutral boundary now prevents the normal adapter-result path from persisting the
tested token-shaped diagnostic. Provider authentication and real receipt handling remain separate
deployment/provider gates.
