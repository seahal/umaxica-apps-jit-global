# Visa OP authorization start and result receipt

Revision: `bde2346c17e2aa911acc95de1f6035f80498f2da`, with the pre-existing staged/unstaged
authentication cycle work, the previous Visa controller refinement, and this uncommitted change.
Scope: the owner requested the OP functionality needed on Visa. This slice closes authorization
start transport gaps and verifies real browser-bound result receipt in APP/COM/ORG.

## Delivered behavior

- Authorization GET and POST reject the presence of `result`, `result_ref`, `transaction_ref`,
  `cancellation_ref` or `switch_handoff` before validation/transaction allocation, including nil
  and empty values. GET also covers populated strings and nested values. These belong to the
  dedicated continuation resources, as required by `two.md` WU-12/WU-13 and section 6.11 N-1.
- Authorization HEAD returns 400 with an empty body and no redirect or new transaction. Before
  this change, a valid HEAD request allocated an authentication transaction.
- The two old result receiver test files now exercise the accepted Design D GET resources. They
  use separate actual Visa/Auth browser sessions, verify signed Jump targets with the configured
  issuer key, follow attachment/confirmation/redemption, and issue proof through the public Auth
  result API. Credential verification is intentionally outside these receiver tests, as before.
- The browser-binding scenario retains foreign attachment, foreign Visa confirmation, foreign Auth
  redemption, foreign Visa result refusal, owning-browser success and final replay refusal. The
  three transport scenarios retain CSRF refusal of a genuine result posted to the old endpoint,
  then prove missing/wrong navigation metadata and HEAD cannot consume it; the same result still
  establishes exactly one root through the proper navigation, and replay establishes no second root.
  Record comparisons assert booleans so a failed assertion cannot dump browser-binding material.
- Discovery route tests compare all three issuers to configured Visa hosts instead of Base and
  remove the old dynamic host selector. The request-profile ADR, authentication checklist AUTH-34
  and cycle ledger describe the current behavior. No state transition, schema, external service
  configuration or production environment was changed.

## Observed checks

- Red, continuation fields: `bin/rails test
  test/integration/visa_authorization_start_boundary_test.rb` failed both initial cases because
  requests containing continuation fields allocated transactions (two tests/nine assertions).
  Green before the HEAD addition: two tests/525 assertions, no failures/errors/skips.
- Red, HEAD: the same file with the HEAD case failed because HEAD allocated a transaction
  (three tests/527 assertions, one failure). Final focused start/receiver run:
  **seven tests/822 assertions, no failures/errors/skips**.
- The previously erroring four cases in `test/controllers/base/oidc_result_browser_binding_test.rb`
  and `test/controllers/base/oidc_result_csrf_transport_test.rb` pass on their current transport:
  four tests/279 assertions, no failures/errors/skips. This supersedes only the four receiver-test
  errors recorded in V8C2, not the entire earlier authentication-cycle failure inventory.
- The first expanded run had 255 tests/2,918 assertions and three failures, all Discovery issuer
  assertions still expecting Base. After correcting those expectations, that file passed alone
  (24 tests/57 assertions).
- **Final expanded run: 255 tests, 2,918 assertions, zero failures/errors/skips.** Command:
  `bin/rails test` with these file groups (braces abbreviate actual arguments):
  - `test/integration/{visa_authorization_start_boundary,visa_authorization_continuations,base_same_origin_handoff,oidc_initiated_sign_in_completion,oidc_rp_browser_flow,root_login_establishment_flow,visa_roots,unknown_host_root}_test.rb`
  - `test/integration/routes/oidc_discovery_route_stability_test.rb`
  - `test/controllers/base/{oidc_result_browser_binding,oidc_result_csrf_transport,oauth_redirect_uri_conformance,edge_v0_token_checks,oauth_token_rate_limit,oauth_token_exchange_e1,edge_v0_token_refreshes,edge_v0_token_refresh_binding,sign_out_and_oauth_revocation}_test.rb`
  - `test/controllers/base/{com,org}/oauth/authorizations_controller_test.rb`
  - `test/controllers/base/{app,com,org}/oidc/logouts_controller_test.rb`
  - `test/controllers/base/app/sign/in/limitations_controller_test.rb`
  - `test/controllers/{controller_inheritance_invariant,controller_base_inheritance}_test.rb`
  - `test/unit/security/{ri_routing_contract,authentication_mode_inventory,forbidden_rails_patterns,standard_csrf_invariant,identity_authority_inversion_guard}_test.rb`
  - `test/security/invariants/csrf_verification_strategy_invariant_test.rb`
- RuboCop: 91 files, no offenses (all 86 Visa controllers, the result-post concern and the four
  new/updated test files). Scoped `git diff --check` passed. One cohesive transport test retains
  its assertions with a documented local MultipleAssertions exemption.

## Limits

This is scoped OP verification, not full WU-02 or authentication-cycle acceptance. The full Rails
suite, the remaining historical protocol test migrations, the global architecture debt gate and
external Jump integration were not rerun or closed here. No deployment or external write occurred.
