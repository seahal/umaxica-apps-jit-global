# Preference token size validation

- Commit: `336811e5072a93c0523e484f905082635b28f48f`; uncommitted changes affected the checks.
- The preference decoder rejects non-string and over-3-KiB inputs before unverified JWT parsing. The limit also applies to the legacy token shape while it remains in use.
- `bin/rails test test/values/anonymous_com_preference_token_shape_test.rb test/values/security_jwt_preference_token_codec_claims_test.rb`: 15 runs, 180 assertions, no failures or errors. The anonymous token tests do not use fixtures, so their unrelated inherited fixtures were disabled after the initial run failed to load them on a foreign-key violation.
- `bundle exec rubocop app/values/security_jwt_preference_token_codec.rb test/values/anonymous_com_preference_token_shape_test.rb`: no offenses.
