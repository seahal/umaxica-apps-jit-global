# Full-suite repair, plan A (Claude): batch 1 remainder and batch 2

- Commit: `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`; dirty worktree (cycle changes, Codex's partial
  batch 1 P3R8, K8L4).
- Fixed:
  - `OpAppAuthorityStop` / `OpComAuthorityStop`: `realm` gains `length: { maximum: 3 }` like Codex's
    ORG change (WU-16; the contract test was the Red). `string_column_length_validation_contract_test`:
    206 runs, 0 failures.
  - `route_naming_test`: `/sign/up` and `/sign/in` POST are now asserted unrouted (Design D; the routes
    are `only: :show`).
  - `default_no_store_standalone_endpoints_test`: the token endpoint test targets the Visa host (WU-02).
  - `jump_directed_handoffs_test` (lines 55, 75), `edit_org_jump_rt_sign_in_test` (29),
    `core_rp_browser_flow_test` (`acme_host` → `PUBLIC_VISA_*_URL`): OP host is Visa (WU-02).
  - Changed files together: 230 runs, 2,448 assertions, 0 failures. RuboCop: no offenses.
- Not easy; reported instead of fixed:
  - Group B (Visa ceremony-binding confirmation, e.g. `auth/app/sign_ups_controller_test.rb`): following
    the redirect reaches the confirmation without the Visa browser nonce (400), because these tests
    build the admission with `OidcTestEntry` instead of a Visa authorize request. Needs a shared
    test helper that establishes the Visa session; a trial on the APP sign-up file was reverted.
  - `step_up_intent_authority_test`, `org_admin_step_up_ceremony_test`: the 302 is a redirect to
    `/sign` because the Base RP session in the test setup is no longer recognized, not a 302-vs-303
    question.
  - `preference_logout_downgrade_test`: the RP sign-out launch answers 422; the test's RP session lacks
    the stored logout binding the launcher now requires (SO-3).
  - `email_signup_base_root_completion_test`, `base/app/social/authentications_controller_test`,
    `app_secret_receipt_collection_journey_test`: the host assertion is one step of a longer
    pre-Visa journey; changing it alone does not repair the journey.
- Not run: a new full suite after these changes.
