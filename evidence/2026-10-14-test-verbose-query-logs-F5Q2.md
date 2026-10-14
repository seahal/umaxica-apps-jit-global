# Test verbose query logging acceptance correction

Recorded against commit `aa92265b7e63bf874fddd0aa8f278d5ed19de6b5` on 2026-10-14.
The worktree contains extensive pre-existing uncommitted implementation and unrelated changes.

AT-055/AT-056 require verbose query logging in test without raising the normal log level.
Inspection showed that `config/environments/test.rb` lacked this setting while development had it.
Added `config.active_record.verbose_query_logs = true` at the existing Strict Loading settings.

Executed on the ordinary Rails test configuration:

```text
env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test bin/rails runner 'puts({strict_loading: ActiveRecord::Base.strict_loading_by_default, strict_loading_mode: ActiveRecord::Base.strict_loading_mode, violation: ActiveRecord.action_on_strict_loading_violation, verbose_query_logs: ActiveRecord.verbose_query_logs, logger_level: Rails.logger.level}.inspect)'
```

The boot succeeded and reported `true`, `:all`, `:raise`, `verbose_query_logs: true`, and
`logger_level: 1` (INFO). No test case was added because environment construction is verified
by execution. No isolated database, migration or reset was used. This corrects one acceptance gap;
it does not establish completion of the remaining requirements.
