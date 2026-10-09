# OIDC RP/IdP 0.2.0 Verification

## Summary

This pass fixed the RP-to-IdP authorization endpoint mismatch for the acme/sign OIDC flow.

## Fixed

- `sign` OAuth authorization routes now expose `/oauth/authorize` for app, com, and org.
- `acme` app/com/org RP authorize redirects now land on an actual same-surface IdP route.
- OIDC browser-flow coverage now verifies `/oauth/authorize` exists and `/oauth/authorization` is
  not exposed.
- Client registry coverage now pins acme app/com/org redirect hosts, audiences, and resource types
  to prevent cross-surface client mixups.

## Verified

- app: `acme_app` redirects to `ID_SERVICE_URL`, validates state/nonce, establishes an RP session,
  and can reach `/accounts` after callback.
- com: `acme_com` redirects to `ID_CORPORATE_URL`, validates state/nonce, establishes an RP session,
  and can reach `/accounts` after callback.
- org: `acme_org` redirects to `ID_STAFF_URL`, validates state/nonce, establishes an RP session, and
  can reach `/accounts` after callback. Org sign-up remains incomplete by product scope, but OIDC
  route/config/callback/logout connection points are present.

## Test Evidence

- `PARALLEL_WORKERS=1 bin/rails test test/integration/oidc_rp_browser_flow_test.rb test/services/oidc/client_registry_test.rb test/services/oidc/authorize_service_test.rb test/services/oidc/token_exchange_service_test.rb test/controllers/concerns/oidc/sso_initiator_test.rb test/controllers/concerns/oidc/callback_test.rb test/controllers/sign/app/authorizes_controller_test.rb test/controllers/sign/org/authorizes_controller_test.rb test/controllers/sign/app/tokens_controller_test.rb test/controllers/sign/com/tokens_controller_test.rb test/controllers/sign/org/tokens_controller_test.rb test/controllers/sign/oidc_logouts_controller_test.rb test/controllers/acme/app/accounts_controller_test.rb test/controllers/acme/com/accounts_controller_test.rb test/controllers/acme/org/accounts_controller_test.rb test/controllers/acme/app/auth/callbacks_controller_test.rb test/controllers/acme/com/auth/callbacks_controller_test.rb test/controllers/acme/org/auth/callbacks_controller_test.rb`
  passed: 129 runs, 549 assertions.

## Known Constraints Before 0.2.0

- Security invariant tests still fail on existing non-OIDC branch state:
  `app/controllers/concerns/jump/to_redirector.rb` cross-host redirect, Turnstile test-aware
  branches, and a stale verification skip allowlist.
- The schema dump had to be refreshed so parallel test worker databases include the pending R18
  preference tables and related sign-up-retention migrations.
- The current ID token implementation still uses the existing `act` contract; the accepted
  `subject_type` ADR alignment remains a separate compatibility-sensitive follow-up.
