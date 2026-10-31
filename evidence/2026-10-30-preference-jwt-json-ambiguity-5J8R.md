# Preference JWT JSON ambiguity

- Commit: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checks.
- Command: `RAILS_ENV=test bundle exec ruby -Itest -r ./config/environment -e 'ActiveRecord.maintain_test_schema = false; ARGV.each { |path| require File.expand_path(path) }' test/values/anonymous_com_preference_token_shape_test.rb test/values/security_jwt_preference_token_codec_claims_test.rb`.
- Result: 21 runs, 202 assertions, no failures, errors, or skips. Schema maintenance was disabled; pending migrations were not applied.
- The added test signs JWTs with duplicate header, claim, and nested preference keys and confirms that decoding rejects them, while the corresponding unambiguous token remains valid.
- `bundle exec rubocop app/values/security_jwt_preference_token_codec.rb test/values/anonymous_com_preference_token_shape_test.rb` passed with no offenses.
