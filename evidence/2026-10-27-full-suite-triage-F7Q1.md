# A-5: full-suite triage (G-1)

- Commit: `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`; dirty worktree with the uncommitted cycle
  changes (including this session's D-198, A-7, A-9 and CSP/LocalBackChannel changes). Test databases
  rebuilt 2026-10-27 with the R6V2 procedure.
- Command: `bin/rails test` (default parallel workers). Result: 18,445 runs, 155,881 assertions,
  179 failures, 244 errors, 0 skips, in 110 files.
- Classification is by failure signature and a reading of representative tests, not a per-test
  investigation. No test or code was changed for this triage, except one regression of this session's
  own D-198 change (below).

| Group | Count | Files | Classification |
|---|---|---|---|
| A. `NoMethodError` on `nil` (`css`, `[]`, `at_css`, `text`) while parsing an entry page or form | 235 | 37 | Test defect: pre-Design-D entry steps (old POST forms, `/ceremony_bindings` POST, Base-hosted authorize page), as in `test/controllers/auth/app/social/ceremony_entry_test.rb:39` and `emails_controller_security_test.rb:36` |
| B. Expected 2xx, got 303 to `visa.umaxica.*/ceremony_bindings/…/confirmation` | 34 | 11 | Test defect: the Visa ceremony-binding confirmation hop (Design D / WU-02) is not followed |
| C. Expected `www.umaxica.*`, got `visa.umaxica.*` (OP host) | 10 | 7 | Test defect: OP moved to Visa (WU-02) |
| D. COM files | 14 | 6 | Out of cycle (D-194) |
| E. Other | 130 | 59 | Mixed; see below |

Group E, by reading the first failure of each file:

- Test defect (expectation predates a decided change): Design D entry redirects (`sign_in_admission`,
  `preference_entry_recovery`, `totp_registration_boundary`, `auth_region_contract`), Base `/sign`
  302 vs 303 (`step_up_intent_authority`, `org_admin_step_up_ceremony`), OP host on Visa
  (`edit_org_jump_rt_sign_in`, `jump_directed_handoffs`, `core_rp_browser_flow`,
  `authentications_controller`), removed routes (`route_naming` `/sign/up` POST,
  `default_no_store_standalone_endpoints`), sign-out completion and Palm (`completions_controller`),
  test doubles missing `actor_record` after the sign-out quality fix (`oidc_token_revocation_service_coverage`),
  `Rack::Test::CookieJar#merge!` in `org_oidc_auth_handoff_root_completion`.
- Tooling/guard baselines to refresh (not behaviour): `architecture_baseline`
  (`bin/rails architecture:baseline`), `controller_inheritance_invariant`, `bare_controller`
  (Visa controller list), `layout_title_contract`, `actor_context_invariant`.
- Candidate code defects (not verified): `string_column_length_validation_contract`
  (`Op{Org,Com}AuthorityStop#realm` accepts a 4-character value), `connection_adapter_port_test`
  (`fd00::1`, the IPv6 classification already seen in SO-5), `signed_return_path_hardening`
  (`https://evil.example.test/steal` reported), `sign_in_path_browser_allowlist` (404 where 406 is
  expected), `authentication_rate_limit` (400 instead of 429), `client_secret_audit_delivery_job`
  (revocation requires scoped Step-Up), `social_pending_client_termination`
  (`admission parent intent mismatch`), `sign_up_passkey_termination_http` (409 expected).
- Environment: `omniauth_apple_strategy_contract` (`OpenSSL::PKey::EC.new` without arguments under
  OpenSSL 3), `root_revoke_others_concurrent_login` (timeout).
- Known and recorded elsewhere: `app_secret_login_journey` (A=… Passkey 400), `preference_logout_downgrade`,
  `welcome_dashboard_authority_slice_1c`, `html_title_contract:360`.

Regression of this session found and fixed: `html_title_contract_test.rb:594` — `GET /social/failure`
without a stored intent answered 503 after D-198. The APP OmniAuth failure endpoint now ends only an
attempt that has a stored sign-path intent, with `state_invalid` (CSRF) or `credential_failed`
(definitive 400) instead of `provider_failed` (503). `html_title_contract_test.rb`,
`social_login_admission_test.rb` and `social_callback_refusal_matrix_test.rb`: 32 runs, 1 failure
(`:360`, present in the full run as well).
