# Processor dispatch outcome null boundary

- Date: 2026-09-23
- Repository: `seahal/umaxica-apps-jit-global`
- HEAD before this local change: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: pre-existing staged, unstaged, and untracked changes were preserved.
- External activity: no provider, production database, AWS, Cloudflare, or GitHub write was used.

## Finding and RED

The public `ProcessorErasureDispatchResult` constructor called `to_sym` directly on its
`outcome` input. A nil or integer outcome therefore raised `NoMethodError` instead of the
explicit `ArgumentError` required at the adapter-result boundary.

The new boundary cases were run before the production correction:

```text
bundle exec ruby -Itest test/values/processor_erasure_delivery_values_test.rb
3 runs, 13 assertions, 1 failure, 0 errors, 0 skips

Failure: nil outcome raised NoMethodError; ArgumentError was expected.
```

## Correction and GREEN

The constructor now normalizes only values that expose `to_sym` and rejects nil, numeric, and
unsupported outcomes with the existing `ArgumentError` contract. No successful outcome or receipt
semantics were changed.

```text
bundle exec ruby -Itest test/values/processor_erasure_delivery_values_test.rb
3 runs, 16 assertions, 0 failures, 0 errors, 0 skips

bundle exec rubocop app/values/processor_erasure_dispatch_result.rb \
  test/values/processor_erasure_delivery_values_test.rb
2 files inspected, no offenses detected

git diff --check
passed
```

This is a provider-neutral value-boundary correction. PostgreSQL-backed delivery, migration, and
queue verification remain subject to the Compose service availability recorded in the companion
pre-deployment evidence.

## Subsequent static recheck

After the correction, the related retry-policy and receipt-value tests were rerun. Repository-wide
static checks also passed:

```text
bundle exec ruby -Itest test/values/processor_erasure_retry_policy_test.rb
3 runs, 11 assertions, 0 failures, 0 errors, 0 skips

bundle exec ruby -Itest test/values/processor_erasure_delivery_values_test.rb
3 runs, 16 assertions, 0 failures, 0 errors, 0 skips

bundle exec rubocop
4773 files inspected, no offenses detected

bundle exec brakeman -q
0 errors, 0 security warnings

git diff --check
passed
```
