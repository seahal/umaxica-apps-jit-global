# Cycle stage 3 selected unit checks

- HEAD `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`; dirty worktree including concurrent cycle changes. Each selected group was run sequentially with `PARALLEL_WORKERS=1 bin/rails test` and the files listed below. Counts are unit runs, not a full suite; repeated files can appear in multiple units. Environment construction and owner-held decisions were not tested.

## 1-01

- Result: 1-01 files 3 exit 0 seconds 10 43 runs, 278 assertions, 0 failures, 0 errors, 0 skips.
- Test files: `test/integration/root_login_establishment_flow_test.rb`, `test/integration/routes/retired_local_sign_in_route_test.rb`, `test/models/auth_ceremony_session_test.rb`.

## 1-03

- Result: 1-03 files 1 exit 0 seconds 9 2 runs, 15 assertions, 0 failures, 0 errors, 0 skips.
- Test files: `test/integration/routes/base_retired_edge_cookie_route_test.rb`.

## 1-04

- Result: 1-04 files 4 exit 1 seconds 15 37 runs, 231 assertions, 16 failures, 0 errors, 0 skips.
- Test files: `test/controllers/auth/app/sign/up/check/telephone/otps_controller_test.rb`, `test/controllers/auth/com/sign/up/check/telephone/otps_controller_test.rb`, `test/integration/telephone_signup_http_delivery_test.rb`, `test/integration/telephone_signup_source_proof_retry_test.rb`.
- Failing tests: `TelephoneSignupHttpDeliveryTest#test_com_actual_Telephone_signup_queues_encrypted_code_and_refuses_reissued_stale_transport`; `TelephoneSignupHttpDeliveryTest#test_com_actual_Telephone_signup_queues_encrypted_code_and_refuses_current_stale_transport`; `TelephoneSignupHttpDeliveryTest#test_app_actual_Telephone_signup_queues_encrypted_code_and_refuses_reissued_stale_transport`; `TelephoneSignupHttpDeliveryTest#test_app_actual_Telephone_signup_queues_encrypted_code_and_refuses_expired_stale_transport`; `TelephoneSignupHttpDeliveryTest#test_app_actual_Telephone_signup_queues_encrypted_code_and_refuses_current_stale_transport`; `TelephoneSignupHttpDeliveryTest#test_app_actual_Telephone_signup_queues_encrypted_code_and_refuses_cancelled_stale_transport`; `TelephoneSignupHttpDeliveryTest#test_com_actual_Telephone_signup_queues_encrypted_code_and_refuses_cancelled_stale_transport`; `TelephoneSignupHttpDeliveryTest#test_com_actual_Telephone_signup_queues_encrypted_code_and_refuses_expired_stale_transport`; `TelephoneSignupSourceProofRetryTest#test_com_telephone_signup_ceremony_proof_survives_Ticket_verify_contact_failure_and_HTTP_retry`; `TelephoneSignupSourceProofRetryTest#test_com_telephone_signup_ceremony_proof_survives_Ticket_enter_checkpoint_failure_and_HTTP_retry`; `TelephoneSignupSourceProofRetryTest#test_app_telephone_signup_ceremony_proof_survives_Ticket_verify_contact_failure_and_HTTP_retry`; `TelephoneSignupSourceProofRetryTest#test_app_telephone_signup_ceremony_proof_survives_Ticket_enter_guardrail_failure_and_HTTP_retry`; `TelephoneSignupSourceProofRetryTest#test_app_telephone_signup_ceremony_proof_survives_Ticket_enter_checkpoint_failure_and_HTTP_retry`; `TelephoneSignupSourceProofRetryTest#test_app_telephone_signup_ceremony_proof_survives_Ticket_clear_requirement_failure_and_HTTP_retry`; `TelephoneSignupSourceProofRetryTest#test_com_telephone_signup_ceremony_proof_survives_Ticket_clear_requirement_failure_and_HTTP_retry`; `TelephoneSignupSourceProofRetryTest#test_com_telephone_signup_ceremony_proof_survives_Ticket_enter_guardrail_failure_and_HTTP_retry`.

