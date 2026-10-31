# Corporate preference save response consent

- Commit: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checks.
- Command: `RAILS_ENV=test bundle exec ruby -Itest -r ./config/environment -e 'ActiveRecord.maintain_test_schema = false; ARGV.each { |path| require File.expand_path(path) }' test/integration/anonymous_com_preference_response_binding_test.rb test/integration/anonymous_com_retired_consent_test.rb test/integration/anonymous_com_web_push_initialization_test.rb test/integration/anonymous_com_web_push_api_test.rb`.
- Result: 35 runs, 389 assertions, no failures, errors, or skips. Schema maintenance was disabled; pending migrations were not applied.
- A theme save whose row expired between its write and response read returned no consent in its JSON response while retaining the stored consent. Existing matching and mismatched browser tests also passed.
- `bundle exec rubocop app/controllers/concerns/preference_resource_sync.rb test/integration/anonymous_com_preference_response_binding_test.rb` passed with no offenses.
- A response-read dependency failure can occur after the preference transaction commits; it is not atomic with the committed write or response delivery. A concurrent independent-connection retirement test remains outstanding.
- Follow-up: the same integration files passed with 36 runs and 396 assertions after injecting a database failure at the response consent read. The request returned 503 with an empty body while the previously committed new generation and theme remained in the database. RuboCop passed for the updated test before its final assertion was changed to check the empty body.
