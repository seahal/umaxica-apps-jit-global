# Corporate preference cookie attributes

- Commit: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checks.
- Command: `RAILS_ENV=test bundle exec ruby -Itest -r ./config/environment -e 'ActiveRecord.maintain_test_schema = false; ARGV.each { |path| require File.expand_path(path) }' test/integration/anonymous_com_web_push_initialization_test.rb test/integration/anonymous_com_web_push_api_test.rb test/integration/anonymous_com_preference_response_binding_test.rb`.
- Result: 12 runs, 123 assertions, no failures, errors, or skips. Schema maintenance was disabled; pending migrations were not applied.
- The HTTPS consent-save response was checked for Secure, Path, SameSite, HttpOnly, and shared-domain or host-only attributes on the four preference cookies.
- `bundle exec rubocop app/controllers/concerns/preference_access_token_issuer.rb app/controllers/concerns/preference_browser_binding.rb test/integration/anonymous_com_web_push_initialization_test.rb` passed with no offenses.