## 1-09

- Result: 1-09 files 1 exit 1 seconds 9 3 runs, 7 assertions, 1 failures, 0 errors, 0 skips.
- Test files: `test/integration/sign_in_path_browser_allowlist_test.rb`.
- Failing tests: `SignInPathBrowserAllowlistTest#test_the_token_endpoint_is_not_gated_on_the_browser_version`.

## 1-11

- Result: 1-11 files 12 exit 1 seconds 13 78 runs, 402 assertions, 1 failures, 0 errors, 0 skips.
- Test files: `test/adapters/oidc_jwks_concurrent_lookup_test.rb`, `test/adapters/oidc_jwks_refetch_limiter_test.rb`, `test/adapters/oidc_jwks_self_fetch_negative_cache_test.rb`, `test/adapters/oidc_op_protocol_verifiers_test.rb`, `test/integration/rp_backchannel_logout_jwks_outage_test.rb`, `test/integration/rp_backchannel_logout_receiver_test.rb`, `test/security/invariants/forbidden_patterns_invariant_test.rb`, `test/services/oidc/id_token_verifier_test.rb`, `test/services/oidc/jwks_service_test.rb`, `test/services/rp_request_authenticator_test.rb`, `test/unit/security/forbidden_rails_patterns_test.rb`, `test/values/jwt_temporal_validation_test.rb`.
- Failing tests: `Security::Invariants::ForbiddenPatternsInvariantTest#test_production_code_does_not_introduce_forbidden_security_patterns`.

## 1-17

- Result: 1-17 files 2 exit 0 seconds 13 109 runs, 503 assertions, 0 failures, 0 errors, 0 skips.
- Test files: `test/operations/op_identity_event_invalidator_test.rb`, `test/services/oidc/token_exchange_service_test.rb`.

## 1-23

- Result: 1-23 NO_MAPPED_TEST_FILES.

## 1-24

- Result: 1-24 files 25 exit 1 seconds 36 191 runs, 2141 assertions, 1 failures, 0 errors, 0 skips.
- Test files: `test/concurrency/sign_up_cleanup_principal_lock_test.rb`, `test/concurrency/sign_up_passkey_termination_http_test.rb`, `test/concurrency/sign_up_secret_lock_order_test.rb`, `test/controllers/auth/app/up/checkpoint_passkeys_controller_test.rb`, `test/controllers/auth/app/up/telephones_controller_test.rb`, `test/controllers/auth/com/sign/up/check/telephone/checkpoint_flow_test.rb`, `test/controllers/auth/effective_entry_intent_test.rb`, `test/controllers/auth/sign_up_admission_ownership_test.rb`, `test/controllers/auth/sign_up_checkpoint_cancellation_test.rb`, `test/integration/acme_social_link_completion_test.rb`, `test/jobs/sign_up_expiry_job_test.rb`, `test/models/sign_up_flow_admission_concurrency_test.rb`, `test/models/sign_up_flow_admission_ownership_test.rb`, `test/operations/auth_admission_binding_purger_test.rb`, `test/resolvers/auth_entry_intent_resolver_test.rb`, `test/resolvers/step_up_resolver_security_mode_test.rb`, `test/security/invariants/lifecycle_direct_state_write_invariant_test.rb`, `test/security/invariants/sign_up_admission_owner_write_invariant_test.rb`, `test/services/admission_binding_deadline_intent_test.rb`, `test/services/base_auth_admission_coordinator_test.rb`, `test/services/sign_up/cancellation_test.rb`, `test/services/sign_up_artifact_cleanup_atomicity_test.rb`, `test/services/sign_up_expiry_race_test.rb`, `test/services/sign_up_termination_idempotence_test.rb`, `test/unit/security/identity_authority_inversion_guard_test.rb`.
- Failing tests: `IdentityAuthorityInversionGuardTest#test_route_sources_use_noun_lifecycle_resources_for_edge_and_preference_routes`.

## 1-31

