# Processor notification-state metadata boundary

- Date: 2026-09-23
- Repository: `seahal/umaxica-apps-jit-global`
- HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: pre-existing staged, unstaged, and untracked changes were preserved.
- External activity: no provider, production database, AWS, Cloudflare, or GitHub write was used.

## Finding

The public `mark_retryable_failure!` and `mark_permanent_failure!` transitions accepted raw error
codes and messages directly, even after the dispatch-result value object had been hardened. A caller
could therefore bypass the normal adapter-result factories and persist an unsafe diagnostic.

## Correction

Both public transitions and the locked `record_failure_locked!` path now use the shared
`ProcessorErasureDispatchResult` error-code normalization and sensitive-message sanitizer before
writing either notification or attempt metadata. Unsafe codes raise before the transition mutates
state. This does not alter retry classification, receipt validation, or terminal-state semantics.

Regression coverage was added to
`test/models/processor_erasure_notification_state_test.rb` for:

- rejecting a token-shaped error code without changing the attempt;
- rejecting a token-shaped error code for both retryable and permanent public transitions;
- sanitizing a token-shaped error message in both notification and attempt records.

## Verification

The DB-backed focused command was attempted with the required test environment:

```text
PARALLEL_WORKERS=1 bundle exec bin/rails test \
  test/models/processor_erasure_notification_state_test.rb
```

It did not reach test execution because PostgreSQL host `primary` could not be resolved:

```text
ActiveRecord::DatabaseConnectionError:
There is an issue connecting with your hostname: primary.
PG::ConnectionBad: could not translate host name "primary" to address:
Temporary failure in name resolution
```

The following DB-free/static checks passed after the correction:

```text
bundle exec ruby -Itest test/values/processor_erasure_delivery_values_test.rb
5 runs, 23 assertions, 0 failures, 0 errors, 0 skips

bundle exec rubocop
4773 files inspected, no offenses detected

bundle exec brakeman -q
0 errors, 0 security warnings

git diff --check
passed
```

The model regression remains unverified until the isolated PostgreSQL/Valkey environment is
reachable. No fallback host, mock, skip, or test weakening was introduced.

## Latest static recheck

After the subsequent worktree verification, the affected Ruby files remained syntactically valid;
repository-wide RuboCop, Brakeman, and `git diff --check` passed again. This does not change the
unverified status of the PostgreSQL-backed model tests.
