# Processor retry boundary correction

- Date: 2026-09-23
- HEAD before this local change: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: pre-existing local changes were preserved. No external service, provider, production
  database, or GitHub write was used.

## Finding

`ProcessorErasureRetryPolicy#retry_at` rejected zero and negative attempt numbers, while
`#exhausted?` accepted them. That made the public retry-policy value contract inconsistent even
though persisted attempt rows are constrained to positive numbers.

## TDD evidence

The new boundary test first failed because `exhausted?(0)` returned normally. Both operations now
share positive attempt-number normalization and reject zero/negative values. The inclusive
exhaustion boundary and configured maximum boundaries are covered.

```text
bundle exec ruby -Itest test/values/processor_erasure_retry_policy_test.rb
3 runs, 11 assertions, 0 failures, 0 errors, 0 skips
```

The changed value object and test pass targeted RuboCop, and `git diff --check` passes.

After the correction, the repository-wide static checks also passed:

```text
bundle exec rubocop
4772 files inspected, no offenses detected

bundle exec brakeman -q
Errors: 0
Security Warnings: 0

git diff --check
passed
```

This is a local input-contract correction. PostgreSQL-backed processor tests and the full Rails
suite were not rerun in this process because the configured `primary` service name is currently
unresolvable; that limitation is not treated as a passing database verification.
