# Phase 04 session re-lock verification

Date: 2026-09-20

This record covers the Base token-exchange sub-slice that validates the exact
Base Browser Session before authorization-code consumption and re-locks that
session after the Valkey code CAS.

## Executed checks

- `export UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example`
- `PARALLEL_WORKERS=1 bin/rails test test/services/oidc/token_exchange_service_test.rb`
  - 93 runs, 419 assertions, 0 failures, 0 errors, 0 skips
- `PARALLEL_WORKERS=1 bin/rails test test/services/oidc/realm_binding_test.rb test/services/valkey/auth_state/authorization_code_store_test.rb test/services/oidc/token_exchange_service_test.rb`
  - 103 runs, 459 assertions, 0 failures, 0 errors, 0 skips
- `bin/rubocop app/services/oidc_token_exchange_coordinator.rb test/services/oidc/token_exchange_service_test.rb`
  - 2 files inspected, no offenses
- `git diff --check`
  - passed

## Observed contract

- An authorization code bound to an already inactive Base Browser Session is
  rejected before the destructive Valkey consume and remains in `issued` state.
- If the parent session is revoked immediately after the code CAS, the
  post-CAS PostgreSQL lock and revalidation reject issuance and return no token
  response. The consumed code is not resurrected.
- The CAS expected fields include the code subject and exact Base Session
  reference in addition to client, redirect, PKCE, and realm bindings.

No live external IdP, browser, or production database was used.
