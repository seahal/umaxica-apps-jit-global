# SimpleCov Phase 3

## Decision

Phase 2 parallel coverage support was discarded. Coverage runs remain limited to one Rails test
worker, while ordinary test runs retain the existing `PARALLEL_WORKERS` behavior.

Phase 3 adds a 70 percent branch coverage gate and omits source text from the JSON report. The
existing 91 percent line gate, `{app,lib}` coverage scope, groups, formatters, and opt-in
`COVERAGE=true` contract remain unchanged.

Method coverage was evaluated but not enabled. SimpleCov 1.0.1 normalizes method keys by converting
their owner to a string, which raises from Active Model when the suite has exercised an anonymous
model class. Enabling it would make coverage reporting replace the suite's real exit behavior with a
reporting exception.

## Migration replayability

The test database reset exposed historical CMS migrations that still require
`db/migration_support/cms_schema.rb`. The migration-only helper was restored exactly so a fresh
database can replay the committed migration history. This does not restore the retired CMS runtime;
later cleanup migrations still remove those tables.

## Verification context

`RAILS_ENV=test bin/rails db:migrate:reset` completed after restoring the migration helper. The full
ordinary test suite then reached 9,098 runs and 43,299 assertions, with failures in concurrently
modified Publishing, Info API, and principal database configuration boundaries. Those failures are
outside this coverage configuration change and were not hidden or rewritten.