- Result: 1-31 files 2 exit 1 seconds 30 78 runs, 773 assertions, 1 failures, 0 errors, 0 skips.
- Test files: `test/controllers/auth/app/in/emails_controller_test.rb`, `test/controllers/auth/com/in/emails_controller_test.rb`.
- Failing tests: `Auth::Com::Sign::In::EmailsControllerTest#test_A34-2:_an_unfinished_COM_registration_cannot_complete_a_valid_email_OTP_sign-in`.

## 1-32

- Result: 1-32 files 2 exit 0 seconds 15 20 runs, 151 assertions, 0 failures, 0 errors, 0 skips.
- Test files: `test/controllers/auth/org/in/passkeys_controller_test.rb`, `test/models/operator_chronicle_sign_flow_halted_test.rb`.

## 1-35

- Result: 1-35 files 1 exit 0 seconds 13 6 runs, 187 assertions, 0 failures, 0 errors, 0 skips.
- Test files: `test/concurrency/sign_up_passkey_termination_http_test.rb`.

## 1-36

- Result: 1-36 files 1 exit 0 seconds 9 8 runs, 14 assertions, 0 failures, 0 errors, 0 skips.
- Test files: `test/unit/core/cookie_options_test.rb`.

## 1-37

- Result: 1-37 NO_MAPPED_TEST_FILES.

## 1-39

- Result: 1-39 NO_MAPPED_TEST_FILES.

## 1-40

- Result: 1-40 files 1 exit 0 seconds 10 6 runs, 66 assertions, 0 failures, 0 errors, 0 skips.
- Test files: `test/controllers/base/identity_recovery_turnstile_test.rb`.

## 1-41

- Result: 1-41 NO_MAPPED_TEST_FILES.

## 1-42

- Result: 1-42 files 1 exit 0 seconds 10 7 runs, 113 assertions, 0 failures, 0 errors, 0 skips.
- Test files: `test/controllers/base/oauth_redirect_uri_conformance_test.rb`.

## 2-02

- Result: 2-02 files 16 exit 1 seconds 24 131 runs, 1871 assertions, 1 failures, 0 errors, 0 skips.
- Test files: `test/controllers/base/edge_v0_token_refresh_binding_test.rb`, `test/controllers/base/oidc_result_browser_binding_test.rb`, `test/integration/acceptance_wu02_base_rp_state_test.rb`, `test/integration/acceptance_wu02_ceremony_purpose_host_test.rb`, `test/integration/acceptance_wu02_client_assertion_audience_test.rb`, `test/integration/acceptance_wu02_jwks_separation_test.rb`, `test/integration/base_same_origin_handoff_test.rb`, `test/integration/oidc_rp_browser_flow_test.rb`, `test/integration/org_root_login_establishment_test.rb`, `test/integration/routes/base_authority_route_contract_test.rb`, `test/integration/routes/oidc_discovery_route_stability_test.rb`, `test/integration/social_auth_app_flow_contract_test.rb`, `test/integration/visa_roots_test.rb`, `test/security/invariants/acceptance_wu02_base_op_session_isolation_test.rb`, `test/services/acceptance_wu02_visa_base_issuer_test.rb`, `test/services/jump_rt/return_policy_test.rb`.
- Failing tests: `OrgRootLoginEstablishmentTest#test_Entra_and_Passkey_establish_Normal_root_credentials_only_on_Visa`.

## 2-05

- Result: 2-05 files 8 exit 1 seconds 11 40 runs, 633 assertions, 0 failures, 6 errors, 0 skips.
- Test files: `test/controllers/auth/app/sign/up/check/google/birthdates_controller_test.rb`, `test/controllers/auth/app/social/ceremony_entry_test.rb`, `test/policies/sign_up/finalization_database_clock_test.rb`, `test/services/identity/social_ceremony_contract_test.rb`, `test/services/sign_up/contracts_test.rb`, `test/services/social_auth_link_concurrency_test.rb`, `test/services/social_callback_state_matrix_test.rb`, `test/views/cloudflare_turnstile_visible_partial_test.rb`.
- Failing tests: `Auth::App::Social::CeremonyEntryTest#test_apple_sign-up_entry_issues_a_sign-up_flow`; `Auth::App::Social::CeremonyEntryTest#test_a_sign-up_callback_without_its_entry_Flow_is_refused_and_creates_no_Flow`; `Auth::App::Social::CeremonyEntryTest#test_sign-in_entry_binds_provider_state_to_the_admitted_SID_without_a_signed_social_grant`; `Auth::App::Social::CeremonyEntryTest#test_google_sign-up_entry_issues_a_sign-up_flow`; `Auth::App::Social::CeremonyEntryTest#test_no_route_exists_for_a_provider_outside_the_supported_set`; `SignUpFinalizationDatabaseClockTest#test_finalization_follows_the_Ticket_database_deadline_immediately_before_at_and_after_expiry_in_both_realms`.

