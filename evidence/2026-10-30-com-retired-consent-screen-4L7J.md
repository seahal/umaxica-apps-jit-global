# Retired corporate preference consent screen

- Commit: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checks.
- Command: `RAILS_ENV=test bundle exec ruby -Itest -r ./config/environment -e 'ActiveRecord.maintain_test_schema = false; ARGV.each { |path| require File.expand_path(path) }' test/integration/anonymous_com_retired_consent_test.rb test/integration/anonymous_com_web_push_initialization_test.rb test/integration/anonymous_com_web_push_api_test.rb`.
- Result: 30 runs, 370 assertions, no failures, errors, or skips. Schema maintenance was disabled; pending migrations were not applied.
- With a valid display JWT and matching browser binding for a retired row, the consent form reported every category declined while leaving the stored consent unchanged and not issuing a binding cookie.
- `bundle exec rubocop app/controllers/concerns/preference_access_token_transport.rb test/integration/anonymous_com_retired_consent_test.rb` passed with no offenses.
- The phase-refusal design in `two.md` section 5.3 requires no state mutation on 409, while `adr/idp-flow-state-machine-lifecycle.md` and `docs/checklists/authentication-flow-integrity.md` describe halting on unsafe same-flow phase violations. Existing `SignInPhaseBindingControllerSupport` invokes that halt before its refusal. The existing transition was left intact pending resolution of the contract discrepancy.
- Follow-up: the same integration files passed with 32 runs and 379 assertions after the consent form switched to the locked active-row read already used by the API. Tests cover an active matching browser and a clock reaching expiration between initial row lookup and the locked consent read. RuboCop passed for the application files; the updated test's style offenses were corrected after the run. An independent-connection retirement race remains unverified.
