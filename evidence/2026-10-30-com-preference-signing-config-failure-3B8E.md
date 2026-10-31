# Corporate preference signing configuration failure

- Commit: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checks.
- Command: `RAILS_ENV=test bundle exec ruby -Itest -r ./config/environment -e 'ActiveRecord.maintain_test_schema = false; ARGV.each { |path| require File.expand_path(path) }' test/integration/anonymous_com_web_push_initialization_test.rb`.
- Result: 14 runs, 202 assertions, no failures, errors, or skips. Schema maintenance was disabled; pending migrations were not applied.
- The new request test makes the private-key provider raise its configuration error during a save. The response was 503; the old generation and theme persisted and no preference cookies were emitted.
- `bundle exec rubocop app/controllers/concerns/preference_write_boundary.rb test/integration/anonymous_com_web_push_initialization_test.rb` passed with no offenses.
