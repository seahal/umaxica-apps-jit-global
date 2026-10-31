# Corporate display repair database clock

- Commit: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checks.
- Command: `RAILS_ENV=test bundle exec ruby -Itest -r ./config/environment -e 'ActiveRecord.maintain_test_schema = false; ARGV.each { |path| require File.expand_path(path) }' test/integration/anonymous_com_web_push_initialization_test.rb test/integration/anonymous_com_web_push_api_test.rb test/integration/anonymous_com_preference_response_binding_test.rb test/integration/anonymous_com_retired_consent_test.rb test/values/anonymous_com_preference_token_shape_test.rb`.
- Result: 40 runs, 410 assertions, no failures, errors, or skips. Schema maintenance was disabled; pending migrations were not applied.
- The added request test advances the application clock beyond the row expiration while the database clock remains before it, and verifies that both display cookies are rebuilt without replacing the JWT.
- `bundle exec rubocop app/controllers/concerns/preference_access_token_transport.rb test/integration/anonymous_com_web_push_initialization_test.rb` passed with no offenses.
