# Corporate display cookies without a JWT

- Commit: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checks.
- Command: `RAILS_ENV=test bundle exec ruby -Itest -r ./config/environment -e 'ActiveRecord.maintain_test_schema = false; ARGV.each { |path| require File.expand_path(path) }' test/integration/anonymous_com_web_push_initialization_test.rb test/integration/anonymous_com_web_push_api_test.rb test/integration/anonymous_com_preference_response_binding_test.rb test/values/anonymous_com_preference_token_shape_test.rb`.
- Result: 36 runs, 386 assertions, no failures, errors, or skips. Schema maintenance was disabled; pending migrations were not applied.
- A Base GET with display cookies but no JWT rendered the default theme, expired both display cookies with the shared domain, and did not create a preference or issue a JWT.
- RuboCop passed on the modified test; one indentation offense in the concern was corrected with `bundle exec rubocop -a` after the test run.
