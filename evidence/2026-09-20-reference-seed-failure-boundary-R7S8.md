# Reference seed failure boundary

Date: 2026-09-20

## Scope

The fixed-reference seed path was narrowed so only duplicate fixed-id races are
treated as recoverable. `ActiveRecord::StatementInvalid` is no longer swallowed
by `ApplicationRecord.insert_missing_fixed_ids!`; constraint, schema, and
connection failures now remain observable to the caller.

## TDD evidence

- RED: `PARALLEL_WORKERS=1 bin/rails test test/models/application_record_test.rb`
  reproduced the defect with `ActiveRecord::StatementInvalid`; the test reported
  `1 failures, 0 errors` because the exception was swallowed.
- GREEN: the updated `test/models/application_record_test.rb` passed with
  `10 runs, 16 assertions, 0 failures, 0 errors, 0 skips`.
- The focused `test/models/application_record_test.rb` passed with
  `10 runs, 16 assertions, 0 failures, 0 errors, 0 skips`.
- The full Rails suite passed with `11404 runs, 72977 assertions, 0 failures,
  0 errors, 5 skips`.
- RuboCop passed for the two changed files with no offenses.

All Rails commands used the configured `.env.devcontainer.example` test
environment. No external service, production database, or GitHub resource was
modified.
