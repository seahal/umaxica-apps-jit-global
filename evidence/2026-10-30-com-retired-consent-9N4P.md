# Retired com preference consent

- Commit: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting the result.
- A com consent read now requires the legacy available status as well as the existing active and unconsumed scopes. A matching browser binding on a retired row cannot authorize stored consent.
- `bin/rails test test/integration/anonymous_com_retired_consent_test.rb`: one run, ten assertions, no failures or errors; it exercises both available and retired rows through the public API without modifying the stored consent.
- `bundle exec rubocop app/controllers/concerns/preference_web_cookie_endpoint.rb test/integration/anonymous_com_retired_consent_test.rb`: no offenses.
- The existing full-fixture journey could not run: fixture loading failed on the `client_auth_admission_bindings.base_token_id` foreign key before either selected case executed.
