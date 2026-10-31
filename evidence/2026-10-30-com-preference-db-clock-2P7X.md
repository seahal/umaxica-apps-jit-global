# Corporate preference database-clock checks

- Commit: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checks.
- Command: `RAILS_ENV=test bundle exec ruby -Itest -r ./config/environment -e 'ActiveRecord.maintain_test_schema = false; ARGV.each { |path| require File.expand_path(path) }' test/integration/anonymous_com_web_push_initialization_test.rb test/integration/anonymous_com_web_push_api_test.rb test/integration/anonymous_com_preference_response_binding_test.rb test/integration/anonymous_com_retired_consent_test.rb test/values/anonymous_com_preference_token_shape_test.rb`.
- Result: 39 runs, 405 assertions, no failures, errors, or skips. Schema maintenance was disabled; pending migrations were not applied.
- With the application clock advanced beyond the row expiration but the database clock still before it, tests verified reuse of the existing preference on save and readable bound consent and Web Push. The existing retired-row tests also passed.
- RuboCop passed on the five changed application and test files after two equivalent safe-navigation corrections made after the test run.
- Follow-up boundary check: running `test/integration/anonymous_com_web_push_api_test.rb`, `test/integration/anonymous_com_web_push_initialization_test.rb`, and `test/integration/anonymous_com_retired_consent_test.rb` with the same schema-maintenance-disabled command passed with 21 runs and 247 assertions. With the owner-clock boundary controlled, bound consent and Web Push were readable one database timestamp unit before expiration and unavailable at and one unit after expiration; their stored values remained intact. RuboCop passed for the updated API test.