## 2-06

- Result: 2-06 files 4 exit 1 seconds 15 17 runs, 262 assertions, 0 failures, 1 errors, 0 skips.
- Test files: `test/concurrency/sign_up_passkey_termination_http_test.rb`, `test/integration/admission_curfew_test.rb`, `test/policies/sign_up/finalization_database_clock_test.rb`, `test/services/base_result_acceptance_curfew_test.rb`.
- Failing tests: `SignUpFinalizationDatabaseClockTest#test_finalization_follows_the_Ticket_database_deadline_immediately_before_at_and_after_expiry_in_both_realms`.

## 2-07

- Result: 2-07 files 9 exit 1 seconds 31 100 runs, 2864 assertions, 0 failures, 5 errors, 0 skips.
- Test files: `test/controllers/auth/app/in/emails_controller_test.rb`, `test/controllers/auth/app/social/ceremony_entry_test.rb`, `test/integration/admission_curfew_test.rb`, `test/integration/sign_entry_sentry_test.rb`, `test/integration/social_callback_refusal_matrix_test.rb`, `test/integration/visa_authorization_start_boundary_test.rb`, `test/resolvers/sign_entry_sentry_resolver_test.rb`, `test/security/invariants/feature_flag_registry_invariant_test.rb`, `test/values/sign_in_path_refusal_value_test.rb`.
- Failing tests: `Auth::App::Social::CeremonyEntryTest#test_a_sign-up_callback_without_its_entry_Flow_is_refused_and_creates_no_Flow`; `Auth::App::Social::CeremonyEntryTest#test_sign-in_entry_binds_provider_state_to_the_admitted_SID_without_a_signed_social_grant`; `Auth::App::Social::CeremonyEntryTest#test_apple_sign-up_entry_issues_a_sign-up_flow`; `Auth::App::Social::CeremonyEntryTest#test_google_sign-up_entry_issues_a_sign-up_flow`; `Auth::App::Social::CeremonyEntryTest#test_no_route_exists_for_a_provider_outside_the_supported_set`.

## 2-08

- Result: 2-08 files 11 exit 0 seconds 21 45 runs, 1908 assertions, 0 failures, 0 errors, 0 skips.
- Test files: `test/integration/social_callback_refusal_matrix_test.rb`, `test/integration/social_login_admission_test.rb`, `test/security/invariants/csrf_verification_strategy_invariant_test.rb`, `test/services/external_authentication_link_use_case_test.rb`, `test/services/external_authentication_login_use_case_test.rb`, `test/services/social_auth_link_handler_diagnostics_test.rb`, `test/services/social_auth_link_handler_test.rb`, `test/services/social_auth_login_handler_test.rb`, `test/services/social_callback_state_matrix_test.rb`, `test/unit/security/forbidden_rails_patterns_test.rb`, `test/unit/security/standard_csrf_invariant_test.rb`.

## 2-10

- Result: 2-10 files 4 exit 0 seconds 27 190 runs, 1134 assertions, 0 failures, 0 errors, 0 skips.
- Test files: `test/controllers/base/oauth_oidc_authority_test.rb`, `test/controllers/concerns/oidc/callback_test.rb`, `test/integration/rp_refresh_recovery_test.rb`, `test/services/oidc/token_exchange_service_test.rb`.

## 2-12

