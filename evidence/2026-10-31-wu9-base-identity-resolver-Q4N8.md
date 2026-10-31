# WU-9 Base identity resolver slice

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive staged, unstaged, and untracked changes. No commit was made.
- `BaseZenithIdentityResolver` already resolves the canonical APP Client or ORG Operator by validating the authenticated RP cell, session binding, OIDC subject, issuer, realm, client ID and actor status. Base APP/ORG expose it through `preference_write_actor` for RP-cell execution. The WU-9 Preference writer does not yet call that method.
- Replaced the resolver's `constantize` lookup of its cell record class with explicit `RpBaseAppRecord` / `RpBaseOrgRecord` entries in the closed surface map. This keeps class selection static and avoids adding dynamic Ruby resolution.
- `PREFERENCE_COM_JWT_ISSUER=urn:umaxica:test:preference:com PREFERENCE_COM_JWT_AUDIENCE=com PREFERENCE_COM_JWT_REVOKED_KIDS= RAILS_ENV=test bin/rails test test/resolvers/base_zenith_identity_resolver_test.rb` passed: 6 runs, 19 assertions, 0 failures, 0 errors, 0 skips.
- `bundle exec rubocop app/resolvers/base_zenith_identity_resolver.rb test/resolvers/base_zenith_identity_resolver_test.rb` passed: 2 files, no offenses.
- Not verified: Base Preference writer integration, full WU-A8, WU-9 Visa sign-in/out, and WU-9 acceptance. The targeted test runner prepared the configured test databases; no destructive WU-9 migration ran.
