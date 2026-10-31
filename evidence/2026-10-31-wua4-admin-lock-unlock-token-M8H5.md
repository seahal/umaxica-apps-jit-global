# APP administrative lock and unlock Access JWT

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Substantial uncommitted worktree changes affected the test.
- An APP test creates a root, grant and signed Access JWT, executes the real administrative lock, OP identity-stop delivery and unlock, and checks the old token through the OIDC authenticator. The token is valid before locking and rejected during and after; the original root remains revoked.
- Afterward the test directly creates a new root with the updated authentication epoch and mints a new token with the application clock advanced beyond the cutoff; that token authenticates. This is a synthetic root and controlled clock, not a browser login.
- `PARALLEL_WORKERS=1 bin/rails test test/services/oidc_access_token_authenticator_test.rb test/services/administrative_access_lock_test.rb test/concurrency/administrative_access_lock_clock_test.rb test/models/concerns/administrative_access_lockable_test.rb`: 29 runs, 154 assertions, no failures, errors or skips. Scoped RuboCop passed after formatting.
- ORG, cross-database commit races, actual remote RP logout delivery, issuer/database clock synchronization and a full suite were not verified.
