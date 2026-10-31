# Corporate invalid preference cookie handling

- Commit: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checks.
- Command: `RAILS_ENV=test bundle exec ruby -Itest -r ./config/environment -e 'ActiveRecord.maintain_test_schema = false; ARGV.each { |path| require File.expand_path(path) }' test/integration/anonymous_com_web_push_initialization_test.rb test/integration/anonymous_com_web_push_api_test.rb test/integration/anonymous_com_preference_response_binding_test.rb test/values/anonymous_com_preference_token_shape_test.rb`.
- Result: 34 runs, 360 assertions, no failures, errors, or skips. Schema maintenance was disabled; pending migrations were not applied.
- Tests check domain-scoped deletion of the three shared cookies on an invalid JWT, preservation of the host binding, no shared cookie deletion or parent-table read on the read-only corporate host, and rebuilding display cookies from the current DB snapshot when an unexpired JWT has an older generation.
- `bundle exec rubocop app/controllers/concerns/preference_transport.rb test/integration/anonymous_com_web_push_initialization_test.rb` passed with no offenses.
