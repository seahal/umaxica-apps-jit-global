# Corporate display with an unavailable preference row

- Commit: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checks.
- Command: `RAILS_ENV=test bundle exec ruby -Itest -r ./config/environment -e 'ActiveRecord.maintain_test_schema = false; ARGV.each { |path| require File.expand_path(path) }' test/integration/anonymous_com_web_push_initialization_test.rb test/integration/anonymous_com_web_push_api_test.rb test/integration/anonymous_com_preference_response_binding_test.rb test/values/anonymous_com_preference_token_shape_test.rb`.
- Result: 35 runs, 370 assertions, no failures, errors, or skips. Schema maintenance was disabled; pending migrations were not applied.
- A valid signed JWT naming a nonexistent preference row rendered its signed theme without creating a row or deleting/reissuing the three shared cookies. This test covers display only; it does not grant consent or write authority to an unavailable row.
- RuboCop passed on the modified application concerns; the integration test's alignment offense was corrected after the test run.