- Result: 2-12 files 15 exit 0 seconds 54 130 runs, 1988 assertions, 0 failures, 0 errors, 0 skips.
- Test files: `test/controllers/auth/ceremony_admission_boundary_test.rb`, `test/controllers/auth/sign_up_checkpoint_cancellation_test.rb`, `test/controllers/base/app/switchers_controller_test.rb`, `test/controllers/base/com/switcher_controller_test.rb`, `test/controllers/base/org/switcher_controller_test.rb`, `test/controllers/concerns/oidc/callback_test.rb`, `test/controllers/concerns/oidc/sso_initiator_test.rb`, `test/integration/acceptance_wu12_relay_repeat_test.rb`, `test/integration/base_dashboard_passkey_login_journey_test.rb`, `test/integration/base_org_dashboard_local_login_journey_test.rb`, `test/integration/oidc_initiated_sign_in_completion_test.rb`, `test/integration/rp_sign_interruption_test.rb`, `test/integration/sign_app_oidc_browser_flow_test.rb`, `test/services/base_auth_admission_cancellation_test.rb`, `test/services/base_switcher_authority_test.rb`.

## 2-13

- Result: 2-13 files 12 exit 0 seconds 48 80 runs, 717 assertions, 0 failures, 0 errors, 0 skips.
- Test files: `test/controllers/auth/sign_up_checkpoint_cancellation_test.rb`, `test/controllers/base/app/switchers_controller_test.rb`, `test/controllers/base/com/switcher_controller_test.rb`, `test/controllers/base/org/switcher_controller_test.rb`, `test/controllers/concerns/oidc/callback_test.rb`, `test/controllers/concerns/oidc/sso_initiator_test.rb`, `test/integration/acceptance_wu13_authorize_unrelated_params_test.rb`, `test/integration/oidc_initiated_sign_in_completion_test.rb`, `test/integration/rp_sign_interruption_test.rb`, `test/integration/sign_app_oidc_browser_flow_test.rb`, `test/services/base_auth_admission_cancellation_test.rb`, `test/services/base_switcher_authority_test.rb`.

## 2-18

- Result: 2-18 NO_MAPPED_TEST_FILES.

## 2-25

- Result: 2-25 files 2 exit 1 seconds 10 10 runs, 122 assertions, 0 failures, 2 errors, 0 skips.
- Test files: `test/services/oidc/discovery_document_test.rb`, `test/services/oidc_token_revocation_service_coverage_test.rb`.
- Failing tests: `OidcTokenRevokerCoverageTest#test_revokes_access_token_when_refresh_token_parsing_fails`; `OidcTokenRevokerCoverageTest#test_revokes_refresh_token_when_the_digest_matches`.

## 2-27

- Result: 2-27 files 5 exit 1 seconds 18 77 runs, 820 assertions, 0 failures, 2 errors, 0 skips.
- Test files: `test/controllers/base/oauth_oidc_authority_test.rb`, `test/controllers/base/oidc_result_browser_binding_test.rb`, `test/controllers/concerns/oidc/sso_initiator_test.rb`, `test/services/oidc/discovery_document_test.rb`, `test/services/oidc_token_revocation_service_coverage_test.rb`.
- Failing tests: `OidcTokenRevokerCoverageTest#test_revokes_access_token_when_refresh_token_parsing_fails`; `OidcTokenRevokerCoverageTest#test_revokes_refresh_token_when_the_digest_matches`.

## 2-29

- Result: 2-29 files 12 exit 0 seconds 26 139 runs, 1446 assertions, 0 failures, 0 errors, 0 skips.
- Test files: `test/controllers/auth/org/in/emergency/passkeys_controller_test.rb`, `test/controllers/auth/org/up/invitations_controller_test.rb`, `test/controllers/base/app/welcomes_controller_test.rb`, `test/controllers/base/oauth_oidc_authority_test.rb`, `test/integration/acceptance_wu29_root_login_sentry_test.rb`, `test/integration/acceptance_wu29_sentry_toggle_test.rb`, `test/integration/acceptance_wu29_sign_entry_sentry_blocked_test.rb`, `test/integration/app_passkey_secret_session_step_up_test.rb`, `test/integration/sign_entry_sentry_test.rb`, `test/integration/social_login_admission_test.rb`, `test/resolvers/sign_entry_sentry_resolver_test.rb`, `test/security/invariants/feature_flag_registry_invariant_test.rb`.

