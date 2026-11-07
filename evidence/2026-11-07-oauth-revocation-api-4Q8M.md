# OAuth revocation API boundary verification

- Date: 2026-11-07
- HEAD: `271673747d6c940325b3287ab7c1045f5a7549ef`
- Worktree: already dirty with unrelated edits before this task; the results below reflect that
  shared worktree. No unrelated files were reverted, stashed or reformatted.

## Change

The Visa APP and ORG `POST /oauth/revoke` leaves inherit from `ActionController::API` and authenticate
the request-body client credentials before the existing revocation operation. The IP guard remains
20 requests per minute; a second Rails-native limit allows 600 requests per authenticated client per
minute. The client limit is keyed through the authenticated `client_id`, with the authentication
result cached on the same per-request operation so a private-key assertion is consumed once. The
ORG `/oauth/token` browser-forgery boundary remains a known residual; no logout-order or CSRF
configuration change was made.

## Verification

- `test/controllers/visa/oauth_revocations_controller_test.rb`: 23 runs, 520 assertions, 0 failures,
  0 errors. Covers ZR-1 through ZR-10 for APP and ORG, including real routing and stop writes,
  assertion rejection/replay, state preservation, FQDN refusal and both rate-limit boundaries.
- APP and ORG Visa logout-confirmation forgery tests at
  `test/controllers/base/app/oidc/logouts_controller_test.rb:3486` and
  `test/controllers/base/org/oidc/logouts_controller_test.rb:849`: 2 runs, 4 assertions, 0 failures,
  0 errors (ZR-11).
- Base APP sign-out ZR-12 test: 1 run, 14 assertions, 0 failures, 0 errors. It uses the real
  `OidcOpRevocationClient` request shape, routes the call through Visa, observes HTTP 200 and verifies
  only the matching RP grant is stopped.
- Revocation controller plus revoker, revocation service and client tests after the final operation
  change: 38 runs, 542 assertions, 0 failures, 0 errors.
- Expanded revocation/sign-out/request-boundary suite: 148 runs, 1,683 assertions, 8 failures,
  0 errors. Its eight failure identifiers exactly match the baseline run below. They are existing
  `OidcRpLogoutRegisteredRpMatrixTest` / `OidcCurrentDeviceLogoutTest` cases expecting 303 but
  receiving 401; none was added by this change.
- Baseline for the overlapping existing suites: 102 runs, 1,001 assertions, the same 8 failures and
  no errors. The failing identifiers are:
  `OidcRpLogoutRegisteredRpMatrixTest#test_each_first-party_RP_clears_local_credentials_without_stopping_its_grant_and_redirects_with_its_stored_hint`,
  `#test_A14-18_old_completion_cannot_destroy_an_APP_RP_sign-in_established_through_the_callback`,
  `#test_an_old_return_refuses_a_wrong_state_and_cannot_disrupt_a_new_RP_session`,
  `OidcCurrentDeviceLogoutTest#test_APP_RP_logout_leaves_the_signed-in_ORG_browser_usable_on_its_next_request`,
  `#test_app_leaving_Visa_confirmation_keeps_the_OP_session_and_both_grants_active`,
  `#test_org_leaving_Visa_confirmation_keeps_the_OP_session_and_both_grants_active`,
  `#test_app_confirmation_stops_both_rotated_roots_and_their_grants_on_the_current_device`, and
  `#test_org_confirmation_stops_both_rotated_roots_and_their_grants_on_the_current_device`.
- The protocol controller boundary and default no-store invariant: 9 runs, 38 assertions, 0 failures,
  0 errors. The FQDN registry invariant also passed in the expanded suite.
- `bin/rubocop` on the 8 changed Ruby files: no offenses. The Brakeman command
  `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` reported 0 errors and 0 security
  warnings. `git diff --check`: clean.

An exploratory run of `test/controllers/security/csrf_route_coverage_test.rb` raised
`NoMethodError` for `forgery_protection_strategy` on the unrelated
`Visa::App::Api::V0::SensitiveAdmissionsController`. Those sensitive-admission API files were
already modified in the dirty worktree and are outside this change. The required browser-forgery
request tests and the protocol controller classification test pass.
