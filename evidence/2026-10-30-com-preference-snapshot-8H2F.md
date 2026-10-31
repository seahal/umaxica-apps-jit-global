# Corporate preference display snapshot

- Commit: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checks.
- Command: `RAILS_ENV=test bundle exec ruby -Itest -r ./config/environment -e 'ActiveRecord.maintain_test_schema = false; ARGV.each { |path| require File.expand_path(path) }' test/integration/anonymous_com_web_push_initialization_test.rb test/integration/anonymous_com_web_push_api_test.rb test/integration/anonymous_com_preference_response_binding_test.rb`.
- Result: 11 runs, 76 assertions, no failures, errors, or skips. Schema maintenance was disabled; pending migrations were not applied.
- The new request test saves an existing preference without display children and checks that the signed JWT, language cookie, and experience cookie contain one consistent complete default snapshot. The other cases exercise Web Push and consent response binding.
- `bundle exec rubocop app/controllers/concerns/preference_base.rb app/controllers/concerns/preference_write_boundary.rb test/integration/anonymous_com_web_push_initialization_test.rb test/values/anonymous_com_preference_payload_build_test.rb` passed with no offenses.
- The fixture-dependent payload build test was updated but not run in this check; the existing test database has unrelated fixture foreign-key inconsistencies.
- Follow-up: the same integration command passed with 12 runs and 83 assertions after adding an invalid stored option case. The request returned 503, retained the previous generation, rolled back the consent child, and emitted neither a new preference JWT nor a binding cookie. RuboCop also passed for the modified integration test.
