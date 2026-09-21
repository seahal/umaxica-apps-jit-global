# Retention evaluation-time consistency

Date: 2026-09-21

## Scope

This slice keeps the existing `discarded_at` / `purged_at` schema unchanged. It makes the
evaluation time explicit for Retainable predicates and TokenStatusManagement expiry checks.
Existing no-argument callers continue to use the application clock; callers that already carry a
reference time no longer cause the predicate and SQL scope to evaluate different instants.

## TDD evidence

The new boundary tests were run before the production change:

- `PARALLEL_WORKERS=1 bin/rails test test/models/concerns/retainable_test.rb test/models/concerns/token_status_management_test.rb`
- Result: 36 runs, 125 assertions, 0 failures, 3 errors.
- The errors demonstrated the missing evaluation-time arguments and the incorrect `discard_now!`
  future-deadline check.

After the implementation and test-double compatibility correction:

- Focused lifecycle tests: 50 runs, 173 assertions, 0 failures, 0 errors, 0 skips.
- Related lifecycle/flow/refresh tests: 95 runs, 547 assertions, 0 failures, 0 errors, 0 skips.
- Full Rails suite: 11,437 runs, 73,134 assertions, 0 failures, 0 errors, 5 skips.
- Targeted RuboCop: 7 files inspected, no offenses.
- `git diff --check`: passed.

The first full-suite run after the production change found two existing test doubles that still
declared the old zero-argument signatures. They were updated to accept the public method's
evaluation-time argument; no production behavior was weakened.

## Remaining scope

This slice does not rename retention columns, replace application-clock defaults with database
clock reads, rebuild initial migrations, or regenerate populated SQL structure dumps. Those remain
separate Phase 09 changes requiring their own schema inventory, migration validation, and isolated
database reconstruction evidence.
