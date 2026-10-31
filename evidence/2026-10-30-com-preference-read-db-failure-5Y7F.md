# Corporate preference display database failure

- Commit: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checks.
- Command: `RAILS_ENV=test bundle exec ruby -Itest -r ./config/environment -e 'ActiveRecord.maintain_test_schema = false; ARGV.each { |path| require File.expand_path(path) }' test/integration/anonymous_com_web_push_initialization_test.rb test/integration/anonymous_com_web_push_api_test.rb test/integration/anonymous_com_retired_consent_test.rb`.
- Result: 27 runs, 337 assertions, no failures, errors, or skips. Schema maintenance was disabled; pending migrations were not applied.
- A Base com root GET with a valid dark-theme JWT and an injected database clock connection failure rendered the default theme and did not delete or replace the shared preference cookies. This does not verify every settings page under a complete database outage.
- `bundle exec rubocop app/controllers/concerns/preference_transport.rb app/controllers/base/com/application_controller.rb test/integration/anonymous_com_web_push_initialization_test.rb` passed with no offenses.
- Follow-up: the same three integration files passed with 28 runs and 348 assertions. With an injected database clock connection failure, the Web Push API returned disabled and the consent API showed its banner while preserving the browser's existing JWT and binding. The Web Push read records the failure; RuboCop passed on its controller and updated test.
- Settings follow-up: the same three integration files passed with 29 runs and 364 assertions. After an injected parent-read failure, the theme, currency, and consent edit pages rendered with the default theme without invoking the relevant child lookup or replacing the JWT. RuboCop passed on both modified concerns and the updated test. A complete DB outage and other settings pages were not exercised.
