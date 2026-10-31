# Com preference JWT host boundary

- Commit: `336811e5072a93c0523e484f905082635b28f48f`; the worktree had uncommitted changes affecting the checks.
- The com JWT decoder now checks that the receiving host belongs to the configured corporate registrable domain, with the existing local com host family allowed in local environments. A com token no longer decodes directly for an app, org, or unrelated com host.
- `bin/rails test test/values/anonymous_com_preference_token_shape_test.rb test/values/security_jwt_preference_token_codec_claims_test.rb test/integration/anonymous_com_web_push_api_test.rb`: 24 runs, 248 assertions, no failures or errors. The new codec test covers a com sibling, app, org and another com domain.
- `bundle exec rubocop app/values/security_jwt_preference_token_codec.rb test/values/anonymous_com_preference_token_shape_test.rb`: no offenses.
- Realm-specific signing keys and the independent browser binding schema remain incomplete; these checks do not prove all six realm key-isolation directions.
