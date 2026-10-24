# WU-12 and WU-13: OIDC continuations, Cancel and Switch

Revision: `ba570a0007b1d40eabe32990a34831317fd98a93`.

Observed with unrelated uncommitted work preserved. No destructive operation or external write was
performed.

## Implemented

- Auth-to-Visa result, Cancel and Switch hops are dedicated Design D browser-navigation GET
  resources; the old multi-purpose authorization POST is no longer the continuation transport.
- Continuations require Fetch Metadata navigation/document requests, reject HEAD and use no-store /
  no-referrer response headers before the transaction-bound binding and single-use checks.
- Visa-side result completion performs the transaction-bound finalization and sends the registered
  RP callback; Auth remains the credential gateway.

## Verification

The combined WU-12/WU-13 command covering cancellation, switch, Auth handoff, OIDC callback,
initiated sign-in, RP completion and interruption was:

`bin/rails test test/services/base_auth_admission_cancellation_test.rb test/services/base_switcher_authority_test.rb test/controllers/base/app/switchers_controller_test.rb test/controllers/base/com/switcher_controller_test.rb test/controllers/base/org/switcher_controller_test.rb test/controllers/auth/sign_up_checkpoint_cancellation_test.rb test/integration/sign_app_oidc_browser_flow_test.rb test/integration/rp_sign_interruption_test.rb test/controllers/concerns/oidc/sso_initiator_test.rb test/controllers/concerns/oidc/callback_test.rb test/integration/oidc_initiated_sign_in_completion_test.rb test/integration/oidc_rp_completion_matrix_test.rb`

Result: **79 runs, 1,362 assertions, 0 failures, 0 errors, 0 skips**.

The full cross-unit acceptance inventory and external Jump/Edge integration remain unverified.
