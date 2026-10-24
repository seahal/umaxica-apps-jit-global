# WU-07 and WU-29: refusal convergence and Sign Entry Sentry

Revision: `ba570a0007b1d40eabe32990a34831317fd98a93`.

Observed with the worktree already uncommitted. The check did not reset, clean, restore or stage
unrelated WU-24/WU-15/WU-18/Jump/Edge work.

## Implemented

- `SignInPathRefusalValue` is the closed six-class catalogue used by the shared refusal responder.
- Ownership and definitive refusals clear only the requester's sign-in/sign-up continuity;
  retryable, dependency, internal and protocol responses keep their owning boundary behavior.
- The shared responder emits one reason-coded `sign.refused` event without flow references, tokens,
  codes or contact values.
- Sign Entry Sentry resolves the six explicit APP/COM/ORG availability flags on every sign-in or
  sign-up entry and at the Auth binding/callback boundary. It does not gate Refresh, Sign Out,
  Step-Up or already-authenticated pages.

## Verification

Command:

`PUBLIC_VISA_SERVICE_URL=visa.umaxica.app PUBLIC_VISA_CORPORATE_URL=visa.umaxica.com PUBLIC_VISA_STAFF_URL=visa.umaxica.org bin/rails test test/resolvers/sign_entry_sentry_resolver_test.rb test/integration/sign_entry_sentry_test.rb test/security/invariants/feature_flag_registry_invariant_test.rb`

Result: **26 runs, 359 assertions, 0 failures, 0 errors, 0 skips**.

The focused curfew/social contract batch also passed **54 runs, 281 assertions, 0 failures, 0
errors**. The full Rails suite was not treated as green.
