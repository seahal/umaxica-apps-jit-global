# Corporate preference reset binding cookie

- Commit: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checks.
- Command: `RAILS_ENV=test bundle exec ruby -Itest -r ./config/environment -e 'ActiveRecord.maintain_test_schema = false; ARGV.each { |path| require File.expand_path(path) }' test/integration/anonymous_com_web_push_initialization_test.rb test/integration/anonymous_com_web_push_api_test.rb test/integration/anonymous_com_retired_consent_test.rb`.
- Result: 22 runs, 262 assertions, no failures, errors, or skips. Schema maintenance was disabled; pending migrations were not applied.
- The reset request retired the prior preference, issued a distinct preference, and expired the host-only binding with Secure, HttpOnly, and Path attributes.
- `bundle exec rubocop app/controllers/base/com/preference/customizations_controller.rb test/integration/anonymous_com_web_push_initialization_test.rb` passed with no offenses.
- A separate-connection read-versus-retirement concurrency test was not run; the existing test database cannot safely be cleaned for a nontransactional test without an approved data-handling procedure.
- Follow-up: the same three integration files passed with 23 runs and 279 assertions after adding a signing-failure request. The old preference status, generation, consent, JWT and binding remained unchanged, and none of the four preference cookies was emitted. RuboCop passed for the updated test.