## 2-33

- Result: 2-33 NO_MAPPED_TEST_FILES.

## 2-34

- Result: 2-34 files 7 exit 0 seconds 56 121 runs, 2502 assertions, 0 failures, 0 errors, 0 skips.
- Test files: `test/controllers/auth/app/in/challenges_controller_test.rb`, `test/controllers/auth/app/in/emails_controller_test.rb`, `test/controllers/auth/app/in/passkeys_controller_test.rb`, `test/controllers/auth/com/in/passkeys_controller_test.rb`, `test/integration/acceptance_wu34_registered_commit_failure_test.rb`, `test/integration/social_callback_refusal_matrix_test.rb`, `test/models/unfinished_registration_login_test.rb`.

## 3-19

- Result: 3-19 files 2 exit 0 seconds 12 32 runs, 451 assertions, 0 failures, 0 errors, 0 skips.
- Test files: `test/controllers/base/preference_authority_slice_1f_test.rb`, `test/initializers/locale_test.rb`.

## 3-20

- Result: 3-20 files 13 exit 0 seconds 44 149 runs, 1168 assertions, 0 failures, 0 errors, 0 skips.
- Test files: `test/concurrency/passkey_authentication_resubmission_http_test.rb`, `test/controllers/auth/app/in/passkeys_controller_test.rb`, `test/controllers/auth/com/in/passkeys_controller_test.rb`, `test/controllers/auth/org/in/emergency/passkeys_controller_test.rb`, `test/controllers/auth/org/in/passkeys_controller_test.rb`, `test/controllers/auth/org/verification/emergency_step_up_prohibition_test.rb`, `test/controllers/auth/org/verification/passkeys_controller_test.rb`, `test/integration/base_passkey_mutation_step_up_test.rb`, `test/queries/passkey_sign_in_identity_resolver_query_test.rb`, `test/services/webauthn/verifier_uv_policy_test.rb`, `test/unit/security/webauthn_invariants_test.rb`, `test/unit/webauthn/challenge_store_test.rb`, `test/unit/webauthn/verifiers_test.rb`.

## 3-26

- Result: 3-26 files 2 exit 0 seconds 10 27 runs, 101 assertions, 0 failures, 0 errors, 0 skips.
- Test files: `test/queries/sign_up_attempt_diagnosis_inventory_test.rb`, `test/services/valkey/auth_state/opaque_admission_store_test.rb`.

## Limits

- File-level success is not automatically acceptance of every case. Cases with missing mapped tests, incomplete assertions, environment checks or owner-held decisions remain open. Full-suite triage is recorded separately.
- Execution stopped at the user's request after the WU-26 group. WU-30 was interrupted during startup and has no completed result; WU-38 and WU-43 were not run. The WU-34 first attempt was interrupted to exclude owner-held APP Secret and COM OTP files, then the remaining seven files passed. The whole-file WU-31 and WU-07 runs had already executed the owner-held COM OTP case; it failed with 403 rather than 422, and no change was made to it.
- Selected 1a/1b tests are not an exhaustive per-case mapping. Notable observations: WU-04 telephone journey tests expected Base where the flow reached Visa (16 failures); WU-09 token-route test received 404; WU-11 security guard flagged `allow_other_host: true` in sign-out; WU-24 route guard expected an Auth registration declaration absent in current routes; WU-05/07 social ceremony setup attempted to read a missing form; WU-25/27 legacy test doubles lacked `actor_record`; WU-02 ORG journey reached passkey registration instead of the expected birthdate scope. These are observations, not a complete diagnosis or authorization to modify product code.
- A-4 Partial-case assertions, A-5 full-suite triage, and A-6 document reconciliation were not started. A44-4 real replica lag, A44-5 actual writer failure and A44-10 remain open as described in `evidence/2026-10-26-wu44-writer-check-N6K3.md`. No full suite, migrations or development DB rebuild was run in this work segment.
