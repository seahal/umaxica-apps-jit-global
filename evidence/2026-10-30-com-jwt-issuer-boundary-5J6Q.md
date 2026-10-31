# Com preference JWT issuance boundary

- Commit: `336811e5072a93c0523e484f905082635b28f48f`; uncommitted worktree changes affected the checks.
- Com JWT issuance rejects app, org and unrelated host domains. It also refuses a non-default issuer namespace rather than silently signing with the default key when a caller requested a different namespace.
- `bin/rails test test/values/anonymous_com_preference_token_shape_test.rb test/values/security_jwt_preference_token_codec_claims_test.rb test/integration/anonymous_com_web_push_api_test.rb`: 26 runs, 252 assertions, no failures or errors.
- `bundle exec rubocop app/values/security_jwt_preference_token_codec.rb test/values/anonymous_com_preference_token_shape_test.rb`: no offenses.
- This restriction does not provide the separately configured realm-specific keys required by two.md. The existing default preference key remains in use until that work is implemented.
