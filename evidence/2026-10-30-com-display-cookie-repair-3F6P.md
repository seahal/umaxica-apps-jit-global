# Corporate preference display cookie repair

- Commit: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checks.
- Command: `RAILS_ENV=test bundle exec ruby -Itest -r ./config/environment -e 'ActiveRecord.maintain_test_schema = false; ARGV.each { |path| require File.expand_path(path) }' test/integration/anonymous_com_web_push_initialization_test.rb test/integration/anonymous_com_web_push_api_test.rb test/integration/anonymous_com_preference_response_binding_test.rb test/values/anonymous_com_preference_token_shape_test.rb`.
- Result: 31 runs, 318 assertions, no failures, errors, or skips. Schema maintenance was disabled; pending migrations were not applied.
- A GET with a valid JWT, a missing language cookie, and an ambiguous experience JSON rebuilt both display cookies from the setting row without an observed SQL write or JWT rotation, using the existing JWT expiration. A separate request with matching display cookies did not reissue them.
- RuboCop passed on the changed application files; the integration test's five style offenses were corrected with `bundle exec rubocop -a` after the test run.
