# Com preference JWT verification namespace

- Commit: `336811e5072a93c0523e484f905082635b28f48f`; uncommitted worktree changes affected these checks.
- Com verification refuses a caller-supplied non-preference issuer namespace, matching the temporary issuance restriction. The test signs the com-shaped claims with the configured Auth app surface key and confirms that this namespace cannot be used to verify them as a com preference.
- `bin/rails test test/values/anonymous_com_preference_token_shape_test.rb test/values/security_jwt_preference_token_codec_claims_test.rb test/integration/anonymous_com_web_push_api_test.rb`: 27 runs, 255 assertions, no failures or errors.
- `bundle exec rubocop app/values/security_jwt_preference_token_codec.rb test/values/anonymous_com_preference_token_shape_test.rb`: no offenses.
- This does not implement realm-specific preference keys, which remain required by two.md. The independent binding schema and broader implementation are also incomplete.
