# Com preference JWT lifetime

- Commit: `336811e5072a93c0523e484f905082635b28f48f`; the worktree had uncommitted changes affecting the checks.
- The com JWT decoder now rejects a signed token whose expiry is not later than its issuance time or whose lifetime exceeds 400 days. The boundary test re-signs tokens with lifetimes one second below, at, and one second above the limit.
- `bin/rails test test/values/anonymous_com_preference_token_shape_test.rb test/values/security_jwt_preference_token_codec_claims_test.rb test/integration/anonymous_com_web_push_api_test.rb`: 21 runs, 213 assertions, no failures or errors.
- `bundle exec rubocop app/values/security_jwt_preference_token_codec.rb test/values/anonymous_com_preference_token_shape_test.rb`: no offenses.
- This does not establish the broader signing-failure or database commit-failure contracts; those remain unverified for the Web Push path. The independent binding table and remaining two.md work are incomplete.
