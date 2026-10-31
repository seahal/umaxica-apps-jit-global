# Corporate browser-bound state reads

- Commit: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checks.
- Command: `RAILS_ENV=test bundle exec ruby -Itest -r ./config/environment -e 'ActiveRecord.maintain_test_schema = false; ARGV.each { |path| require File.expand_path(path) }' test/integration/anonymous_com_web_push_api_test.rb test/integration/anonymous_com_web_push_initialization_test.rb test/integration/anonymous_com_retired_consent_test.rb test/integration/anonymous_com_preference_response_binding_test.rb`.
- Result: 23 runs, 252 assertions, no failures, errors, or skips. Schema maintenance was disabled; pending migrations were not applied.
- Existing request tests cover matched and mismatched bindings, retired rows, and database-clock expiration after the reads were moved under a parent-row lock. They do not exercise a concurrent read and retirement; that concurrency check remains outstanding.
- `bundle exec rubocop app/controllers/concerns/preference_web_cookie_endpoint.rb app/controllers/base/com/api/v0/preferences/web_pushes_controller.rb` passed with no offenses.
