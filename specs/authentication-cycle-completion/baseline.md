# Initial authentication cycle baseline dispositions

Status: implementing. Each entry below was reported by the actual full-suite run.
All are untriaged; none is waived or reassigned by this list. Follow G-1 when touching its area.

- Commit: `6e4d70d0b0799a4ef9bd9fc4cea2c21d4b3eca72`; pre-existing dirty worktree.
- Command: `bin/rails test`.
- Result: 18422 runs, 158064 assertions, 146 failures, 24 errors, 0 skips; exit 1.
- Baseline log SHA-256: `1a933e0685225b0ee692ba03ae7ca0a61896a6fd78ee114a620e8bd5ba8d3e4c`.
- New cleanup regression files were created after the runner loaded its test list; no production
  code changed during the baseline.

| Outcome | Test identity / reported location | Disposition |
|---|---|---|
| Failure | `Security::Invariants::DefaultNoStorePolicyInvariantTest#test_every_controller_beneath_a_policy_root_runs_no-store_first_and_the_availability_gate_second [test/security/invariants/default_no_store_policy_invariant_test.rb:160]:` | Untriaged |
| Failure | `AuthStaffTest#test_log_in_sets_access_token_in_cookie [test/concerns/auth/staff_test.rb:102]:` | Untriaged |
| Failure | `Base::Org::AvatarOwnershipTransfersControllerTest#test_another_authorized_source_agent_can_cancel_a_transfer_over_HTTP [test/controllers/base/org/avatar_ownership_transfers_controller_test.rb:407]:` | Untriaged |
| Failure | `Base::Org::AvatarOwnershipTransfersControllerTest#test_registry_accept_transport_is_refused_before_the_verified_ownership_cutover [test/controllers/base/org/avatar_ownership_transfers_controller_test.rb:200]:` | Untriaged |
| Error | `AuthStaffTest#test_log_out_clears_session_and_current_operator:` | Untriaged |
| Error | `AuthStaffTest#test_log_in_sets_cookie_expirations:` | Untriaged |
| Error | `AuthStaffTest#test_log_out_revokes_refresh_token_and_removes_cookies:` | Untriaged |
| Failure | `AuthStaffTest#test_log_in_returns_tokens_hash [test/concerns/auth/staff_test.rb:157]:` | Untriaged |
| Error | `AuthStaffTest#test_log_in_uses_host-only_cookies:` | Untriaged |
| Failure | `Base::Org::AvatarOwnershipTransfersControllerTest#test_registry_request_transport_is_refused_before_the_verified_ownership_cutover [test/controllers/base/org/avatar_ownership_transfers_controller_test.rb:51]:` | Untriaged |
| Failure | `Base::Org::AvatarOwnershipTransfersControllerTest#test_registry_request_refuses_a_reused_idempotency_key_with_different_input [test/controllers/base/org/avatar_ownership_transfers_controller_test.rb:86]:` | Untriaged |
| Failure | `Base::Org::AvatarOwnershipTransfersControllerTest#test_registry_request_refuses_a_reused_idempotency_key_from_a_different_initiator [test/controllers/base/org/avatar_ownership_transfers_controller_test.rb:113]:` | Untriaged |
| Error | `AuthStaffTest#test_log_in_schedules_forced_logout_and_delayed_deletion_for_staff_token:` | Untriaged |
| Failure | `Base::Org::AvatarOwnershipTransfersControllerTest#test_org_owner_can_request_app_transfer_and_cancel_only_with_cancel_scope [test/controllers/base/org/avatar_ownership_transfers_controller_test.rb:276]:` | Untriaged |
| Failure | `Base::Org::AvatarOwnershipTransfersControllerTest#test_registry_request_replays_the_committed_result_for_a_stable_idempotency_key [test/controllers/base/org/avatar_ownership_transfers_controller_test.rb:69]:` | Untriaged |
| Failure | `Base::Org::AvatarOwnershipTransfersControllerTest#test_registry_accept_transport_completes_an_explicit_registry_reservation [test/controllers/base/org/avatar_ownership_transfers_controller_test.rb:640]:` | Untriaged |
| Failure | `Base::Org::AvatarOwnershipTransfersControllerTest#test_keyless_legacy_request_is_refused_after_the_ownership_cutover [test/controllers/base/org/avatar_ownership_transfers_controller_test.rb:167]:` | Untriaged |
| Failure | `AppPasskeySecretSessionStepUpTest#test_additional_TOTP_registration_starts_with_a_read-only_Base_form_and_purpose-bound_POST [test/integration/app_passkey_secret_session_step_up_test.rb:284]:` | Untriaged |
| Failure | `OidcResultCsrfTransportTest#test_app_genuine_OIDC_result_requires_missing-header_CSRF_fallback_and_finalizes_one_root [test/controllers/base/oidc_result_csrf_transport_test.rb:135]:` | Untriaged |
| Failure | `OidcResultCsrfTransportTest#test_com_genuine_OIDC_result_requires_missing-header_CSRF_fallback_and_finalizes_one_root [test/controllers/base/oidc_result_csrf_transport_test.rb:135]:` | Untriaged |
| Failure | `OidcResultCsrfTransportTest#test_org_genuine_OIDC_result_requires_missing-header_CSRF_fallback_and_finalizes_one_root [test/controllers/base/oidc_result_csrf_transport_test.rb:135]:` | Untriaged |
| Failure | `Base::Org::WelcomeReturnTargetControllerTest#test_org_Next_returns_to_the_verified_pre-sign-in_page [test/controllers/base/welcome_return_target_realms_test.rb:241]:` | Untriaged |
| Error | `Base::Org::WelcomeReturnTargetControllerTest#test_org_ignores_a_return_target_issued_for_the_com_surface:` | Untriaged |
| Failure | `Base::Org::WelcomeReturnTargetControllerTest#test_org_skips_the_page_without_its_own_gate_even_when_the_com_gate_is_present [test/controllers/base/welcome_return_target_realms_test.rb:292]:` | Untriaged |
| Failure | `Base::Org::Organizations::MembershipsControllerTest#test_a_malformed_page_number_is_a_bad_request,_not_an_empty_page [test/controllers/base/org/organizations/memberships_controller_test.rb:168]:` | Untriaged |
| Failure | `Base::Org::SwitcherControllerTest#test_operator_can_select_an_org-owned_Avatar_without_making_it_the_operator_identity [test/controllers/base/org/switcher_controller_test.rb:355]:` | Untriaged |
| Failure | `AppSecretLoginJourneyTest#test_manual_HTTP_delivery_and_storage_confirmation_lead_to_one_canonical_Base_Secret_login [test/integration/app_secret_login_journey_test.rb:1190]:` | Untriaged |
| Failure | `Base::Org::Identity::RotationsControllerTest#test_a_credential_owned_by_another_operator_is_not_found [test/controllers/base/org/identity/rotations_controller_test.rb:151]:` | Untriaged |
| Failure | `Base::Org::SwitcherControllerTest#test_authenticated_operator_can_access_switcher_update [test/controllers/base/org/switcher_controller_test.rb:251]:` | Untriaged |
| Failure | `Base::App::AvatarOwnershipTransfersControllerTest#test_org_target_accepts_with_its_operation-specific_Step-Up_and_no_AAL_floor [test/controllers/base/app/avatar_ownership_transfers_controller_test.rb:952]:` | Untriaged |
| Failure | `SignOrgCredentialRemovalConstraintsTest#test_email_telephone_passkey_and_secret_credential_removals_are_allowed_when_dimensions_remain [test/integration/sign/org/credential_removal_constraints_test.rb:1123]:` | Untriaged |
| Failure | `Base::Org::Organizations::MembershipsControllerTest#test_org_idor_cannot_swap_membership_id_from_another_org [test/controllers/base/org/organizations/memberships_controller_test.rb:533]:` | Untriaged |
| Failure | `Base::Org::Identity::RotationsControllerTest#test_the_owner_is_handed_to_the_secret_credential_edit_page [test/controllers/base/org/identity/rotations_controller_test.rb:80]:` | Untriaged |
| Failure | `Base::Org::SwitcherControllerTest#test_HTML_switcher_page_displays_the_optional_Avatar_candidate_context [test/controllers/base/org/switcher_controller_test.rb:166]:` | Untriaged |
| Failure | `Base::Org::SwitcherControllerTest#test_authenticated_operator_can_access_switcher_show [test/controllers/base/org/switcher_controller_test.rb:92]:` | Untriaged |
| Error | `Auth::OrgEmergencySessionContinuityTest#test_a_normal_sign-in_records_the_normal_context_and_never_the_emergency_one:` | Untriaged |
| Failure | `IdentityCredentialRemovalCommitterTest#test_removal_deletes_passkeys_or_retains_terminal_non-passkey_credentials_while_preserving_root_sessions [test/operations/identity_credential_removal_committer_test.rb:343]:` | Untriaged |
| Failure | `Base::Org::Organizations::MembershipsControllerTest#test_show_returns_the_membership_the_actor_may_read [test/controllers/base/org/organizations/memberships_controller_test.rb:742]:` | Untriaged |
| Failure | `AppSecretRootLoginConcurrencyTest#test_Base_Secret_results_racing_completion_cannot_establish_a_second_or_terminal_root_login [test/integration/app_secret_root_login_concurrency_test.rb:474]:` | Untriaged |
| Failure | `Base::Org::Organizations::MembershipsControllerTest#test_index_lists_the_bureau's_real_memberships [test/controllers/base/org/organizations/memberships_controller_test.rb:94]:` | Untriaged |
| Failure | `SignOrgCredentialRemovalConstraintsTest#test_email_removal_may_leave_a_usable_passkey-only_identity [test/integration/sign/org/credential_removal_constraints_test.rb:175]:` | Untriaged |
| Error | `Auth::OrgEmergencySessionContinuityTest#test_repeated_rotation_never_drops_the_emergency_context:` | Untriaged |
| Failure | `IdentityCredentialRemovalCommitterTest#test_revoked_session_and_ticket_failure_leave_an_owned_credential_active [test/operations/identity_credential_removal_committer_test.rb:428]:` | Untriaged |
| Failure | `Auth::OrgEmergencySessionContinuityTest#test_an_emergency_sign-in_records_the_context_on_the_session_row_and_in_the_access_token [test/concerns/auth/org_emergency_session_continuity_test.rb:85]:` | Untriaged |
| Failure | `SignOrgCredentialRemovalConstraintsTest#test_telephone_removal_may_leave_a_usable_passkey-only_identity [test/integration/sign/org/credential_removal_constraints_test.rb:332]:` | Untriaged |
| Error | `Auth::OrgEmergencySessionContinuityTest#test_refresh_keeps_the_emergency_context_and_never_upgrades_the_session:` | Untriaged |
| Error | `Auth::OrgEmergencySessionContinuityTest#test_signing_out_of_an_emergency_session_and_signing_in_normally_produces_a_new_normal_session:` | Untriaged |
| Failure | `AppleSocialFlowsTest#test_sign_up_waits_for_confirmation_before_creating_user_and_identity [test/integration/apple_social_flows_test.rb:449]:` | Untriaged |
| Failure | `SignOrgCredentialRemovalConstraintsTest#test_secret_removal_requires_an_independent_step-up_method [test/integration/sign/org/credential_removal_constraints_test.rb:646]:` | Untriaged |
| Failure | `AppleSocialFlowsTest#test_sign_in_uses_existing_identity [test/integration/apple_social_flows_test.rb:969]:` | Untriaged |
| Error | `Sign::In::OtpResendServiceTest#test_app_resend_preserves_independent_candidates_and_delivers_only_to_the_effective_owner:` | Untriaged |
| Error | `Sign::In::OtpResendServiceTest#test_com_resend_preserves_independent_candidates_and_delivers_only_to_the_effective_owner:` | Untriaged |
| Failure | `BaseStepUpIntentAuthorityTest#test_org_a_changed_return_target_conflicts_and_protected_continue_retains_the_original_intent [test/controllers/base/step_up_intent_authority_test.rb:535]:` | Untriaged |
| Failure | `BaseStepUpIntentAuthorityTest#test_com_a_changed_return_target_conflicts_and_protected_continue_retains_the_original_intent [test/controllers/base/step_up_intent_authority_test.rb:535]:` | Untriaged |
| Failure | `BaseStepUpIntentAuthorityTest#test_app_ordinary_verification_conflicts_with_a_pending_bootstrap_purpose_without_replacing_it [test/controllers/base/step_up_intent_authority_test.rb:266]:` | Untriaged |
| Failure | `BaseStepUpIntentAuthorityTest#test_app_conflict_continue_explicitly_restarts_an_expired_binding_without_extending_its_parent_deadline [test/controllers/base/step_up_intent_authority_test.rb:773]:` | Untriaged |
| Failure | `BaseStepUpIntentAuthorityTest#test_app_conflict_continue_returns_to_admitted_Auth_without_allocating_another_admission [test/controllers/base/step_up_intent_authority_test.rb:889]:` | Untriaged |
| Failure | `BaseStepUpIntentAuthorityTest#test_org_ordinary_verification_conflicts_with_a_pending_bootstrap_purpose_without_replacing_it [test/controllers/base/step_up_intent_authority_test.rb:266]:` | Untriaged |
| Failure | `BaseStepUpIntentAuthorityTest#test_com_ordinary_verification_conflicts_with_a_pending_bootstrap_purpose_without_replacing_it [test/controllers/base/step_up_intent_authority_test.rb:266]:` | Untriaged |
| Failure | `BaseStepUpIntentAuthorityTest#test_app_conflict_forms_preserve_validated_scope_and_return_proof_through_protected_choices [test/controllers/base/step_up_intent_authority_test.rb:661]:` | Untriaged |
| Failure | `BaseStepUpIntentAuthorityTest#test_app_a_changed_return_target_conflicts_and_protected_continue_retains_the_original_intent [test/controllers/base/step_up_intent_authority_test.rb:535]:` | Untriaged |
| Failure | `SocialAuthAppFlowContractTest#test_Apple_sign_up_entry_creates_one_client_and_one_active_social_identity_without_email [test/integration/social_auth_app_flow_contract_test.rb:1452]:` | Untriaged |
| Failure | `BaseOauthOidcAuthorityTest#test_base_oauth_authorize_can_retry_a_finalized_result_without_a_second_root_session [test/controllers/base/oauth_oidc_authority_test.rb:1825]:` | Untriaged |
| Failure | `SocialAuthAppFlowContractTest#test_Google_sign_up_entry_creates_one_client_and_one_active_social_identity_without_email [test/integration/social_auth_app_flow_contract_test.rb:736]:` | Untriaged |
| Failure | `OrgOidcAuthHandoffRootCompletionTest#test_org_real_OIDC_Entra_and_Passkey_complete_preserves_Base_root_authority [test/integration/org_oidc_auth_handoff_root_completion_test.rb:356]:` | Untriaged |
| Failure | `Security::Invariants::AuthorizationFailureAuditInvariantTest#test_an_operator_refused_by_a_staff_policy_is_answered_403_and_recorded_as_an_authorization_failure [test/security/invariants/authorization_failure_audit_invariant_test.rb:64]:` | Untriaged |
| Failure | `Base::App::Social::AuthenticationsControllerTest#test_a_result-delivery_outage_resumes_the_exact_committed_signup_without_another_Source_or_Root [test/controllers/base/app/social/authentications_controller_test.rb:548]:` | Untriaged |
| Failure | `SocialAuthAppFlowContractTest#test_Google_sign_in_reuses_existing_social_identity_and_refreshes_credentials [test/integration/social_auth_app_flow_contract_test.rb:1850]:` | Untriaged |
| Failure | `SocialAuthAppFlowContractTest#test_Apple_sign_in_reuses_existing_social_identity_and_refreshes_credentials [test/integration/social_auth_app_flow_contract_test.rb:2240]:` | Untriaged |
| Failure | `SignOrgVerificationBaseDirectCoverageTest#test_a_forged_verification_cookie_cannot_authorize_the_protected_Base_operation [test/controllers/concerns/sign/org_verification_base_included_do_test.rb:78]:` | Untriaged |
| Failure | `Base::Org::Identity::BirthdatesControllerTest#test_show_reports_that_a_birthdate_is_not_set [test/controllers/base/org/identity/birthdates_controller_test.rb:82]:` | Untriaged |
| Failure | `Base::Org::Identity::BirthdatesControllerTest#test_show_includes_the_stored_birthdate_when_one_is_present [test/controllers/base/org/identity/birthdates_controller_test.rb:156]:` | Untriaged |
| Failure | `SessionLimitResolutionTransactionableTest#test_org_refuses_a_different_root_flow_when_a_live_waiting_slot_is_occupied [test/models/session_limit_resolution_transactionable_test.rb:694]:` | Untriaged |
| Failure | `SignOrgVerificationBaseDirectCoverageTest#test_a_missing_verification_cookie_leaves_the_protected_Base_operation_pending [test/controllers/concerns/sign/org_verification_base_included_do_test.rb:68]:` | Untriaged |
| Failure | `SessionLimitResolutionTransactionableTest#test_org_concurrent_root_logins_for_the_last_slot_commit_one_session_and_resolve_the_other [test/models/session_limit_resolution_transactionable_test.rb:832]:` | Untriaged |
| Failure | `Base::Org::AvatarsControllerTest#test_selector-only_operator_cannot_access_org_avatar [test/controllers/base/org/avatars_controller_test.rb:88]:` | Untriaged |
| Failure | `Base::Org::AvatarsControllerTest#test_request_parameters_cannot_replace_the_selected_org_Avatar [test/controllers/base/org/avatars_controller_test.rb:458]:` | Untriaged |
| Failure | `Base::Org::AvatarsControllerTest#test_selected_org-owned_Avatar_can_be_shown_and_its_moniker_updated [test/controllers/base/org/avatars_controller_test.rb:237]:` | Untriaged |
| Error | `Auth::Org::ApplicationControllerTest#test_am_i_user?_returns_false:` | Untriaged |
| Failure | `Base::Org::AvatarsControllerTest#test_org_remains_usable_with_no_default_Avatar_selected_or_provisioned [test/controllers/base/org/avatars_controller_test.rb:161]:` | Untriaged |
| Failure | `Base::Org::AvatarsControllerTest#test_post-cutover_moniker_update_uses_concrete_Bureau_ownership [test/controllers/base/org/avatars_controller_test.rb:554]:` | Untriaged |
| Failure | `AuthSessionIssuanceBoundarySurfacesTest#test_org:_an_issuance-pending_flow_is_completed_in_the_same_commit_and_bound_to_the_session [test/controllers/concerns/auth/session_issuance_boundary_surfaces_test.rb:206]:` | Untriaged |
| Error | `Auth::Org::ApplicationControllerTest#test_includes_expected_concerns:` | Untriaged |
| Failure | `AuthSessionIssuanceBoundarySurfacesTest#test_org:_a_flow_that_already_carries_a_session_is_refused_at_the_final_boundary [test/controllers/concerns/auth/session_issuance_boundary_surfaces_test.rb:183]:` | Untriaged |
| Failure | `AuthSessionIssuanceBoundarySurfacesTest#test_org:_at_the_limit_nothing_is_issued,_no_cookie_is_set,_and_the_existing_context_is_kept [test/controllers/concerns/auth/session_issuance_boundary_surfaces_test.rb:162]:` | Untriaged |
| Failure | `AuthSessionIssuanceBoundarySurfacesTest#test_org:_a_flow_bound_to_a_different_actor_is_refused_at_the_final_boundary [test/controllers/concerns/auth/session_issuance_boundary_surfaces_test.rb:196]:` | Untriaged |
| Error | `Auth::Org::ApplicationControllerTest#test_reflects_localization_and_theme_after_actor_context_is_set:` | Untriaged |
| Error | `Base::App::Verification::SetupsControllerTest#test_a_wrong_email_code_leaves_the_bootstrap_pending:` | Untriaged |
| Failure | `AuthSessionIssuanceBoundarySurfacesTest#test_org:_one_below_the_limit_commits_one_ACTIVE_root_session_with_cookies_and_context [test/controllers/concerns/auth/session_issuance_boundary_surfaces_test.rb:135]:` | Untriaged |
| Failure | `BasePasskeyMutationStepUpTest#test_Base_passkey_rename_and_deletion_require_scoped_step-up_in_app_com_and_org [test/integration/base_passkey_mutation_step_up_test.rb:91]:` | Untriaged |
| Failure | `Base::Org::SelectorControllerTest#test_selector_update_renders_invalid_selection_error_as_json [test/controllers/base/org/selector_controller_test.rb:173]:` | Untriaged |
| Error | `Auth::Org::ApplicationControllerTest#test_defines_full_access_controller:` | Untriaged |
| Failure | `SignOrgVerificationBaseDirectCoverageTest#test_the_protected_GET_returns_to_Base_verification_with_its_original_operation_scope [test/controllers/concerns/sign/org_verification_base_included_do_test.rb:113]:` | Untriaged |
| Failure | `HasBirthdateTest#test_blank_birthdate_is_valid [test/models/concerns/has_birthdate_test.rb:38]:` | Untriaged |
| Failure | `AuthLoginCooldownSurfacesTest#test_org:_signing_out_does_not_clear_the_anchor_(revoked_root_login_inside_the_window) [test/controllers/concerns/auth/login_cooldown_surfaces_test.rb:129]:` | Untriaged |
| Failure | `Base::Org::Support::EnforcementApprovalFailuresTest#test_each_event_names_the_operator_who_performed_it:_A_opens,_B_approves_and_applies,_C_releases [test/controllers/base/org/support/enforcement_approval_failures_test.rb:635]:` | Untriaged |
| Error | `Auth::Org::ApplicationControllerTest#test_clears_actor_context_through_around_lifecycle:` | Untriaged |
| Failure | `Base::Org::SelectorControllerTest#test_authenticated_operator_without_selected_actor_context_can_access_selector [test/controllers/base/org/selector_controller_test.rb:95]:` | Untriaged |
| Failure | `HasBirthdateTest#test_birthdate_validation_requires_both_accepted_format_and_date_before_today [test/models/concerns/has_birthdate_test.rb:56]:` | Untriaged |
| Failure | `Base::App::Verification::SetupsControllerTest#test_email_bootstrap_completes_without_freshness_and_the_protected_operation_then_needs_a_new_verification [test/controllers/base/app/verification/setups_controller_test.rb:301]:` | Untriaged |
| Failure | `HasBirthdateTest#test_calendar-invalid_zero-padded_date_is_valid_as_input [test/models/concerns/has_birthdate_test.rb:46]:` | Untriaged |
| Failure | `HasBirthdateTest#test_nil_birthdate_is_valid [test/models/concerns/has_birthdate_test.rb:34]:` | Untriaged |
| Failure | `AuthLoginCooldownSurfacesTest#test_org:_a_root_login_29_seconds_after_the_previous_one_is_refused [test/controllers/concerns/auth/login_cooldown_surfaces_test.rb:65]:` | Untriaged |
| Failure | `HasBirthdateTest#test_zero-padded_ISO_date_is_valid [test/models/concerns/has_birthdate_test.rb:42]:` | Untriaged |
| Failure | `AuthLoginCooldownSurfacesTest#test_org:_an_RP_session_neither_checks_nor_records_the_root_login_anchor [test/controllers/concerns/auth/login_cooldown_surfaces_test.rb:174]:` | Untriaged |
| Failure | `AuthLoginCooldownSurfacesTest#test_org:_a_zero_cooldown_disables_the_gate_even_for_a_root_login_committed_this_instant [test/controllers/concerns/auth/login_cooldown_surfaces_test.rb:188]:` | Untriaged |
| Failure | `AuthLoginCooldownSurfacesTest#test_org:_a_root_login_exactly_30_seconds_after_the_previous_one_is_not_refused_by_the_cooldown [test/controllers/concerns/auth/login_cooldown_surfaces_test.rb:105]:` | Untriaged |
| Failure | `ArchitectureBaselineTest#test_baseline_does_not_list_resolved_files [test/tooling/architecture_baseline_test.rb:48]:` | Untriaged |
| Failure | `AuthLoginCooldownSurfacesTest#test_org:_a_root_login_one_microsecond_inside_the_window_is_refused [test/controllers/concerns/auth/login_cooldown_surfaces_test.rb:93]:` | Untriaged |
| Failure | `AuthLoginCooldownSurfacesTest#test_org:_a_token_created_this_instant_without_a_root_login_record_does_not_trigger_the_cooldown [test/controllers/concerns/auth/login_cooldown_surfaces_test.rb:141]:` | Untriaged |
| Failure | `AuthLoginCooldownSurfacesTest#test_org:_a_refusal_writes_nothing_and_does_not_move_the_anchor [test/controllers/concerns/auth/login_cooldown_surfaces_test.rb:155]:` | Untriaged |
| Failure | `ArchitectureBaselineTest#test_no_file_exceeds_its_recorded_architecture_debt [test/tooling/architecture_baseline_test.rb:26]:` | Untriaged |
| Error | `Auth::Org::ApplicationControllerTest#test_authenticate_operator!_allows_access_when_operator_is_logged_in:` | Untriaged |
| Failure | `AuthSessionIssuanceBoundarySurfacesTest#test_org:_a_database_failure_while_creating_the_device_session_rolls_the_token_back [test/controllers/concerns/auth/session_issuance_boundary_surfaces_test.rb:219]:` | Untriaged |
| Failure | `HasBirthdateTest#test_dates_before_today_are_valid [test/models/concerns/has_birthdate_test.rb:69]:` | Untriaged |
| Failure | `Base::Com::Identity::Emails::RegistrationsControllerTest#test_first_confirmed_contact_is_registered_on_Base_without_freshness_and_ends_the_initial_exception [test/controllers/base/com/identity/emails/registrations_controller_test.rb:628]:` | Untriaged |
| Failure | `AppleAuthTest#test_Apple_login_without_email_waits_for_confirmation_before_creating_user [test/integration/apple_auth_test.rb:1267]:` | Untriaged |
| Failure | `AuthLoginCooldownSurfacesTest#test_org:_an_application_clock_ahead_of_the_database_cannot_bypass_the_cooldown [test/controllers/concerns/auth/login_cooldown_surfaces_test.rb:78]:` | Untriaged |
| Failure | `AppleAuthTest#test_first_Apple_login_waits_for_confirmation_before_creating_user [test/integration/apple_auth_test.rb:454]:` | Untriaged |
| Error | `Auth::Org::Verification::SetupsControllerTest#test_an_admitted_bootstrap_shows_the_passkey_registration_method_and_cancellation,_never_a_back_link:` | Untriaged |
| Failure | `OidcResultBrowserBindingTest#test_an_authenticated_OIDC_result_cannot_establish_a_root_in_a_different_Base_browser_in_any_realm [test/controllers/base/oidc_result_browser_binding_test.rb:207]:` | Untriaged |
| Failure | `AppleAuthTest#test_Google_login_without_email_waits_for_confirmation_before_creating_user [test/integration/apple_auth_test.rb:2144]:` | Untriaged |
| Failure | `AuthLoginCooldownSurfacesTest#test_org:_a_root_login_31_seconds_after_the_previous_one_is_not_refused_by_the_cooldown [test/controllers/concerns/auth/login_cooldown_surfaces_test.rb:116]:` | Untriaged |
| Failure | `ContactRegistrationOtpBootstrapReceiptRecoveryTest#test_app_email_bootstrap_recovers_contact_receipt_through_identical_HTTP_without_granting_freshness [test/integration/contact_registration_otp_bootstrap_receipt_recovery_test.rb:130]:` | Untriaged |
| Failure | `ContactRegistrationOtpBootstrapReceiptRecoveryTest#test_com_email_bootstrap_recovers_bootstrap_receipt_through_identical_HTTP_without_granting_freshness [test/integration/contact_registration_otp_bootstrap_receipt_recovery_test.rb:130]:` | Untriaged |
| Failure | `AppleAuthTest#test_Apple_login_without_email_does_not_save_email_to_ClientAppleIdentity_after_confirmation [test/integration/apple_auth_test.rb:1697]:` | Untriaged |
| Failure | `ContactRegistrationOtpBootstrapReceiptRecoveryTest#test_com_email_bootstrap_recovers_contact_receipt_through_identical_HTTP_without_granting_freshness [test/integration/contact_registration_otp_bootstrap_receipt_recovery_test.rb:130]:` | Untriaged |
| Failure | `OmniauthCallbacksTest#test_should_sign_in_with_existing_Google_user [test/integration/omniauth_callbacks_test.rb:1308]:` | Untriaged |
| Failure | `BaseOauthAuthorizationSurfacesTest#test_com_authorize_reuses_a_finalized_browser_session_without_creating_another_root_session [test/controllers/base/oauth_authorization_surfaces_test.rb:935]:` | Untriaged |
| Failure | `BaseOrgDashboardLocalLoginJourneyTest#test_anonymous_org_Dashboard_completes_Entra_and_Passkey_on_Auth_then_establishes_its_Base_session [test/integration/base_org_dashboard_local_login_journey_test.rb:343]:` | Untriaged |
| Failure | `BaseOauthAuthorizationSurfacesTest#test_org_authorize_reuses_a_finalized_browser_session_without_creating_another_root_session [test/controllers/base/oauth_authorization_surfaces_test.rb:1446]:` | Untriaged |
| Failure | `ContactRegistrationOtpBootstrapReceiptRecoveryTest#test_app_email_bootstrap_recovers_bootstrap_receipt_through_identical_HTTP_without_granting_freshness [test/integration/contact_registration_otp_bootstrap_receipt_recovery_test.rb:130]:` | Untriaged |
| Error | `Base::Org::FullAccessGateTest#test_dashboard_requests_selection_as_json_when_context_is_missing:` | Untriaged |
| Failure | `Base::Org::FullAccessGateTest#test_dashboard_redirects_authenticated_unselected_operator_to_selector [test/controllers/base/org/full_access_gate_test.rb:81]:` | Untriaged |
| Failure | `SocialAuthLoginTest#test_Google_sign_up_entry_with_existing_identity_falls_through_to_sign_in_flow [test/integration/social_auth_login_test.rb:2130]:` | Untriaged |
| Failure | `Base::Org::DashboardAvatarImagesControllerTest#test_a_selected_Avatar_with_a_stored_image_is_shown_and_streamed_privately [test/support/inertia_page_object.rb:15]:` | Untriaged |
| Failure | `SocialAuthLoginTest#test_login_updates_last_authenticated_at_on_existing_identity [test/integration/social_auth_login_test.rb:7897]:` | Untriaged |
| Failure | `Base::Org::Identity::Revocations::OthersControllerTest#test_destroy_revokes_every_other_staff_session_and_keeps_the_current_one [test/controllers/base/org/identity/revocations/others_controller_test.rb:99]:` | Untriaged |
| Failure | `OrgStepUpVerificationEnforcerTest#test_GET_protected_endpoint_redirects_to_verification_when_usable_methods_exist [test/integration/org_step_up_verification_enforcer_test.rb:195]:` | Untriaged |
| Failure | `Base::Org::DashboardAvatarImagesControllerTest#test_a_selected_Avatar_without_a_stored_image_is_a_normal_absence_with_no_default_image [test/controllers/base/org/dashboard_avatar_images_controller_test.rb:436]:` | Untriaged |
| Error | `Base::Org::DashboardAvatarImagesControllerTest#test_switching_back_to_the_Avatar-less_selection_drops_the_previous_Avatar's_image:` | Untriaged |
| Failure | `SocialAuthLoginTest#test_Apple_sign_up_entry_with_existing_identity_falls_through_to_sign_in_flow [test/integration/social_auth_login_test.rb:5597]:` | Untriaged |
| Failure | `SocialAuthLoginTest#test_Apple_login_with_existing_identity_does_not_create_new_user [test/integration/social_auth_login_test.rb:4691]:` | Untriaged |
| Failure | `Base::Org::DashboardAvatarImagesControllerTest#test_no_selected_Avatar_is_a_normal_absence:_no_image_element_and_a_404_image [test/controllers/base/org/dashboard_avatar_images_controller_test.rb:159]:` | Untriaged |
| Failure | `SocialAuthLoginTest#test_Google_login_with_existing_identity_completes_on_the_app_Dashboard,_never_Home [test/integration/social_auth_login_test.rb:961]:` | Untriaged |
| Failure | `AppSecretParallelLoginTest#test_parallel_submissions_and_duplicate_callbacks_commit_one_root_login_and_receipt [test/integration/app_secret_parallel_login_test.rb:457]:` | Untriaged |
| Failure | `SocialAuthLoginTest#test_Apple_login_with_existing_identity_completes_on_the_app_Dashboard,_never_Home [test/integration/social_auth_login_test.rb:5143]:` | Untriaged |
| Failure | `BaseOauthAuthorizationSurfacesTest#test_com_result_binding_mismatch_does_not_consume_the_result [test/controllers/base/oauth_authorization_surfaces_test.rb:2959]:` | Untriaged |
| Failure | `SocialAuthLoginTest#test_Apple_sign_up_entry_without_an_existing_identity_creates_the_client,_identity_and_ceremony [test/integration/social_auth_login_test.rb:4238]:` | Untriaged |
| Failure | `Auth::App::Sign::In::ChallengesControllerTest#test_show_renders_for_pending_mfa_user_with_MFA_enabled [test/controllers/auth/app/in/challenges_controller_test.rb:185]:` | Untriaged |
| Failure | `Base::Org::Identity::Revocations::OthersControllerTest#test_destroy_requires_a_fresh_step-up [test/controllers/base/org/identity/revocations/others_controller_test.rb:182]:` | Untriaged |
| Failure | `SocialAuthLoginTest#test_Google_sign_up_entry_without_an_existing_identity_creates_the_client,_identity_and_ceremony [test/integration/social_auth_login_test.rb:2805]:` | Untriaged |
| Failure | `Auth::App::Sign::In::ChallengesControllerTest#test_the_TOTP_challenge_keeps_back_to_method_selection_separate_from_cancellation [test/controllers/auth/app/in/challenges_controller_test.rb:293]:` | Untriaged |
| Failure | `SocialAuthLoginTest#test_Google_login_with_existing_identity_does_not_create_new_user [test/integration/social_auth_login_test.rb:500]:` | Untriaged |
| Failure | `OrgStepUpVerificationEnforcerTest#test_GET_protected_endpoint_redirects_to_setup_when_configured_methods_are_zero [test/integration/org_step_up_verification_enforcer_test.rb:160]:` | Untriaged |
| Failure | `EmailSignupBaseRootCompletionTest#test_app_email_signup_binds_its_original_OIDC_browser_and_Base_commits_exactly_one_root [test/integration/email_signup_base_root_completion_test.rb:296]:` | Untriaged |
| Failure | `StepUpAuthenticationTest#test_MFA_disable_through_controller_retains_current_session_and_revokes_other_sessions_and_step-up_grants [test/integration/step_up_authentication_test.rb:248]:` | Untriaged |
| Failure | `AuthEndpointBurstRateLimitTest#test_app_MFA_TOTP_challenge_answers_429_once_the_per-account_allowance_is_spent [test/integration/auth_endpoint_burst_rate_limit_test.rb:1305]:` | Untriaged |
| Failure | `AuthCeremonyRevocationConcurrencyTest#test_independent_removal_writers_preserve_the_last_compatible_method_on_each_surface [test/models/auth_ceremony_revocation_concurrency_test.rb:182]:` | Untriaged |
| Failure | `EmailSignupBaseRootCompletionTest#test_com_email_signup_binds_its_original_OIDC_browser_and_Base_commits_exactly_one_root [test/integration/email_signup_base_root_completion_test.rb:296]:` | Untriaged |
| Failure | `FqdnAvailabilityGateTest#test_the_gate_is_the_very_first_before_action_on_every_gated_controller [test/integration/fqdn_availability_gate_test.rb:823]:` | Untriaged |
| Failure | `OrgRootLoginEstablishmentTest#test_Entra_and_Passkey_establish_Normal_root_credentials_only_on_Base [test/integration/org_root_login_establishment_test.rb:225]:` | Untriaged |
| Failure | `BaseDashboardPasskeyLoginJourneyTest#test_app_anonymous_Dashboard_returns_through_Auth_Passkey_and_canonical_Base_login [test/integration/base_dashboard_passkey_login_journey_test.rb:172]:` | Untriaged |
| Failure | `BaseDashboardPasskeyLoginJourneyTest#test_com_anonymous_Dashboard_returns_through_Auth_Passkey_and_canonical_Base_login [test/integration/base_dashboard_passkey_login_journey_test.rb:172]:` | Untriaged |
| Failure | `AuthEndpointBurstRateLimitTest#test_app_MFA_TOTP_challenge_answers_429_once_the_per-IP_burst_allowance_is_spent [test/integration/auth_endpoint_burst_rate_limit_test.rb:556]:` | Untriaged |
| Error | `ActorSupportLifecycleTest#test_sequential_app_and_org_requests_rebuild_actor_context_without_cross_surface_leakage:` | Untriaged |
| Error | `ActorSupportLifecycleTest#test_sign_org_request_does_not_use_staff_preference_record_as_runtime_fallback_and_resets_afterwards:` | Untriaged |
| Failure | `Base::Org::Identity::RemovalsControllerTest#test_a_credential_owned_by_another_operator_is_not_found [test/controllers/base/org/identity/removals_controller_test.rb:508]:` | Untriaged |
| Failure | `Base::Org::Identity::RemovalsControllerTest#test_removes_a_Secret_when_the_registered_Passkey_remains_as_the_sign-in_method [test/controllers/base/org/identity/removals_controller_test.rb:409]:` | Untriaged |
| Failure | `OidcInitiatedSignInCompletionTest#test_saved_Secret_records_OIDC_authentication_evidence_without_issuing_an_Auth_session [test/integration/oidc_initiated_sign_in_completion_test.rb:461]:` | Untriaged |
