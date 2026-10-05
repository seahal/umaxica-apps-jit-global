# Current storage topology

Checked-in PostgreSQL structures and migrations, including pre-existing uncommitted files, at commit `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`. Live database application and catalog validation are UNCONFIRMED. `NOT VALID` enforces new writes; historical rows are not yet validated. Omitted ON DELETE means PostgreSQL NO ACTION. CHECKs constrain rows; they are not transition graphs.

## Ownership index

| Machine | Fact / transaction table | State axis | State reference | SQL source | State FK |
| --- | --- | --- | --- | --- | --- |
| idp-client-sign-in | client_sign_in_flows | status_id | client_sign_in_flow_statuses | db/app_ticket_structure.sql | ALTER TABLE ONLY public.client_sign_in_flows     ADD CONSTRAINT fk_rails_4e35f66d42 FOREIGN KEY (status_id) REFERENCES public.client_sign_in_flow_statuses(id) NOT VALID; |
| idp-client-sign-up | client_sign_up_flows | status_id | client_sign_up_flow_statuses | db/app_ticket_structure.sql | ALTER TABLE ONLY public.client_sign_up_flows     ADD CONSTRAINT fk_rails_533362926d FOREIGN KEY (status_id) REFERENCES public.client_sign_up_flow_statuses(id) ON DELETE RESTRICT NOT VALID; |
| idp-client-sign-out | client_sign_out_flows | status_id | client_sign_out_flow_statuses | db/app_ticket_structure.sql | ALTER TABLE ONLY public.client_sign_out_flows     ADD CONSTRAINT fk_rails_bbc7001388 FOREIGN KEY (status_id) REFERENCES public.client_sign_out_flow_statuses(id) NOT VALID; |
| idp-client-auth-ceremony-session | client_auth_ceremony_sessions | admitted_at / authentication_event_at / completed_at / cancelled_at / revoked_at / expires_at | None (state axis has no reference FK) | db/app_ticket_structure.sql | None for this axis |
| idp-client-email-ceremony | client_email_ceremony_transactions | status | None (state axis has no reference FK) | db/app_ticket_structure.sql | None for this axis |
| idp-client-telephone-ceremony | client_telephone_ceremony_transactions | status | None (state axis has no reference FK) | db/app_ticket_structure.sql | None for this axis |
| idp-client-passkey-ceremony | client_passkey_ceremony_transactions | status | None (state axis has no reference FK) | db/app_ticket_structure.sql | None for this axis |
| idp-client-secret-credential-ceremony | client_secret_credential_ceremony_transactions | status | None (state axis has no reference FK) | db/app_ticket_structure.sql | None for this axis |
| idp-client-step-up-ceremony | client_step_up_ceremony_transactions | status | None (state axis has no reference FK) | db/app_ticket_structure.sql | None for this axis |
| idp-client-oidc-authorization | client_oidc_authorization_transactions | status | None (state axis has no reference FK) | db/app_ticket_structure.sql | None for this axis |
| idp-client-oauth-callback | client_oauth_callback_states | consumed_at / expires_at | None (state axis has no reference FK) | db/app_ticket_structure.sql | None for this axis |
| idp-client-local-result-delivery | client_sign_in_flows | result_generation / result_digest / base_finalized_at | None (state axis has no reference FK) | db/app_ticket_structure.sql | None for this axis |
| idp-client-token | client_tokens | user_token_status_id | client_token_statuses | db/app_ticket_structure.sql | ALTER TABLE ONLY public.client_tokens     ADD CONSTRAINT fk_rails_c11b41180d FOREIGN KEY (user_token_status_id) REFERENCES public.client_token_statuses(id) ON DELETE RESTRICT NOT VALID; |
| idp-client-dbsc | client_tokens | user_token_dbsc_status_id | client_token_dbsc_statuses | db/app_ticket_structure.sql | ALTER TABLE ONLY public.client_tokens     ADD CONSTRAINT fk_user_tokens_on_user_token_dbsc_status_id FOREIGN KEY (user_token_dbsc_status_id) REFERENCES public.client_token_dbsc_statuses(id) NOT VALID; |
| idp-client-device-session | client_device_sessions | status_id | None (state axis has no reference FK) | db/app_ticket_structure.sql | None for this axis |
| idp-client-rp-session | client_rp_sessions | revoked_at / refresh_token_expires_at / oidc_access_token_max_expires_at | None (state axis has no reference FK) | db/app_ticket_structure.sql | None for this axis |
| idp-client-passkey-credential | client_passkeys | status_id | client_passkey_statuses | db/app_zenith_structure.sql | ALTER TABLE ONLY public.client_passkeys     ADD CONSTRAINT fk_rails_f5e90919e8 FOREIGN KEY (status_id) REFERENCES public.client_passkey_statuses(id); |
| idp-visitor-sign-in | visitor_sign_in_flows | status_id | visitor_sign_in_flow_statuses | db/com_ticket_structure.sql | ALTER TABLE ONLY public.visitor_sign_in_flows     ADD CONSTRAINT fk_rails_75353bbdcf FOREIGN KEY (status_id) REFERENCES public.visitor_sign_in_flow_statuses(id) NOT VALID; |
| idp-visitor-sign-up | visitor_sign_up_flows | status_id | visitor_sign_up_flow_statuses | db/com_ticket_structure.sql | ALTER TABLE ONLY public.visitor_sign_up_flows     ADD CONSTRAINT fk_rails_8cef237db7 FOREIGN KEY (status_id) REFERENCES public.visitor_sign_up_flow_statuses(id) ON DELETE RESTRICT NOT VALID; |
| idp-visitor-sign-out | visitor_sign_out_flows | status_id | visitor_sign_out_flow_statuses | db/com_ticket_structure.sql | ALTER TABLE ONLY public.visitor_sign_out_flows     ADD CONSTRAINT fk_rails_0289bc0560 FOREIGN KEY (status_id) REFERENCES public.visitor_sign_out_flow_statuses(id) NOT VALID; |
| idp-visitor-auth-ceremony-session | visitor_auth_ceremony_sessions | admitted_at / authentication_event_at / completed_at / cancelled_at / revoked_at / expires_at | None (state axis has no reference FK) | db/com_ticket_structure.sql | None for this axis |
| idp-visitor-email-ceremony | visitor_email_ceremony_transactions | status | None (state axis has no reference FK) | db/com_ticket_structure.sql | None for this axis |
| idp-visitor-telephone-ceremony | visitor_telephone_ceremony_transactions | status | None (state axis has no reference FK) | db/com_ticket_structure.sql | None for this axis |
| idp-visitor-passkey-ceremony | visitor_passkey_ceremony_transactions | status | None (state axis has no reference FK) | db/com_ticket_structure.sql | None for this axis |
| idp-visitor-secret-credential-ceremony | visitor_secret_credential_ceremony_transactions | status | visitor_secret_credential_statuses | db/com_ticket_structure.sql | None for this axis |
| idp-visitor-step-up-ceremony | visitor_step_up_ceremony_transactions | status | None (state axis has no reference FK) | db/com_ticket_structure.sql | None for this axis |
| idp-visitor-oidc-authorization | visitor_oidc_authorization_transactions | status | None (state axis has no reference FK) | db/com_ticket_structure.sql | None for this axis |
| idp-visitor-local-result-delivery | visitor_sign_in_flows | result_generation / result_digest / base_finalized_at | None (state axis has no reference FK) | db/com_ticket_structure.sql | None for this axis |
| idp-visitor-token | visitor_tokens | visitor_token_status_id | visitor_token_statuses | db/com_ticket_structure.sql | ALTER TABLE ONLY public.visitor_tokens     ADD CONSTRAINT fk_customer_tokens_on_customer_token_status_id FOREIGN KEY (visitor_token_status_id) REFERENCES public.visitor_token_statuses(id) NOT VALID; |
| idp-visitor-dbsc | visitor_tokens | visitor_token_dbsc_status_id | visitor_token_dbsc_statuses | db/com_ticket_structure.sql | ALTER TABLE ONLY public.visitor_tokens     ADD CONSTRAINT fk_customer_tokens_on_customer_token_dbsc_status_id FOREIGN KEY (visitor_token_dbsc_status_id) REFERENCES public.visitor_token_dbsc_statuses(id) NOT VALID; |
| idp-visitor-device-session | visitor_device_sessions | status_id | None (state axis has no reference FK) | db/com_ticket_structure.sql | None for this axis |
| idp-visitor-rp-session | visitor_rp_sessions | revoked_at / refresh_token_expires_at / oidc_access_token_max_expires_at | None (state axis has no reference FK) | db/com_ticket_structure.sql | None for this axis |
| idp-visitor-passkey-credential | visitor_passkeys | status_id | visitor_passkey_statuses | db/com_zenith_structure.sql | ALTER TABLE ONLY public.visitor_passkeys     ADD CONSTRAINT fk_rails_3ced60caec FOREIGN KEY (status_id) REFERENCES public.visitor_passkey_statuses(id); |
| idp-operator-sign-in | operator_sign_in_flows | status_id | operator_sign_in_flow_statuses | db/org_ticket_structure.sql | ALTER TABLE ONLY public.operator_sign_in_flows     ADD CONSTRAINT fk_rails_6ed9308623 FOREIGN KEY (status_id) REFERENCES public.operator_sign_in_flow_statuses(id) NOT VALID; |
| idp-operator-sign-up | operator_sign_up_flows | status_id | operator_sign_up_flow_statuses | db/org_ticket_structure.sql | ALTER TABLE ONLY public.operator_sign_up_flows     ADD CONSTRAINT fk_rails_fb3acc316b FOREIGN KEY (status_id) REFERENCES public.operator_sign_up_flow_statuses(id) NOT VALID; |
| idp-operator-sign-out | operator_sign_out_flows | status_id | operator_sign_out_flow_statuses | db/org_ticket_structure.sql | ALTER TABLE ONLY public.operator_sign_out_flows     ADD CONSTRAINT fk_rails_85024a94ea FOREIGN KEY (status_id) REFERENCES public.operator_sign_out_flow_statuses(id) NOT VALID; |
| idp-operator-auth-ceremony-session | operator_auth_ceremony_sessions | admitted_at / authentication_event_at / completed_at / cancelled_at / revoked_at / expires_at | None (state axis has no reference FK) | db/org_ticket_structure.sql | None for this axis |
| idp-operator-email-ceremony | operator_email_ceremony_transactions | status | None (state axis has no reference FK) | db/org_ticket_structure.sql | None for this axis |
| idp-operator-telephone-ceremony | operator_telephone_ceremony_transactions | status | None (state axis has no reference FK) | db/org_ticket_structure.sql | None for this axis |
| idp-operator-passkey-ceremony | operator_passkey_ceremony_transactions | status | None (state axis has no reference FK) | db/org_ticket_structure.sql | None for this axis |
| idp-operator-secret-credential-ceremony | operator_secret_credential_ceremony_transactions | status | operator_secret_credential_statuses | db/org_ticket_structure.sql | None for this axis |
| idp-operator-step-up-ceremony | operator_step_up_ceremony_transactions | status | None (state axis has no reference FK) | db/org_ticket_structure.sql | None for this axis |
| idp-operator-oidc-authorization | operator_oidc_authorization_transactions | status | None (state axis has no reference FK) | db/org_ticket_structure.sql | None for this axis |
| idp-operator-oauth-callback | operator_oauth_callback_states | consumed_at / expires_at | None (state axis has no reference FK) | db/org_ticket_structure.sql | None for this axis |
| idp-operator-local-result-delivery | operator_sign_in_flows | result_generation / result_digest / base_finalized_at | None (state axis has no reference FK) | db/org_ticket_structure.sql | None for this axis |
| idp-operator-token | operator_tokens | staff_token_status_id | operator_token_statuses | db/org_ticket_structure.sql | ALTER TABLE ONLY public.operator_tokens     ADD CONSTRAINT fk_rails_1a807f181b FOREIGN KEY (staff_token_status_id) REFERENCES public.operator_token_statuses(id) ON DELETE RESTRICT NOT VALID; |
| idp-operator-dbsc | operator_tokens | staff_token_dbsc_status_id | operator_token_dbsc_statuses | db/org_ticket_structure.sql | ALTER TABLE ONLY public.operator_tokens     ADD CONSTRAINT fk_staff_tokens_on_staff_token_dbsc_status_id FOREIGN KEY (staff_token_dbsc_status_id) REFERENCES public.operator_token_dbsc_statuses(id) NOT VALID; |
| idp-operator-device-session | operator_device_sessions | status_id | None (state axis has no reference FK) | db/org_ticket_structure.sql | None for this axis |
| idp-operator-rp-session | operator_rp_sessions | revoked_at / refresh_token_expires_at / oidc_access_token_max_expires_at | None (state axis has no reference FK) | db/org_ticket_structure.sql | None for this axis |
| idp-operator-passkey-credential | operator_passkeys | status_id | operator_passkey_statuses | db/org_zenith_structure.sql | ALTER TABLE ONLY public.operator_passkeys     ADD CONSTRAINT fk_rails_b17ae8dc5f FOREIGN KEY (status_id) REFERENCES public.operator_passkey_statuses(id); |
| idp-client-sign-up-cleanup | client_sign_up_flows | cleanup_status_id | client_sign_up_flow_cleanup_statuses | db/app_ticket_structure.sql | ALTER TABLE ONLY public.client_sign_up_flows     ADD CONSTRAINT fk_rails_9b0b63a0c6 FOREIGN KEY (cleanup_status_id) REFERENCES public.client_sign_up_flow_cleanup_statuses(id) NOT VALID; |
| idp-client-withdrawal-ceremony | client_withdrawal_ceremonies | status_id | None (state axis has no reference FK) | db/app_zenith_structure.sql | None for this axis |
| idp-client-enforcement-recovery-ceremony | client_enforcement_recovery_ceremonies | status_id | None (state axis has no reference FK) | db/app_zenith_structure.sql | None for this axis |
| idp-visitor-sign-up-cleanup | visitor_sign_up_flows | cleanup_status_id | visitor_sign_up_flow_cleanup_statuses | db/com_ticket_structure.sql | ALTER TABLE ONLY public.visitor_sign_up_flows     ADD CONSTRAINT fk_rails_cf6ee54a77 FOREIGN KEY (cleanup_status_id) REFERENCES public.visitor_sign_up_flow_cleanup_statuses(id) NOT VALID; |
| idp-visitor-withdrawal-ceremony | visitor_withdrawal_ceremonies | status_id | None (state axis has no reference FK) | db/com_zenith_structure.sql | None for this axis |
| idp-visitor-enforcement-recovery-ceremony | visitor_enforcement_recovery_ceremonies | status_id | None (state axis has no reference FK) | db/com_zenith_structure.sql | None for this axis |
| idp-client-totp-ceremony | client_totp_ceremony_transactions | status | None (state axis has no reference FK) | db/app_ticket_structure.sql | None for this axis |
| idp-client-social-ceremony | client_social_ceremony_transactions | status | None (state axis has no reference FK) | db/app_ticket_structure.sql | None for this axis |
| idp-client-secret-issuance | client_secret_issuances | presented_at / confirmed_at / canceled_at / expires_at | None (state axis has no reference FK) | db/app_zenith_structure.sql | None for this axis |
| idp-client-session-limit-resolution | client_session_limit_resolution_transactions | status | None (state axis has no reference FK) | db/app_ticket_structure.sql | None for this axis |
| idp-client-apple-notification | client_apple_notification_events | status | None (state axis has no reference FK) | db/app_zenith_structure.sql | None for this axis |
| idp-client-external-identity | client_external_identities | state | None (state axis has no reference FK) | db/app_zenith_structure.sql | None for this axis |
| idp-client-totp-credential | client_totp_credentials | user_identity_totp_credential_status_id | client_totp_credential_statuses | db/app_zenith_structure.sql | ALTER TABLE ONLY public.client_totp_credentials     ADD CONSTRAINT fk_rails_ee2c1859b3 FOREIGN KEY (user_identity_totp_credential_status_id) REFERENCES public.client_totp_credential_statuses(id); |
| idp-identity-totp-enrollment | identity_totp_ceremony_candidates | consumed_at / expires_at | None (state axis has no reference FK) | db/app_ticket_structure.sql | None for this axis |
| idp-identity-secret-credential-candidate | identity_secret_credential_ceremony_candidates | consumed_at / expires_at | None (state axis has no reference FK) | db/app_ticket_structure.sql | None for this axis |
| idp-identity-social-candidate | identity_social_ceremony_candidates | consumed_at / expires_at | None (state axis has no reference FK) | db/app_ticket_structure.sql | None for this axis |
| idp-operator-organization-invitation | organization_invitations | consumed_at / expires_at | None (state axis has no reference FK) | db/org_ticket_structure.sql | None for this axis |
| idp-operator-operator-lifecycle | operator_lifecycle_requests | status | None (state axis has no reference FK) | db/org_zenith_structure.sql | None for this axis |
| idp-shared-sequence-carrier | None (Rails session) | state / terminal_state | None | None / UNCONFIRMED | None for this axis |
| idp-shared-authorization-code | None (Valkey) | state | None | None / UNCONFIRMED | None for this axis |
| idp-shared-opaque-admission | None (Valkey) | state | None | None / UNCONFIRMED | None for this axis |
| idp-client-secret-credential | client_secret_credentials | confirmed_at / claimed_at / claim_operation_id / revoked_at / discard_at | None (state axis has no reference FK) | db/app_zenith_structure.sql | None for this axis |
| idp-client-dpop-nonce | client_dpop_proof_states | nonce_used_at / expires_at | None (state axis has no reference FK) | db/app_ticket_structure.sql | None for this axis |
| idp-client-administrative-access | clients | access_state | None (state axis has no reference FK) | db/app_zenith_structure.sql | None for this axis |
| idp-client-email-verification-challenge | client_email_ceremony_transactions | evp_outcome / expires_at | None (state axis has no reference FK) | db/app_ticket_structure.sql | None for this axis |
| idp-client-preference-dbsc | app_preferences | dbsc_status_id | app_preference_dbsc_statuses | db/app_setting_structure.sql | ALTER TABLE ONLY public.app_preferences     ADD CONSTRAINT fk_app_preferences_on_dbsc_status_id FOREIGN KEY (dbsc_status_id) REFERENCES public.app_preference_dbsc_statuses(id) NOT VALID; |
| idp-client-email-otp | client_emails | otp_expires_at / otp_attempts_count / locked_at | None (state axis has no reference FK) | db/app_zenith_structure.sql | None for this axis |
| idp-client-telephone-otp | client_telephones | otp_expires_at / otp_attempts_count / locked_at | None (state axis has no reference FK) | db/app_zenith_structure.sql | None for this axis |
| idp-visitor-secret-credential | visitor_secret_credentials | visitor_secret_credential_status_id | visitor_secret_credential_statuses | db/com_zenith_structure.sql | ALTER TABLE ONLY public.visitor_secret_credentials     ADD CONSTRAINT fk_rails_2ee7e81748 FOREIGN KEY (visitor_secret_credential_status_id) REFERENCES public.visitor_secret_credential_statuses(id); |
| idp-visitor-dpop-nonce | visitor_dpop_proof_states | nonce_used_at / expires_at | None (state axis has no reference FK) | db/com_ticket_structure.sql | None for this axis |
| idp-visitor-administrative-access | visitors | access_state | None (state axis has no reference FK) | db/com_zenith_structure.sql | None for this axis |
| idp-visitor-email-verification-challenge | visitor_email_ceremony_transactions | evp_outcome / expires_at | None (state axis has no reference FK) | db/com_ticket_structure.sql | None for this axis |
| idp-visitor-preference-dbsc | com_preferences | dbsc_status_id | com_preference_dbsc_statuses | db/com_setting_structure.sql | ALTER TABLE ONLY public.com_preferences     ADD CONSTRAINT fk_com_preferences_on_dbsc_status_id FOREIGN KEY (dbsc_status_id) REFERENCES public.com_preference_dbsc_statuses(id) NOT VALID; |
| idp-visitor-email-otp | visitor_emails | otp_expires_at / otp_attempts_count / locked_at | None (state axis has no reference FK) | db/com_zenith_structure.sql | None for this axis |
| idp-visitor-telephone-otp | visitor_telephones | otp_expires_at / otp_attempts_count / locked_at | None (state axis has no reference FK) | db/com_zenith_structure.sql | None for this axis |
| idp-operator-secret-credential | operator_secret_credentials | staff_identity_secret_status_id | operator_secret_credential_statuses | db/org_zenith_structure.sql | ALTER TABLE ONLY public.operator_secret_credentials     ADD CONSTRAINT fk_rails_8f8aed461a FOREIGN KEY (staff_identity_secret_status_id) REFERENCES public.operator_secret_credential_statuses(id); |
| idp-operator-dpop-nonce | operator_dpop_proof_states | nonce_used_at / expires_at | None (state axis has no reference FK) | db/org_ticket_structure.sql | None for this axis |
| idp-operator-administrative-access | operators | access_state | None (state axis has no reference FK) | db/org_zenith_structure.sql | None for this axis |
| idp-operator-email-verification-challenge | operator_email_ceremony_transactions | evp_outcome / expires_at | None (state axis has no reference FK) | db/org_ticket_structure.sql | None for this axis |
| idp-operator-preference-dbsc | org_preferences | dbsc_status_id | org_preference_dbsc_statuses | db/org_setting_structure.sql | ALTER TABLE ONLY public.org_preferences     ADD CONSTRAINT fk_org_preferences_on_dbsc_status_id FOREIGN KEY (dbsc_status_id) REFERENCES public.org_preference_dbsc_statuses(id) NOT VALID; |
| idp-operator-email-otp | operator_emails | otp_expires_at / otp_attempts_count / locked_at | None (state axis has no reference FK) | db/org_zenith_structure.sql | None for this axis |
| idp-operator-telephone-otp | operator_telephones | otp_expires_at / otp_attempts_count / locked_at | None (state axis has no reference FK) | db/org_zenith_structure.sql | None for this axis |
| idp-client-withdrawal | client_withdrawal_flows | status_id | client_withdrawal_flow_statuses | db/app_zenith_structure.sql | ALTER TABLE ONLY public.client_withdrawal_flows     ADD CONSTRAINT fk_rails_3a897cfb78 FOREIGN KEY (status_id) REFERENCES public.client_withdrawal_flow_statuses(id) NOT VALID; |
| idp-visitor-withdrawal | visitor_withdrawal_flows | status_id | visitor_withdrawal_flow_statuses | db/com_zenith_structure.sql | ALTER TABLE ONLY public.visitor_withdrawal_flows     ADD CONSTRAINT fk_rails_8021cd7888 FOREIGN KEY (status_id) REFERENCES public.visitor_withdrawal_flow_statuses(id) NOT VALID; |
| idp-security-one-time-reveal | security_one_time_reveals | consumed_at / expires_at | None (state axis has no reference FK) | db/app_ticket_structure.sql | None for this axis |
| idp-operator-entra-identity | operator_entra_identities | status_id | operator_entra_identity_states | db/org_zenith_structure.sql | ALTER TABLE ONLY public.operator_entra_identities     ADD CONSTRAINT fk_rails_168298cb60 FOREIGN KEY (status_id) REFERENCES public.operator_entra_identity_states(id); |
| idp-client-step-up-session | client_step_up_sessions | status / discard_at | None (state axis has no reference FK) | db/app_ticket_structure.sql | None for this axis |
| idp-client-step-up-passkey-challenge | client_step_up_sessions | passkey_challenge_ref / passkey_challenge_consumed_at / passkey_challenge_expires_at | None (state axis has no reference FK) | db/app_ticket_structure.sql | None for this axis |
| idp-client-step-up-email-challenge | client_step_up_sessions | email_delivery_state / email_code_generation / email_code_consumed_at / email_code_expires_at | None (state axis has no reference FK) | db/app_ticket_structure.sql | None for this axis |
| idp-client-email-credential | client_emails | user_email_status_id | client_email_statuses | db/app_zenith_structure.sql | ALTER TABLE ONLY public.client_emails     ADD CONSTRAINT fk_rails_15a0bdccd5 FOREIGN KEY (user_email_status_id) REFERENCES public.client_email_statuses(id); |
| idp-client-telephone-credential | client_telephones | user_identity_telephone_status_id | client_telephone_statuses | db/app_zenith_structure.sql | ALTER TABLE ONLY public.client_telephones     ADD CONSTRAINT fk_rails_c81d47bc96 FOREIGN KEY (user_identity_telephone_status_id) REFERENCES public.client_telephone_statuses(id); |
| idp-client-actor-withdrawal | clients | withdrawal_started_at / deactivated_at / withdrawn_at / terminated_at / discard_at / purge_eligible_at | None (state axis has no reference FK) | db/app_zenith_structure.sql | None for this axis |
| idp-visitor-step-up-session | visitor_step_up_sessions | status / discard_at | None (state axis has no reference FK) | db/com_ticket_structure.sql | None for this axis |
| idp-visitor-step-up-passkey-challenge | visitor_step_up_sessions | passkey_challenge_ref / passkey_challenge_consumed_at / passkey_challenge_expires_at | None (state axis has no reference FK) | db/com_ticket_structure.sql | None for this axis |
| idp-visitor-step-up-email-challenge | visitor_step_up_sessions | email_delivery_state / email_code_generation / email_code_consumed_at / email_code_expires_at | None (state axis has no reference FK) | db/com_ticket_structure.sql | None for this axis |
| idp-visitor-email-credential | visitor_emails | visitor_email_status_id | visitor_email_statuses | db/com_zenith_structure.sql | ALTER TABLE ONLY public.visitor_emails     ADD CONSTRAINT fk_rails_07ea0750f3 FOREIGN KEY (visitor_email_status_id) REFERENCES public.visitor_email_statuses(id); |
| idp-visitor-telephone-credential | visitor_telephones | visitor_telephone_status_id | visitor_telephone_statuses | db/com_zenith_structure.sql | ALTER TABLE ONLY public.visitor_telephones     ADD CONSTRAINT fk_rails_c534739d95 FOREIGN KEY (visitor_telephone_status_id) REFERENCES public.visitor_telephone_statuses(id); |
| idp-visitor-actor-withdrawal | visitors | withdrawal_started_at / deactivated_at / withdrawn_at / terminated_at / discard_at / purge_eligible_at | None (state axis has no reference FK) | db/com_zenith_structure.sql | None for this axis |
| idp-operator-step-up-session | operator_step_up_sessions | status / discard_at | None (state axis has no reference FK) | db/org_ticket_structure.sql | None for this axis |
| idp-operator-step-up-passkey-challenge | operator_step_up_sessions | passkey_challenge_ref / passkey_challenge_consumed_at / passkey_challenge_expires_at | None (state axis has no reference FK) | db/org_ticket_structure.sql | None for this axis |
| idp-operator-email-credential | operator_emails | staff_identity_email_status_id | operator_email_statuses | db/org_zenith_structure.sql | ALTER TABLE ONLY public.operator_emails     ADD CONSTRAINT fk_rails_b0310624d3 FOREIGN KEY (staff_identity_email_status_id) REFERENCES public.operator_email_statuses(id); |
| idp-operator-telephone-credential | operator_telephones | staff_identity_telephone_status_id | operator_telephone_statuses | db/org_zenith_structure.sql | ALTER TABLE ONLY public.operator_telephones     ADD CONSTRAINT fk_rails_52c0d3ae3b FOREIGN KEY (staff_identity_telephone_status_id) REFERENCES public.operator_telephone_statuses(id); |
| idp-operator-actor-withdrawal | operators | withdrawal_started_at / deactivated_at / withdrawn_at / discard_at / purge_eligible_at | None (state axis has no reference FK) | db/org_zenith_structure.sql | None for this axis |
| idp-client-actor-provisioning | clients | status_id | client_statuses | db/app_zenith_structure.sql | ALTER TABLE ONLY public.clients     ADD CONSTRAINT fk_rails_ce4a327a04 FOREIGN KEY (status_id) REFERENCES public.client_statuses(id); |
| idp-shared-acme-logout | acme_logout_transactions | status / expected_step / completed_steps | None (state axis has no reference FK) | db/app_ticket_structure.sql | None for this axis |
| idp-shared-webauthn-challenge | None (Rails session) | passkey_challenges entry / expires_at | None | None / UNCONFIRMED | None for this axis |
| idp-client-enforcement-case | app_enforcement_cases | state / ended_at | None (state axis has no reference FK) | db/app_zenith_structure.sql | None for this axis |
| idp-client-enforcement-appeal | app_enforcement_appeals | state / resolution_code / reviewed_at | None (state axis has no reference FK) | db/app_zenith_structure.sql | None for this axis |
| idp-visitor-enforcement-case | com_enforcement_cases | state / ended_at | None (state axis has no reference FK) | db/com_zenith_structure.sql | None for this axis |
| idp-visitor-enforcement-appeal | com_enforcement_appeals | state / resolution_code / reviewed_at | None (state axis has no reference FK) | db/com_zenith_structure.sql | None for this axis |
| idp-operator-enforcement-case | org_enforcement_cases | state / ended_at | None (state axis has no reference FK) | db/org_zenith_structure.sql | None for this axis |
| idp-operator-enforcement-appeal | org_enforcement_appeals | state / resolution_code / reviewed_at | None (state axis has no reference FK) | db/org_zenith_structure.sql | None for this axis |
| idp-shared-sign-out-notice | None (Valkey) | Key presence / payload expiry | None | None / UNCONFIRMED | None for this axis |
| idp-client-mfa-readiness | clients | mfa_status_id | client_mfa_statuses | db/app_zenith_structure.sql | ALTER TABLE ONLY public.clients     ADD CONSTRAINT fk_rails_67ec2e6839 FOREIGN KEY (mfa_status_id) REFERENCES public.client_mfa_statuses(id); |
| idp-visitor-mfa-readiness | visitors | mfa_status_id | visitor_mfa_statuses | db/com_zenith_structure.sql | ALTER TABLE ONLY public.visitors     ADD CONSTRAINT fk_rails_6e2a03b63d FOREIGN KEY (mfa_status_id) REFERENCES public.visitor_mfa_statuses(id); |
| idp-operator-mfa-readiness | operators | mfa_status_id | operator_mfa_statuses | db/org_zenith_structure.sql | ALTER TABLE ONLY public.operators     ADD CONSTRAINT fk_rails_cfd2f37948 FOREIGN KEY (mfa_status_id) REFERENCES public.operator_mfa_statuses(id); |
| idp-client-email-registration-session | Rails session (no fact table) | session[:sign_up_email_flow_state] | None | Controller/concern session storage | None (no state FK) |
| idp-visitor-email-registration-session | Rails session (no fact table) | session[:auth_com_up_email_flow_state] | None | Controller/concern session storage | None (no state FK) |

## Exact table definitions

The same table may own several indexed machines. Each table is shown once. All columns are retained here so duplicated state/string/step/timestamp authorities and column defaults can be checked against each machine. Primary-key SQL explicitly records the key; column types apply to both flow and reference tables. Each FK lists its actual direction, validation status and deletion rule. No Ruby association is promoted to an FK.

### acme_logout_transactions

Source: `db/app_ticket_structure.sql:49`. Machines: `idp-shared-acme-logout`.

```sql
CREATE TABLE acme_logout_transactions (
    id bigint NOT NULL,
    public_id character varying NOT NULL,
    origin_surface character varying NOT NULL,
    initiating_client_id character varying NOT NULL,
    completion_url text NOT NULL,
    actor_ref character varying,
    session_ref character varying,
    callback_state character varying,
    status character varying DEFAULT 'initiated'::character varying NOT NULL,
    expected_step character varying DEFAULT 'origin_cleared'::character varying NOT NULL,
    completed_steps jsonb DEFAULT '[]'::jsonb NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    finalized_at timestamp(6) with time zone,
    failed_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);
ALTER TABLE ONLY public.acme_logout_transactions
    ADD CONSTRAINT acme_logout_transactions_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_tickets_migrate/20260621150000_create_acme_logout_transactions.rb`.

### app_enforcement_appeals

Source: `db/app_zenith_structure.sql:146`. Machines: `idp-client-enforcement-appeal`.

```sql
CREATE TABLE app_enforcement_appeals (
    id bigint NOT NULL,
    app_enforcement_case_id bigint NOT NULL,
    public_id character varying NOT NULL,
    state character varying DEFAULT 'submitted'::character varying NOT NULL,
    reason_code character varying NOT NULL,
    statement text,
    submitted_at timestamp(6) with time zone NOT NULL,
    reviewed_at timestamp(6) with time zone,
    reviewer_operator_public_id character varying,
    resolution_code character varying,
    redacted_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_app_enforcement_appeals_state CHECK (((state)::text = ANY ((ARRAY['submitted'::character varying, 'under_review'::character varying, 'approved'::character varying, 'rejected'::character varying, 'redacted'::character varying])::text[])))
);
ALTER TABLE ONLY public.app_enforcement_appeals
    ADD CONSTRAINT app_enforcement_appeals_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.app_enforcement_appeals
    ADD CONSTRAINT fk_rails_a976d1689b FOREIGN KEY (app_enforcement_case_id) REFERENCES public.app_enforcement_cases(id);
```

Migration provenance: `db/app_zenith_migrate/20260729120000_create_app_enforcement_appeals.rb`.

### app_enforcement_authentication_method_effects

Source: `db/app_zenith_structure.sql:187`. Machines: .

```sql
CREATE TABLE app_enforcement_authentication_method_effects (
    id bigint NOT NULL,
    app_enforcement_case_id bigint NOT NULL,
    principal_public_id character varying NOT NULL,
    authentication_method character varying NOT NULL,
    effect character varying NOT NULL,
    effective_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone,
    ended_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_app_enforcement_method_effects_effect CHECK (((effect)::text = ANY ((ARRAY['mutation_locked'::character varying, 'unusable'::character varying, 'permanently_frozen'::character varying])::text[]))),
    CONSTRAINT chk_app_enforcement_method_effects_method CHECK (((authentication_method)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'secret'::character varying, 'passkey'::character varying, 'totp'::character varying, 'google'::character varying, 'apple'::character varying])::text[]))),
    CONSTRAINT chk_app_enforcement_method_effects_no_social_freeze CHECK ((((effect)::text <> 'permanently_frozen'::text) OR ((authentication_method)::text <> ALL ((ARRAY['google'::character varying, 'apple'::character varying])::text[]))))
);
ALTER TABLE ONLY public.app_enforcement_authentication_method_effects
    ADD CONSTRAINT app_enforcement_authentication_method_effects_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.app_enforcement_authentication_method_effects
    ADD CONSTRAINT fk_rails_123aa7db5e FOREIGN KEY (app_enforcement_case_id) REFERENCES public.app_enforcement_cases(id);
```

Migration provenance: `db/app_zenith_migrate/20260727120002_create_app_enforcement_authentication_method_effects.rb`, `db/app_zenith_migrate/20260727140000_create_client_emails_permanent_freeze_trigger.rb`.

### app_enforcement_cases

Source: `db/app_zenith_structure.sql:227`. Machines: `idp-client-enforcement-case`.

```sql
CREATE TABLE app_enforcement_cases (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    kind character varying NOT NULL,
    state character varying DEFAULT 'draft'::character varying NOT NULL,
    duration_mode character varying NOT NULL,
    visibility character varying DEFAULT 'visible'::character varying NOT NULL,
    release_mode character varying NOT NULL,
    effective_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone,
    ended_at timestamp(6) with time zone,
    end_reason character varying,
    review_due_at timestamp(6) with time zone,
    reason_code character varying NOT NULL,
    reason_note text,
    ticket_id character varying,
    principal_public_id character varying NOT NULL,
    applied_by_operator_public_id character varying NOT NULL,
    approved_by_operator_public_id character varying,
    ended_by_operator_public_id character varying,
    break_glass boolean DEFAULT false NOT NULL,
    break_glass_approved_by_operator_public_id character varying,
    sessions_revoked_at timestamp(6) with time zone,
    audited_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_app_enforcement_cases_approval_separation CHECK (((approved_by_operator_public_id IS NULL) OR ((approved_by_operator_public_id)::text <> (applied_by_operator_public_id)::text))),
    CONSTRAINT chk_app_enforcement_cases_break_glass_approver CHECK (((break_glass = false) OR (break_glass_approved_by_operator_public_id IS NOT NULL))),
    CONSTRAINT chk_app_enforcement_cases_cooldown_duration CHECK ((((kind)::text <> 'cooldown'::text) OR (((duration_mode)::text = 'timed'::text) AND (expires_at IS NOT NULL) AND (expires_at <= (effective_at + '30 days'::interval))))),
    CONSTRAINT chk_app_enforcement_cases_duration_mode CHECK (((duration_mode)::text = ANY ((ARRAY['timed'::character varying, 'indefinite'::character varying, 'permanent'::character varying])::text[]))),
    CONSTRAINT chk_app_enforcement_cases_end_reason CHECK (((end_reason IS NULL) OR ((end_reason)::text = ANY ((ARRAY['expired'::character varying, 'revoked'::character varying, 'superseded'::character varying, 'corrected'::character varying, 'appeal_approved'::character varying, 'break_glass_released'::character varying, 'verification_completed'::character varying])::text[])))),
    CONSTRAINT chk_app_enforcement_cases_hidden CHECK ((((visibility)::text <> 'hidden'::text) OR ((kind)::text = 'permanent_ban'::text))),
    CONSTRAINT chk_app_enforcement_cases_indefinite_freeze_review CHECK ((((kind)::text <> 'temporary_freeze'::text) OR ((duration_mode)::text <> 'indefinite'::text) OR ((review_due_at IS NOT NULL) AND ((release_mode)::text = 'operator'::text)))),
    CONSTRAINT chk_app_enforcement_cases_kind CHECK (((kind)::text = ANY ((ARRAY['security_lock'::character varying, 'cooldown'::character varying, 'temporary_freeze'::character varying, 'permanent_ban'::character varying, 'method_protection'::character varying])::text[]))),
    CONSTRAINT chk_app_enforcement_cases_no_self_action CHECK (((principal_public_id)::text <> (applied_by_operator_public_id)::text)),
    CONSTRAINT chk_app_enforcement_cases_permanent_ban_duration CHECK ((((kind)::text <> 'permanent_ban'::text) OR (((duration_mode)::text = 'permanent'::text) AND (expires_at IS NULL)))),
    CONSTRAINT chk_app_enforcement_cases_release_mode CHECK (((release_mode)::text = ANY ((ARRAY['automatic'::character varying, 'operator'::character varying, 'verification_required'::character varying, 'break_glass_only'::character varying])::text[]))),
    CONSTRAINT chk_app_enforcement_cases_security_lock_release CHECK ((((kind)::text <> 'security_lock'::text) OR ((release_mode)::text = 'verification_required'::text))),
    CONSTRAINT chk_app_enforcement_cases_state CHECK (((state)::text = ANY ((ARRAY['draft'::character varying, 'pending_approval'::character varying, 'active'::character varying, 'ended'::character varying, 'failed'::character varying])::text[]))),
    CONSTRAINT chk_app_enforcement_cases_temp_freeze_duration_mode CHECK ((((kind)::text <> 'temporary_freeze'::text) OR ((duration_mode)::text = ANY ((ARRAY['timed'::character varying, 'indefinite'::character varying])::text[])))),
    CONSTRAINT chk_app_enforcement_cases_visibility CHECK (((visibility)::text = ANY ((ARRAY['visible'::character varying, 'hidden'::character varying])::text[])))
);
ALTER TABLE ONLY public.app_enforcement_cases
    ADD CONSTRAINT app_enforcement_cases_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_zenith_migrate/20260727120000_create_app_enforcement_cases.rb`, `db/app_zenith_migrate/20260830120000_allow_verification_completed_app_enforcement_case_end_reason.rb`, `db/app_zenith_migrate/20260727140001_create_clients_hard_delete_protection_trigger.rb`.

### app_enforcement_identifier_effects

Source: `db/app_zenith_structure.sql:294`. Machines: .

```sql
CREATE TABLE app_enforcement_identifier_effects (
    id bigint NOT NULL,
    app_enforcement_case_id bigint NOT NULL,
    identifier_kind character varying NOT NULL,
    lookup_digest character varying NOT NULL,
    key_version integer NOT NULL,
    digest_version integer NOT NULL,
    normalization_version integer NOT NULL,
    display_value text,
    registration_blocked boolean DEFAULT false NOT NULL,
    attachment_blocked boolean DEFAULT false NOT NULL,
    recovery_blocked boolean DEFAULT false NOT NULL,
    effective_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone,
    ended_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_app_enforcement_identifier_effects_kind CHECK (((identifier_kind)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'google_subject'::character varying, 'apple_subject'::character varying, 'identity_id'::character varying])::text[])))
);
ALTER TABLE ONLY public.app_enforcement_identifier_effects
    ADD CONSTRAINT app_enforcement_identifier_effects_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.app_enforcement_identifier_effects
    ADD CONSTRAINT fk_rails_948f351e94 FOREIGN KEY (app_enforcement_case_id) REFERENCES public.app_enforcement_cases(id);
```

Migration provenance: `db/app_zenith_migrate/20260727120003_create_app_enforcement_identifier_effects.rb`.

### app_enforcement_principal_effects

Source: `db/app_zenith_structure.sql:338`. Machines: .

```sql
CREATE TABLE app_enforcement_principal_effects (
    id bigint NOT NULL,
    app_enforcement_case_id bigint NOT NULL,
    principal_public_id character varying NOT NULL,
    access_blocking boolean DEFAULT false NOT NULL,
    recovery_blocked boolean DEFAULT false NOT NULL,
    reactivation_blocked boolean DEFAULT false NOT NULL,
    withdrawal_purge_blocked boolean DEFAULT false NOT NULL,
    principal_hard_delete_blocked boolean DEFAULT false NOT NULL,
    profile_effect character varying,
    effective_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone,
    ended_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);
ALTER TABLE ONLY public.app_enforcement_principal_effects
    ADD CONSTRAINT app_enforcement_principal_effects_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.app_enforcement_principal_effects
    ADD CONSTRAINT fk_rails_a7ff4f6c71 FOREIGN KEY (app_enforcement_case_id) REFERENCES public.app_enforcement_cases(id);
```

Migration provenance: `db/app_zenith_migrate/20260727120001_create_app_enforcement_principal_effects.rb`, `db/app_zenith_migrate/20260727140001_create_clients_hard_delete_protection_trigger.rb`.

### app_enforcement_principal_links

Source: `db/app_zenith_structure.sql:379`. Machines: .

```sql
CREATE TABLE app_enforcement_principal_links (
    id bigint NOT NULL,
    app_enforcement_case_id bigint NOT NULL,
    principal_kind character varying NOT NULL,
    principal_public_id character varying NOT NULL,
    relationship_kind character varying NOT NULL,
    linked_at timestamp(6) with time zone NOT NULL,
    ended_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_app_enforcement_principal_links_relationship_kind CHECK (((relationship_kind)::text = ANY ((ARRAY['target_principal'::character varying, 'former_principal'::character varying, 'related_principal'::character varying, 'suspected_duplicate'::character varying, 'reinstated_principal'::character varying, 'false_positive'::character varying])::text[])))
);
ALTER TABLE ONLY public.app_enforcement_principal_links
    ADD CONSTRAINT app_enforcement_principal_links_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.app_enforcement_principal_links
    ADD CONSTRAINT fk_rails_e04b2bda45 FOREIGN KEY (app_enforcement_case_id) REFERENCES public.app_enforcement_cases(id);
```

Migration provenance: `db/app_zenith_migrate/20260727120004_create_app_enforcement_principal_links.rb`.

### app_preference_binding_methods

Source: `db/app_setting_structure.sql:109`. Machines: .

```sql
CREATE TABLE app_preference_binding_methods (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.app_preference_binding_methods
    ADD CONSTRAINT app_preference_binding_methods_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_settings_migrate/20260518030000_load_initial_app_setting_schema.rb`.

### app_preference_dbsc_statuses

Source: `db/app_setting_structure.sql:294`. Machines: .

```sql
CREATE TABLE app_preference_dbsc_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.app_preference_dbsc_statuses
    ADD CONSTRAINT app_preference_dbsc_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_settings_migrate/20260518030000_load_initial_app_setting_schema.rb`.

### app_preference_statuses

Source: `db/app_setting_structure.sql:622`. Machines: .

```sql
CREATE TABLE app_preference_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.app_preference_statuses
    ADD CONSTRAINT app_preference_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_settings_migrate/20260518030000_load_initial_app_setting_schema.rb`.

### app_preferences

Source: `db/app_setting_structure.sql:830`. Machines: `idp-client-preference-dbsc`.

```sql
CREATE TABLE app_preferences (
    id bigint NOT NULL,
    binding_method_id bigint DEFAULT 0 NOT NULL,
    dbsc_challenge text,
    dbsc_challenge_issued_at timestamp(6) with time zone,
    dbsc_public_key jsonb,
    dbsc_session_id character varying,
    dbsc_status_id bigint DEFAULT 0 NOT NULL,
    jti character varying,
    public_id character varying NOT NULL,
    replaced_by_id bigint,
    status_id bigint DEFAULT 0 NOT NULL,
    token_digest bytea,
    used_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    explicit_fields jsonb DEFAULT '[]'::jsonb NOT NULL
);
ALTER TABLE ONLY public.app_preferences
    ADD CONSTRAINT app_preferences_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.app_preferences
    ADD CONSTRAINT fk_app_preferences_on_binding_method_id FOREIGN KEY (binding_method_id) REFERENCES public.app_preference_binding_methods(id) NOT VALID;
ALTER TABLE ONLY public.app_preferences
    ADD CONSTRAINT fk_app_preferences_on_dbsc_status_id FOREIGN KEY (dbsc_status_id) REFERENCES public.app_preference_dbsc_statuses(id) NOT VALID;
ALTER TABLE ONLY public.app_preferences
    ADD CONSTRAINT fk_app_preferences_on_status_id FOREIGN KEY (status_id) REFERENCES public.app_preference_statuses(id) NOT VALID;
ALTER TABLE ONLY public.app_preferences
    ADD CONSTRAINT fk_rails_40612c8731 FOREIGN KEY (replaced_by_id) REFERENCES public.app_preferences(id) ON DELETE SET NULL NOT VALID;
```

Migration provenance: `db/app_settings_migrate/20260530120000_add_explicit_fields_to_app_preferences.rb`, `db/app_settings_migrate/20260921133000_rename_app_setting_retention_columns_to_semantic_names.rb`, `db/app_settings_migrate/20260702000000_change_app_preferences_status_id_default_to_nothing.rb`, `db/app_settings_migrate/20260518030000_load_initial_app_setting_schema.rb`, `db/app_settings_migrate/20260526120200_remove_device_id_from_app_preferences.rb`, `db/app_settings_migrate/20260526090000_create_app_preference_r18_display_stoppers.rb`, `db/com_principals_migrate/20260508135008_consolidate_retention_on_app_preferences.rb`, `db/app_zenith_migrate/20260721090000_add_explicit_fields_to_client_preferences.rb`.

### client_apple_notification_events

Source: `db/app_zenith_structure.sql:498`. Machines: `idp-client-apple-notification`.

```sql
CREATE TABLE client_apple_notification_events (
    id bigint NOT NULL,
    jti character varying NOT NULL,
    event_type character varying(32) NOT NULL,
    client_external_identity_id bigint,
    received_at timestamp(6) with time zone NOT NULL,
    occurred_at timestamp(6) with time zone NOT NULL,
    status character varying(32) DEFAULT 'received'::character varying NOT NULL,
    processing_attempts integer DEFAULT 0 NOT NULL,
    next_retry_at timestamp(6) with time zone,
    processed_at timestamp(6) with time zone,
    dead_lettered_at timestamp(6) with time zone,
    failure_code character varying DEFAULT ''::character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    client_id bigint,
    CONSTRAINT chk_client_apple_notification_events_attempts CHECK ((processing_attempts >= 0)),
    CONSTRAINT chk_client_apple_notification_events_status CHECK (((status)::text = ANY ((ARRAY['received'::character varying, 'retrying'::character varying, 'completed'::character varying, 'dead_letter'::character varying])::text[]))),
    CONSTRAINT chk_client_apple_notification_events_type CHECK (((event_type)::text = ANY ((ARRAY['email-enabled'::character varying, 'email-disabled'::character varying, 'consent-revoked'::character varying, 'account-deleted'::character varying])::text[])))
);
ALTER TABLE ONLY public.client_apple_notification_events
    ADD CONSTRAINT client_apple_notification_events_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.client_apple_notification_events
    ADD CONSTRAINT fk_rails_23d9ef1894 FOREIGN KEY (client_external_identity_id) REFERENCES public.client_external_identities(id) ON DELETE SET NULL;
ALTER TABLE ONLY public.client_apple_notification_events
    ADD CONSTRAINT fk_rails_37bfb38140 FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE SET NULL;
```

Migration provenance: `db/app_principals_migrate/20260724201400_add_legacy_apple_identity_foreign_key_to_notification_events.rb`, `db/app_principals_migrate/20260724201000_add_client_to_apple_notification_events.rb`, `db/app_principals_migrate/20260731121000_remove_persisted_apple_provider_tokens.rb`, `db/app_principals_migrate/20260724201700_validate_external_authentication_foreign_keys.rb`, `db/app_principals_migrate/20260724201300_add_legacy_apple_identity_to_notification_events.rb`, `db/app_principals_migrate/20260724201100_add_client_foreign_key_to_apple_notification_events.rb`, `db/app_principals_migrate/20260724201500_validate_legacy_apple_identity_foreign_key_on_notification_events.rb`, `db/app_principals_migrate/20260724201600_nullify_notification_event_identity_foreign_keys.rb`, `db/app_principals_migrate/20260724200000_create_client_apple_notification_events.rb`, `db/app_principals_migrate/20260724201200_validate_client_foreign_key_on_apple_notification_events.rb`.

### client_auth_ceremony_sessions

Source: `db/app_ticket_structure.sql:104`. Machines: `idp-client-auth-ceremony-session`.

```sql
CREATE TABLE client_auth_ceremony_sessions (
    id bigint NOT NULL,
    sid_digest character varying(64) NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    revoked_at timestamp(6) with time zone,
    rotated_at timestamp(6) with time zone,
    previous_sid_digest character varying(64),
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    authorization_transaction_ref character varying,
    admitted_at timestamp(6) with time zone,
    completed_at timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    authentication_method character varying,
    authentication_event_at timestamp(6) with time zone,
    local_sign_in_flow_ref character varying,
    local_sign_up_flow_ref character varying,
    admission_purpose character varying,
    step_up_ceremony_transaction_ref character varying,
    CONSTRAINT client_auth_admission_purpose_valid CHECK (((admission_purpose IS NULL) OR ((admission_purpose)::text = ANY ((ARRAY['local_sign_in'::character varying, 'local_sign_up'::character varying, 'authentication_handoff'::character varying, 'invitation_handoff'::character varying, 'step_up_handoff'::character varying, 'reauthentication_handoff'::character varying, 'bootstrap_handoff'::character varying, 'credential_registration_handoff'::character varying, 'credential_change_handoff'::character varying])::text[])))),
    CONSTRAINT client_auth_ceremony_purpose_exclusive CHECK ((num_nonnulls(authorization_transaction_ref, local_sign_in_flow_ref, local_sign_up_flow_ref) <= 1)),
    CONSTRAINT client_auth_ceremony_sessions_admission_binding CHECK (((authorization_transaction_ref IS NULL) OR (admitted_at IS NOT NULL))),
    CONSTRAINT client_auth_ceremony_sessions_authentication_evidence_pair CHECK (((authentication_method IS NULL) = (authentication_event_at IS NULL))),
    CONSTRAINT client_auth_ceremony_sessions_authentication_method CHECK (((authentication_method IS NULL) OR ((authentication_method)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'secret'::character varying, 'passkey'::character varying, 'totp'::character varying, 'google'::character varying, 'apple'::character varying, 'entra'::character varying])::text[])))),
    CONSTRAINT client_auth_ceremony_sessions_one_terminal_timestamp CHECK ((num_nonnulls(revoked_at, completed_at, cancelled_at) <= 1)),
    CONSTRAINT client_auth_ceremony_transaction_exclusive CHECK ((num_nonnulls(authorization_transaction_ref, local_sign_in_flow_ref, local_sign_up_flow_ref, step_up_ceremony_transaction_ref) <= 1))
);
ALTER TABLE ONLY public.client_auth_ceremony_sessions
    ADD CONSTRAINT client_auth_ceremony_sessions_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.client_auth_ceremony_sessions
    ADD CONSTRAINT fk_rails_268e296ad7 FOREIGN KEY (step_up_ceremony_transaction_ref) REFERENCES public.client_step_up_ceremony_transactions(transaction_id) ON DELETE RESTRICT;
ALTER TABLE ONLY public.client_auth_ceremony_sessions
    ADD CONSTRAINT fk_rails_6413141ed8 FOREIGN KEY (local_sign_up_flow_ref) REFERENCES public.client_sign_up_flows(public_id) ON DELETE RESTRICT;
ALTER TABLE ONLY public.client_auth_ceremony_sessions
    ADD CONSTRAINT fk_rails_694b855234 FOREIGN KEY (local_sign_in_flow_ref) REFERENCES public.client_sign_in_flows(public_id) ON DELETE RESTRICT;
```

Migration provenance: `db/app_tickets_migrate/20261003215004_bind_client_credential_ceremonies_to_base_authority.rb`, `db/app_tickets_migrate/20260913140000_create_client_auth_ceremony_sessions.rb`, `db/app_tickets_migrate/20260920150000_extend_client_auth_ceremony_session_lifecycle.rb`, `db/app_tickets_migrate/20261003175614_bind_client_local_authentication_results.rb`, `db/app_tickets_migrate/20260920151000_validate_client_auth_ceremony_session_lifecycle.rb`, `db/app_tickets_migrate/20260921140100_validate_authentication_evidence_constraints.rb`, `db/app_tickets_migrate/20261003183659_bind_client_opaque_step_up_ceremonies.rb`, `db/app_tickets_migrate/20260921140000_add_authentication_evidence_to_client_auth_ceremony_sessions.rb`.

### client_device_sessions

Source: `db/app_ticket_structure.sql:156`. Machines: `idp-client-device-session`.

```sql
CREATE TABLE client_device_sessions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    user_id bigint NOT NULL,
    dbsc_session_id_digest character varying,
    dbsc_public_key_thumbprint character varying,
    dbsc_bound_at timestamp(6) with time zone,
    dpop_jkt character varying,
    status_id bigint DEFAULT 1 NOT NULL,
    current_refresh_token_id bigint,
    refresh_token_family_id character varying,
    last_seen_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    revoke_reason character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    last_network_hmac character varying
);
ALTER TABLE ONLY public.client_device_sessions
    ADD CONSTRAINT client_device_sessions_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.client_device_sessions
    ADD CONSTRAINT fk_client_device_sessions_on_current_refresh_token_owner FOREIGN KEY (id, current_refresh_token_id) REFERENCES public.client_tokens(device_session_id, id) ON DELETE SET NULL (current_refresh_token_id) DEFERRABLE INITIALLY DEFERRED;
```

Migration provenance: `db/app_tickets_migrate/20260611100000_add_last_network_hmac_to_client_device_sessions.rb`, `db/app_tickets_migrate/20260924154000_add_client_device_session_actor_reference_index.rb`, `db/app_tickets_migrate/20260924153000_validate_client_current_refresh_token_owner.rb`, `db/app_tickets_migrate/20260520190000_create_device_sessions_for_user_tokens.rb`, `db/app_tickets_migrate/20260526120100_remove_device_id_from_app_tickets.rb`, `db/app_tickets_migrate/20260924155000_add_client_token_device_session_actor_foreign_key.rb`, `db/app_tickets_migrate/20260924151000_add_client_device_session_token_foreign_keys.rb`.

### client_dpop_proof_states

Source: `db/app_ticket_structure.sql:199`. Machines: `idp-client-dpop-nonce`.

```sql
CREATE TABLE client_dpop_proof_states (
    id bigint NOT NULL,
    jti character varying,
    jkt character varying,
    nonce character varying,
    htm character varying,
    htu character varying,
    seen_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    nonce_used_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);
ALTER TABLE ONLY public.client_dpop_proof_states
    ADD CONSTRAINT client_dpop_proof_states_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_tickets_migrate/20260526120000_create_client_dpop_proof_states.rb`.

### client_email_ceremony_transactions

Source: `db/app_ticket_structure.sql:237`. Machines: `idp-client-email-ceremony`, `idp-client-email-verification-challenge`.

```sql
CREATE TABLE client_email_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    operation character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    grant_jti character varying NOT NULL,
    result_jti character varying,
    email_candidate_ref character varying,
    normalized_email_digest character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    evp_nonce_digest character varying,
    evp_token_digest character varying,
    evp_outcome character varying,
    evp_failure_reason character varying,
    evp_issuer character varying,
    evp_issued_at timestamp(6) with time zone,
    evp_verified_at timestamp(6) with time zone,
    evp_consumed_at timestamp(6) with time zone,
    evp_attempt_count integer DEFAULT 0 NOT NULL
);
ALTER TABLE ONLY public.client_email_ceremony_transactions
    ADD CONSTRAINT client_email_ceremony_transactions_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_tickets_migrate/20260710220000_add_evp_state_to_client_email_ceremony_transactions.rb`, `db/app_tickets_migrate/20260603121000_create_client_email_ceremony_transactions.rb`.

### client_email_statuses

Source: `db/app_zenith_structure.sql:646`. Machines: .

```sql
CREATE TABLE client_email_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.client_email_statuses
    ADD CONSTRAINT client_email_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_principals_migrate/20260520143000_rename_app_principal_tables_to_model_conventions.rb`.

### client_emails

Source: `db/app_zenith_structure.sql:674`. Machines: `idp-client-email-otp`, `idp-client-email-credential`.

```sql
CREATE TABLE client_emails (
    id bigint NOT NULL,
    address character varying DEFAULT ''::character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    locked_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    otp_attempts_count integer DEFAULT 0 NOT NULL,
    otp_counter text DEFAULT ''::text NOT NULL,
    otp_expires_at timestamp(6) with time zone DEFAULT '-infinity'::timestamp with time zone NOT NULL,
    otp_last_sent_at timestamp(6) with time zone DEFAULT '-infinity'::timestamp with time zone NOT NULL,
    otp_private_key character varying DEFAULT ''::character varying NOT NULL,
    public_id character varying(21) NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint NOT NULL,
    verification_token_digest bytea,
    user_email_status_id bigint DEFAULT 0 NOT NULL,
    address_digest character varying,
    undeletable boolean DEFAULT false NOT NULL,
    promotional boolean DEFAULT true NOT NULL,
    notifiable boolean DEFAULT true NOT NULL,
    subscribable boolean DEFAULT true NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    step_up_otp_failures integer DEFAULT 0 NOT NULL,
    step_up_otp_locked_until timestamp(6) with time zone,
    step_up_otp_last_issued_at timestamp(6) with time zone,
    CONSTRAINT client_email_step_up_failures_nonnegative CHECK ((step_up_otp_failures >= 0))
);
ALTER TABLE ONLY public.client_emails
    ADD CONSTRAINT client_emails_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.client_emails
    ADD CONSTRAINT fk_rails_15a0bdccd5 FOREIGN KEY (user_email_status_id) REFERENCES public.client_email_statuses(id);
ALTER TABLE ONLY public.client_emails
    ADD CONSTRAINT fk_rails_410ac92848 FOREIGN KEY (user_id) REFERENCES public.clients(id);
```

Migration provenance: `db/seeds.rb`, `db/app_principals_migrate/20260520143000_rename_app_principal_tables_to_model_conventions.rb`, `db/app_principals_migrate/20260525131000_scope_client_contact_identifier_uniqueness_to_active_records.rb`, `db/app_principals_migrate/20260525120000_add_retention_to_client_sign_up_artifacts.rb`, `db/app_principals_migrate/20261003202225_preserve_client_step_up_email_failures.rb`, `db/app_zenith_migrate/20260727140000_create_client_emails_permanent_freeze_trigger.rb`, `db/app_zenith_migrate/20260921133000_rename_app_zenith_retention_columns_to_semantic_names.rb`.

### client_enforcement_recovery_ceremonies

Source: `db/app_zenith_structure.sql:726`. Machines: `idp-client-enforcement-recovery-ceremony`.

```sql
CREATE TABLE client_enforcement_recovery_ceremonies (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    client_id bigint NOT NULL,
    status_id integer DEFAULT 1 NOT NULL,
    token_digest bytea NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    ip_digest bytea,
    user_agent_digest bytea,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);
ALTER TABLE ONLY public.client_enforcement_recovery_ceremonies
    ADD CONSTRAINT client_enforcement_recovery_ceremonies_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.client_enforcement_recovery_ceremonies
    ADD CONSTRAINT fk_rails_589be2c97e FOREIGN KEY (client_id) REFERENCES public.clients(id);
```

Migration provenance: `db/app_principals_migrate/20260729130000_create_client_enforcement_recovery_ceremonies.rb`.

### client_external_identities

Source: `db/app_zenith_structure.sql:765`. Machines: `idp-client-external-identity`.

```sql
CREATE TABLE client_external_identities (
    id bigint NOT NULL,
    client_id bigint NOT NULL,
    provider character varying(16) NOT NULL,
    issuer character varying NOT NULL,
    subject text NOT NULL,
    audience character varying NOT NULL,
    state character varying(32) DEFAULT 'active'::character varying NOT NULL,
    verification_authority character varying NOT NULL,
    verified_at timestamp(6) with time zone NOT NULL,
    last_authenticated_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    last_provider_event_at timestamp(6) with time zone,
    CONSTRAINT chk_client_external_identities_provider CHECK (((provider)::text = ANY ((ARRAY['apple'::character varying, 'google'::character varying])::text[]))),
    CONSTRAINT chk_client_external_identities_state CHECK (((state)::text = ANY ((ARRAY['active'::character varying, 'consent_revoked'::character varying, 'account_deleted'::character varying])::text[])))
);
ALTER TABLE ONLY public.client_external_identities
    ADD CONSTRAINT client_external_identities_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.client_external_identities
    ADD CONSTRAINT fk_rails_abadb8885a FOREIGN KEY (client_id) REFERENCES public.clients(id);
```

Migration provenance: `db/app_principals_migrate/20260724190000_create_client_external_identities.rb`, `db/app_principals_migrate/20260911120000_log_client_external_identities.rb`, `db/app_principals_migrate/20260724201700_validate_external_authentication_foreign_keys.rb`, `db/app_principals_migrate/20260724201600_nullify_notification_event_identity_foreign_keys.rb`, `db/app_principals_migrate/20260724200000_create_client_apple_notification_events.rb`.

### client_mfa_levels

Source: `db/app_zenith_structure.sql:1131`. Machines: .

```sql
CREATE TABLE client_mfa_levels (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.client_mfa_levels
    ADD CONSTRAINT client_mfa_levels_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_principals_migrate/20260530031000_rename_app_principal_model_terms.rb`.

### client_mfa_statuses

Source: `db/app_zenith_structure.sql:1159`. Machines: .

```sql
CREATE TABLE client_mfa_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.client_mfa_statuses
    ADD CONSTRAINT client_mfa_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_principals_migrate/20260530031000_rename_app_principal_model_terms.rb`.

### client_oauth_callback_states

Source: `db/app_ticket_structure.sql:322`. Machines: `idp-client-oauth-callback`.

```sql
CREATE TABLE client_oauth_callback_states (
    id bigint NOT NULL,
    state_digest character varying NOT NULL,
    provider character varying NOT NULL,
    intent character varying,
    issued_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);
ALTER TABLE ONLY public.client_oauth_callback_states
    ADD CONSTRAINT client_oauth_callback_states_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_tickets_migrate/20260530130100_rename_app_ticket_model_terms.rb`.

### client_oidc_authorization_transactions

Source: `db/app_ticket_structure.sql:358`. Machines: `idp-client-oidc-authorization`.

```sql
CREATE TABLE client_oidc_authorization_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    intent character varying NOT NULL,
    client_id character varying NOT NULL,
    redirect_uri character varying NOT NULL,
    response_type character varying NOT NULL,
    scope character varying NOT NULL,
    state character varying NOT NULL,
    nonce character varying NOT NULL,
    code_challenge character varying NOT NULL,
    code_challenge_method character varying NOT NULL,
    login_challenge character varying NOT NULL,
    login_challenge_expires_at timestamp(6) with time zone NOT NULL,
    authenticated_at timestamp(6) with time zone,
    actor_ref character varying,
    session_ref character varying,
    auth_method character varying,
    acr character varying,
    consumed_at timestamp(6) with time zone,
    expires_at timestamp(6) with time zone NOT NULL,
    status character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    oidc_prompt character varying,
    oidc_max_age integer,
    result_generation integer DEFAULT 0 NOT NULL,
    result_digest character varying(64),
    result_expires_at timestamp(6) with time zone,
    result_consumed_at timestamp(6) with time zone,
    browser_session_ref character varying,
    base_finalized_at timestamp(6) with time zone,
    authorization_grant_redeemed_at timestamp(6) with time zone,
    CONSTRAINT client_oidc_auth_transactions_result_generation_nonnegative CHECK ((result_generation >= 0))
);
ALTER TABLE ONLY public.client_oidc_authorization_transactions
    ADD CONSTRAINT client_oidc_authorization_transactions_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_tickets_migrate/20260922120100_validate_cross_store_oidc_finalization_client_transactions.rb`, `db/app_tickets_migrate/20260611150000_create_client_oidc_authorization_transactions.rb`, `db/app_tickets_migrate/20260915180000_add_oidc_freshness_options_to_client_authorization_transactions.rb`, `db/app_tickets_migrate/20260922120000_add_cross_store_oidc_finalization_to_client_transactions.rb`.

### client_passkey_ceremony_transactions

Source: `db/app_ticket_structure.sql:455`. Machines: `idp-client-passkey-ceremony`.

```sql
CREATE TABLE client_passkey_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    operation character varying NOT NULL,
    rp_id character varying NOT NULL,
    origin character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    grant_jti character varying NOT NULL,
    result_jti character varying,
    credential_candidate_ref character varying,
    credential_candidate_digest character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    step_up_ceremony_transaction_ref character varying
);
ALTER TABLE ONLY public.client_passkey_ceremony_transactions
    ADD CONSTRAINT client_passkey_ceremony_transactions_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.client_passkey_ceremony_transactions
    ADD CONSTRAINT fk_rails_aac854f11a FOREIGN KEY (step_up_ceremony_transaction_ref) REFERENCES public.client_step_up_ceremony_transactions(transaction_id) ON DELETE RESTRICT;
```

Migration provenance: `db/app_tickets_migrate/20261003215004_bind_client_credential_ceremonies_to_base_authority.rb`, `db/app_tickets_migrate/20260603123000_create_client_passkey_ceremony_transactions.rb`.

### client_passkey_statuses

Source: `db/app_zenith_structure.sql:1187`. Machines: .

```sql
CREATE TABLE client_passkey_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.client_passkey_statuses
    ADD CONSTRAINT client_passkey_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_principals_migrate/20260520143000_rename_app_principal_tables_to_model_conventions.rb`.

### client_passkeys

Source: `db/app_zenith_structure.sql:1215`. Machines: `idp-client-passkey-credential`.

```sql
CREATE TABLE client_passkeys (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    description character varying DEFAULT ''::character varying NOT NULL,
    external_id uuid NOT NULL,
    public_key text NOT NULL,
    sign_count bigint DEFAULT 0 NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint NOT NULL,
    webauthn_id character varying DEFAULT ''::character varying NOT NULL,
    status_id bigint DEFAULT 1 NOT NULL,
    last_used_at timestamp(6) with time zone,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    public_id character varying(21),
    aaguid uuid,
    transports jsonb,
    backup_eligible boolean,
    backup_state boolean,
    authenticator_attachment character varying,
    provider_name character varying,
    metadata_source character varying,
    uv_verified_at timestamp(6) with time zone
);
ALTER TABLE ONLY public.client_passkeys
    ADD CONSTRAINT client_passkeys_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.client_passkeys
    ADD CONSTRAINT fk_rails_0095e1bdca FOREIGN KEY (user_id) REFERENCES public.clients(id);
ALTER TABLE ONLY public.client_passkeys
    ADD CONSTRAINT fk_rails_f5e90919e8 FOREIGN KEY (status_id) REFERENCES public.client_passkey_statuses(id);
```

Migration provenance: `db/app_principals_migrate/20260714100000_add_public_id_to_client_passkeys.rb`, `db/app_principals_migrate/20260520143000_rename_app_principal_tables_to_model_conventions.rb`, `db/app_principals_migrate/20260525120000_add_retention_to_client_sign_up_artifacts.rb`, `db/app_principals_migrate/20260831064103_add_uv_verified_at_to_client_passkeys.rb`, `db/app_principals_migrate/20260719100000_add_authenticator_metadata_to_client_passkeys.rb`, `db/app_zenith_migrate/20260921133000_rename_app_zenith_retention_columns_to_semantic_names.rb`.

### client_rp_sessions

Source: `db/app_ticket_structure.sql:501`. Machines: `idp-client-rp-session`.

```sql
CREATE TABLE client_rp_sessions (
    id bigint NOT NULL,
    client_token_id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    oidc_client_id character varying(64) NOT NULL,
    oidc_scope text,
    oidc_jti character varying,
    refresh_token_digest character varying,
    previous_refresh_token_digest character varying,
    refresh_token_expires_at timestamp(6) with time zone,
    refresh_token_rotated_at timestamp(6) with time zone,
    dpop_jkt character varying,
    last_used_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    last_logout_status character varying,
    last_logout_attempted_at timestamp(6) with time zone,
    logged_out_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    oidc_auth_time timestamp(6) with time zone,
    oidc_acr character varying,
    oidc_amr text,
    oidc_nonce character varying,
    oidc_access_token_max_expires_at timestamp(6) with time zone
);
ALTER TABLE ONLY public.client_rp_sessions
    ADD CONSTRAINT client_rp_sessions_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.client_rp_sessions
    ADD CONSTRAINT fk_rails_132e7e72b8 FOREIGN KEY (client_token_id) REFERENCES public.client_tokens(id) ON DELETE CASCADE;
```

Migration provenance: `db/app_tickets_migrate/20260624000000_create_client_rp_sessions_and_bind_authorization_codes.rb`, `db/app_tickets_migrate/20260917130000_add_oidc_access_token_expiry_tracking_to_client_rp_sessions.rb`, `db/app_tickets_migrate/20260915170000_add_oidc_refresh_claims_to_client_rp_sessions.rb`.

### client_secret_audit_outboxes

Source: `db/app_zenith_structure.sql:2591`. Machines: .

```sql
CREATE TABLE client_secret_audit_outboxes (
    id bigint NOT NULL,
    event_id uuid NOT NULL,
    event_name character varying(128) NOT NULL,
    client_ref character varying(21) NOT NULL,
    credential_ref character varying(21),
    actor_type character varying,
    actor_id bigint,
    actor_public_ref character varying(21),
    executor_job_id character varying,
    operation_ref uuid NOT NULL,
    occurred_at timestamp(6) with time zone NOT NULL,
    reason character varying(128),
    item_count integer,
    delivered_at timestamp(6) with time zone,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT client_secret_audit_actor CHECK ((((actor_type IS NULL) AND (actor_id IS NULL) AND (actor_public_ref IS NULL)) OR ((actor_type IS NOT NULL) AND ((actor_type)::text = 'Client'::text) AND (actor_id IS NOT NULL) AND (actor_public_ref IS NOT NULL)))),
    CONSTRAINT client_secret_audit_count CHECK (((item_count IS NULL) OR ((item_count >= 0) AND (item_count <= 20)))),
    CONSTRAINT client_secret_audit_delivery_retention CHECK (((delivered_at IS NOT NULL) OR (purge_eligible_at = 'infinity'::timestamp with time zone)))
);
ALTER TABLE ONLY public.client_secret_audit_outboxes
    ADD CONSTRAINT client_secret_audit_outboxes_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_principals_migrate/20261003215326_rebuild_app_secret_credentials.rb`.

### client_secret_credential_ceremony_transactions

Source: `db/app_ticket_structure.sql:551`. Machines: `idp-client-secret-credential-ceremony`.

```sql
CREATE TABLE client_secret_credential_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    operation character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    grant_jti character varying NOT NULL,
    result_jti character varying,
    credential_candidate_ref character varying,
    credential_candidate_digest character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);
ALTER TABLE ONLY public.client_secret_credential_ceremony_transactions
    ADD CONSTRAINT client_secret_credential_ceremony_transactions_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_tickets_migrate/20260603130000_create_client_secret_credential_ceremony_transactions.rb`.

### client_secret_credentials

Source: `db/app_zenith_structure.sql:2639`. Machines: `idp-client-secret-credential`.

```sql
CREATE TABLE client_secret_credentials (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    client_id bigint NOT NULL,
    issuance_id bigint NOT NULL,
    name character varying(255) NOT NULL,
    password_digest character varying(255) NOT NULL,
    lookup_digest character varying(64) NOT NULL,
    confirmed_at timestamp(6) with time zone,
    claimed_at timestamp(6) with time zone,
    claim_operation_id uuid,
    revoked_at timestamp(6) with time zone,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT client_secret_credential_claim CHECK ((((claimed_at IS NULL) = (claim_operation_id IS NULL)) AND ((claimed_at IS NULL) OR ((confirmed_at IS NOT NULL) AND (claimed_at >= confirmed_at)))))
);
ALTER TABLE ONLY public.client_secret_credentials
    ADD CONSTRAINT client_secret_credentials_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.client_secret_credentials
    ADD CONSTRAINT fk_rails_12f3aec1d7 FOREIGN KEY (client_id) REFERENCES public.clients(id);
ALTER TABLE ONLY public.client_secret_credentials
    ADD CONSTRAINT fk_rails_1f331d9a65 FOREIGN KEY (issuance_id, client_id) REFERENCES public.client_secret_issuances(id, client_id);
```

Migration provenance: `db/app_principals_migrate/20260530031000_rename_app_principal_model_terms.rb`, `db/app_principals_migrate/20260612100000_add_new_secret_axis_to_client_secret_credentials.rb`, `db/app_principals_migrate/20261003215326_rebuild_app_secret_credentials.rb`, `db/app_zenith_migrate/20260921133000_rename_app_zenith_retention_columns_to_semantic_names.rb`, `db/app_zenith_migrate/20260926170000_add_emergency_claim_to_client_secret_credentials.rb`.

### client_secret_issuances

Source: `db/app_zenith_structure.sql:2682`. Machines: `idp-client-secret-issuance`.

```sql
CREATE TABLE client_secret_issuances (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    client_id bigint NOT NULL,
    origin_operation_id uuid NOT NULL,
    origin character varying NOT NULL,
    attempt_number integer NOT NULL,
    browser_session_ref character varying,
    sign_up_flow_ref character varying,
    planned_count integer NOT NULL,
    expires_at timestamp(6) with time zone,
    presented_at timestamp(6) with time zone,
    confirmed_at timestamp(6) with time zone,
    canceled_at timestamp(6) with time zone,
    encrypted_payload text,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT client_secret_issuance_binding CHECK (((browser_session_ref IS NULL) <> (sign_up_flow_ref IS NULL))),
    CONSTRAINT client_secret_issuance_count CHECK ((((origin)::text = ANY ((ARRAY['manual'::character varying, 'passkey_registration'::character varying])::text[])) AND (attempt_number > 0) AND ((planned_count >= 0) AND (planned_count <= 2)) AND (((origin)::text <> 'manual'::text) OR (planned_count <= 1)))),
    CONSTRAINT client_secret_issuance_facts CHECK (((NOT ((confirmed_at IS NOT NULL) AND (canceled_at IS NOT NULL))) AND ((confirmed_at IS NULL) OR ((presented_at IS NOT NULL) AND (confirmed_at >= presented_at) AND (confirmed_at < expires_at))) AND ((presented_at IS NULL) OR (presented_at < expires_at)))),
    CONSTRAINT client_secret_issuance_omission CHECK ((((planned_count = 0) AND (expires_at IS NULL) AND (presented_at IS NULL) AND (confirmed_at IS NULL) AND (canceled_at IS NULL) AND (encrypted_payload IS NULL)) OR ((planned_count > 0) AND (expires_at IS NOT NULL))))
);
ALTER TABLE ONLY public.client_secret_issuances
    ADD CONSTRAINT client_secret_issuances_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.client_secret_issuances
    ADD CONSTRAINT fk_rails_da68d427e0 FOREIGN KEY (client_id) REFERENCES public.clients(id);
```

Migration provenance: `db/app_principals_migrate/20261003215326_rebuild_app_secret_credentials.rb`.

### client_secret_sign_in_receipts

Source: `db/app_ticket_structure.sql:594`. Machines: .

```sql
CREATE TABLE client_secret_sign_in_receipts (
    id bigint NOT NULL,
    operation_id uuid NOT NULL,
    credential_ref character varying(21) NOT NULL,
    client_ref character varying(21) NOT NULL,
    sign_in_flow_id bigint NOT NULL,
    root_token_ref character varying(21) NOT NULL,
    committed_at timestamp(6) with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);
ALTER TABLE ONLY public.client_secret_sign_in_receipts
    ADD CONSTRAINT client_secret_sign_in_receipts_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.client_secret_sign_in_receipts
    ADD CONSTRAINT fk_rails_33b6c86074 FOREIGN KEY (sign_in_flow_id) REFERENCES public.client_sign_in_flows(id);
```

Migration provenance: `db/app_tickets_migrate/20261003215633_create_client_secret_sign_in_receipts.rb`.

### client_session_limit_resolution_transactions

Source: `db/app_ticket_structure.sql:632`. Machines: `idp-client-session-limit-resolution`.

```sql
CREATE TABLE client_session_limit_resolution_transactions (
    id bigint NOT NULL,
    challenge_digest character varying NOT NULL,
    actor_type character varying NOT NULL,
    actor_ref character varying NOT NULL,
    oidc_authorization_transaction_id bigint NOT NULL,
    status character varying NOT NULL,
    selected_session_ref character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    selected_at timestamp(6) with time zone,
    resolved_at timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    consumed_at timestamp(6) with time zone,
    finalized_at timestamp(6) with time zone,
    audit_context jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);
ALTER TABLE ONLY public.client_session_limit_resolution_transactions
    ADD CONSTRAINT client_session_limit_resolution_transactions_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_tickets_migrate/20260623120000_create_client_session_limit_resolution_transactions.rb`.

### client_sign_in_flow_statuses

Source: `db/app_ticket_structure.sql:675`. Machines: .

```sql
CREATE TABLE client_sign_in_flow_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.client_sign_in_flow_statuses
    ADD CONSTRAINT client_sign_in_flow_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_tickets_migrate/20260530130100_rename_app_ticket_model_terms.rb`.

### client_sign_in_flows

Source: `db/app_ticket_structure.sql:703`. Machines: `idp-client-sign-in`, `idp-client-local-result-delivery`.

```sql
CREATE TABLE client_sign_in_flows (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    principal_id bigint,
    token_id bigint,
    state character varying NOT NULL,
    step character varying NOT NULL,
    return_to text,
    nonce_digest character varying NOT NULL,
    issued_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    completed_at timestamp(6) with time zone,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    status_id bigint DEFAULT 10 NOT NULL,
    selected_region_id bigint,
    selected_persona_id bigint,
    selector_completed_at timestamp(6) with time zone,
    session_issued_at timestamp(6) with time zone,
    result_digest character varying(64),
    result_generation integer DEFAULT 0 NOT NULL,
    result_expires_at timestamp(6) with time zone,
    base_finalized_at timestamp(6) with time zone,
    authentication_method character varying,
    authentication_event_at timestamp(6) with time zone,
    authentication_context character varying,
    CONSTRAINT chk_app_sign_in_sequence_tickets_lifetime_order CHECK ((issued_at < expires_at)),
    CONSTRAINT chk_app_sign_in_sequence_tickets_retention_order CHECK ((discard_at <= purge_eligible_at)),
    CONSTRAINT client_local_authentication_context_valid CHECK (((authentication_context IS NULL) OR ((authentication_context)::text = ANY ((ARRAY['normal'::character varying, 'emergency'::character varying])::text[])))),
    CONSTRAINT client_sign_in_flows_authentication_evidence_valid CHECK ((((authentication_method IS NULL) AND (authentication_event_at IS NULL)) OR (((authentication_method)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'secret'::character varying, 'passkey'::character varying, 'totp'::character varying, 'google'::character varying, 'apple'::character varying, 'entra'::character varying])::text[])) AND (authentication_event_at IS NOT NULL) AND (principal_id IS NOT NULL)))),
    CONSTRAINT client_sign_in_flows_base_finalization_valid CHECK (((base_finalized_at IS NULL) OR ((token_id IS NOT NULL) AND (result_digest IS NOT NULL)))),
    CONSTRAINT client_sign_in_flows_evidence_complete CHECK (((authentication_event_at IS NULL) OR (authentication_method IS NOT NULL))),
    CONSTRAINT client_sign_in_flows_result_complete CHECK (((result_generation = 0) OR ((result_digest IS NOT NULL) AND (result_expires_at IS NOT NULL) AND (authentication_event_at IS NOT NULL)))),
    CONSTRAINT client_sign_in_flows_result_delivery_valid CHECK ((((result_digest IS NULL) AND (result_expires_at IS NULL) AND (result_generation = 0)) OR ((length((result_digest)::text) = 64) AND (result_expires_at IS NOT NULL) AND (result_generation > 0) AND (authentication_event_at IS NOT NULL)))),
    CONSTRAINT client_sign_in_flows_result_generation_valid CHECK ((result_generation >= 0))
);
ALTER TABLE ONLY public.client_sign_in_flows
    ADD CONSTRAINT client_sign_in_flows_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.client_sign_in_flows
    ADD CONSTRAINT fk_rails_4e35f66d42 FOREIGN KEY (status_id) REFERENCES public.client_sign_in_flow_statuses(id) NOT VALID;
ALTER TABLE ONLY public.client_sign_in_flows
    ADD CONSTRAINT fk_rails_bd772deef1 FOREIGN KEY (token_id) REFERENCES public.client_tokens(id) ON DELETE CASCADE NOT VALID;
```

Migration provenance: `db/app_tickets_migrate/20261003181712_preserve_client_local_authentication_context.rb`, `db/app_tickets_migrate/20260530130100_rename_app_ticket_model_terms.rb`, `db/app_tickets_migrate/20261002120000_add_root_login_established_at_to_client_tokens.rb`, `db/app_tickets_migrate/20260528162100_harden_client_sign_in_cycle_state_constraints.rb`, `db/app_tickets_migrate/20261003175614_bind_client_local_authentication_results.rb`, `db/app_tickets_migrate/20260520143002_rename_app_ticket_tables_to_model_conventions.rb`, `db/app_tickets_migrate/20260525233000_add_selector_activation_to_client_sign_in_cycles.rb`, `db/app_tickets_migrate/20261003215633_create_client_secret_sign_in_receipts.rb`, `db/app_tickets_migrate/20260921133000_rename_app_ticket_retention_columns_to_semantic_names.rb`.

### client_sign_out_flow_kinds

Source: `db/app_ticket_structure.sql:766`. Machines: .

```sql
CREATE TABLE client_sign_out_flow_kinds (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.client_sign_out_flow_kinds
    ADD CONSTRAINT client_sign_out_flow_kinds_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_tickets_migrate/20260530130100_rename_app_ticket_model_terms.rb`.

### client_sign_out_flow_statuses

Source: `db/app_ticket_structure.sql:794`. Machines: .

```sql
CREATE TABLE client_sign_out_flow_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.client_sign_out_flow_statuses
    ADD CONSTRAINT client_sign_out_flow_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_tickets_migrate/20260530130100_rename_app_ticket_model_terms.rb`.

### client_sign_out_flows

Source: `db/app_ticket_structure.sql:822`. Machines: `idp-client-sign-out`.

```sql
CREATE TABLE client_sign_out_flows (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    principal_id bigint,
    token_id bigint,
    status_id bigint DEFAULT 10 NOT NULL,
    kind_id bigint DEFAULT 0 NOT NULL,
    refresh_token_family_id character varying,
    requested_at timestamp(6) with time zone NOT NULL,
    access_discarded_at timestamp(6) with time zone,
    logically_revoked_at timestamp(6) with time zone,
    access_expires_at timestamp(6) with time zone NOT NULL,
    refresh_expires_at timestamp(6) with time zone NOT NULL,
    completed_at timestamp(6) with time zone,
    failed_at timestamp(6) with time zone,
    return_to text,
    nonce_digest character varying,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_client_sign_out_cycles_retention_order CHECK ((discard_at <= purge_eligible_at)),
    CONSTRAINT chk_client_sign_out_cycles_token_expiry_order CHECK ((access_expires_at <= refresh_expires_at))
);
ALTER TABLE ONLY public.client_sign_out_flows
    ADD CONSTRAINT client_sign_out_flows_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.client_sign_out_flows
    ADD CONSTRAINT fk_rails_39d731f429 FOREIGN KEY (kind_id) REFERENCES public.client_sign_out_flow_kinds(id) NOT VALID;
ALTER TABLE ONLY public.client_sign_out_flows
    ADD CONSTRAINT fk_rails_4bbbc632e2 FOREIGN KEY (token_id) REFERENCES public.client_tokens(id) ON DELETE CASCADE NOT VALID;
ALTER TABLE ONLY public.client_sign_out_flows
    ADD CONSTRAINT fk_rails_bbc7001388 FOREIGN KEY (status_id) REFERENCES public.client_sign_out_flow_statuses(id) NOT VALID;
```

Migration provenance: `db/app_tickets_migrate/20260530130100_rename_app_ticket_model_terms.rb`, `db/app_tickets_migrate/20260519092000_create_client_sign_out_cycles.rb`, `db/app_tickets_migrate/20260921133000_rename_app_ticket_retention_columns_to_semantic_names.rb`.

### client_sign_up_flow_cleanup_statuses

Source: `db/app_ticket_structure.sql:871`. Machines: .

```sql
CREATE TABLE client_sign_up_flow_cleanup_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.client_sign_up_flow_cleanup_statuses
    ADD CONSTRAINT client_sign_up_flow_cleanup_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_tickets_migrate/20260530130100_rename_app_ticket_model_terms.rb`.

### client_sign_up_flow_statuses

Source: `db/app_ticket_structure.sql:899`. Machines: .

```sql
CREATE TABLE client_sign_up_flow_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.client_sign_up_flow_statuses
    ADD CONSTRAINT client_sign_up_flow_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_tickets_migrate/20260530130100_rename_app_ticket_model_terms.rb`, `db/app_tickets_migrate/20260616150010_add_on_delete_actions_to_client_ticket_foreign_keys.rb`.

### client_sign_up_flows

Source: `db/app_ticket_structure.sql:927`. Machines: `idp-client-sign-up`, `idp-client-sign-up-cleanup`.

```sql
CREATE TABLE client_sign_up_flows (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    principal_id bigint,
    token_id bigint,
    state character varying NOT NULL,
    step character varying NOT NULL,
    return_to text,
    nonce_digest character varying NOT NULL,
    issued_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    completed_at timestamp(6) with time zone,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    status_id bigint DEFAULT 10 NOT NULL,
    entry_method character varying NOT NULL,
    pending_contact_type character varying,
    pending_contact_id bigint,
    social_provider character varying,
    completed_requirements jsonb DEFAULT '{}'::jsonb NOT NULL,
    failed_at timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    checkpoint_version integer DEFAULT 0 NOT NULL,
    cleanup_attempted_at timestamp(6) with time zone,
    cleanup_completed_at timestamp(6) with time zone,
    cleanup_error_code character varying,
    pending_passkey_registration_id bigint,
    cleanup_attempts_count integer DEFAULT 0 NOT NULL,
    cleanup_status_id bigint DEFAULT 10 NOT NULL,
    result_digest character varying(64),
    result_generation integer DEFAULT 0 NOT NULL,
    result_expires_at timestamp(6) with time zone,
    base_finalized_at timestamp(6) with time zone,
    authentication_method character varying,
    authentication_event_at timestamp(6) with time zone,
    CONSTRAINT chk_app_sign_up_sequence_tickets_lifetime_order CHECK ((issued_at < expires_at)),
    CONSTRAINT chk_app_sign_up_sequence_tickets_retention_order CHECK ((discard_at <= purge_eligible_at)),
    CONSTRAINT client_sign_up_flows_authentication_evidence_valid CHECK ((((authentication_method IS NULL) AND (authentication_event_at IS NULL)) OR (((authentication_method)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'secret'::character varying, 'passkey'::character varying, 'totp'::character varying, 'google'::character varying, 'apple'::character varying, 'entra'::character varying])::text[])) AND (authentication_event_at IS NOT NULL) AND (principal_id IS NOT NULL)))),
    CONSTRAINT client_sign_up_flows_base_finalization_valid CHECK (((base_finalized_at IS NULL) OR ((token_id IS NOT NULL) AND (result_digest IS NOT NULL)))),
    CONSTRAINT client_sign_up_flows_evidence_complete CHECK (((authentication_event_at IS NULL) OR (authentication_method IS NOT NULL))),
    CONSTRAINT client_sign_up_flows_result_complete CHECK (((result_generation = 0) OR ((result_digest IS NOT NULL) AND (result_expires_at IS NOT NULL) AND (authentication_event_at IS NOT NULL)))),
    CONSTRAINT client_sign_up_flows_result_delivery_valid CHECK ((((result_digest IS NULL) AND (result_expires_at IS NULL) AND (result_generation = 0)) OR ((length((result_digest)::text) = 64) AND (result_expires_at IS NOT NULL) AND (result_generation > 0) AND (authentication_event_at IS NOT NULL)))),
    CONSTRAINT client_sign_up_flows_result_generation_valid CHECK ((result_generation >= 0))
);
ALTER TABLE ONLY public.client_sign_up_flows
    ADD CONSTRAINT client_sign_up_flows_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.client_sign_up_flows
    ADD CONSTRAINT fk_rails_533362926d FOREIGN KEY (status_id) REFERENCES public.client_sign_up_flow_statuses(id) ON DELETE RESTRICT NOT VALID;
ALTER TABLE ONLY public.client_sign_up_flows
    ADD CONSTRAINT fk_rails_7b193122e7 FOREIGN KEY (token_id) REFERENCES public.client_tokens(id) ON DELETE RESTRICT;
ALTER TABLE ONLY public.client_sign_up_flows
    ADD CONSTRAINT fk_rails_9b0b63a0c6 FOREIGN KEY (cleanup_status_id) REFERENCES public.client_sign_up_flow_cleanup_statuses(id) NOT VALID;
```

Migration provenance: `db/app_tickets_migrate/20261003181712_preserve_client_local_authentication_context.rb`, `db/app_tickets_migrate/20260525200000_drop_cleanup_token_from_client_sign_up_cycles.rb`, `db/app_tickets_migrate/20260530130100_rename_app_ticket_model_terms.rb`, `db/app_tickets_migrate/20260525124500_add_cleanup_state_to_client_sign_up_cycles.rb`, `db/app_tickets_migrate/20260920152001_validate_restrict_client_sign_up_flow_token_delete.rb`, `db/app_tickets_migrate/20261003175614_bind_client_local_authentication_results.rb`, `db/app_tickets_migrate/20260520143002_rename_app_ticket_tables_to_model_conventions.rb`, `db/app_tickets_migrate/20260525200500_add_cleanup_attempts_count_to_client_sign_up_cycles.rb`, `db/app_tickets_migrate/20260920152000_restrict_client_sign_up_flow_token_delete.rb`, `db/app_tickets_migrate/20260616150020_remove_redundant_app_ticket_indexes.rb`, `db/app_tickets_migrate/20260525123000_add_checkpoint_version_to_client_sign_up_cycles.rb`, `db/app_tickets_migrate/20260616150000_add_entry_method_not_null_to_client_sign_up_flows.rb`, `db/app_tickets_migrate/20260921133000_rename_app_ticket_retention_columns_to_semantic_names.rb`, `db/app_tickets_migrate/20260525131500_restrict_client_sign_up_cycle_token_delete.rb`, `db/app_tickets_migrate/20260616150010_add_on_delete_actions_to_client_ticket_foreign_keys.rb`, `db/app_tickets_migrate/20260616150005_validate_add_entry_method_not_null_to_client_sign_up_flows.rb`, `db/app_tickets_migrate/20260525210000_create_client_sign_up_cycle_cleanup_statuses.rb`.

### client_social_ceremony_transactions

Source: `db/app_ticket_structure.sql:998`. Machines: `idp-client-social-ceremony`.

```sql
CREATE TABLE client_social_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    operation character varying NOT NULL,
    provider character varying NOT NULL,
    resource_ref character varying,
    return_to character varying,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    grant_jti character varying NOT NULL,
    result_jti character varying,
    provider_subject_ref character varying,
    provider_subject_digest character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);
ALTER TABLE ONLY public.client_social_ceremony_transactions
    ADD CONSTRAINT client_social_ceremony_transactions_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_tickets_migrate/20260603140000_create_client_social_ceremony_transactions.rb`.

### client_statuses

Source: `db/app_zenith_structure.sql:2731`. Machines: .

```sql
CREATE TABLE client_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.client_statuses
    ADD CONSTRAINT client_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_principals_migrate/20260202200000_fix_clients_status_relations.rb`, `db/app_principals_migrate/20260204150845_seed_principal_status_tables.rb`, `db/app_principals_migrate/20260108100600_rename_principal_tables.rb`, `db/app_principals_migrate/20260202250001_replace_code_with_fixed_ids_principal.rb`, `db/app_principals_migrate/20260520143000_rename_app_principal_tables_to_model_conventions.rb`, `db/app_principals_migrate/20260201214420_convert_all_principal_pks_to_bigint.rb`, `db/app_principals_migrate/20260201190008_convert_principal_pks.rb`, `db/app_principals_migrate/20260131140000_convert_client_statuses_to_smallint.rb`, `db/app_principals_migrate/20260202210000_add_lower_code_unique_indexes_principal.rb`, `db/app_principals_migrate/20260131149000_cleanup_principal_reference_tables.rb`, `db/app_principals_migrate/20260202160000_fix_consistency_users.rb`, `db/app_principals_migrate/20260130130002_principal_reference_table_timestamps_removal.rb`, `db/app_principals_migrate/20260212000001_ensure_seed_reference_data_in_principals.rb`, `db/app_principals_migrate/20260202185000_fix_principal_consistency.rb`.

### client_step_up_ceremony_transactions

Source: `db/app_ticket_structure.sql:1044`. Machines: `idp-client-step-up-ceremony`.

```sql
CREATE TABLE client_step_up_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    required_scope character varying NOT NULL,
    required_aal character varying NOT NULL,
    allowed_methods text NOT NULL,
    resource_ref character varying,
    return_to character varying,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    grant_jti character varying NOT NULL,
    result_jti character varying,
    method character varying,
    aal character varying,
    verified_at timestamp(6) with time zone,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    phishing_resistant_required boolean DEFAULT false NOT NULL,
    phishing_resistant boolean DEFAULT false NOT NULL,
    purpose character varying DEFAULT 'step_up'::character varying NOT NULL,
    result_digest character varying(64),
    result_generation integer DEFAULT 0 NOT NULL,
    result_expires_at timestamp(6) with time zone,
    canceled_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    verified_credential_ref character varying,
    CONSTRAINT client_step_up_purpose_valid CHECK (((purpose)::text = ANY ((ARRAY['step_up'::character varying, 'reauthentication'::character varying, 'bootstrap'::character varying, 'credential_registration'::character varying, 'credential_change'::character varying])::text[]))),
    CONSTRAINT client_step_up_result_valid CHECK (((result_generation >= 0) AND (((result_digest IS NULL) AND (result_expires_at IS NULL) AND (result_generation = 0)) OR ((result_digest IS NOT NULL) AND ((result_digest)::text ~ '^[0-9a-f]{64}$'::text) AND (result_expires_at IS NOT NULL) AND (result_generation > 0) AND (verified_at IS NOT NULL))))),
    CONSTRAINT client_step_up_status_valid CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'verified'::character varying, 'consumed'::character varying, 'canceled'::character varying, 'expired'::character varying, 'revoked'::character varying])::text[]))),
    CONSTRAINT client_step_up_terminal_valid CHECK ((((canceled_at IS NULL) OR ((status)::text = 'canceled'::text)) AND ((revoked_at IS NULL) OR ((status)::text = 'revoked'::text)) AND (((status)::text <> 'revoked'::text) OR (revoked_at IS NOT NULL)) AND (((status)::text <> 'verified'::text) OR ((verified_at IS NOT NULL) AND (method IS NOT NULL) AND (aal IS NOT NULL))))),
    CONSTRAINT client_step_up_verified_credential_present CHECK ((((status)::text <> 'verified'::text) OR (((purpose)::text = ANY ((ARRAY['bootstrap'::character varying, 'credential_registration'::character varying])::text[])) AND (verified_credential_ref IS NULL) AND ((aal)::text = 'none'::text) AND ((required_aal)::text = 'none'::text) AND (phishing_resistant IS FALSE) AND (phishing_resistant_required IS FALSE) AND ((method)::text = ANY ((ARRAY['passkey'::character varying, 'totp'::character varying])::text[]))) OR (((purpose)::text <> ALL ((ARRAY['bootstrap'::character varying, 'credential_registration'::character varying])::text[])) AND (verified_credential_ref IS NOT NULL) AND (length((verified_credential_ref)::text) > 0))))
);
ALTER TABLE ONLY public.client_step_up_ceremony_transactions
    ADD CONSTRAINT client_step_up_ceremony_transactions_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_tickets_migrate/20261003215004_bind_client_credential_ceremonies_to_base_authority.rb`, `db/app_tickets_migrate/20261003221628_separate_client_registration_evidence_from_step_up_credential.rb`, `db/app_tickets_migrate/20261003185506_bind_client_verified_step_up_credential.rb`, `db/app_tickets_migrate/20260603122000_create_client_step_up_ceremony_transactions.rb`, `db/app_tickets_migrate/20260831064102_add_phishing_resistance_to_client_step_up_ceremony_transactions.rb`, `db/app_tickets_migrate/20261003183659_bind_client_opaque_step_up_ceremonies.rb`.

### client_step_up_sessions

Source: `db/app_ticket_structure.sql:1106`. Machines: `idp-client-step-up-session`, `idp-client-step-up-passkey-challenge`, `idp-client-step-up-email-challenge`.

```sql
CREATE TABLE client_step_up_sessions (
    id bigint NOT NULL,
    attempt_count integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    method character varying,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    return_to text NOT NULL,
    scope character varying NOT NULL,
    status character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_token_id bigint NOT NULL,
    verified_at timestamp(6) with time zone,
    step_up_ceremony_transaction_ref character varying,
    passkey_challenge text,
    passkey_challenge_ref character varying,
    passkey_rp_id character varying,
    passkey_origin character varying,
    passkey_challenge_expires_at timestamp(6) with time zone,
    passkey_challenge_consumed_at timestamp(6) with time zone,
    email_credential_ref character varying,
    email_code_digest character varying(64),
    email_code_generation integer DEFAULT 0 NOT NULL,
    email_code_issued_at timestamp(6) with time zone,
    email_code_expires_at timestamp(6) with time zone,
    email_code_consumed_at timestamp(6) with time zone,
    email_delivery_state character varying,
    CONSTRAINT client_step_up_challenge_bound CHECK (((passkey_challenge IS NULL) OR ((step_up_ceremony_transaction_ref IS NOT NULL) AND (passkey_challenge_ref IS NOT NULL) AND (passkey_rp_id IS NOT NULL) AND (passkey_origin IS NOT NULL) AND (passkey_challenge_expires_at IS NOT NULL) AND (passkey_challenge_expires_at <= discard_at)))),
    CONSTRAINT client_step_up_email_generation_valid CHECK ((((email_code_generation = 0) AND (email_credential_ref IS NULL) AND (email_code_digest IS NULL) AND (email_code_issued_at IS NULL) AND (email_code_expires_at IS NULL) AND (email_code_consumed_at IS NULL) AND (email_delivery_state IS NULL)) OR ((email_code_generation > 0) AND (email_credential_ref IS NOT NULL) AND (length((email_credential_ref)::text) > 0) AND (email_code_digest IS NOT NULL) AND ((email_code_digest)::text ~ '^[0-9a-f]{64}$'::text) AND (email_code_issued_at IS NOT NULL) AND (email_code_expires_at IS NOT NULL) AND (email_code_expires_at > email_code_issued_at) AND (email_code_expires_at <= (email_code_issued_at + '00:10:00'::interval)) AND (email_delivery_state IS NOT NULL) AND ((email_delivery_state)::text = ANY ((ARRAY['pending'::character varying, 'delivered'::character varying, 'failed'::character varying])::text[])) AND ((email_code_consumed_at IS NULL) OR (((email_delivery_state)::text = 'delivered'::text) AND (email_code_consumed_at >= email_code_issued_at) AND (email_code_consumed_at < email_code_expires_at))))))
);
ALTER TABLE ONLY public.client_step_up_sessions
    ADD CONSTRAINT client_step_up_sessions_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.client_step_up_sessions
    ADD CONSTRAINT fk_rails_64ec203fd3 FOREIGN KEY (user_token_id) REFERENCES public.client_tokens(id) ON DELETE CASCADE NOT VALID;
ALTER TABLE ONLY public.client_step_up_sessions
    ADD CONSTRAINT fk_rails_96e42d5326 FOREIGN KEY (step_up_ceremony_transaction_ref) REFERENCES public.client_step_up_ceremony_transactions(transaction_id) ON DELETE RESTRICT;
```

Migration provenance: `db/app_tickets_migrate/20260520143002_rename_app_ticket_tables_to_model_conventions.rb`, `db/app_tickets_migrate/20261003202100_bind_client_step_up_email_challenge.rb`, `db/app_tickets_migrate/20260921133000_rename_app_ticket_retention_columns_to_semantic_names.rb`, `db/app_tickets_migrate/20261003183659_bind_client_opaque_step_up_ceremonies.rb`.

### client_telephone_ceremony_transactions

Source: `db/app_ticket_structure.sql:1161`. Machines: `idp-client-telephone-ceremony`.

```sql
CREATE TABLE client_telephone_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    operation character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    grant_jti character varying NOT NULL,
    result_jti character varying,
    telephone_candidate_ref character varying,
    normalized_number_digest character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);
ALTER TABLE ONLY public.client_telephone_ceremony_transactions
    ADD CONSTRAINT client_telephone_ceremony_transactions_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_tickets_migrate/20260603120000_create_client_telephone_ceremony_transactions.rb`.

### client_telephone_statuses

Source: `db/app_zenith_structure.sql:2759`. Machines: .

```sql
CREATE TABLE client_telephone_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.client_telephone_statuses
    ADD CONSTRAINT client_telephone_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_principals_migrate/20260520143000_rename_app_principal_tables_to_model_conventions.rb`.

### client_telephones

Source: `db/app_zenith_structure.sql:2787`. Machines: `idp-client-telephone-otp`, `idp-client-telephone-credential`.

```sql
CREATE TABLE client_telephones (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    locked_at timestamp(6) with time zone DEFAULT '-infinity'::timestamp with time zone NOT NULL,
    number character varying DEFAULT ''::character varying NOT NULL,
    otp_attempts_count integer DEFAULT 0 NOT NULL,
    otp_counter text DEFAULT ''::text NOT NULL,
    otp_expires_at timestamp(6) with time zone DEFAULT '-infinity'::timestamp with time zone NOT NULL,
    otp_private_key character varying DEFAULT ''::character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint NOT NULL,
    user_identity_telephone_status_id bigint DEFAULT 0 NOT NULL,
    public_id character varying(21) NOT NULL,
    number_digest character varying,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL
);
ALTER TABLE ONLY public.client_telephones
    ADD CONSTRAINT client_telephones_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.client_telephones
    ADD CONSTRAINT fk_rails_7d903b3fd3 FOREIGN KEY (user_id) REFERENCES public.clients(id);
ALTER TABLE ONLY public.client_telephones
    ADD CONSTRAINT fk_rails_c81d47bc96 FOREIGN KEY (user_identity_telephone_status_id) REFERENCES public.client_telephone_statuses(id);
```

Migration provenance: `db/app_principals_migrate/20260520143000_rename_app_principal_tables_to_model_conventions.rb`, `db/app_principals_migrate/20260525131000_scope_client_contact_identifier_uniqueness_to_active_records.rb`, `db/app_principals_migrate/20260525120000_add_retention_to_client_sign_up_artifacts.rb`, `db/app_zenith_migrate/20260921133000_rename_app_zenith_retention_columns_to_semantic_names.rb`.

### client_token_binding_methods

Source: `db/app_ticket_structure.sql:1204`. Machines: .

```sql
CREATE TABLE client_token_binding_methods (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.client_token_binding_methods
    ADD CONSTRAINT client_token_binding_methods_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_tickets_migrate/20260520143002_rename_app_ticket_tables_to_model_conventions.rb`.

### client_token_dbsc_statuses

Source: `db/app_ticket_structure.sql:1232`. Machines: .

```sql
CREATE TABLE client_token_dbsc_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.client_token_dbsc_statuses
    ADD CONSTRAINT client_token_dbsc_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_tickets_migrate/20260520143002_rename_app_ticket_tables_to_model_conventions.rb`.

### client_token_kinds

Source: `db/app_ticket_structure.sql:1260`. Machines: .

```sql
CREATE TABLE client_token_kinds (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.client_token_kinds
    ADD CONSTRAINT client_token_kinds_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_tickets_migrate/20260520143002_rename_app_ticket_tables_to_model_conventions.rb`, `db/app_tickets_migrate/20260616150010_add_on_delete_actions_to_client_ticket_foreign_keys.rb`.

### client_token_statuses

Source: `db/app_ticket_structure.sql:1288`. Machines: .

```sql
CREATE TABLE client_token_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.client_token_statuses
    ADD CONSTRAINT client_token_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_tickets_migrate/20260520143002_rename_app_ticket_tables_to_model_conventions.rb`, `db/app_tickets_migrate/20260616150010_add_on_delete_actions_to_client_ticket_foreign_keys.rb`.

### client_tokens

Source: `db/app_ticket_structure.sql:1316`. Machines: `idp-client-token`, `idp-client-dbsc`.

```sql
CREATE TABLE client_tokens (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    dbsc_challenge text,
    dbsc_challenge_issued_at timestamp(6) with time zone,
    dbsc_public_key jsonb,
    dbsc_session_id character varying,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    last_step_up_at timestamp(6) with time zone,
    last_step_up_scope character varying,
    last_used_at timestamp(6) with time zone,
    public_id character varying(21) DEFAULT ''::character varying NOT NULL,
    refresh_token_digest bytea,
    refresh_token_family_id character varying,
    refresh_token_generation integer DEFAULT 0 NOT NULL,
    rotated_at timestamp(6) with time zone,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint NOT NULL,
    user_token_binding_method_id bigint DEFAULT 0 NOT NULL,
    user_token_dbsc_status_id bigint DEFAULT 0 NOT NULL,
    user_token_kind_id bigint DEFAULT 11 NOT NULL,
    user_token_status_id bigint DEFAULT 1 NOT NULL,
    dpop_jkt character varying,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    oidc_connection_id bigint,
    oidc_client_id character varying(64),
    oidc_scope character varying,
    oidc_sid uuid DEFAULT gen_random_uuid(),
    oidc_jti uuid DEFAULT gen_random_uuid(),
    device_session_id bigint,
    last_step_up_aal character varying,
    last_step_up_method character varying,
    last_step_up_purpose character varying,
    last_step_up_audience character varying,
    last_step_up_session_public_id character varying,
    selected_account_public_id character varying,
    selected_collective_public_id character varying,
    selected_collective_unit_public_id character varying,
    selected_avatar_public_id character varying,
    selected_at timestamp(6) with time zone,
    established_authentication_method character varying,
    last_step_up_phishing_resistant boolean DEFAULT false NOT NULL,
    authentication_event_at timestamp(6) with time zone,
    root_login_established_at timestamp with time zone,
    CONSTRAINT chk_client_tokens_established_authentication_method CHECK (((established_authentication_method IS NULL) OR ((established_authentication_method)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'secret'::character varying, 'passkey'::character varying, 'totp'::character varying, 'google'::character varying, 'apple'::character varying])::text[])))),
    CONSTRAINT chk_user_tokens_kind_id_positive CHECK ((user_token_kind_id >= 0)),
    CONSTRAINT chk_user_tokens_status_id_positive CHECK ((user_token_status_id >= 0))
);
ALTER TABLE ONLY public.client_tokens
    ADD CONSTRAINT client_tokens_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.client_tokens
    ADD CONSTRAINT fk_client_tokens_on_device_session_id FOREIGN KEY (device_session_id) REFERENCES public.client_device_sessions(id) ON DELETE RESTRICT;
ALTER TABLE ONLY public.client_tokens
    ADD CONSTRAINT fk_client_tokens_on_user_id_and_device_session_id FOREIGN KEY (user_id, device_session_id) REFERENCES public.client_device_sessions(user_id, id) ON DELETE RESTRICT;
ALTER TABLE ONLY public.client_tokens
    ADD CONSTRAINT fk_rails_c11b41180d FOREIGN KEY (user_token_status_id) REFERENCES public.client_token_statuses(id) ON DELETE RESTRICT NOT VALID;
ALTER TABLE ONLY public.client_tokens
    ADD CONSTRAINT fk_rails_f69bf5b8f0 FOREIGN KEY (user_token_kind_id) REFERENCES public.client_token_kinds(id) ON DELETE RESTRICT NOT VALID;
ALTER TABLE ONLY public.client_tokens
    ADD CONSTRAINT fk_user_tokens_on_user_token_binding_method_id FOREIGN KEY (user_token_binding_method_id) REFERENCES public.client_token_binding_methods(id) NOT VALID;
ALTER TABLE ONLY public.client_tokens
    ADD CONSTRAINT fk_user_tokens_on_user_token_dbsc_status_id FOREIGN KEY (user_token_dbsc_status_id) REFERENCES public.client_token_dbsc_statuses(id) NOT VALID;
```

Migration provenance: `db/app_tickets_migrate/20260915160000_add_authentication_event_at_to_client_tokens.rb`, `db/app_tickets_migrate/20261002120000_add_root_login_established_at_to_client_tokens.rb`, `db/app_tickets_migrate/20260727100000_add_established_authentication_method_to_client_tokens.rb`, `db/app_tickets_migrate/20260924152000_validate_client_token_device_session_reference.rb`, `db/app_tickets_migrate/20260924156000_validate_client_token_device_session_actor_foreign_key.rb`, `db/app_tickets_migrate/20260727100001_validate_established_authentication_method_on_client_tokens.rb`, `db/app_tickets_migrate/20260920152001_validate_restrict_client_sign_up_flow_token_delete.rb`, `db/app_tickets_migrate/20260520190000_create_device_sessions_for_user_tokens.rb`, `db/app_tickets_migrate/20260924150000_add_client_token_device_session_reference_index.rb`, `db/app_tickets_migrate/20260520143002_rename_app_ticket_tables_to_model_conventions.rb`, `db/app_tickets_migrate/20260606120000_add_selected_context_to_client_tokens.rb`, `db/app_tickets_migrate/20260526120100_remove_device_id_from_app_tickets.rb`, `db/app_tickets_migrate/20260920152000_restrict_client_sign_up_flow_token_delete.rb`, `db/app_tickets_migrate/20260921133000_rename_app_ticket_retention_columns_to_semantic_names.rb`, `db/app_tickets_migrate/20260924155000_add_client_token_device_session_actor_foreign_key.rb`, `db/app_tickets_migrate/20260525131500_restrict_client_sign_up_cycle_token_delete.rb`, `db/app_tickets_migrate/20260616150010_add_on_delete_actions_to_client_ticket_foreign_keys.rb`, `db/app_tickets_migrate/20260924151000_add_client_device_session_token_foreign_keys.rb`, `db/app_tickets_migrate/20260831064124_add_last_step_up_phishing_resistant_to_client_tokens.rb`, `db/app_tickets_migrate/20260528183000_add_strict_step_up_state_to_client_tokens.rb`.

### client_totp_ceremony_transactions

Source: `db/app_ticket_structure.sql:1389`. Machines: `idp-client-totp-ceremony`.

```sql
CREATE TABLE client_totp_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    operation character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    grant_jti character varying NOT NULL,
    result_jti character varying,
    credential_candidate_ref character varying,
    credential_candidate_digest character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    step_up_ceremony_transaction_ref character varying
);
ALTER TABLE ONLY public.client_totp_ceremony_transactions
    ADD CONSTRAINT client_totp_ceremony_transactions_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.client_totp_ceremony_transactions
    ADD CONSTRAINT fk_rails_23f495015b FOREIGN KEY (step_up_ceremony_transaction_ref) REFERENCES public.client_step_up_ceremony_transactions(transaction_id) ON DELETE RESTRICT;
```

Migration provenance: `db/app_tickets_migrate/20261003215004_bind_client_credential_ceremonies_to_base_authority.rb`, `db/app_tickets_migrate/20260603124000_create_client_totp_ceremony_transactions.rb`.

### client_totp_credential_statuses

Source: `db/app_zenith_structure.sql:2829`. Machines: .

```sql
CREATE TABLE client_totp_credential_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.client_totp_credential_statuses
    ADD CONSTRAINT client_totp_credential_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_principals_migrate/20260530031000_rename_app_principal_model_terms.rb`.

### client_totp_credentials

Source: `db/app_zenith_structure.sql:2857`. Machines: `idp-client-totp-credential`.

```sql
CREATE TABLE client_totp_credentials (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    last_otp_at timestamp(6) with time zone,
    private_key character varying(1024) DEFAULT ''::character varying NOT NULL,
    public_id character varying(21) NOT NULL,
    title character varying(32),
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint NOT NULL,
    user_identity_totp_credential_status_id bigint DEFAULT 5 NOT NULL,
    otp_attempts_count integer DEFAULT 0 NOT NULL,
    CONSTRAINT client_totp_credentials_otp_attempts_count_range CHECK (((otp_attempts_count >= 0) AND (otp_attempts_count <= 100)))
);
ALTER TABLE ONLY public.client_totp_credentials
    ADD CONSTRAINT client_totp_credentials_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.client_totp_credentials
    ADD CONSTRAINT fk_rails_5146d3e196 FOREIGN KEY (user_id) REFERENCES public.clients(id);
ALTER TABLE ONLY public.client_totp_credentials
    ADD CONSTRAINT fk_rails_ee2c1859b3 FOREIGN KEY (user_identity_totp_credential_status_id) REFERENCES public.client_totp_credential_statuses(id);
```

Migration provenance: `db/app_principals_migrate/20260530031000_rename_app_principal_model_terms.rb`, `db/app_principals_migrate/20260920110000_make_totp_failures_terminal.rb`, `db/app_principals_migrate/20260922130000_allow_null_for_client_totp_last_otp_at.rb`, `db/app_principals_migrate/20260920110001_validate_totp_failure_count.rb`, `db/app_principals_migrate/20260530032000_rename_client_totp_credential_status_column.rb`, `db/app_principals_migrate/20260919120000_add_totp_attempt_lock_to_client_totp_credentials.rb`.

### client_visibilities

Source: `db/app_zenith_structure.sql:2895`. Machines: .

```sql
CREATE TABLE client_visibilities (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.client_visibilities
    ADD CONSTRAINT client_visibilities_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_principals_migrate/20260520143000_rename_app_principal_tables_to_model_conventions.rb`.

### client_withdrawal_ceremonies

Source: `db/app_zenith_structure.sql:2923`. Machines: `idp-client-withdrawal-ceremony`.

```sql
CREATE TABLE client_withdrawal_ceremonies (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    client_id bigint NOT NULL,
    purpose character varying NOT NULL,
    status_id integer DEFAULT 1 NOT NULL,
    token_digest bytea NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    ip_digest bytea,
    user_agent_digest bytea,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);
ALTER TABLE ONLY public.client_withdrawal_ceremonies
    ADD CONSTRAINT client_withdrawal_ceremonies_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.client_withdrawal_ceremonies
    ADD CONSTRAINT fk_rails_9386315187 FOREIGN KEY (client_id) REFERENCES public.clients(id);
```

Migration provenance: `db/app_principals_migrate/20260703010000_create_client_withdrawal_ceremonies.rb`.

### client_withdrawal_flow_events

Source: `db/app_zenith_structure.sql:2964`. Machines: .

```sql
CREATE TABLE client_withdrawal_flow_events (
    id bigint NOT NULL,
    client_withdrawal_flow_id bigint NOT NULL,
    client_id bigint NOT NULL,
    from_status_id bigint,
    to_status_id bigint NOT NULL,
    occurred_at timestamp(6) with time zone NOT NULL,
    token_public_id character varying(64) DEFAULT ''::character varying NOT NULL,
    reason character varying(64) DEFAULT ''::character varying NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);
ALTER TABLE ONLY public.client_withdrawal_flow_events
    ADD CONSTRAINT client_withdrawal_flow_events_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.client_withdrawal_flow_events
    ADD CONSTRAINT fk_rails_7344701780 FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE CASCADE NOT VALID;
ALTER TABLE ONLY public.client_withdrawal_flow_events
    ADD CONSTRAINT fk_rails_9511d96f8c FOREIGN KEY (to_status_id) REFERENCES public.client_withdrawal_flow_statuses(id) ON DELETE RESTRICT NOT VALID;
ALTER TABLE ONLY public.client_withdrawal_flow_events
    ADD CONSTRAINT fk_rails_b55e5a56c4 FOREIGN KEY (client_withdrawal_flow_id) REFERENCES public.client_withdrawal_flows(id) NOT VALID;
ALTER TABLE ONLY public.client_withdrawal_flow_events
    ADD CONSTRAINT fk_rails_f24d4919a7 FOREIGN KEY (from_status_id) REFERENCES public.client_withdrawal_flow_statuses(id) ON DELETE RESTRICT NOT VALID;
```

Migration provenance: `db/app_principals_migrate/20260530032300_rename_client_withdrawal_flow_tables.rb`, `db/app_principals_migrate/20260616150010_add_on_delete_actions_to_client_principal_foreign_keys.rb`, `db/app_principals_migrate/20260530032500_rename_client_withdrawal_flow_event_column.rb`.

### client_withdrawal_flow_statuses

Source: `db/app_zenith_structure.sql:3002`. Machines: .

```sql
CREATE TABLE client_withdrawal_flow_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.client_withdrawal_flow_statuses
    ADD CONSTRAINT client_withdrawal_flow_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_principals_migrate/20260530032300_rename_client_withdrawal_flow_tables.rb`, `db/app_principals_migrate/20260616150010_add_on_delete_actions_to_client_principal_foreign_keys.rb`.

### client_withdrawal_flows

Source: `db/app_zenith_structure.sql:3030`. Machines: `idp-client-withdrawal`.

```sql
CREATE TABLE client_withdrawal_flows (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    client_id bigint NOT NULL,
    status_id bigint DEFAULT 10 NOT NULL,
    began_at timestamp(6) with time zone NOT NULL,
    completed_at timestamp(6) with time zone,
    failed_at timestamp(6) with time zone,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_client_withdrawal_cycles_retention_order CHECK ((discard_at <= purge_eligible_at))
);
ALTER TABLE ONLY public.client_withdrawal_flows
    ADD CONSTRAINT client_withdrawal_flows_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.client_withdrawal_flows
    ADD CONSTRAINT fk_rails_3a897cfb78 FOREIGN KEY (status_id) REFERENCES public.client_withdrawal_flow_statuses(id) NOT VALID;
ALTER TABLE ONLY public.client_withdrawal_flows
    ADD CONSTRAINT fk_rails_e5e99fd372 FOREIGN KEY (client_id) REFERENCES public.clients(id) NOT VALID;
```

Migration provenance: `db/app_principals_migrate/20260530032300_rename_client_withdrawal_flow_tables.rb`, `db/app_principals_migrate/20260519094000_create_client_withdrawal_cycles.rb`, `db/app_zenith_migrate/20260921133000_rename_app_zenith_retention_columns_to_semantic_names.rb`.

### clients

Source: `db/app_zenith_structure.sql:3069`. Machines: `idp-client-administrative-access`, `idp-client-actor-withdrawal`, `idp-client-actor-provisioning`, `idp-client-mfa-readiness`.

```sql
CREATE TABLE clients (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    last_step_up_at timestamp(6) with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    public_id character varying(255) DEFAULT ''::character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    withdrawn_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone,
    status_id bigint DEFAULT 11 NOT NULL,
    mfa_level_enabled boolean DEFAULT false NOT NULL,
    withdrawal_started_at timestamp(6) with time zone,
    deactivated_at timestamp(6) with time zone,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    visibility_id bigint DEFAULT 2 NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    mfa_level_id bigint DEFAULT 0 NOT NULL,
    mfa_status_id bigint DEFAULT 5 NOT NULL,
    terminated_at timestamp(6) with time zone,
    birthdate text,
    access_state character varying DEFAULT 'enabled'::character varying NOT NULL,
    admin_locked_at timestamp(6) with time zone,
    admin_locked_by_operator_id bigint,
    admin_locked_reason_code character varying,
    admin_locked_reason_note text,
    token_valid_after_at timestamp(6) with time zone,
    reactivated_at timestamp(6) with time zone,
    webauthn_user_handle character varying NOT NULL,
    CONSTRAINT chk_clients_access_state CHECK (((access_state)::text = ANY ((ARRAY['enabled'::character varying, 'admin_locked'::character varying])::text[]))),
    CONSTRAINT chk_clients_admin_locked_reason_code CHECK (((admin_locked_reason_code IS NULL) OR ((admin_locked_reason_code)::text = ANY ((ARRAY['abuse'::character varying, 'security_incident'::character varying, 'chargeback'::character varying, 'terms_violation'::character varying, 'support_request'::character varying, 'legal_hold'::character varying, 'operator_error_recovery'::character varying, 'other'::character varying])::text[])))),
    CONSTRAINT chk_clients_birthdate_length CHECK (((birthdate IS NULL) OR (char_length(birthdate) <= 1000))),
    CONSTRAINT chk_users_retention_order CHECK ((discard_at <= purge_eligible_at))
);
ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.clients
    ADD CONSTRAINT fk_rails_67ec2e6839 FOREIGN KEY (mfa_status_id) REFERENCES public.client_mfa_statuses(id);
ALTER TABLE ONLY public.clients
    ADD CONSTRAINT fk_rails_73fa0fcaee FOREIGN KEY (mfa_level_id) REFERENCES public.client_mfa_levels(id);
ALTER TABLE ONLY public.clients
    ADD CONSTRAINT fk_rails_c9df50d461 FOREIGN KEY (visibility_id) REFERENCES public.client_visibilities(id);
ALTER TABLE ONLY public.clients
    ADD CONSTRAINT fk_rails_ce4a327a04 FOREIGN KEY (status_id) REFERENCES public.client_statuses(id);
```

Migration provenance: `db/org_principals_migrate/20260103133001_validate_fix_database_consistency_identity_relations.rb`, `db/org_principals_migrate/20260103120000_add_division_fk_to_clients.rb`, `db/org_principals_migrate/20260102034808_remove_redundant_identity_indexes.rb`, `db/org_principals_migrate/20260102100036_add_division_to_clients.rb`, `db/org_principals_migrate/20260103122221_add_foreign_keys_to_workspace_organization_division.rb`, `db/org_principals_migrate/20260103133000_fix_database_consistency_identity_relations.rb`, `db/org_principals_migrate/20260102035351_fix_database_consistency_identity.rb`, `db/app_principals_migrate/20260202200000_fix_clients_status_relations.rb`, `db/app_principals_migrate/20260518170001_validate_clients_birthdate_length.rb`, `db/app_principals_migrate/20260525200000_drop_deletable_at_from_clients.rb`, `db/app_principals_migrate/20260518181000_validate_remaining_app_principal_foreign_keys.rb`, `db/app_principals_migrate/20260528162000_harden_client_lifecycle_and_mfa_constraints.rb`, `db/app_principals_migrate/20260520143000_rename_app_principal_tables_to_model_conventions.rb`, `db/app_principals_migrate/20260518170000_add_birthdate_to_clients.rb`, `db/app_principals_migrate/20260201210004_remove_redundant_principal_indexes.rb`, `db/app_principals_migrate/20251230150021_validate_user_client_foreign_keys.rb`, `db/app_principals_migrate/20260201190008_convert_principal_pks.rb`, `db/app_principals_migrate/20260616150005_add_client_fk_to_client_preferences.rb`, `db/app_principals_migrate/20260530032400_rename_client_mfa_enabled_column.rb`, `db/app_principals_migrate/20251230150010_create_user_clients.rb`, `db/app_principals_migrate/20260131140000_convert_client_statuses_to_smallint.rb`, `db/app_principals_migrate/20260114120221_add_lock_version_to_users_and_clients.rb`, `db/app_principals_migrate/20251230170005_add_user_id_to_clients.rb`, `db/app_principals_migrate/20260724190000_create_client_external_identities.rb`, `db/app_principals_migrate/20260102035038_fix_client_fk_behaviors.rb`, `db/app_principals_migrate/20260507000006_create_client_banners.rb`, `db/app_principals_migrate/20260110194100_remove_redundant_indexes_principal_user_clients.rb`, `db/app_principals_migrate/20260614090000_add_administrative_access_lock_to_clients.rb`, `db/app_principals_migrate/20260911120000_log_client_external_identities.rb`, `db/app_principals_migrate/20260109141212_add_id_format_constraints_to_principal_tables.rb`, `db/app_principals_migrate/20260202160000_fix_consistency_users.rb`, `db/app_principals_migrate/20260719100001_add_webauthn_user_handle_to_clients.rb`, `db/app_principals_migrate/20260102035039_validate_client_fk_behaviors.rb`, `db/app_principals_migrate/20260616150010_add_on_delete_actions_to_client_principal_foreign_keys.rb`, `db/app_principals_migrate/20260724201700_validate_external_authentication_foreign_keys.rb`, `db/app_principals_migrate/20260519172001_remove_client_banner_client_foreign_key.rb`, `db/app_principals_migrate/20251230140819_create_clients.rb`, `db/app_principals_migrate/20260724201100_add_client_foreign_key_to_apple_notification_events.rb`, `db/app_principals_migrate/20251230145346_add_status_id_to_clients.rb`, `db/app_principals_migrate/20260105150000_add_division_to_clients_identity.rb`, `db/app_principals_migrate/20260724201600_nullify_notification_event_identity_foreign_keys.rb`, `db/app_principals_migrate/20260614090001_validate_administrative_access_lock_on_clients.rb`, `db/app_principals_migrate/20260530032100_rename_client_mfa_columns.rb`, `db/app_principals_migrate/20260724201200_validate_client_foreign_key_on_apple_notification_events.rb`, `db/app_principals_migrate/20260202185000_fix_principal_consistency.rb`, `db/app_zenith_migrate/20260917120000_create_app_authority_relations.rb`, `db/app_zenith_migrate/20260727140000_create_client_emails_permanent_freeze_trigger.rb`, `db/app_zenith_migrate/20260921133000_rename_app_zenith_retention_columns_to_semantic_names.rb`, `db/app_zenith_migrate/20260727140001_create_clients_hard_delete_protection_trigger.rb`.

### com_enforcement_appeals

Source: `db/com_zenith_structure.sql:82`. Machines: `idp-visitor-enforcement-appeal`.

```sql
CREATE TABLE com_enforcement_appeals (
    id bigint NOT NULL,
    com_enforcement_case_id bigint NOT NULL,
    public_id character varying NOT NULL,
    state character varying DEFAULT 'submitted'::character varying NOT NULL,
    reason_code character varying NOT NULL,
    statement text,
    submitted_at timestamp(6) with time zone NOT NULL,
    reviewed_at timestamp(6) with time zone,
    reviewer_operator_public_id character varying,
    resolution_code character varying,
    redacted_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_com_enforcement_appeals_state CHECK (((state)::text = ANY ((ARRAY['submitted'::character varying, 'under_review'::character varying, 'approved'::character varying, 'rejected'::character varying, 'redacted'::character varying])::text[])))
);
ALTER TABLE ONLY public.com_enforcement_appeals
    ADD CONSTRAINT com_enforcement_appeals_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.com_enforcement_appeals
    ADD CONSTRAINT fk_rails_761c041c0c FOREIGN KEY (com_enforcement_case_id) REFERENCES public.com_enforcement_cases(id);
```

Migration provenance: `db/com_zenith_migrate/20260729120000_create_com_enforcement_appeals.rb`.

### com_enforcement_authentication_method_effects

Source: `db/com_zenith_structure.sql:123`. Machines: .

```sql
CREATE TABLE com_enforcement_authentication_method_effects (
    id bigint NOT NULL,
    com_enforcement_case_id bigint NOT NULL,
    principal_public_id character varying NOT NULL,
    authentication_method character varying NOT NULL,
    effect character varying NOT NULL,
    effective_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone,
    ended_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_com_enforcement_method_effects_effect CHECK (((effect)::text = ANY ((ARRAY['mutation_locked'::character varying, 'unusable'::character varying, 'permanently_frozen'::character varying])::text[]))),
    CONSTRAINT chk_com_enforcement_method_effects_method CHECK (((authentication_method)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'secret'::character varying, 'passkey'::character varying])::text[])))
);
ALTER TABLE ONLY public.com_enforcement_authentication_method_effects
    ADD CONSTRAINT com_enforcement_authentication_method_effects_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.com_enforcement_authentication_method_effects
    ADD CONSTRAINT fk_rails_0e70aae130 FOREIGN KEY (com_enforcement_case_id) REFERENCES public.com_enforcement_cases(id);
```

Migration provenance: `db/com_zenith_migrate/20260727120002_create_com_enforcement_authentication_method_effects.rb`.

### com_enforcement_cases

Source: `db/com_zenith_structure.sql:162`. Machines: `idp-visitor-enforcement-case`.

```sql
CREATE TABLE com_enforcement_cases (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    kind character varying NOT NULL,
    state character varying DEFAULT 'draft'::character varying NOT NULL,
    duration_mode character varying NOT NULL,
    visibility character varying DEFAULT 'visible'::character varying NOT NULL,
    release_mode character varying NOT NULL,
    effective_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone,
    ended_at timestamp(6) with time zone,
    end_reason character varying,
    review_due_at timestamp(6) with time zone,
    reason_code character varying NOT NULL,
    reason_note text,
    ticket_id character varying,
    principal_public_id character varying NOT NULL,
    applied_by_operator_public_id character varying NOT NULL,
    approved_by_operator_public_id character varying,
    ended_by_operator_public_id character varying,
    break_glass boolean DEFAULT false NOT NULL,
    break_glass_approved_by_operator_public_id character varying,
    sessions_revoked_at timestamp(6) with time zone,
    audited_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_com_enforcement_cases_approval_separation CHECK (((approved_by_operator_public_id IS NULL) OR ((approved_by_operator_public_id)::text <> (applied_by_operator_public_id)::text))),
    CONSTRAINT chk_com_enforcement_cases_break_glass_approver CHECK (((break_glass = false) OR (break_glass_approved_by_operator_public_id IS NOT NULL))),
    CONSTRAINT chk_com_enforcement_cases_cooldown_duration CHECK ((((kind)::text <> 'cooldown'::text) OR (((duration_mode)::text = 'timed'::text) AND (expires_at IS NOT NULL) AND (expires_at <= (effective_at + '30 days'::interval))))),
    CONSTRAINT chk_com_enforcement_cases_duration_mode CHECK (((duration_mode)::text = ANY ((ARRAY['timed'::character varying, 'indefinite'::character varying, 'permanent'::character varying])::text[]))),
    CONSTRAINT chk_com_enforcement_cases_end_reason CHECK (((end_reason IS NULL) OR ((end_reason)::text = ANY ((ARRAY['expired'::character varying, 'revoked'::character varying, 'superseded'::character varying, 'corrected'::character varying, 'appeal_approved'::character varying, 'break_glass_released'::character varying, 'verification_completed'::character varying])::text[])))),
    CONSTRAINT chk_com_enforcement_cases_hidden CHECK ((((visibility)::text <> 'hidden'::text) OR ((kind)::text = 'permanent_ban'::text))),
    CONSTRAINT chk_com_enforcement_cases_indefinite_freeze_review CHECK ((((kind)::text <> 'temporary_freeze'::text) OR ((duration_mode)::text <> 'indefinite'::text) OR ((review_due_at IS NOT NULL) AND ((release_mode)::text = 'operator'::text)))),
    CONSTRAINT chk_com_enforcement_cases_kind CHECK (((kind)::text = ANY ((ARRAY['security_lock'::character varying, 'cooldown'::character varying, 'temporary_freeze'::character varying, 'permanent_ban'::character varying, 'method_protection'::character varying])::text[]))),
    CONSTRAINT chk_com_enforcement_cases_no_self_action CHECK (((principal_public_id)::text <> (applied_by_operator_public_id)::text)),
    CONSTRAINT chk_com_enforcement_cases_permanent_ban_duration CHECK ((((kind)::text <> 'permanent_ban'::text) OR (((duration_mode)::text = 'permanent'::text) AND (expires_at IS NULL)))),
    CONSTRAINT chk_com_enforcement_cases_release_mode CHECK (((release_mode)::text = ANY ((ARRAY['automatic'::character varying, 'operator'::character varying, 'verification_required'::character varying, 'break_glass_only'::character varying])::text[]))),
    CONSTRAINT chk_com_enforcement_cases_security_lock_release CHECK ((((kind)::text <> 'security_lock'::text) OR ((release_mode)::text = 'verification_required'::text))),
    CONSTRAINT chk_com_enforcement_cases_state CHECK (((state)::text = ANY ((ARRAY['draft'::character varying, 'pending_approval'::character varying, 'active'::character varying, 'ended'::character varying, 'failed'::character varying])::text[]))),
    CONSTRAINT chk_com_enforcement_cases_temp_freeze_duration_mode CHECK ((((kind)::text <> 'temporary_freeze'::text) OR ((duration_mode)::text = ANY ((ARRAY['timed'::character varying, 'indefinite'::character varying])::text[])))),
    CONSTRAINT chk_com_enforcement_cases_visibility CHECK (((visibility)::text = ANY ((ARRAY['visible'::character varying, 'hidden'::character varying])::text[])))
);
ALTER TABLE ONLY public.com_enforcement_cases
    ADD CONSTRAINT com_enforcement_cases_pkey PRIMARY KEY (id);
```

Migration provenance: `db/com_zenith_migrate/20260830120000_allow_verification_completed_com_enforcement_case_end_reason.rb`, `db/com_zenith_migrate/20260727120000_create_com_enforcement_cases.rb`.

### com_enforcement_identifier_effects

Source: `db/com_zenith_structure.sql:229`. Machines: .

```sql
CREATE TABLE com_enforcement_identifier_effects (
    id bigint NOT NULL,
    com_enforcement_case_id bigint NOT NULL,
    identifier_kind character varying NOT NULL,
    lookup_digest character varying NOT NULL,
    key_version integer NOT NULL,
    digest_version integer NOT NULL,
    normalization_version integer NOT NULL,
    display_value text,
    registration_blocked boolean DEFAULT false NOT NULL,
    attachment_blocked boolean DEFAULT false NOT NULL,
    recovery_blocked boolean DEFAULT false NOT NULL,
    effective_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone,
    ended_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_com_enforcement_identifier_effects_kind CHECK (((identifier_kind)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'identity_id'::character varying])::text[])))
);
ALTER TABLE ONLY public.com_enforcement_identifier_effects
    ADD CONSTRAINT com_enforcement_identifier_effects_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.com_enforcement_identifier_effects
    ADD CONSTRAINT fk_rails_25cb89edf0 FOREIGN KEY (com_enforcement_case_id) REFERENCES public.com_enforcement_cases(id);
```

Migration provenance: `db/com_zenith_migrate/20260727120003_create_com_enforcement_identifier_effects.rb`.

### com_enforcement_principal_effects

Source: `db/com_zenith_structure.sql:273`. Machines: .

```sql
CREATE TABLE com_enforcement_principal_effects (
    id bigint NOT NULL,
    com_enforcement_case_id bigint NOT NULL,
    principal_public_id character varying NOT NULL,
    access_blocking boolean DEFAULT false NOT NULL,
    recovery_blocked boolean DEFAULT false NOT NULL,
    reactivation_blocked boolean DEFAULT false NOT NULL,
    withdrawal_purge_blocked boolean DEFAULT false NOT NULL,
    principal_hard_delete_blocked boolean DEFAULT false NOT NULL,
    profile_effect character varying,
    effective_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone,
    ended_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);
ALTER TABLE ONLY public.com_enforcement_principal_effects
    ADD CONSTRAINT com_enforcement_principal_effects_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.com_enforcement_principal_effects
    ADD CONSTRAINT fk_rails_36c24dea97 FOREIGN KEY (com_enforcement_case_id) REFERENCES public.com_enforcement_cases(id);
```

Migration provenance: `db/com_zenith_migrate/20260727120001_create_com_enforcement_principal_effects.rb`.

### com_enforcement_principal_links

Source: `db/com_zenith_structure.sql:314`. Machines: .

```sql
CREATE TABLE com_enforcement_principal_links (
    id bigint NOT NULL,
    com_enforcement_case_id bigint NOT NULL,
    principal_kind character varying NOT NULL,
    principal_public_id character varying NOT NULL,
    relationship_kind character varying NOT NULL,
    linked_at timestamp(6) with time zone NOT NULL,
    ended_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_com_enforcement_principal_links_relationship_kind CHECK (((relationship_kind)::text = ANY ((ARRAY['target_principal'::character varying, 'former_principal'::character varying, 'related_principal'::character varying, 'suspected_duplicate'::character varying, 'reinstated_principal'::character varying, 'false_positive'::character varying])::text[])))
);
ALTER TABLE ONLY public.com_enforcement_principal_links
    ADD CONSTRAINT com_enforcement_principal_links_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.com_enforcement_principal_links
    ADD CONSTRAINT fk_rails_b1a1063626 FOREIGN KEY (com_enforcement_case_id) REFERENCES public.com_enforcement_cases(id);
```

Migration provenance: `db/com_zenith_migrate/20260727120004_create_com_enforcement_principal_links.rb`.

### com_preference_binding_methods

Source: `db/com_setting_structure.sql:121`. Machines: .

```sql
CREATE TABLE com_preference_binding_methods (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.com_preference_binding_methods
    ADD CONSTRAINT com_preference_binding_methods_pkey PRIMARY KEY (id);
```

Migration provenance: `db/com_settings_migrate/20260518030000_load_initial_com_setting_schema.rb`.

### com_preference_dbsc_statuses

Source: `db/com_setting_structure.sql:306`. Machines: .

```sql
CREATE TABLE com_preference_dbsc_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.com_preference_dbsc_statuses
    ADD CONSTRAINT com_preference_dbsc_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/com_settings_migrate/20260518030000_load_initial_com_setting_schema.rb`.

### com_preference_statuses

Source: `db/com_setting_structure.sql:634`. Machines: .

```sql
CREATE TABLE com_preference_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.com_preference_statuses
    ADD CONSTRAINT com_preference_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/com_settings_migrate/20260518030000_load_initial_com_setting_schema.rb`.

### com_preferences

Source: `db/com_setting_structure.sql:842`. Machines: `idp-visitor-preference-dbsc`.

```sql
CREATE TABLE com_preferences (
    id bigint NOT NULL,
    binding_method_id bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    dbsc_challenge text,
    dbsc_challenge_issued_at timestamp(6) with time zone,
    dbsc_public_key jsonb,
    dbsc_session_id character varying,
    dbsc_status_id bigint DEFAULT 0 NOT NULL,
    jti character varying,
    public_id character varying NOT NULL,
    replaced_by_id bigint,
    status_id bigint DEFAULT 2 NOT NULL,
    token_digest bytea,
    updated_at timestamp(6) with time zone NOT NULL,
    used_at timestamp(6) with time zone,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    explicit_fields jsonb DEFAULT '[]'::jsonb NOT NULL
);
ALTER TABLE ONLY public.com_preferences
    ADD CONSTRAINT com_preferences_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.com_preferences
    ADD CONSTRAINT fk_com_preferences_on_binding_method_id FOREIGN KEY (binding_method_id) REFERENCES public.com_preference_binding_methods(id) NOT VALID;
ALTER TABLE ONLY public.com_preferences
    ADD CONSTRAINT fk_com_preferences_on_dbsc_status_id FOREIGN KEY (dbsc_status_id) REFERENCES public.com_preference_dbsc_statuses(id) NOT VALID;
ALTER TABLE ONLY public.com_preferences
    ADD CONSTRAINT fk_com_preferences_on_status_id FOREIGN KEY (status_id) REFERENCES public.com_preference_statuses(id) NOT VALID;
ALTER TABLE ONLY public.com_preferences
    ADD CONSTRAINT fk_rails_1c704c910f FOREIGN KEY (replaced_by_id) REFERENCES public.com_preferences(id) ON DELETE SET NULL NOT VALID;
```

Migration provenance: `db/com_zenith_migrate/20260721090000_add_explicit_fields_to_visitor_preferences.rb`, `db/com_settings_migrate/20260530120000_add_explicit_fields_to_com_preferences.rb`, `db/com_settings_migrate/20260526090000_create_com_preference_r18_display_stoppers.rb`, `db/com_settings_migrate/20260526120202_remove_device_id_from_com_preferences.rb`, `db/com_settings_migrate/20260518030000_load_initial_com_setting_schema.rb`, `db/com_settings_migrate/20260921133000_rename_com_setting_retention_columns_to_semantic_names.rb`.

### identity_secret_credential_ceremony_candidates

Source: `db/app_ticket_structure.sql:1469`. Machines: `idp-identity-secret-credential-candidate`.

```sql
CREATE TABLE identity_secret_credential_ceremony_candidates (
    id bigint NOT NULL,
    ref character varying NOT NULL,
    digest character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    transaction_id character varying NOT NULL,
    operation character varying NOT NULL,
    password_digest text NOT NULL,
    name character varying NOT NULL,
    enabled boolean NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);
ALTER TABLE ONLY public.identity_secret_credential_ceremony_candidates
    ADD CONSTRAINT identity_secret_credential_ceremony_candidates_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_tickets_migrate/20260618120000_create_identity_ceremony_candidates.rb`.

### identity_social_ceremony_candidates

Source: `db/app_ticket_structure.sql:1512`. Machines: `idp-identity-social-candidate`.

```sql
CREATE TABLE identity_social_ceremony_candidates (
    id bigint NOT NULL,
    ref character varying NOT NULL,
    digest character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    transaction_id character varying NOT NULL,
    operation character varying NOT NULL,
    provider character varying NOT NULL,
    auth_hash text NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);
ALTER TABLE ONLY public.identity_social_ceremony_candidates
    ADD CONSTRAINT identity_social_ceremony_candidates_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_tickets_migrate/20260618120000_create_identity_ceremony_candidates.rb`.

### identity_totp_ceremony_candidates

Source: `db/app_ticket_structure.sql:1554`. Machines: `idp-identity-totp-enrollment`.

```sql
CREATE TABLE identity_totp_ceremony_candidates (
    id bigint NOT NULL,
    ref character varying NOT NULL,
    digest character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    private_key text NOT NULL,
    title character varying,
    last_otp_at timestamp(6) with time zone,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    step_up_ceremony_transaction_ref character varying,
    CONSTRAINT totp_candidate_pending_authority CHECK (((last_otp_at IS NOT NULL) OR (step_up_ceremony_transaction_ref IS NOT NULL)))
);
ALTER TABLE ONLY public.identity_totp_ceremony_candidates
    ADD CONSTRAINT identity_totp_ceremony_candidates_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.identity_totp_ceremony_candidates
    ADD CONSTRAINT fk_rails_5e9f08645d FOREIGN KEY (step_up_ceremony_transaction_ref) REFERENCES public.client_step_up_ceremony_transactions(transaction_id) ON DELETE RESTRICT;
```

Migration provenance: `db/app_tickets_migrate/20261003215004_bind_client_credential_ceremonies_to_base_authority.rb`, `db/app_tickets_migrate/20260618120000_create_identity_ceremony_candidates.rb`.

### operator_auth_ceremony_sessions

Source: `db/org_ticket_structure.sql:61`. Machines: `idp-operator-auth-ceremony-session`.

```sql
CREATE TABLE operator_auth_ceremony_sessions (
    id bigint NOT NULL,
    sid_digest character varying(64) NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    revoked_at timestamp(6) with time zone,
    rotated_at timestamp(6) with time zone,
    previous_sid_digest character varying(64),
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    authorization_transaction_ref character varying,
    admitted_at timestamp(6) with time zone,
    completed_at timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    authentication_method character varying,
    authentication_event_at timestamp(6) with time zone,
    local_sign_in_flow_ref character varying,
    local_sign_up_flow_ref character varying,
    admission_purpose character varying,
    step_up_ceremony_transaction_ref character varying,
    CONSTRAINT operator_auth_admission_purpose_valid CHECK (((admission_purpose IS NULL) OR ((admission_purpose)::text = ANY ((ARRAY['local_sign_in'::character varying, 'local_sign_up'::character varying, 'authentication_handoff'::character varying, 'invitation_handoff'::character varying, 'step_up_handoff'::character varying, 'reauthentication_handoff'::character varying, 'bootstrap_handoff'::character varying, 'credential_registration_handoff'::character varying, 'credential_change_handoff'::character varying])::text[])))),
    CONSTRAINT operator_auth_ceremony_purpose_exclusive CHECK ((num_nonnulls(authorization_transaction_ref, local_sign_in_flow_ref, local_sign_up_flow_ref) <= 1)),
    CONSTRAINT operator_auth_ceremony_sessions_admission_binding CHECK (((authorization_transaction_ref IS NULL) OR (admitted_at IS NOT NULL))),
    CONSTRAINT operator_auth_ceremony_sessions_authentication_evidence_pair CHECK (((authentication_method IS NULL) = (authentication_event_at IS NULL))),
    CONSTRAINT operator_auth_ceremony_sessions_authentication_method CHECK (((authentication_method IS NULL) OR ((authentication_method)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'secret'::character varying, 'passkey'::character varying, 'totp'::character varying, 'google'::character varying, 'apple'::character varying, 'entra'::character varying])::text[])))),
    CONSTRAINT operator_auth_ceremony_sessions_one_terminal_timestamp CHECK ((num_nonnulls(revoked_at, completed_at, cancelled_at) <= 1)),
    CONSTRAINT operator_auth_ceremony_transaction_exclusive CHECK ((num_nonnulls(authorization_transaction_ref, local_sign_in_flow_ref, local_sign_up_flow_ref, step_up_ceremony_transaction_ref) <= 1))
);
ALTER TABLE ONLY public.operator_auth_ceremony_sessions
    ADD CONSTRAINT operator_auth_ceremony_sessions_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.operator_auth_ceremony_sessions
    ADD CONSTRAINT fk_rails_562d790641 FOREIGN KEY (step_up_ceremony_transaction_ref) REFERENCES public.operator_step_up_ceremony_transactions(transaction_id) ON DELETE RESTRICT;
ALTER TABLE ONLY public.operator_auth_ceremony_sessions
    ADD CONSTRAINT fk_rails_5ea4994c1a FOREIGN KEY (local_sign_up_flow_ref) REFERENCES public.operator_sign_up_flows(public_id) ON DELETE RESTRICT;
ALTER TABLE ONLY public.operator_auth_ceremony_sessions
    ADD CONSTRAINT fk_rails_ed41a3bf04 FOREIGN KEY (local_sign_in_flow_ref) REFERENCES public.operator_sign_in_flows(public_id) ON DELETE RESTRICT;
```

Migration provenance: `db/org_tickets_migrate/20260921140100_validate_authentication_evidence_constraints.rb`, `db/org_tickets_migrate/20261003183915_bind_operator_opaque_step_up_ceremonies.rb`, `db/org_tickets_migrate/20261003175658_bind_operator_local_authentication_results.rb`, `db/org_tickets_migrate/20260921140000_add_authentication_evidence_to_operator_auth_ceremony_sessions.rb`, `db/org_tickets_migrate/20260920150000_extend_operator_auth_ceremony_session_lifecycle.rb`, `db/org_tickets_migrate/20260913140000_create_operator_auth_ceremony_sessions.rb`, `db/org_tickets_migrate/20261003215031_bind_operator_credential_ceremonies_to_base_authority.rb`, `db/org_tickets_migrate/20260920151000_validate_operator_auth_ceremony_session_lifecycle.rb`.

### operator_device_sessions

Source: `db/org_ticket_structure.sql:113`. Machines: `idp-operator-device-session`.

```sql
CREATE TABLE operator_device_sessions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    staff_id bigint NOT NULL,
    dbsc_session_id_digest character varying,
    dbsc_public_key_thumbprint character varying,
    dbsc_bound_at timestamp(6) with time zone,
    dpop_jkt character varying,
    status_id bigint DEFAULT 1 NOT NULL,
    current_refresh_token_id bigint,
    refresh_token_family_id character varying,
    last_seen_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    revoke_reason character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    last_network_hmac character varying
);
ALTER TABLE ONLY public.operator_device_sessions
    ADD CONSTRAINT operator_device_sessions_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.operator_device_sessions
    ADD CONSTRAINT fk_operator_device_sessions_on_current_refresh_token_owner FOREIGN KEY (id, current_refresh_token_id) REFERENCES public.operator_tokens(device_session_id, id) ON DELETE SET NULL (current_refresh_token_id) DEFERRABLE INITIALLY DEFERRED;
```

Migration provenance: `db/org_tickets_migrate/20260611100100_add_last_network_hmac_to_operator_device_sessions.rb`, `db/org_tickets_migrate/20260520190001_create_device_sessions_for_staff_tokens.rb`, `db/org_tickets_migrate/20260924154000_add_operator_device_session_actor_reference_index.rb`, `db/org_tickets_migrate/20260924155000_add_operator_token_device_session_actor_foreign_key.rb`, `db/org_tickets_migrate/20260924151000_add_operator_device_session_token_foreign_keys.rb`, `db/org_tickets_migrate/20260526120101_remove_device_id_from_org_tickets.rb`, `db/org_tickets_migrate/20260924153000_validate_operator_current_refresh_token_owner.rb`.

### operator_dpop_proof_states

Source: `db/org_ticket_structure.sql:156`. Machines: `idp-operator-dpop-nonce`.

```sql
CREATE TABLE operator_dpop_proof_states (
    id bigint NOT NULL,
    jti character varying,
    jkt character varying,
    nonce character varying,
    htm character varying,
    htu character varying,
    seen_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    nonce_used_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);
ALTER TABLE ONLY public.operator_dpop_proof_states
    ADD CONSTRAINT operator_dpop_proof_states_pkey PRIMARY KEY (id);
```

Migration provenance: `db/org_tickets_migrate/20260526120001_create_operator_dpop_proof_states.rb`.

### operator_email_ceremony_transactions

Source: `db/org_ticket_structure.sql:194`. Machines: `idp-operator-email-ceremony`, `idp-operator-email-verification-challenge`.

```sql
CREATE TABLE operator_email_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    operation character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    grant_jti character varying NOT NULL,
    result_jti character varying,
    email_candidate_ref character varying,
    normalized_email_digest character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    evp_nonce_digest character varying,
    evp_token_digest character varying,
    evp_outcome character varying,
    evp_failure_reason character varying,
    evp_issuer character varying,
    evp_issued_at timestamp(6) with time zone,
    evp_verified_at timestamp(6) with time zone,
    evp_consumed_at timestamp(6) with time zone,
    evp_attempt_count integer DEFAULT 0 NOT NULL
);
ALTER TABLE ONLY public.operator_email_ceremony_transactions
    ADD CONSTRAINT operator_email_ceremony_transactions_pkey PRIMARY KEY (id);
```

Migration provenance: `db/org_tickets_migrate/20260710220002_add_evp_state_to_operator_email_ceremony_transactions.rb`, `db/org_tickets_migrate/20260603121001_create_operator_email_ceremony_transactions.rb`.

### operator_email_statuses

Source: `db/org_zenith_structure.sql:1287`. Machines: .

```sql
CREATE TABLE operator_email_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.operator_email_statuses
    ADD CONSTRAINT operator_email_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/org_principals_migrate/20260520143008_rename_org_principal_tables_to_model_conventions.rb`.

### operator_emails

Source: `db/org_zenith_structure.sql:1315`. Machines: `idp-operator-email-otp`, `idp-operator-email-credential`.

```sql
CREATE TABLE operator_emails (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    address character varying NOT NULL,
    otp_private_key character varying NOT NULL,
    otp_counter text NOT NULL,
    otp_expires_at timestamp(6) with time zone,
    otp_last_sent_at timestamp(6) with time zone,
    otp_attempts_count integer DEFAULT 0 NOT NULL,
    locked_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    staff_identity_email_status_id bigint DEFAULT 0 NOT NULL,
    public_id character varying(21) DEFAULT ''::character varying NOT NULL,
    undeletable boolean DEFAULT false NOT NULL,
    promotional boolean DEFAULT true NOT NULL,
    notifiable boolean DEFAULT true NOT NULL,
    subscribable boolean DEFAULT true NOT NULL,
    address_digest character varying
);
ALTER TABLE ONLY public.operator_emails
    ADD CONSTRAINT operator_emails_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.operator_emails
    ADD CONSTRAINT fk_rails_b0310624d3 FOREIGN KEY (staff_identity_email_status_id) REFERENCES public.operator_email_statuses(id);
ALTER TABLE ONLY public.operator_emails
    ADD CONSTRAINT fk_rails_cceb4b91db FOREIGN KEY (staff_id) REFERENCES public.operators(id);
```

Migration provenance: `db/org_principals_migrate/20260520143008_rename_org_principal_tables_to_model_conventions.rb`.

### operator_entra_identities

Source: `db/org_zenith_structure.sql:1360`. Machines: `idp-operator-entra-identity`.

```sql
CREATE TABLE operator_entra_identities (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    operator_id bigint NOT NULL,
    connection_id bigint,
    entra_tenant_id character varying(36) NOT NULL,
    entra_object_id character varying(36) NOT NULL,
    evidence_issuer character varying(512),
    evidence_subject character varying(512),
    status_id bigint DEFAULT 0 NOT NULL,
    last_authenticated_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);
ALTER TABLE ONLY public.operator_entra_identities
    ADD CONSTRAINT operator_entra_identities_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.operator_entra_identities
    ADD CONSTRAINT fk_rails_168298cb60 FOREIGN KEY (status_id) REFERENCES public.operator_entra_identity_states(id);
```

Migration provenance: `db/org_zenith_migrate/20260630000005_validate_entra_foreign_keys.rb`, `db/org_zenith_migrate/20260630000004_create_operator_entra_identities.rb`, `db/org_zenith_migrate/20260811190000_detach_operator_entra_identities_from_connections.rb`.

### operator_entra_identity_states

Source: `db/org_zenith_structure.sql:1399`. Machines: .

```sql
CREATE TABLE operator_entra_identity_states (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.operator_entra_identity_states
    ADD CONSTRAINT operator_entra_identity_states_pkey PRIMARY KEY (id);
```

Migration provenance: `db/org_zenith_migrate/20260630000002_create_operator_entra_identity_states.rb`, `db/org_zenith_migrate/20260630000005_validate_entra_foreign_keys.rb`, `db/org_zenith_migrate/20260630000004_create_operator_entra_identities.rb`.

### operator_lifecycle_requests

Source: `db/org_zenith_structure.sql:1559`. Machines: `idp-operator-operator-lifecycle`.

```sql
CREATE TABLE operator_lifecycle_requests (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    action character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    target_operator_id bigint,
    target_email character varying,
    organization_id bigint,
    role_id bigint DEFAULT 0 NOT NULL,
    requested_by_operator_id bigint NOT NULL,
    approved_by_operator_id bigint,
    rejected_by_operator_id bigint,
    executed_by_operator_id bigint,
    invitation_id bigint,
    reason text,
    rejection_reason text,
    approved_at timestamp(6) with time zone,
    rejected_at timestamp(6) with time zone,
    executed_at timestamp(6) with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);
ALTER TABLE ONLY public.operator_lifecycle_requests
    ADD CONSTRAINT operator_lifecycle_requests_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.operator_lifecycle_requests
    ADD CONSTRAINT fk_rails_be7647e7b5 FOREIGN KEY (requested_by_operator_id) REFERENCES public.operators(id) ON DELETE RESTRICT NOT VALID;
```

Migration provenance: `db/org_principals_migrate/20260518130000_create_operator_lifecycle_requests.rb`, `db/org_principals_migrate/20260616150003_add_missing_indexes_to_operator_lifecycle_requests.rb`, `db/org_principals_migrate/20260616150005_add_requested_by_operator_fk_to_operator_lifecycle_requests.rb`.

### operator_mfa_levels

Source: `db/org_zenith_structure.sql:1607`. Machines: .

```sql
CREATE TABLE operator_mfa_levels (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.operator_mfa_levels
    ADD CONSTRAINT operator_mfa_levels_pkey PRIMARY KEY (id);
```

Migration provenance: `db/org_principals_migrate/20260530031000_rename_org_principal_model_terms.rb`.

### operator_mfa_statuses

Source: `db/org_zenith_structure.sql:1635`. Machines: .

```sql
CREATE TABLE operator_mfa_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.operator_mfa_statuses
    ADD CONSTRAINT operator_mfa_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/org_principals_migrate/20260530031000_rename_org_principal_model_terms.rb`.

### operator_oauth_callback_states

Source: `db/org_ticket_structure.sql:246`. Machines: `idp-operator-oauth-callback`.

```sql
CREATE TABLE operator_oauth_callback_states (
    id bigint NOT NULL,
    state_digest character varying NOT NULL,
    provider character varying NOT NULL,
    intent character varying,
    issued_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);
ALTER TABLE ONLY public.operator_oauth_callback_states
    ADD CONSTRAINT operator_oauth_callback_states_pkey PRIMARY KEY (id);
```

Migration provenance: `db/org_tickets_migrate/20260530130101_rename_org_ticket_model_terms.rb`.

### operator_oidc_authorization_transactions

Source: `db/org_ticket_structure.sql:282`. Machines: `idp-operator-oidc-authorization`.

```sql
CREATE TABLE operator_oidc_authorization_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    intent character varying NOT NULL,
    client_id character varying NOT NULL,
    redirect_uri character varying NOT NULL,
    response_type character varying NOT NULL,
    scope character varying NOT NULL,
    state character varying NOT NULL,
    nonce character varying NOT NULL,
    code_challenge character varying NOT NULL,
    code_challenge_method character varying NOT NULL,
    login_challenge character varying NOT NULL,
    login_challenge_expires_at timestamp(6) with time zone NOT NULL,
    authenticated_at timestamp(6) with time zone,
    actor_ref character varying,
    session_ref character varying,
    auth_method character varying,
    acr character varying,
    consumed_at timestamp(6) with time zone,
    expires_at timestamp(6) with time zone NOT NULL,
    status character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    oidc_prompt character varying,
    oidc_max_age integer,
    result_generation integer DEFAULT 0 NOT NULL,
    result_digest character varying(64),
    result_expires_at timestamp(6) with time zone,
    result_consumed_at timestamp(6) with time zone,
    browser_session_ref character varying,
    base_finalized_at timestamp(6) with time zone,
    authorization_grant_redeemed_at timestamp(6) with time zone,
    CONSTRAINT operator_oidc_auth_transactions_result_generation_nonnegative CHECK ((result_generation >= 0))
);
ALTER TABLE ONLY public.operator_oidc_authorization_transactions
    ADD CONSTRAINT operator_oidc_authorization_transactions_pkey PRIMARY KEY (id);
```

Migration provenance: `db/org_tickets_migrate/20260922120100_validate_cross_store_oidc_finalization_operator_transactions.rb`, `db/org_tickets_migrate/20260922120000_add_cross_store_oidc_finalization_to_operator_transactions.rb`, `db/org_tickets_migrate/20260611150002_create_operator_oidc_authorization_transactions.rb`, `db/org_tickets_migrate/20260915180000_add_oidc_freshness_options_to_operator_authorization_transactions.rb`.

### operator_passkey_ceremony_transactions

Source: `db/org_ticket_structure.sql:379`. Machines: `idp-operator-passkey-ceremony`.

```sql
CREATE TABLE operator_passkey_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    operation character varying NOT NULL,
    rp_id character varying NOT NULL,
    origin character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    grant_jti character varying NOT NULL,
    result_jti character varying,
    credential_candidate_ref character varying,
    credential_candidate_digest character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    step_up_ceremony_transaction_ref character varying
);
ALTER TABLE ONLY public.operator_passkey_ceremony_transactions
    ADD CONSTRAINT operator_passkey_ceremony_transactions_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.operator_passkey_ceremony_transactions
    ADD CONSTRAINT fk_rails_c78dc3cda8 FOREIGN KEY (step_up_ceremony_transaction_ref) REFERENCES public.operator_step_up_ceremony_transactions(transaction_id) ON DELETE RESTRICT;
```

Migration provenance: `db/org_tickets_migrate/20260603123001_create_operator_passkey_ceremony_transactions.rb`, `db/org_tickets_migrate/20261003215031_bind_operator_credential_ceremonies_to_base_authority.rb`.

### operator_passkey_statuses

Source: `db/org_zenith_structure.sql:1663`. Machines: .

```sql
CREATE TABLE operator_passkey_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.operator_passkey_statuses
    ADD CONSTRAINT operator_passkey_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/org_principals_migrate/20260520143008_rename_org_principal_tables_to_model_conventions.rb`.

### operator_passkeys

Source: `db/org_zenith_structure.sql:1691`. Machines: `idp-operator-passkey-credential`.

```sql
CREATE TABLE operator_passkeys (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    external_id uuid NOT NULL,
    public_key text NOT NULL,
    sign_count bigint DEFAULT 0 NOT NULL,
    description character varying DEFAULT ''::character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    status_id bigint DEFAULT 0 NOT NULL,
    webauthn_id character varying DEFAULT ''::character varying NOT NULL,
    last_used_at timestamp(6) with time zone,
    aaguid uuid,
    transports jsonb,
    backup_eligible boolean,
    backup_state boolean,
    authenticator_attachment character varying,
    provider_name character varying,
    metadata_source character varying,
    uv_verified_at timestamp(6) with time zone
);
ALTER TABLE ONLY public.operator_passkeys
    ADD CONSTRAINT operator_passkeys_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.operator_passkeys
    ADD CONSTRAINT fk_rails_45b43df39a FOREIGN KEY (staff_id) REFERENCES public.operators(id);
ALTER TABLE ONLY public.operator_passkeys
    ADD CONSTRAINT fk_rails_b17ae8dc5f FOREIGN KEY (status_id) REFERENCES public.operator_passkey_statuses(id);
```

Migration provenance: `db/org_principals_migrate/20260719100000_align_operator_passkeys_with_client_passkeys.rb`, `db/org_principals_migrate/20260520143008_rename_org_principal_tables_to_model_conventions.rb`, `db/org_principals_migrate/20260831064103_add_uv_verified_at_to_operator_passkeys.rb`.

### operator_rp_sessions

Source: `db/org_ticket_structure.sql:425`. Machines: `idp-operator-rp-session`.

```sql
CREATE TABLE operator_rp_sessions (
    id bigint NOT NULL,
    operator_token_id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    oidc_client_id character varying(64) NOT NULL,
    oidc_scope text,
    oidc_jti character varying,
    refresh_token_digest character varying,
    previous_refresh_token_digest character varying,
    refresh_token_expires_at timestamp(6) with time zone,
    refresh_token_rotated_at timestamp(6) with time zone,
    dpop_jkt character varying,
    last_used_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    last_logout_status character varying,
    last_logout_attempted_at timestamp(6) with time zone,
    logged_out_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    oidc_auth_time timestamp(6) with time zone,
    oidc_acr character varying,
    oidc_amr text,
    oidc_nonce character varying,
    oidc_access_token_max_expires_at timestamp(6) with time zone
);
ALTER TABLE ONLY public.operator_rp_sessions
    ADD CONSTRAINT operator_rp_sessions_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.operator_rp_sessions
    ADD CONSTRAINT fk_rails_c004babbad FOREIGN KEY (operator_token_id) REFERENCES public.operator_tokens(id) ON DELETE CASCADE;
```

Migration provenance: `db/org_tickets_migrate/20260917130002_add_oidc_access_token_expiry_tracking_to_operator_rp_sessions.rb`, `db/org_tickets_migrate/20260624000000_create_operator_rp_sessions_and_bind_authorization_codes.rb`, `db/org_tickets_migrate/20260915170000_add_oidc_refresh_claims_to_operator_rp_sessions.rb`.

### operator_secret_credential_ceremony_transactions

Source: `db/org_ticket_structure.sql:475`. Machines: `idp-operator-secret-credential-ceremony`.

```sql
CREATE TABLE operator_secret_credential_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    operation character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    grant_jti character varying NOT NULL,
    result_jti character varying,
    credential_candidate_ref character varying,
    credential_candidate_digest character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);
ALTER TABLE ONLY public.operator_secret_credential_ceremony_transactions
    ADD CONSTRAINT operator_secret_credential_ceremony_transactions_pkey PRIMARY KEY (id);
```

Migration provenance: `db/org_tickets_migrate/20260603130001_create_operator_secret_credential_ceremony_transactions.rb`.

### operator_secret_credential_kinds

Source: `db/org_zenith_structure.sql:2446`. Machines: .

```sql
CREATE TABLE operator_secret_credential_kinds (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.operator_secret_credential_kinds
    ADD CONSTRAINT operator_secret_credential_kinds_pkey PRIMARY KEY (id);
```

Migration provenance: `db/org_principals_migrate/20260530031000_rename_org_principal_model_terms.rb`.

### operator_secret_credential_statuses

Source: `db/org_zenith_structure.sql:2474`. Machines: .

```sql
CREATE TABLE operator_secret_credential_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.operator_secret_credential_statuses
    ADD CONSTRAINT operator_secret_credential_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/org_principals_migrate/20260530031000_rename_org_principal_model_terms.rb`.

### operator_secret_credentials

Source: `db/org_zenith_structure.sql:2502`. Machines: `idp-operator-secret-credential`.

```sql
CREATE TABLE operator_secret_credentials (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    password_digest character varying,
    last_used_at timestamp(6) with time zone,
    name character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    staff_identity_secret_status_id bigint DEFAULT 0 NOT NULL,
    staff_secret_kind_id bigint DEFAULT 0 NOT NULL,
    public_id character varying(21) NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    secret_kind character varying,
    usage_policy character varying,
    lookup_digest character varying,
    safe_prefix character varying,
    issued_at timestamp(6) with time zone,
    issued_by_type character varying,
    issued_by_id bigint,
    issued_by_ref character varying,
    delivery_method character varying,
    scope character varying,
    use_count integer DEFAULT 0 NOT NULL,
    failure_count integer DEFAULT 0 NOT NULL,
    max_uses integer,
    max_failures integer,
    not_before_at timestamp(6) with time zone,
    consumed_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    locked_at timestamp(6) with time zone,
    last_failed_at timestamp(6) with time zone,
    CONSTRAINT chk_staff_secrets_retention_order CHECK ((discard_at <= purge_eligible_at))
);
ALTER TABLE ONLY public.operator_secret_credentials
    ADD CONSTRAINT operator_secret_credentials_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.operator_secret_credentials
    ADD CONSTRAINT fk_rails_2386c20852 FOREIGN KEY (staff_id) REFERENCES public.operators(id);
ALTER TABLE ONLY public.operator_secret_credentials
    ADD CONSTRAINT fk_rails_8f8aed461a FOREIGN KEY (staff_identity_secret_status_id) REFERENCES public.operator_secret_credential_statuses(id);
ALTER TABLE ONLY public.operator_secret_credentials
    ADD CONSTRAINT fk_staff_secrets_on_staff_secret_kind_id FOREIGN KEY (staff_secret_kind_id) REFERENCES public.operator_secret_credential_kinds(id);
```

Migration provenance: `db/seeds.rb`, `db/org_principals_migrate/20260530031000_rename_org_principal_model_terms.rb`, `db/org_principals_migrate/20260612100000_add_new_secret_axis_to_operator_secret_credentials.rb`, `db/org_zenith_migrate/20260921133000_rename_org_zenith_retention_columns_to_semantic_names.rb`.

### operator_sign_in_flow_statuses

Source: `db/org_ticket_structure.sql:518`. Machines: .

```sql
CREATE TABLE operator_sign_in_flow_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.operator_sign_in_flow_statuses
    ADD CONSTRAINT operator_sign_in_flow_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/org_tickets_migrate/20260530130101_rename_org_ticket_model_terms.rb`.

### operator_sign_in_flows

Source: `db/org_ticket_structure.sql:546`. Machines: `idp-operator-sign-in`, `idp-operator-local-result-delivery`.

```sql
CREATE TABLE operator_sign_in_flows (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    principal_id bigint,
    token_id bigint,
    state character varying NOT NULL,
    step character varying NOT NULL,
    return_to text,
    nonce_digest character varying NOT NULL,
    issued_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    completed_at timestamp(6) with time zone,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    status_id bigint DEFAULT 10 NOT NULL,
    selected_region_id bigint,
    selected_persona_id bigint,
    selector_completed_at timestamp(6) with time zone,
    session_issued_at timestamp(6) with time zone,
    result_digest character varying(64),
    result_generation integer DEFAULT 0 NOT NULL,
    result_expires_at timestamp(6) with time zone,
    base_finalized_at timestamp(6) with time zone,
    authentication_method character varying,
    authentication_event_at timestamp(6) with time zone,
    authentication_context character varying,
    CONSTRAINT chk_org_sign_in_sequence_tickets_lifetime_order CHECK ((issued_at < expires_at)),
    CONSTRAINT chk_org_sign_in_sequence_tickets_retention_order CHECK ((discard_at <= purge_eligible_at)),
    CONSTRAINT operator_local_authentication_context_valid CHECK (((authentication_context IS NULL) OR ((authentication_context)::text = ANY ((ARRAY['normal'::character varying, 'emergency'::character varying])::text[])))),
    CONSTRAINT operator_sign_in_flows_authentication_evidence_valid CHECK ((((authentication_method IS NULL) AND (authentication_event_at IS NULL)) OR (((authentication_method)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'secret'::character varying, 'passkey'::character varying, 'totp'::character varying, 'google'::character varying, 'apple'::character varying, 'entra'::character varying])::text[])) AND (authentication_event_at IS NOT NULL) AND (principal_id IS NOT NULL)))),
    CONSTRAINT operator_sign_in_flows_base_finalization_valid CHECK (((base_finalized_at IS NULL) OR ((token_id IS NOT NULL) AND (result_digest IS NOT NULL)))),
    CONSTRAINT operator_sign_in_flows_evidence_complete CHECK (((authentication_event_at IS NULL) OR (authentication_method IS NOT NULL))),
    CONSTRAINT operator_sign_in_flows_result_complete CHECK (((result_generation = 0) OR ((result_digest IS NOT NULL) AND (result_expires_at IS NOT NULL) AND (authentication_event_at IS NOT NULL)))),
    CONSTRAINT operator_sign_in_flows_result_delivery_valid CHECK ((((result_digest IS NULL) AND (result_expires_at IS NULL) AND (result_generation = 0)) OR ((length((result_digest)::text) = 64) AND (result_expires_at IS NOT NULL) AND (result_generation > 0) AND (authentication_event_at IS NOT NULL)))),
    CONSTRAINT operator_sign_in_flows_result_generation_valid CHECK ((result_generation >= 0))
);
ALTER TABLE ONLY public.operator_sign_in_flows
    ADD CONSTRAINT operator_sign_in_flows_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.operator_sign_in_flows
    ADD CONSTRAINT fk_rails_0451f7d1d6 FOREIGN KEY (token_id) REFERENCES public.operator_tokens(id) ON DELETE CASCADE NOT VALID;
ALTER TABLE ONLY public.operator_sign_in_flows
    ADD CONSTRAINT fk_rails_6ed9308623 FOREIGN KEY (status_id) REFERENCES public.operator_sign_in_flow_statuses(id) NOT VALID;
```

Migration provenance: `db/org_tickets_migrate/20260520143010_rename_org_ticket_tables_to_model_conventions.rb`, `db/org_tickets_migrate/20260530130101_rename_org_ticket_model_terms.rb`, `db/org_tickets_migrate/20261003181725_preserve_operator_local_authentication_context.rb`, `db/org_tickets_migrate/20260525233000_add_selector_activation_to_operator_sign_in_cycles.rb`, `db/org_tickets_migrate/20260528162101_harden_operator_sign_in_cycle_state_constraints.rb`, `db/org_tickets_migrate/20261002120000_add_root_login_established_at_to_operator_tokens.rb`, `db/org_tickets_migrate/20260921133000_rename_org_ticket_retention_columns_to_semantic_names.rb`, `db/org_tickets_migrate/20261003175658_bind_operator_local_authentication_results.rb`.

### operator_sign_out_flow_kinds

Source: `db/org_ticket_structure.sql:609`. Machines: .

```sql
CREATE TABLE operator_sign_out_flow_kinds (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.operator_sign_out_flow_kinds
    ADD CONSTRAINT operator_sign_out_flow_kinds_pkey PRIMARY KEY (id);
```

Migration provenance: `db/org_tickets_migrate/20260530130101_rename_org_ticket_model_terms.rb`.

### operator_sign_out_flow_statuses

Source: `db/org_ticket_structure.sql:637`. Machines: .

```sql
CREATE TABLE operator_sign_out_flow_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.operator_sign_out_flow_statuses
    ADD CONSTRAINT operator_sign_out_flow_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/org_tickets_migrate/20260530130101_rename_org_ticket_model_terms.rb`.

### operator_sign_out_flows

Source: `db/org_ticket_structure.sql:665`. Machines: `idp-operator-sign-out`.

```sql
CREATE TABLE operator_sign_out_flows (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    principal_id bigint,
    token_id bigint,
    status_id bigint DEFAULT 10 NOT NULL,
    kind_id bigint DEFAULT 0 NOT NULL,
    refresh_token_family_id character varying,
    requested_at timestamp(6) with time zone NOT NULL,
    access_discarded_at timestamp(6) with time zone,
    logically_revoked_at timestamp(6) with time zone,
    access_expires_at timestamp(6) with time zone NOT NULL,
    refresh_expires_at timestamp(6) with time zone NOT NULL,
    completed_at timestamp(6) with time zone,
    failed_at timestamp(6) with time zone,
    return_to text,
    nonce_digest character varying,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_operator_sign_out_cycles_retention_order CHECK ((discard_at <= purge_eligible_at)),
    CONSTRAINT chk_operator_sign_out_cycles_token_expiry_order CHECK ((access_expires_at <= refresh_expires_at))
);
ALTER TABLE ONLY public.operator_sign_out_flows
    ADD CONSTRAINT operator_sign_out_flows_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.operator_sign_out_flows
    ADD CONSTRAINT fk_rails_0467d6b6d1 FOREIGN KEY (kind_id) REFERENCES public.operator_sign_out_flow_kinds(id) NOT VALID;
ALTER TABLE ONLY public.operator_sign_out_flows
    ADD CONSTRAINT fk_rails_85024a94ea FOREIGN KEY (status_id) REFERENCES public.operator_sign_out_flow_statuses(id) NOT VALID;
ALTER TABLE ONLY public.operator_sign_out_flows
    ADD CONSTRAINT fk_rails_caa3cf1c6d FOREIGN KEY (token_id) REFERENCES public.operator_tokens(id) ON DELETE CASCADE NOT VALID;
```

Migration provenance: `db/org_tickets_migrate/20260530130101_rename_org_ticket_model_terms.rb`, `db/org_tickets_migrate/20260519092002_create_operator_sign_out_cycles.rb`, `db/org_tickets_migrate/20260921133000_rename_org_ticket_retention_columns_to_semantic_names.rb`.

### operator_sign_up_flow_statuses

Source: `db/org_ticket_structure.sql:714`. Machines: .

```sql
CREATE TABLE operator_sign_up_flow_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.operator_sign_up_flow_statuses
    ADD CONSTRAINT operator_sign_up_flow_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/org_tickets_migrate/20260530130101_rename_org_ticket_model_terms.rb`.

### operator_sign_up_flows

Source: `db/org_ticket_structure.sql:742`. Machines: `idp-operator-sign-up`.

```sql
CREATE TABLE operator_sign_up_flows (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    principal_id bigint,
    token_id bigint,
    state character varying NOT NULL,
    step character varying NOT NULL,
    return_to text,
    nonce_digest character varying NOT NULL,
    issued_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    completed_at timestamp(6) with time zone,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    status_id bigint DEFAULT 10 NOT NULL,
    result_digest character varying(64),
    result_generation integer DEFAULT 0 NOT NULL,
    result_expires_at timestamp(6) with time zone,
    base_finalized_at timestamp(6) with time zone,
    authentication_method character varying,
    authentication_event_at timestamp(6) with time zone,
    CONSTRAINT chk_org_sign_up_sequence_tickets_lifetime_order CHECK ((issued_at < expires_at)),
    CONSTRAINT chk_org_sign_up_sequence_tickets_retention_order CHECK ((discard_at <= purge_eligible_at)),
    CONSTRAINT operator_sign_up_flows_authentication_evidence_valid CHECK ((((authentication_method IS NULL) AND (authentication_event_at IS NULL)) OR (((authentication_method)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'secret'::character varying, 'passkey'::character varying, 'totp'::character varying, 'google'::character varying, 'apple'::character varying, 'entra'::character varying])::text[])) AND (authentication_event_at IS NOT NULL) AND (principal_id IS NOT NULL)))),
    CONSTRAINT operator_sign_up_flows_base_finalization_valid CHECK (((base_finalized_at IS NULL) OR ((token_id IS NOT NULL) AND (result_digest IS NOT NULL)))),
    CONSTRAINT operator_sign_up_flows_evidence_complete CHECK (((authentication_event_at IS NULL) OR (authentication_method IS NOT NULL))),
    CONSTRAINT operator_sign_up_flows_result_complete CHECK (((result_generation = 0) OR ((result_digest IS NOT NULL) AND (result_expires_at IS NOT NULL) AND (authentication_event_at IS NOT NULL)))),
    CONSTRAINT operator_sign_up_flows_result_delivery_valid CHECK ((((result_digest IS NULL) AND (result_expires_at IS NULL) AND (result_generation = 0)) OR ((length((result_digest)::text) = 64) AND (result_expires_at IS NOT NULL) AND (result_generation > 0) AND (authentication_event_at IS NOT NULL)))),
    CONSTRAINT operator_sign_up_flows_result_generation_valid CHECK ((result_generation >= 0))
);
ALTER TABLE ONLY public.operator_sign_up_flows
    ADD CONSTRAINT operator_sign_up_flows_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.operator_sign_up_flows
    ADD CONSTRAINT fk_rails_10f95a7068 FOREIGN KEY (token_id) REFERENCES public.operator_tokens(id) ON DELETE CASCADE NOT VALID;
ALTER TABLE ONLY public.operator_sign_up_flows
    ADD CONSTRAINT fk_rails_fb3acc316b FOREIGN KEY (status_id) REFERENCES public.operator_sign_up_flow_statuses(id) NOT VALID;
```

Migration provenance: `db/org_tickets_migrate/20260520143010_rename_org_ticket_tables_to_model_conventions.rb`, `db/org_tickets_migrate/20260530130101_rename_org_ticket_model_terms.rb`, `db/org_tickets_migrate/20261003181725_preserve_operator_local_authentication_context.rb`, `db/org_tickets_migrate/20260921133000_rename_org_ticket_retention_columns_to_semantic_names.rb`, `db/org_tickets_migrate/20261003175658_bind_operator_local_authentication_results.rb`.

### operator_statuses

Source: `db/org_zenith_structure.sql:2561`. Machines: .

```sql
CREATE TABLE operator_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.operator_statuses
    ADD CONSTRAINT operator_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/org_principals_migrate/20260108100600_rename_operator_tables.rb`, `db/org_principals_migrate/20260212000003_ensure_seed_reference_data_in_operators.rb`, `db/org_principals_migrate/20260109141212_add_id_format_constraints_to_operator_tables.rb`, `db/org_principals_migrate/20260202260000_replace_code_with_fixed_ids.rb`, `db/org_principals_migrate/20260530031000_rename_org_principal_model_terms.rb`, `db/org_principals_migrate/20260202210000_add_lower_code_unique_indexes_operator.rb`, `db/org_principals_migrate/20260202170000_fix_consistency_operators.rb`, `db/org_principals_migrate/20260201214320_convert_all_operator_pks_to_bigint.rb`, `db/org_principals_migrate/20260201190010_convert_operator_pks.rb`.

### operator_step_up_ceremony_transactions

Source: `db/org_ticket_structure.sql:799`. Machines: `idp-operator-step-up-ceremony`.

```sql
CREATE TABLE operator_step_up_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    required_scope character varying NOT NULL,
    required_aal character varying NOT NULL,
    allowed_methods text NOT NULL,
    resource_ref character varying,
    return_to character varying,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    grant_jti character varying NOT NULL,
    result_jti character varying,
    method character varying,
    aal character varying,
    verified_at timestamp(6) with time zone,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    phishing_resistant_required boolean DEFAULT false NOT NULL,
    phishing_resistant boolean DEFAULT false NOT NULL,
    purpose character varying DEFAULT 'step_up'::character varying NOT NULL,
    result_digest character varying(64),
    result_generation integer DEFAULT 0 NOT NULL,
    result_expires_at timestamp(6) with time zone,
    canceled_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    verified_credential_ref character varying,
    CONSTRAINT operator_step_up_purpose_valid CHECK (((purpose)::text = ANY ((ARRAY['step_up'::character varying, 'reauthentication'::character varying, 'bootstrap'::character varying, 'credential_registration'::character varying, 'credential_change'::character varying])::text[]))),
    CONSTRAINT operator_step_up_result_valid CHECK (((result_generation >= 0) AND (((result_digest IS NULL) AND (result_expires_at IS NULL) AND (result_generation = 0)) OR ((result_digest IS NOT NULL) AND ((result_digest)::text ~ '^[0-9a-f]{64}$'::text) AND (result_expires_at IS NOT NULL) AND (result_generation > 0) AND (verified_at IS NOT NULL))))),
    CONSTRAINT operator_step_up_status_valid CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'verified'::character varying, 'consumed'::character varying, 'canceled'::character varying, 'expired'::character varying, 'revoked'::character varying])::text[]))),
    CONSTRAINT operator_step_up_terminal_valid CHECK ((((canceled_at IS NULL) OR ((status)::text = 'canceled'::text)) AND ((revoked_at IS NULL) OR ((status)::text = 'revoked'::text)) AND (((status)::text <> 'revoked'::text) OR (revoked_at IS NOT NULL)) AND (((status)::text <> 'verified'::text) OR ((verified_at IS NOT NULL) AND (method IS NOT NULL) AND (aal IS NOT NULL))))),
    CONSTRAINT operator_step_up_verified_credential_present CHECK ((((status)::text <> 'verified'::text) OR (((purpose)::text = ANY ((ARRAY['bootstrap'::character varying, 'credential_registration'::character varying])::text[])) AND (verified_credential_ref IS NULL) AND ((aal)::text = 'none'::text) AND ((required_aal)::text = 'none'::text) AND (phishing_resistant IS FALSE) AND (phishing_resistant_required IS FALSE) AND ((method)::text = ANY ((ARRAY['passkey'::character varying, 'totp'::character varying])::text[]))) OR (((purpose)::text <> ALL ((ARRAY['bootstrap'::character varying, 'credential_registration'::character varying])::text[])) AND (verified_credential_ref IS NOT NULL) AND (length((verified_credential_ref)::text) > 0))))
);
ALTER TABLE ONLY public.operator_step_up_ceremony_transactions
    ADD CONSTRAINT operator_step_up_ceremony_transactions_pkey PRIMARY KEY (id);
```

Migration provenance: `db/org_tickets_migrate/20260831064102_add_phishing_resistance_to_operator_step_up_ceremony_transactions.rb`, `db/org_tickets_migrate/20261003221725_separate_operator_registration_evidence_from_step_up_credential.rb`, `db/org_tickets_migrate/20260603122001_create_operator_step_up_ceremony_transactions.rb`, `db/org_tickets_migrate/20261003185508_bind_operator_verified_step_up_credential.rb`, `db/org_tickets_migrate/20261003183915_bind_operator_opaque_step_up_ceremonies.rb`, `db/org_tickets_migrate/20261003215031_bind_operator_credential_ceremonies_to_base_authority.rb`.

### operator_step_up_sessions

Source: `db/org_ticket_structure.sql:861`. Machines: `idp-operator-step-up-session`, `idp-operator-step-up-passkey-challenge`.

```sql
CREATE TABLE operator_step_up_sessions (
    id bigint NOT NULL,
    attempt_count integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    method character varying,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    return_to text NOT NULL,
    scope character varying NOT NULL,
    staff_token_id bigint NOT NULL,
    status character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    verified_at timestamp(6) with time zone,
    step_up_ceremony_transaction_ref character varying,
    passkey_challenge text,
    passkey_challenge_ref character varying,
    passkey_rp_id character varying,
    passkey_origin character varying,
    passkey_challenge_expires_at timestamp(6) with time zone,
    passkey_challenge_consumed_at timestamp(6) with time zone,
    CONSTRAINT operator_step_up_challenge_bound CHECK (((passkey_challenge IS NULL) OR ((step_up_ceremony_transaction_ref IS NOT NULL) AND (passkey_challenge_ref IS NOT NULL) AND (passkey_rp_id IS NOT NULL) AND (passkey_origin IS NOT NULL) AND (passkey_challenge_expires_at IS NOT NULL) AND (passkey_challenge_expires_at <= discard_at))))
);
ALTER TABLE ONLY public.operator_step_up_sessions
    ADD CONSTRAINT operator_step_up_sessions_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.operator_step_up_sessions
    ADD CONSTRAINT fk_rails_100937c5e6 FOREIGN KEY (step_up_ceremony_transaction_ref) REFERENCES public.operator_step_up_ceremony_transactions(transaction_id) ON DELETE RESTRICT;
ALTER TABLE ONLY public.operator_step_up_sessions
    ADD CONSTRAINT fk_rails_6daa6fb880 FOREIGN KEY (staff_token_id) REFERENCES public.operator_tokens(id) ON DELETE CASCADE NOT VALID;
```

Migration provenance: `db/org_tickets_migrate/20260520143010_rename_org_ticket_tables_to_model_conventions.rb`, `db/org_tickets_migrate/20260921133000_rename_org_ticket_retention_columns_to_semantic_names.rb`, `db/org_tickets_migrate/20261003183915_bind_operator_opaque_step_up_ceremonies.rb`.

### operator_telephone_ceremony_transactions

Source: `db/org_ticket_structure.sql:908`. Machines: `idp-operator-telephone-ceremony`.

```sql
CREATE TABLE operator_telephone_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    operation character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    grant_jti character varying NOT NULL,
    result_jti character varying,
    telephone_candidate_ref character varying,
    normalized_number_digest character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);
ALTER TABLE ONLY public.operator_telephone_ceremony_transactions
    ADD CONSTRAINT operator_telephone_ceremony_transactions_pkey PRIMARY KEY (id);
```

Migration provenance: `db/org_tickets_migrate/20260603120001_create_operator_telephone_ceremony_transactions.rb`.

### operator_telephone_statuses

Source: `db/org_zenith_structure.sql:2589`. Machines: .

```sql
CREATE TABLE operator_telephone_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.operator_telephone_statuses
    ADD CONSTRAINT operator_telephone_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/org_principals_migrate/20260520143008_rename_org_principal_tables_to_model_conventions.rb`.

### operator_telephones

Source: `db/org_zenith_structure.sql:2617`. Machines: `idp-operator-telephone-otp`, `idp-operator-telephone-credential`.

```sql
CREATE TABLE operator_telephones (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    number character varying NOT NULL,
    otp_private_key character varying NOT NULL,
    otp_counter text NOT NULL,
    otp_expires_at timestamp(6) with time zone,
    otp_attempts_count integer DEFAULT 0 NOT NULL,
    locked_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    staff_identity_telephone_status_id bigint DEFAULT 0 NOT NULL,
    number_digest character varying
);
ALTER TABLE ONLY public.operator_telephones
    ADD CONSTRAINT operator_telephones_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.operator_telephones
    ADD CONSTRAINT fk_rails_52c0d3ae3b FOREIGN KEY (staff_identity_telephone_status_id) REFERENCES public.operator_telephone_statuses(id);
ALTER TABLE ONLY public.operator_telephones
    ADD CONSTRAINT fk_rails_e5ae4ba106 FOREIGN KEY (staff_id) REFERENCES public.operators(id);
```

Migration provenance: `db/org_principals_migrate/20260520143008_rename_org_principal_tables_to_model_conventions.rb`.

### operator_token_binding_methods

Source: `db/org_ticket_structure.sql:951`. Machines: .

```sql
CREATE TABLE operator_token_binding_methods (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.operator_token_binding_methods
    ADD CONSTRAINT operator_token_binding_methods_pkey PRIMARY KEY (id);
```

Migration provenance: `db/org_tickets_migrate/20260520143010_rename_org_ticket_tables_to_model_conventions.rb`.

### operator_token_dbsc_statuses

Source: `db/org_ticket_structure.sql:979`. Machines: .

```sql
CREATE TABLE operator_token_dbsc_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.operator_token_dbsc_statuses
    ADD CONSTRAINT operator_token_dbsc_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/org_tickets_migrate/20260520143010_rename_org_ticket_tables_to_model_conventions.rb`.

### operator_token_kinds

Source: `db/org_ticket_structure.sql:1007`. Machines: .

```sql
CREATE TABLE operator_token_kinds (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.operator_token_kinds
    ADD CONSTRAINT operator_token_kinds_pkey PRIMARY KEY (id);
```

Migration provenance: `db/org_tickets_migrate/20260520143010_rename_org_ticket_tables_to_model_conventions.rb`, `db/org_tickets_migrate/20260616150010_add_on_delete_actions_to_operator_ticket_foreign_keys.rb`.

### operator_token_statuses

Source: `db/org_ticket_structure.sql:1035`. Machines: .

```sql
CREATE TABLE operator_token_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.operator_token_statuses
    ADD CONSTRAINT operator_token_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/org_tickets_migrate/20260520143010_rename_org_ticket_tables_to_model_conventions.rb`, `db/org_tickets_migrate/20260616150010_add_on_delete_actions_to_operator_ticket_foreign_keys.rb`.

### operator_tokens

Source: `db/org_ticket_structure.sql:1063`. Machines: `idp-operator-token`, `idp-operator-dbsc`.

```sql
CREATE TABLE operator_tokens (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    dbsc_challenge text,
    dbsc_challenge_issued_at timestamp(6) with time zone,
    dbsc_public_key jsonb,
    dbsc_session_id character varying,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    last_step_up_at timestamp(6) with time zone,
    last_step_up_scope character varying,
    last_used_at timestamp(6) with time zone,
    public_id character varying(21) DEFAULT ''::character varying NOT NULL,
    refresh_token_digest bytea,
    refresh_token_family_id character varying,
    refresh_token_generation integer DEFAULT 0 NOT NULL,
    rotated_at timestamp(6) with time zone,
    staff_id bigint NOT NULL,
    staff_token_binding_method_id bigint DEFAULT 0 NOT NULL,
    staff_token_dbsc_status_id bigint DEFAULT 0 NOT NULL,
    staff_token_kind_id bigint DEFAULT 0 NOT NULL,
    staff_token_status_id bigint DEFAULT 1 NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    dpop_jkt character varying,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    oidc_connection_id bigint,
    oidc_client_id character varying(64),
    oidc_scope character varying,
    oidc_sid uuid DEFAULT gen_random_uuid(),
    oidc_jti uuid DEFAULT gen_random_uuid(),
    device_session_id bigint,
    last_step_up_aal character varying,
    last_step_up_method character varying,
    last_step_up_purpose character varying,
    last_step_up_audience character varying,
    last_step_up_session_public_id character varying,
    selected_account_public_id character varying,
    selected_collective_public_id character varying,
    selected_collective_unit_public_id character varying,
    selected_at timestamp(6) with time zone,
    established_authentication_method character varying,
    last_step_up_phishing_resistant boolean DEFAULT false NOT NULL,
    authentication_context character varying,
    authentication_event_at timestamp(6) with time zone,
    selected_avatar_public_id character varying,
    root_login_established_at timestamp with time zone,
    CONSTRAINT chk_operator_tokens_authentication_context CHECK (((authentication_context IS NULL) OR ((authentication_context)::text = ANY ((ARRAY['normal'::character varying, 'emergency'::character varying])::text[])))),
    CONSTRAINT chk_operator_tokens_established_authentication_method CHECK (((established_authentication_method IS NULL) OR ((established_authentication_method)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'secret'::character varying, 'passkey'::character varying, 'entra'::character varying])::text[])))),
    CONSTRAINT chk_staff_tokens_kind_id_positive CHECK ((staff_token_kind_id >= 0)),
    CONSTRAINT chk_staff_tokens_status_id_positive CHECK ((staff_token_status_id >= 0))
);
ALTER TABLE ONLY public.operator_tokens
    ADD CONSTRAINT operator_tokens_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.operator_tokens
    ADD CONSTRAINT fk_operator_tokens_on_device_session_id FOREIGN KEY (device_session_id) REFERENCES public.operator_device_sessions(id) ON DELETE RESTRICT;
ALTER TABLE ONLY public.operator_tokens
    ADD CONSTRAINT fk_operator_tokens_on_staff_id_and_device_session_id FOREIGN KEY (staff_id, device_session_id) REFERENCES public.operator_device_sessions(staff_id, id) ON DELETE RESTRICT;
ALTER TABLE ONLY public.operator_tokens
    ADD CONSTRAINT fk_rails_1a807f181b FOREIGN KEY (staff_token_status_id) REFERENCES public.operator_token_statuses(id) ON DELETE RESTRICT NOT VALID;
ALTER TABLE ONLY public.operator_tokens
    ADD CONSTRAINT fk_rails_f211b6bc2e FOREIGN KEY (staff_token_kind_id) REFERENCES public.operator_token_kinds(id) ON DELETE RESTRICT NOT VALID;
ALTER TABLE ONLY public.operator_tokens
    ADD CONSTRAINT fk_staff_tokens_on_staff_token_binding_method_id FOREIGN KEY (staff_token_binding_method_id) REFERENCES public.operator_token_binding_methods(id) NOT VALID;
ALTER TABLE ONLY public.operator_tokens
    ADD CONSTRAINT fk_staff_tokens_on_staff_token_dbsc_status_id FOREIGN KEY (staff_token_dbsc_status_id) REFERENCES public.operator_token_dbsc_statuses(id) NOT VALID;
```

Migration provenance: `db/org_tickets_migrate/20260520143010_rename_org_ticket_tables_to_model_conventions.rb`, `db/org_tickets_migrate/20260924156000_validate_operator_token_device_session_actor_foreign_key.rb`, `db/org_tickets_migrate/20260909100001_validate_authentication_context_on_operator_tokens.rb`, `db/org_tickets_migrate/20260520190001_create_device_sessions_for_staff_tokens.rb`, `db/org_tickets_migrate/20260831064140_add_last_step_up_phishing_resistant_to_operator_tokens.rb`, `db/org_tickets_migrate/20260924177000_add_selected_avatar_public_id_to_operator_tokens.rb`, `db/org_tickets_migrate/20260924155000_add_operator_token_device_session_actor_foreign_key.rb`, `db/org_tickets_migrate/20260606120002_add_selected_context_to_operator_tokens.rb`, `db/org_tickets_migrate/20260924152000_validate_operator_token_device_session_reference.rb`, `db/org_tickets_migrate/20260924150000_add_operator_token_device_session_reference_index.rb`, `db/org_tickets_migrate/20261002120000_add_root_login_established_at_to_operator_tokens.rb`, `db/org_tickets_migrate/20260909100000_add_authentication_context_to_operator_tokens.rb`, `db/org_tickets_migrate/20260921133000_rename_org_ticket_retention_columns_to_semantic_names.rb`, `db/org_tickets_migrate/20260528183001_add_strict_step_up_state_to_operator_tokens.rb`, `db/org_tickets_migrate/20260727100000_add_established_authentication_method_to_operator_tokens.rb`, `db/org_tickets_migrate/20260915160000_add_authentication_event_at_to_operator_tokens.rb`, `db/org_tickets_migrate/20260616150010_add_on_delete_actions_to_operator_ticket_foreign_keys.rb`, `db/org_tickets_migrate/20260924151000_add_operator_device_session_token_foreign_keys.rb`, `db/org_tickets_migrate/20260526120101_remove_device_id_from_org_tickets.rb`, `db/org_tickets_migrate/20260727100001_validate_established_authentication_method_on_operator_tokens.rb`.

### operator_visibilities

Source: `db/org_zenith_structure.sql:2656`. Machines: .

```sql
CREATE TABLE operator_visibilities (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.operator_visibilities
    ADD CONSTRAINT operator_visibilities_pkey PRIMARY KEY (id);
```

Migration provenance: `db/org_principals_migrate/20260520143008_rename_org_principal_tables_to_model_conventions.rb`.

### operators

Source: `db/org_zenith_structure.sql:2780`. Machines: `idp-operator-administrative-access`, `idp-operator-actor-withdrawal`, `idp-operator-mfa-readiness`.

```sql
CREATE TABLE operators (
    id bigint NOT NULL,
    webauthn_id character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    public_id character varying(16) NOT NULL,
    withdrawn_at timestamp(6) with time zone,
    status_id bigint DEFAULT 0 NOT NULL,
    mfa_level_enabled boolean DEFAULT false NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    visibility_id bigint DEFAULT 2 NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    mfa_level_id bigint DEFAULT 0 NOT NULL,
    mfa_status_id bigint DEFAULT 5 NOT NULL,
    withdrawal_started_at timestamp(6) with time zone,
    deactivated_at timestamp(6) with time zone,
    birthdate text,
    access_state character varying DEFAULT 'enabled'::character varying NOT NULL,
    admin_locked_at timestamp(6) with time zone,
    admin_locked_by_operator_id bigint,
    admin_locked_reason_code character varying,
    admin_locked_reason_note text,
    token_valid_after_at timestamp(6) with time zone,
    reactivated_at timestamp(6) with time zone,
    webauthn_user_handle character varying NOT NULL,
    CONSTRAINT chk_operators_access_state CHECK (((access_state)::text = ANY ((ARRAY['enabled'::character varying, 'admin_locked'::character varying])::text[]))),
    CONSTRAINT chk_operators_admin_locked_reason_code CHECK (((admin_locked_reason_code IS NULL) OR ((admin_locked_reason_code)::text = ANY ((ARRAY['abuse'::character varying, 'security_incident'::character varying, 'chargeback'::character varying, 'terms_violation'::character varying, 'support_request'::character varying, 'legal_hold'::character varying, 'operator_error_recovery'::character varying, 'other'::character varying])::text[])))),
    CONSTRAINT chk_operators_birthdate_length CHECK (((birthdate IS NULL) OR (char_length(birthdate) <= 1000))),
    CONSTRAINT chk_staffs_public_id_format CHECK (((public_id)::text ~ '^[0-9A-FGHJKMNPQRSTVWXYZ]{16}$'::text)),
    CONSTRAINT chk_staffs_public_id_length CHECK ((char_length((public_id)::text) = 16)),
    CONSTRAINT chk_staffs_retention_order CHECK ((discard_at <= purge_eligible_at))
);
ALTER TABLE ONLY public.operators
    ADD CONSTRAINT operators_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.operators
    ADD CONSTRAINT fk_rails_5525188c4e FOREIGN KEY (status_id) REFERENCES public.operator_statuses(id);
ALTER TABLE ONLY public.operators
    ADD CONSTRAINT fk_rails_64606abff9 FOREIGN KEY (visibility_id) REFERENCES public.operator_visibilities(id);
ALTER TABLE ONLY public.operators
    ADD CONSTRAINT fk_rails_894ffe7965 FOREIGN KEY (mfa_level_id) REFERENCES public.operator_mfa_levels(id);
ALTER TABLE ONLY public.operators
    ADD CONSTRAINT fk_rails_cfd2f37948 FOREIGN KEY (mfa_status_id) REFERENCES public.operator_mfa_statuses(id);
```

Migration provenance: `db/org_principals_migrate/20260102034859_validate_not_null_admin_staff_id.rb`, `db/org_principals_migrate/20260114120236_add_lock_version_to_admins_and_staffs.rb`, `db/org_principals_migrate/20251230145339_add_status_id_to_admins.rb`, `db/org_principals_migrate/20260530032100_rename_operator_mfa_columns.rb`, `db/org_principals_migrate/20260508160000_drop_legacy_retention_columns_from_operators.rb`, `db/org_principals_migrate/20260614090001_validate_administrative_access_lock_on_operators.rb`, `db/org_principals_migrate/20251230150000_create_staff_admins.rb`, `db/org_principals_migrate/20260514153000_add_withdrawal_state_to_operators.rb`, `db/org_principals_migrate/20260103050110_add_department_to_admins.rb`, `db/org_principals_migrate/20260103133001_validate_fix_database_consistency_identity_relations.rb`, `db/org_principals_migrate/20260202200000_fix_operator_fks_and_pks.rb`, `db/org_principals_migrate/20260614090000_add_administrative_access_lock_to_operators.rb`, `db/org_principals_migrate/20260102034808_remove_redundant_identity_indexes.rb`, `db/org_principals_migrate/20260507000003_add_shreddable_at_to_operators.rb`, `db/org_principals_migrate/20251230170004_move_admin_reference_to_admins.rb`, `db/org_principals_migrate/20260518180000_add_discarded_at_index_to_operators.rb`, `db/org_principals_migrate/20260305000000_rename_admin_to_operator.rb`, `db/org_principals_migrate/20260518181000_validate_remaining_org_principal_foreign_keys.rb`, `db/org_principals_migrate/20260103122221_add_foreign_keys_to_workspace_organization_division.rb`, `db/org_principals_migrate/20260518170000_add_birthdate_to_operators.rb`, `db/org_principals_migrate/20260103133000_fix_database_consistency_identity_relations.rb`, `db/org_principals_migrate/20260518170001_validate_operators_birthdate_length.rb`, `db/org_principals_migrate/20260514113000_align_operator_model_table_names.rb`, `db/org_principals_migrate/20251230140828_create_admins.rb`, `db/org_principals_migrate/20260719100001_add_webauthn_user_handle_to_operators.rb`, `db/org_principals_migrate/20260102035351_fix_database_consistency_identity.rb`, `db/org_principals_migrate/20260514143000_default_operator_multi_factor_status_to_unconfigured.rb`, `db/org_principals_migrate/20260616150005_add_requested_by_operator_fk_to_operator_lifecycle_requests.rb`, `db/org_principals_migrate/20260202170000_fix_consistency_operators.rb`, `db/org_principals_migrate/20260530032400_rename_operator_mfa_enabled_column.rb`, `db/org_principals_migrate/20260103050111_validate_department_foreign_key_on_admins.rb`, `db/org_principals_migrate/20251230150020_validate_staff_admin_foreign_keys.rb`, `db/org_principals_migrate/20260514140000_add_multi_factor_status_reference_to_staffs.rb`, `db/org_principals_migrate/20260521120000_create_operator_social_googles.rb`, `db/org_principals_migrate/20260528162001_harden_operator_lifecycle_and_mfa_constraints.rb`, `db/org_principals_migrate/20260102025200_validate_admin_staff_foreign_key.rb`, `db/org_principals_migrate/20260102034858_add_not_null_to_admin_staff_id.rb`, `db/org_principals_migrate/20260201190010_convert_operator_pks.rb`, `db/org_zenith_migrate/20260926120000_create_operator_capability_grants.rb`, `db/org_zenith_migrate/20260921133000_rename_org_zenith_retention_columns_to_semantic_names.rb`, `db/org_zenith_migrate/20260917120002_create_org_authority_relations.rb`, `db/app_principals_migrate/20260518180001_backfill_and_default_users_purged_at.rb`.

### org_enforcement_appeals

Source: `db/org_zenith_structure.sql:2838`. Machines: `idp-operator-enforcement-appeal`.

```sql
CREATE TABLE org_enforcement_appeals (
    id bigint NOT NULL,
    org_enforcement_case_id bigint NOT NULL,
    public_id character varying NOT NULL,
    state character varying DEFAULT 'submitted'::character varying NOT NULL,
    reason_code character varying NOT NULL,
    statement text,
    submitted_at timestamp(6) with time zone NOT NULL,
    reviewed_at timestamp(6) with time zone,
    reviewer_operator_public_id character varying,
    resolution_code character varying,
    redacted_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_org_enforcement_appeals_state CHECK (((state)::text = ANY ((ARRAY['submitted'::character varying, 'under_review'::character varying, 'approved'::character varying, 'rejected'::character varying, 'redacted'::character varying])::text[])))
);
ALTER TABLE ONLY public.org_enforcement_appeals
    ADD CONSTRAINT org_enforcement_appeals_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.org_enforcement_appeals
    ADD CONSTRAINT fk_rails_6a88e9a573 FOREIGN KEY (org_enforcement_case_id) REFERENCES public.org_enforcement_cases(id);
```

Migration provenance: `db/org_zenith_migrate/20260729120000_create_org_enforcement_appeals.rb`.

### org_enforcement_authentication_method_effects

Source: `db/org_zenith_structure.sql:2879`. Machines: .

```sql
CREATE TABLE org_enforcement_authentication_method_effects (
    id bigint NOT NULL,
    org_enforcement_case_id bigint NOT NULL,
    principal_public_id character varying NOT NULL,
    authentication_method character varying NOT NULL,
    effect character varying NOT NULL,
    effective_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone,
    ended_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_org_enforcement_method_effects_effect CHECK (((effect)::text = ANY ((ARRAY['mutation_locked'::character varying, 'unusable'::character varying, 'permanently_frozen'::character varying])::text[]))),
    CONSTRAINT chk_org_enforcement_method_effects_method CHECK (((authentication_method)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'secret'::character varying, 'passkey'::character varying, 'entra'::character varying])::text[])))
);
ALTER TABLE ONLY public.org_enforcement_authentication_method_effects
    ADD CONSTRAINT org_enforcement_authentication_method_effects_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.org_enforcement_authentication_method_effects
    ADD CONSTRAINT fk_rails_46912ae025 FOREIGN KEY (org_enforcement_case_id) REFERENCES public.org_enforcement_cases(id);
```

Migration provenance: `db/org_zenith_migrate/20260727120002_create_org_enforcement_authentication_method_effects.rb`.

### org_enforcement_cases

Source: `db/org_zenith_structure.sql:2918`. Machines: `idp-operator-enforcement-case`.

```sql
CREATE TABLE org_enforcement_cases (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    kind character varying NOT NULL,
    state character varying DEFAULT 'draft'::character varying NOT NULL,
    duration_mode character varying NOT NULL,
    visibility character varying DEFAULT 'visible'::character varying NOT NULL,
    release_mode character varying NOT NULL,
    effective_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone,
    ended_at timestamp(6) with time zone,
    end_reason character varying,
    review_due_at timestamp(6) with time zone,
    reason_code character varying NOT NULL,
    reason_note text,
    ticket_id character varying,
    principal_public_id character varying NOT NULL,
    applied_by_operator_public_id character varying NOT NULL,
    approved_by_operator_public_id character varying,
    ended_by_operator_public_id character varying,
    break_glass boolean DEFAULT false NOT NULL,
    break_glass_approved_by_operator_public_id character varying,
    sessions_revoked_at timestamp(6) with time zone,
    audited_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_org_enforcement_cases_approval_separation CHECK (((approved_by_operator_public_id IS NULL) OR ((approved_by_operator_public_id)::text <> (applied_by_operator_public_id)::text))),
    CONSTRAINT chk_org_enforcement_cases_break_glass_approver CHECK (((break_glass = false) OR (break_glass_approved_by_operator_public_id IS NOT NULL))),
    CONSTRAINT chk_org_enforcement_cases_cooldown_duration CHECK ((((kind)::text <> 'cooldown'::text) OR (((duration_mode)::text = 'timed'::text) AND (expires_at IS NOT NULL) AND (expires_at <= (effective_at + '30 days'::interval))))),
    CONSTRAINT chk_org_enforcement_cases_duration_mode CHECK (((duration_mode)::text = ANY ((ARRAY['timed'::character varying, 'indefinite'::character varying, 'permanent'::character varying])::text[]))),
    CONSTRAINT chk_org_enforcement_cases_end_reason CHECK (((end_reason IS NULL) OR ((end_reason)::text = ANY ((ARRAY['expired'::character varying, 'revoked'::character varying, 'superseded'::character varying, 'corrected'::character varying, 'appeal_approved'::character varying, 'break_glass_released'::character varying, 'verification_completed'::character varying])::text[])))),
    CONSTRAINT chk_org_enforcement_cases_hidden CHECK ((((visibility)::text <> 'hidden'::text) OR ((kind)::text = 'permanent_ban'::text))),
    CONSTRAINT chk_org_enforcement_cases_indefinite_freeze_review CHECK ((((kind)::text <> 'temporary_freeze'::text) OR ((duration_mode)::text <> 'indefinite'::text) OR ((review_due_at IS NOT NULL) AND ((release_mode)::text = 'operator'::text)))),
    CONSTRAINT chk_org_enforcement_cases_kind CHECK (((kind)::text = ANY ((ARRAY['security_lock'::character varying, 'cooldown'::character varying, 'temporary_freeze'::character varying, 'permanent_ban'::character varying, 'method_protection'::character varying])::text[]))),
    CONSTRAINT chk_org_enforcement_cases_no_self_action CHECK (((principal_public_id)::text <> (applied_by_operator_public_id)::text)),
    CONSTRAINT chk_org_enforcement_cases_permanent_ban_duration CHECK ((((kind)::text <> 'permanent_ban'::text) OR (((duration_mode)::text = 'permanent'::text) AND (expires_at IS NULL)))),
    CONSTRAINT chk_org_enforcement_cases_release_mode CHECK (((release_mode)::text = ANY ((ARRAY['automatic'::character varying, 'operator'::character varying, 'verification_required'::character varying, 'break_glass_only'::character varying])::text[]))),
    CONSTRAINT chk_org_enforcement_cases_security_lock_release CHECK ((((kind)::text <> 'security_lock'::text) OR ((release_mode)::text = 'verification_required'::text))),
    CONSTRAINT chk_org_enforcement_cases_state CHECK (((state)::text = ANY ((ARRAY['draft'::character varying, 'pending_approval'::character varying, 'active'::character varying, 'ended'::character varying, 'failed'::character varying])::text[]))),
    CONSTRAINT chk_org_enforcement_cases_temp_freeze_duration_mode CHECK ((((kind)::text <> 'temporary_freeze'::text) OR ((duration_mode)::text = ANY ((ARRAY['timed'::character varying, 'indefinite'::character varying])::text[])))),
    CONSTRAINT chk_org_enforcement_cases_visibility CHECK (((visibility)::text = ANY ((ARRAY['visible'::character varying, 'hidden'::character varying])::text[])))
);
ALTER TABLE ONLY public.org_enforcement_cases
    ADD CONSTRAINT org_enforcement_cases_pkey PRIMARY KEY (id);
```

Migration provenance: `db/org_zenith_migrate/20260727120000_create_org_enforcement_cases.rb`, `db/org_zenith_migrate/20260830120000_allow_verification_completed_org_enforcement_case_end_reason.rb`.

### org_enforcement_identifier_effects

Source: `db/org_zenith_structure.sql:2985`. Machines: .

```sql
CREATE TABLE org_enforcement_identifier_effects (
    id bigint NOT NULL,
    org_enforcement_case_id bigint NOT NULL,
    identifier_kind character varying NOT NULL,
    lookup_digest character varying NOT NULL,
    key_version integer NOT NULL,
    digest_version integer NOT NULL,
    normalization_version integer NOT NULL,
    display_value text,
    registration_blocked boolean DEFAULT false NOT NULL,
    attachment_blocked boolean DEFAULT false NOT NULL,
    recovery_blocked boolean DEFAULT false NOT NULL,
    effective_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone,
    ended_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_org_enforcement_identifier_effects_kind CHECK (((identifier_kind)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'identity_id'::character varying])::text[])))
);
ALTER TABLE ONLY public.org_enforcement_identifier_effects
    ADD CONSTRAINT org_enforcement_identifier_effects_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.org_enforcement_identifier_effects
    ADD CONSTRAINT fk_rails_09a3dd541d FOREIGN KEY (org_enforcement_case_id) REFERENCES public.org_enforcement_cases(id);
```

Migration provenance: `db/org_zenith_migrate/20260727120003_create_org_enforcement_identifier_effects.rb`.

### org_enforcement_principal_effects

Source: `db/org_zenith_structure.sql:3029`. Machines: .

```sql
CREATE TABLE org_enforcement_principal_effects (
    id bigint NOT NULL,
    org_enforcement_case_id bigint NOT NULL,
    principal_public_id character varying NOT NULL,
    access_blocking boolean DEFAULT false NOT NULL,
    recovery_blocked boolean DEFAULT false NOT NULL,
    reactivation_blocked boolean DEFAULT false NOT NULL,
    withdrawal_purge_blocked boolean DEFAULT false NOT NULL,
    principal_hard_delete_blocked boolean DEFAULT false NOT NULL,
    profile_effect character varying,
    effective_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone,
    ended_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);
ALTER TABLE ONLY public.org_enforcement_principal_effects
    ADD CONSTRAINT org_enforcement_principal_effects_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.org_enforcement_principal_effects
    ADD CONSTRAINT fk_rails_facb871ecd FOREIGN KEY (org_enforcement_case_id) REFERENCES public.org_enforcement_cases(id);
```

Migration provenance: `db/org_zenith_migrate/20260727120001_create_org_enforcement_principal_effects.rb`.

### org_enforcement_principal_links

Source: `db/org_zenith_structure.sql:3070`. Machines: .

```sql
CREATE TABLE org_enforcement_principal_links (
    id bigint NOT NULL,
    org_enforcement_case_id bigint NOT NULL,
    principal_kind character varying NOT NULL,
    principal_public_id character varying NOT NULL,
    relationship_kind character varying NOT NULL,
    linked_at timestamp(6) with time zone NOT NULL,
    ended_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_org_enforcement_principal_links_relationship_kind CHECK (((relationship_kind)::text = ANY ((ARRAY['target_principal'::character varying, 'former_principal'::character varying, 'related_principal'::character varying, 'suspected_duplicate'::character varying, 'reinstated_principal'::character varying, 'false_positive'::character varying])::text[])))
);
ALTER TABLE ONLY public.org_enforcement_principal_links
    ADD CONSTRAINT org_enforcement_principal_links_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.org_enforcement_principal_links
    ADD CONSTRAINT fk_rails_522f837e23 FOREIGN KEY (org_enforcement_case_id) REFERENCES public.org_enforcement_cases(id);
```

Migration provenance: `db/org_zenith_migrate/20260727120004_create_org_enforcement_principal_links.rb`.

### org_preference_binding_methods

Source: `db/org_setting_structure.sql:121`. Machines: .

```sql
CREATE TABLE org_preference_binding_methods (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.org_preference_binding_methods
    ADD CONSTRAINT org_preference_binding_methods_pkey PRIMARY KEY (id);
```

Migration provenance: `db/org_settings_migrate/20260518030000_load_initial_org_setting_schema.rb`.

### org_preference_dbsc_statuses

Source: `db/org_setting_structure.sql:306`. Machines: .

```sql
CREATE TABLE org_preference_dbsc_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.org_preference_dbsc_statuses
    ADD CONSTRAINT org_preference_dbsc_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/org_settings_migrate/20260518030000_load_initial_org_setting_schema.rb`.

### org_preference_statuses

Source: `db/org_setting_structure.sql:634`. Machines: .

```sql
CREATE TABLE org_preference_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.org_preference_statuses
    ADD CONSTRAINT org_preference_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/org_settings_migrate/20260518030000_load_initial_org_setting_schema.rb`.

### org_preferences

Source: `db/org_setting_structure.sql:842`. Machines: `idp-operator-preference-dbsc`.

```sql
CREATE TABLE org_preferences (
    id bigint NOT NULL,
    binding_method_id bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    dbsc_challenge text,
    dbsc_challenge_issued_at timestamp(6) with time zone,
    dbsc_public_key jsonb,
    dbsc_session_id character varying,
    dbsc_status_id bigint DEFAULT 0 NOT NULL,
    jti character varying,
    public_id character varying NOT NULL,
    replaced_by_id bigint,
    status_id bigint DEFAULT 2 NOT NULL,
    token_digest bytea,
    updated_at timestamp(6) with time zone NOT NULL,
    used_at timestamp(6) with time zone,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    explicit_fields jsonb DEFAULT '[]'::jsonb NOT NULL
);
ALTER TABLE ONLY public.org_preferences
    ADD CONSTRAINT org_preferences_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.org_preferences
    ADD CONSTRAINT fk_org_preferences_on_binding_method_id FOREIGN KEY (binding_method_id) REFERENCES public.org_preference_binding_methods(id) NOT VALID;
ALTER TABLE ONLY public.org_preferences
    ADD CONSTRAINT fk_org_preferences_on_dbsc_status_id FOREIGN KEY (dbsc_status_id) REFERENCES public.org_preference_dbsc_statuses(id) NOT VALID;
ALTER TABLE ONLY public.org_preferences
    ADD CONSTRAINT fk_org_preferences_on_status_id FOREIGN KEY (status_id) REFERENCES public.org_preference_statuses(id) NOT VALID;
ALTER TABLE ONLY public.org_preferences
    ADD CONSTRAINT fk_rails_981b4c7c84 FOREIGN KEY (replaced_by_id) REFERENCES public.org_preferences(id) ON DELETE SET NULL NOT VALID;
```

Migration provenance: `db/org_settings_migrate/20260921133000_rename_org_setting_retention_columns_to_semantic_names.rb`, `db/org_settings_migrate/20260530120000_add_explicit_fields_to_org_preferences.rb`, `db/org_settings_migrate/20260526090000_create_org_preference_r18_display_stoppers.rb`, `db/org_settings_migrate/20260518030000_load_initial_org_setting_schema.rb`, `db/org_settings_migrate/20260526120201_remove_device_id_from_org_preferences.rb`, `db/app_settings_migrate/20260702000000_change_app_preferences_status_id_default_to_nothing.rb`, `db/org_zenith_migrate/20260721090000_add_explicit_fields_to_operator_preferences.rb`.

### organization_invitations

Source: `db/org_ticket_structure.sql:1174`. Machines: `idp-operator-organization-invitation`.

```sql
CREATE TABLE organization_invitations (
    id bigint NOT NULL,
    code character varying(32) NOT NULL,
    consumed_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    email character varying NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    invited_by_id bigint NOT NULL,
    organization_id bigint NOT NULL,
    role_id bigint DEFAULT 0 NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);
ALTER TABLE ONLY public.organization_invitations
    ADD CONSTRAINT organization_invitations_pkey PRIMARY KEY (id);
```

Migration provenance: `db/org_tickets_migrate/20260501000000_load_initial_org_ticket_schema.rb`.

### security_one_time_reveals

Source: `db/app_ticket_structure.sql:1681`. Machines: `idp-security-one-time-reveal`.

```sql
CREATE TABLE security_one_time_reveals (
    id bigint NOT NULL,
    jti_digest character varying NOT NULL,
    actor_type character varying NOT NULL,
    actor_id bigint NOT NULL,
    session_nonce_digest character varying NOT NULL,
    purpose character varying NOT NULL,
    encrypted_payload text NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);
ALTER TABLE ONLY public.security_one_time_reveals
    ADD CONSTRAINT security_one_time_reveals_pkey PRIMARY KEY (id);
```

Migration provenance: `db/app_tickets_migrate/20260905000000_create_security_one_time_reveals.rb`.

### visitor_auth_ceremony_sessions

Source: `db/com_ticket_structure.sql:106`. Machines: `idp-visitor-auth-ceremony-session`.

```sql
CREATE TABLE visitor_auth_ceremony_sessions (
    id bigint NOT NULL,
    sid_digest character varying(64) NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    revoked_at timestamp(6) with time zone,
    rotated_at timestamp(6) with time zone,
    previous_sid_digest character varying(64),
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    authorization_transaction_ref character varying,
    admitted_at timestamp(6) with time zone,
    completed_at timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    authentication_method character varying,
    authentication_event_at timestamp(6) with time zone,
    local_sign_in_flow_ref character varying,
    local_sign_up_flow_ref character varying,
    admission_purpose character varying,
    step_up_ceremony_transaction_ref character varying,
    CONSTRAINT visitor_auth_admission_purpose_valid CHECK (((admission_purpose IS NULL) OR ((admission_purpose)::text = ANY ((ARRAY['local_sign_in'::character varying, 'local_sign_up'::character varying, 'authentication_handoff'::character varying, 'invitation_handoff'::character varying, 'step_up_handoff'::character varying, 'reauthentication_handoff'::character varying, 'bootstrap_handoff'::character varying, 'credential_registration_handoff'::character varying, 'credential_change_handoff'::character varying])::text[])))),
    CONSTRAINT visitor_auth_ceremony_purpose_exclusive CHECK ((num_nonnulls(authorization_transaction_ref, local_sign_in_flow_ref, local_sign_up_flow_ref) <= 1)),
    CONSTRAINT visitor_auth_ceremony_sessions_admission_binding CHECK (((authorization_transaction_ref IS NULL) OR (admitted_at IS NOT NULL))),
    CONSTRAINT visitor_auth_ceremony_sessions_authentication_evidence_pair CHECK (((authentication_method IS NULL) = (authentication_event_at IS NULL))),
    CONSTRAINT visitor_auth_ceremony_sessions_authentication_method CHECK (((authentication_method IS NULL) OR ((authentication_method)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'secret'::character varying, 'passkey'::character varying, 'totp'::character varying, 'google'::character varying, 'apple'::character varying, 'entra'::character varying])::text[])))),
    CONSTRAINT visitor_auth_ceremony_sessions_one_terminal_timestamp CHECK ((num_nonnulls(revoked_at, completed_at, cancelled_at) <= 1)),
    CONSTRAINT visitor_auth_ceremony_transaction_exclusive CHECK ((num_nonnulls(authorization_transaction_ref, local_sign_in_flow_ref, local_sign_up_flow_ref, step_up_ceremony_transaction_ref) <= 1))
);
ALTER TABLE ONLY public.visitor_auth_ceremony_sessions
    ADD CONSTRAINT visitor_auth_ceremony_sessions_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.visitor_auth_ceremony_sessions
    ADD CONSTRAINT fk_rails_94c3c1f31a FOREIGN KEY (local_sign_in_flow_ref) REFERENCES public.visitor_sign_in_flows(public_id) ON DELETE RESTRICT;
ALTER TABLE ONLY public.visitor_auth_ceremony_sessions
    ADD CONSTRAINT fk_rails_d273fa69d4 FOREIGN KEY (step_up_ceremony_transaction_ref) REFERENCES public.visitor_step_up_ceremony_transactions(transaction_id) ON DELETE RESTRICT;
ALTER TABLE ONLY public.visitor_auth_ceremony_sessions
    ADD CONSTRAINT fk_rails_d67de11b1e FOREIGN KEY (local_sign_up_flow_ref) REFERENCES public.visitor_sign_up_flows(public_id) ON DELETE RESTRICT;
```

Migration provenance: `db/com_tickets_migrate/20260913140000_create_visitor_auth_ceremony_sessions.rb`, `db/com_tickets_migrate/20261003183734_bind_visitor_opaque_step_up_ceremonies.rb`, `db/com_tickets_migrate/20261003175643_bind_visitor_local_authentication_results.rb`, `db/com_tickets_migrate/20261003215022_bind_visitor_credential_ceremonies_to_base_authority.rb`, `db/com_tickets_migrate/20260920151000_validate_visitor_auth_ceremony_session_lifecycle.rb`, `db/com_tickets_migrate/20260921140100_validate_authentication_evidence_constraints.rb`, `db/com_tickets_migrate/20260921140000_add_authentication_evidence_to_visitor_auth_ceremony_sessions.rb`, `db/com_tickets_migrate/20260920150000_extend_visitor_auth_ceremony_session_lifecycle.rb`.

### visitor_device_sessions

Source: `db/com_ticket_structure.sql:158`. Machines: `idp-visitor-device-session`.

```sql
CREATE TABLE visitor_device_sessions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    visitor_id bigint NOT NULL,
    dbsc_session_id_digest character varying,
    dbsc_public_key_thumbprint character varying,
    dbsc_bound_at timestamp(6) with time zone,
    dpop_jkt character varying,
    status_id bigint DEFAULT 1 NOT NULL,
    current_refresh_token_id bigint,
    refresh_token_family_id character varying,
    last_seen_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    revoke_reason character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    last_network_hmac character varying
);
ALTER TABLE ONLY public.visitor_device_sessions
    ADD CONSTRAINT visitor_device_sessions_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.visitor_device_sessions
    ADD CONSTRAINT fk_visitor_device_sessions_on_current_refresh_token_owner FOREIGN KEY (id, current_refresh_token_id) REFERENCES public.visitor_tokens(device_session_id, id) ON DELETE SET NULL (current_refresh_token_id) DEFERRABLE INITIALLY DEFERRED;
```

Migration provenance: `db/com_tickets_migrate/20260924151000_add_visitor_device_session_token_foreign_keys.rb`, `db/com_tickets_migrate/20260924155000_add_visitor_token_device_session_actor_foreign_key.rb`, `db/com_tickets_migrate/20260924153000_validate_visitor_current_refresh_token_owner.rb`, `db/com_tickets_migrate/20260924154000_add_visitor_device_session_actor_reference_index.rb`, `db/com_tickets_migrate/20260520190002_create_device_sessions_for_visitor_tokens.rb`, `db/com_tickets_migrate/20260611100200_add_last_network_hmac_to_visitor_device_sessions.rb`, `db/com_tickets_migrate/20260526120102_remove_device_id_from_com_tickets.rb`.

### visitor_dpop_proof_states

Source: `db/com_ticket_structure.sql:201`. Machines: `idp-visitor-dpop-nonce`.

```sql
CREATE TABLE visitor_dpop_proof_states (
    id bigint NOT NULL,
    jti character varying,
    jkt character varying,
    nonce character varying,
    htm character varying,
    htu character varying,
    seen_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    nonce_used_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);
ALTER TABLE ONLY public.visitor_dpop_proof_states
    ADD CONSTRAINT visitor_dpop_proof_states_pkey PRIMARY KEY (id);
```

Migration provenance: `db/com_tickets_migrate/20260526120002_create_visitor_dpop_proof_states.rb`.

### visitor_email_ceremony_transactions

Source: `db/com_ticket_structure.sql:239`. Machines: `idp-visitor-email-ceremony`, `idp-visitor-email-verification-challenge`.

```sql
CREATE TABLE visitor_email_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    operation character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    grant_jti character varying NOT NULL,
    result_jti character varying,
    email_candidate_ref character varying,
    normalized_email_digest character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    evp_nonce_digest character varying,
    evp_token_digest character varying,
    evp_outcome character varying,
    evp_failure_reason character varying,
    evp_issuer character varying,
    evp_issued_at timestamp(6) with time zone,
    evp_verified_at timestamp(6) with time zone,
    evp_consumed_at timestamp(6) with time zone,
    evp_attempt_count integer DEFAULT 0 NOT NULL
);
ALTER TABLE ONLY public.visitor_email_ceremony_transactions
    ADD CONSTRAINT visitor_email_ceremony_transactions_pkey PRIMARY KEY (id);
```

Migration provenance: `db/com_tickets_migrate/20260710220001_add_evp_state_to_visitor_email_ceremony_transactions.rb`, `db/com_tickets_migrate/20260603121002_create_visitor_email_ceremony_transactions.rb`.

### visitor_email_statuses

Source: `db/com_zenith_structure.sql:1316`. Machines: .

```sql
CREATE TABLE visitor_email_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.visitor_email_statuses
    ADD CONSTRAINT visitor_email_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/com_principals_migrate/20260513130000_rename_customer_actor_to_visitor.rb`.

### visitor_emails

Source: `db/com_zenith_structure.sql:1344`. Machines: `idp-visitor-email-otp`, `idp-visitor-email-credential`.

```sql
CREATE TABLE visitor_emails (
    id bigint NOT NULL,
    address character varying DEFAULT ''::character varying NOT NULL,
    address_digest character varying,
    locked_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    otp_attempts_count integer DEFAULT 0 NOT NULL,
    otp_counter text DEFAULT ''::text NOT NULL,
    otp_expires_at timestamp(6) with time zone DEFAULT '-infinity'::timestamp with time zone NOT NULL,
    otp_last_sent_at timestamp(6) with time zone DEFAULT '-infinity'::timestamp with time zone NOT NULL,
    otp_private_key character varying DEFAULT ''::character varying NOT NULL,
    undeletable boolean DEFAULT false NOT NULL,
    verification_token_digest bytea,
    public_id character varying(21) NOT NULL,
    visitor_id bigint NOT NULL,
    visitor_email_status_id bigint DEFAULT 1 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    promotional boolean DEFAULT true NOT NULL,
    notifiable boolean DEFAULT true NOT NULL,
    subscribable boolean DEFAULT true NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    step_up_otp_failures integer DEFAULT 0 NOT NULL,
    step_up_otp_locked_until timestamp(6) with time zone,
    step_up_otp_last_issued_at timestamp(6) with time zone,
    CONSTRAINT visitor_email_step_up_failures_nonnegative CHECK ((step_up_otp_failures >= 0))
);
ALTER TABLE ONLY public.visitor_emails
    ADD CONSTRAINT visitor_emails_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.visitor_emails
    ADD CONSTRAINT fk_rails_07ea0750f3 FOREIGN KEY (visitor_email_status_id) REFERENCES public.visitor_email_statuses(id);
ALTER TABLE ONLY public.visitor_emails
    ADD CONSTRAINT fk_rails_9525e3bd11 FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);
```

Migration provenance: `db/com_zenith_migrate/20260921133000_rename_com_zenith_retention_columns_to_semantic_names.rb`, `db/com_principals_migrate/20260525131000_scope_visitor_contact_identifier_uniqueness_to_active_records.rb`, `db/com_principals_migrate/20261003202301_preserve_visitor_step_up_email_failures.rb`, `db/com_principals_migrate/20260513130000_rename_customer_actor_to_visitor.rb`, `db/com_principals_migrate/20260518163000_remove_encrypted_identifier_lookup_indexes_from_visitor_identities.rb`, `db/com_principals_migrate/20260525120000_add_retention_to_visitor_sign_up_artifacts.rb`.

### visitor_enforcement_recovery_ceremonies

Source: `db/com_zenith_structure.sql:1396`. Machines: `idp-visitor-enforcement-recovery-ceremony`.

```sql
CREATE TABLE visitor_enforcement_recovery_ceremonies (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    visitor_id bigint NOT NULL,
    status_id integer DEFAULT 1 NOT NULL,
    token_digest bytea NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    ip_digest bytea,
    user_agent_digest bytea,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);
ALTER TABLE ONLY public.visitor_enforcement_recovery_ceremonies
    ADD CONSTRAINT visitor_enforcement_recovery_ceremonies_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.visitor_enforcement_recovery_ceremonies
    ADD CONSTRAINT fk_rails_f886bbbdce FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);
```

Migration provenance: `db/com_principals_migrate/20260729130000_create_visitor_enforcement_recovery_ceremonies.rb`.

### visitor_mfa_levels

Source: `db/com_zenith_structure.sql:1501`. Machines: .

```sql
CREATE TABLE visitor_mfa_levels (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.visitor_mfa_levels
    ADD CONSTRAINT visitor_mfa_levels_pkey PRIMARY KEY (id);
```

Migration provenance: `db/com_principals_migrate/20260530031000_rename_com_principal_model_terms.rb`.

### visitor_mfa_statuses

Source: `db/com_zenith_structure.sql:1529`. Machines: .

```sql
CREATE TABLE visitor_mfa_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.visitor_mfa_statuses
    ADD CONSTRAINT visitor_mfa_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/com_principals_migrate/20260530031000_rename_com_principal_model_terms.rb`.

### visitor_oidc_authorization_transactions

Source: `db/com_ticket_structure.sql:291`. Machines: `idp-visitor-oidc-authorization`.

```sql
CREATE TABLE visitor_oidc_authorization_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    intent character varying NOT NULL,
    client_id character varying NOT NULL,
    redirect_uri character varying NOT NULL,
    response_type character varying NOT NULL,
    scope character varying NOT NULL,
    state character varying NOT NULL,
    nonce character varying NOT NULL,
    code_challenge character varying NOT NULL,
    code_challenge_method character varying NOT NULL,
    login_challenge character varying NOT NULL,
    login_challenge_expires_at timestamp(6) with time zone NOT NULL,
    authenticated_at timestamp(6) with time zone,
    actor_ref character varying,
    session_ref character varying,
    auth_method character varying,
    acr character varying,
    consumed_at timestamp(6) with time zone,
    expires_at timestamp(6) with time zone NOT NULL,
    status character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    oidc_prompt character varying,
    oidc_max_age integer,
    result_generation integer DEFAULT 0 NOT NULL,
    result_digest character varying(64),
    result_expires_at timestamp(6) with time zone,
    result_consumed_at timestamp(6) with time zone,
    browser_session_ref character varying,
    base_finalized_at timestamp(6) with time zone,
    authorization_grant_redeemed_at timestamp(6) with time zone,
    CONSTRAINT visitor_oidc_auth_transactions_result_generation_nonnegative CHECK ((result_generation >= 0))
);
ALTER TABLE ONLY public.visitor_oidc_authorization_transactions
    ADD CONSTRAINT visitor_oidc_authorization_transactions_pkey PRIMARY KEY (id);
```

Migration provenance: `db/com_tickets_migrate/20260922120100_validate_cross_store_oidc_finalization_visitor_transactions.rb`, `db/com_tickets_migrate/20260611150001_create_visitor_oidc_authorization_transactions.rb`, `db/com_tickets_migrate/20260922120000_add_cross_store_oidc_finalization_to_visitor_transactions.rb`, `db/com_tickets_migrate/20260915180000_add_oidc_freshness_options_to_visitor_authorization_transactions.rb`.

### visitor_passkey_ceremony_transactions

Source: `db/com_ticket_structure.sql:388`. Machines: `idp-visitor-passkey-ceremony`.

```sql
CREATE TABLE visitor_passkey_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    operation character varying NOT NULL,
    rp_id character varying NOT NULL,
    origin character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    grant_jti character varying NOT NULL,
    result_jti character varying,
    credential_candidate_ref character varying,
    credential_candidate_digest character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    step_up_ceremony_transaction_ref character varying
);
ALTER TABLE ONLY public.visitor_passkey_ceremony_transactions
    ADD CONSTRAINT visitor_passkey_ceremony_transactions_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.visitor_passkey_ceremony_transactions
    ADD CONSTRAINT fk_rails_ebaeb32aa4 FOREIGN KEY (step_up_ceremony_transaction_ref) REFERENCES public.visitor_step_up_ceremony_transactions(transaction_id) ON DELETE RESTRICT;
```

Migration provenance: `db/com_tickets_migrate/20261003215022_bind_visitor_credential_ceremonies_to_base_authority.rb`, `db/com_tickets_migrate/20260603123002_create_visitor_passkey_ceremony_transactions.rb`.

### visitor_passkey_statuses

Source: `db/com_zenith_structure.sql:1557`. Machines: .

```sql
CREATE TABLE visitor_passkey_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.visitor_passkey_statuses
    ADD CONSTRAINT visitor_passkey_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/com_principals_migrate/20260513130000_rename_customer_actor_to_visitor.rb`.

### visitor_passkeys

Source: `db/com_zenith_structure.sql:1585`. Machines: `idp-visitor-passkey-credential`.

```sql
CREATE TABLE visitor_passkeys (
    id bigint NOT NULL,
    description character varying DEFAULT ''::character varying NOT NULL,
    external_id uuid NOT NULL,
    last_used_at timestamp(6) with time zone,
    public_key text NOT NULL,
    sign_count bigint DEFAULT 0 NOT NULL,
    public_id character varying(21) NOT NULL,
    webauthn_id character varying DEFAULT ''::character varying NOT NULL,
    visitor_id bigint NOT NULL,
    status_id bigint DEFAULT 1 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    aaguid uuid,
    transports jsonb,
    backup_eligible boolean,
    backup_state boolean,
    authenticator_attachment character varying,
    provider_name character varying,
    metadata_source character varying,
    uv_verified_at timestamp(6) with time zone
);
ALTER TABLE ONLY public.visitor_passkeys
    ADD CONSTRAINT visitor_passkeys_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.visitor_passkeys
    ADD CONSTRAINT fk_rails_3ced60caec FOREIGN KEY (status_id) REFERENCES public.visitor_passkey_statuses(id);
ALTER TABLE ONLY public.visitor_passkeys
    ADD CONSTRAINT fk_rails_cb59e99a6f FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);
```

Migration provenance: `db/com_zenith_migrate/20260921133000_rename_com_zenith_retention_columns_to_semantic_names.rb`, `db/com_principals_migrate/20260513130000_rename_customer_actor_to_visitor.rb`, `db/com_principals_migrate/20260719100000_add_authenticator_metadata_to_visitor_passkeys.rb`, `db/com_principals_migrate/20260831064102_add_uv_verified_at_to_visitor_passkeys.rb`, `db/com_principals_migrate/20260525120000_add_retention_to_visitor_sign_up_artifacts.rb`.

### visitor_rp_sessions

Source: `db/com_ticket_structure.sql:434`. Machines: `idp-visitor-rp-session`.

```sql
CREATE TABLE visitor_rp_sessions (
    id bigint NOT NULL,
    visitor_token_id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    oidc_client_id character varying(64) NOT NULL,
    oidc_scope text,
    oidc_jti character varying,
    refresh_token_digest character varying,
    previous_refresh_token_digest character varying,
    refresh_token_expires_at timestamp(6) with time zone,
    refresh_token_rotated_at timestamp(6) with time zone,
    dpop_jkt character varying,
    last_used_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    last_logout_status character varying,
    last_logout_attempted_at timestamp(6) with time zone,
    logged_out_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    oidc_auth_time timestamp(6) with time zone,
    oidc_acr character varying,
    oidc_amr text,
    oidc_nonce character varying,
    oidc_access_token_max_expires_at timestamp(6) with time zone
);
ALTER TABLE ONLY public.visitor_rp_sessions
    ADD CONSTRAINT visitor_rp_sessions_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.visitor_rp_sessions
    ADD CONSTRAINT fk_rails_367c8ed0a4 FOREIGN KEY (visitor_token_id) REFERENCES public.visitor_tokens(id) ON DELETE CASCADE;
```

Migration provenance: `db/com_tickets_migrate/20260917130001_add_oidc_access_token_expiry_tracking_to_visitor_rp_sessions.rb`, `db/com_tickets_migrate/20260915170000_add_oidc_refresh_claims_to_visitor_rp_sessions.rb`, `db/com_tickets_migrate/20260624000000_create_visitor_rp_sessions_and_bind_authorization_codes.rb`.

### visitor_secret_credential_ceremony_transactions

Source: `db/com_ticket_structure.sql:484`. Machines: `idp-visitor-secret-credential-ceremony`.

```sql
CREATE TABLE visitor_secret_credential_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    operation character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    grant_jti character varying NOT NULL,
    result_jti character varying,
    credential_candidate_ref character varying,
    credential_candidate_digest character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);
ALTER TABLE ONLY public.visitor_secret_credential_ceremony_transactions
    ADD CONSTRAINT visitor_secret_credential_ceremony_transactions_pkey PRIMARY KEY (id);
```

Migration provenance: `db/com_tickets_migrate/20260603130002_create_visitor_secret_credential_ceremony_transactions.rb`.

### visitor_secret_credential_kinds

Source: `db/com_zenith_structure.sql:2621`. Machines: .

```sql
CREATE TABLE visitor_secret_credential_kinds (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.visitor_secret_credential_kinds
    ADD CONSTRAINT visitor_secret_credential_kinds_pkey PRIMARY KEY (id);
```

Migration provenance: `db/com_principals_migrate/20260530031000_rename_com_principal_model_terms.rb`.

### visitor_secret_credential_statuses

Source: `db/com_zenith_structure.sql:2649`. Machines: .

```sql
CREATE TABLE visitor_secret_credential_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.visitor_secret_credential_statuses
    ADD CONSTRAINT visitor_secret_credential_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/com_principals_migrate/20260530031000_rename_com_principal_model_terms.rb`.

### visitor_secret_credentials

Source: `db/com_zenith_structure.sql:2677`. Machines: `idp-visitor-secret-credential`.

```sql
CREATE TABLE visitor_secret_credentials (
    id bigint NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL,
    password_digest character varying DEFAULT ''::character varying NOT NULL,
    last_used_at timestamp(6) with time zone,
    uses_remaining integer DEFAULT 1 NOT NULL,
    public_id character varying(21) NOT NULL,
    visitor_id bigint NOT NULL,
    visitor_secret_credential_status_id bigint DEFAULT 1 NOT NULL,
    visitor_secret_credential_kind_id bigint DEFAULT 1 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    secret_kind character varying,
    usage_policy character varying,
    lookup_digest character varying,
    safe_prefix character varying,
    issued_at timestamp(6) with time zone,
    issued_by_type character varying,
    issued_by_id bigint,
    issued_by_ref character varying,
    delivery_method character varying,
    scope character varying,
    use_count integer DEFAULT 0 NOT NULL,
    failure_count integer DEFAULT 0 NOT NULL,
    max_uses integer,
    max_failures integer,
    not_before_at timestamp(6) with time zone,
    consumed_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    locked_at timestamp(6) with time zone,
    last_failed_at timestamp(6) with time zone,
    CONSTRAINT chk_customer_secrets_retention_order CHECK ((discard_at <= purge_eligible_at))
);
ALTER TABLE ONLY public.visitor_secret_credentials
    ADD CONSTRAINT visitor_secret_credentials_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.visitor_secret_credentials
    ADD CONSTRAINT fk_rails_2ee7e81748 FOREIGN KEY (visitor_secret_credential_status_id) REFERENCES public.visitor_secret_credential_statuses(id);
ALTER TABLE ONLY public.visitor_secret_credentials
    ADD CONSTRAINT fk_rails_41951b924f FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);
ALTER TABLE ONLY public.visitor_secret_credentials
    ADD CONSTRAINT fk_rails_e1dad63cb9 FOREIGN KEY (visitor_secret_credential_kind_id) REFERENCES public.visitor_secret_credential_kinds(id);
```

Migration provenance: `db/com_zenith_migrate/20260921133000_rename_com_zenith_retention_columns_to_semantic_names.rb`, `db/com_principals_migrate/20260530032200_rename_visitor_secret_credential_columns.rb`, `db/com_principals_migrate/20260530031000_rename_com_principal_model_terms.rb`, `db/com_principals_migrate/20260612100000_add_new_secret_axis_to_visitor_secret_credentials.rb`.

### visitor_sign_in_flow_statuses

Source: `db/com_ticket_structure.sql:527`. Machines: .

```sql
CREATE TABLE visitor_sign_in_flow_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.visitor_sign_in_flow_statuses
    ADD CONSTRAINT visitor_sign_in_flow_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/com_tickets_migrate/20260530031000_rename_com_ticket_model_terms.rb`.

### visitor_sign_in_flows

Source: `db/com_ticket_structure.sql:555`. Machines: `idp-visitor-sign-in`, `idp-visitor-local-result-delivery`.

```sql
CREATE TABLE visitor_sign_in_flows (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    principal_id bigint,
    token_id bigint,
    state character varying NOT NULL,
    step character varying NOT NULL,
    return_to text,
    nonce_digest character varying NOT NULL,
    issued_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    completed_at timestamp(6) with time zone,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    status_id bigint DEFAULT 10 NOT NULL,
    selected_region_id bigint,
    selected_persona_id bigint,
    selector_completed_at timestamp(6) with time zone,
    session_issued_at timestamp(6) with time zone,
    result_digest character varying(64),
    result_generation integer DEFAULT 0 NOT NULL,
    result_expires_at timestamp(6) with time zone,
    base_finalized_at timestamp(6) with time zone,
    authentication_method character varying,
    authentication_event_at timestamp(6) with time zone,
    authentication_context character varying,
    CONSTRAINT chk_com_sign_in_sequence_tickets_lifetime_order CHECK ((issued_at < expires_at)),
    CONSTRAINT chk_com_sign_in_sequence_tickets_retention_order CHECK ((discard_at <= purge_eligible_at)),
    CONSTRAINT visitor_local_authentication_context_valid CHECK (((authentication_context IS NULL) OR ((authentication_context)::text = ANY ((ARRAY['normal'::character varying, 'emergency'::character varying])::text[])))),
    CONSTRAINT visitor_sign_in_flows_authentication_evidence_valid CHECK ((((authentication_method IS NULL) AND (authentication_event_at IS NULL)) OR (((authentication_method)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'secret'::character varying, 'passkey'::character varying, 'totp'::character varying, 'google'::character varying, 'apple'::character varying, 'entra'::character varying])::text[])) AND (authentication_event_at IS NOT NULL) AND (principal_id IS NOT NULL)))),
    CONSTRAINT visitor_sign_in_flows_base_finalization_valid CHECK (((base_finalized_at IS NULL) OR ((token_id IS NOT NULL) AND (result_digest IS NOT NULL)))),
    CONSTRAINT visitor_sign_in_flows_evidence_complete CHECK (((authentication_event_at IS NULL) OR (authentication_method IS NOT NULL))),
    CONSTRAINT visitor_sign_in_flows_result_complete CHECK (((result_generation = 0) OR ((result_digest IS NOT NULL) AND (result_expires_at IS NOT NULL) AND (authentication_event_at IS NOT NULL)))),
    CONSTRAINT visitor_sign_in_flows_result_delivery_valid CHECK ((((result_digest IS NULL) AND (result_expires_at IS NULL) AND (result_generation = 0)) OR ((length((result_digest)::text) = 64) AND (result_expires_at IS NOT NULL) AND (result_generation > 0) AND (authentication_event_at IS NOT NULL)))),
    CONSTRAINT visitor_sign_in_flows_result_generation_valid CHECK ((result_generation >= 0))
);
ALTER TABLE ONLY public.visitor_sign_in_flows
    ADD CONSTRAINT visitor_sign_in_flows_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.visitor_sign_in_flows
    ADD CONSTRAINT fk_rails_75353bbdcf FOREIGN KEY (status_id) REFERENCES public.visitor_sign_in_flow_statuses(id) NOT VALID;
ALTER TABLE ONLY public.visitor_sign_in_flows
    ADD CONSTRAINT fk_rails_9797ae40cc FOREIGN KEY (token_id) REFERENCES public.visitor_tokens(id) ON DELETE CASCADE NOT VALID;
```

Migration provenance: `db/com_tickets_migrate/20261003175643_bind_visitor_local_authentication_results.rb`, `db/com_tickets_migrate/20260520143006_rename_com_ticket_tables_to_model_conventions.rb`, `db/com_tickets_migrate/20260530031000_rename_com_ticket_model_terms.rb`, `db/com_tickets_migrate/20260525233000_add_selector_activation_to_visitor_sign_in_cycles.rb`, `db/com_tickets_migrate/20260528162102_harden_visitor_sign_in_cycle_state_constraints.rb`, `db/com_tickets_migrate/20260921133000_rename_com_ticket_retention_columns_to_semantic_names.rb`, `db/com_tickets_migrate/20261003181718_preserve_visitor_local_authentication_context.rb`, `db/com_tickets_migrate/20261002120000_add_root_login_established_at_to_visitor_tokens.rb`.

### visitor_sign_out_flow_kinds

Source: `db/com_ticket_structure.sql:618`. Machines: .

```sql
CREATE TABLE visitor_sign_out_flow_kinds (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.visitor_sign_out_flow_kinds
    ADD CONSTRAINT visitor_sign_out_flow_kinds_pkey PRIMARY KEY (id);
```

Migration provenance: `db/com_tickets_migrate/20260530031000_rename_com_ticket_model_terms.rb`.

### visitor_sign_out_flow_statuses

Source: `db/com_ticket_structure.sql:646`. Machines: .

```sql
CREATE TABLE visitor_sign_out_flow_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.visitor_sign_out_flow_statuses
    ADD CONSTRAINT visitor_sign_out_flow_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/com_tickets_migrate/20260530031000_rename_com_ticket_model_terms.rb`.

### visitor_sign_out_flows

Source: `db/com_ticket_structure.sql:674`. Machines: `idp-visitor-sign-out`.

```sql
CREATE TABLE visitor_sign_out_flows (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    principal_id bigint,
    token_id bigint,
    status_id bigint DEFAULT 10 NOT NULL,
    kind_id bigint DEFAULT 0 NOT NULL,
    refresh_token_family_id character varying,
    requested_at timestamp(6) with time zone NOT NULL,
    access_discarded_at timestamp(6) with time zone,
    logically_revoked_at timestamp(6) with time zone,
    access_expires_at timestamp(6) with time zone NOT NULL,
    refresh_expires_at timestamp(6) with time zone NOT NULL,
    completed_at timestamp(6) with time zone,
    failed_at timestamp(6) with time zone,
    return_to text,
    nonce_digest character varying,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_visitor_sign_out_cycles_retention_order CHECK ((discard_at <= purge_eligible_at)),
    CONSTRAINT chk_visitor_sign_out_cycles_token_expiry_order CHECK ((access_expires_at <= refresh_expires_at))
);
ALTER TABLE ONLY public.visitor_sign_out_flows
    ADD CONSTRAINT visitor_sign_out_flows_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.visitor_sign_out_flows
    ADD CONSTRAINT fk_rails_0289bc0560 FOREIGN KEY (status_id) REFERENCES public.visitor_sign_out_flow_statuses(id) NOT VALID;
ALTER TABLE ONLY public.visitor_sign_out_flows
    ADD CONSTRAINT fk_rails_173a30a232 FOREIGN KEY (token_id) REFERENCES public.visitor_tokens(id) ON DELETE CASCADE NOT VALID;
ALTER TABLE ONLY public.visitor_sign_out_flows
    ADD CONSTRAINT fk_rails_8ef47d5e3c FOREIGN KEY (kind_id) REFERENCES public.visitor_sign_out_flow_kinds(id) NOT VALID;
```

Migration provenance: `db/com_tickets_migrate/20260519092001_create_visitor_sign_out_cycles.rb`, `db/com_tickets_migrate/20260530031000_rename_com_ticket_model_terms.rb`, `db/com_tickets_migrate/20260921133000_rename_com_ticket_retention_columns_to_semantic_names.rb`.

### visitor_sign_up_flow_cleanup_statuses

Source: `db/com_ticket_structure.sql:723`. Machines: .

```sql
CREATE TABLE visitor_sign_up_flow_cleanup_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.visitor_sign_up_flow_cleanup_statuses
    ADD CONSTRAINT visitor_sign_up_flow_cleanup_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/com_tickets_migrate/20260530031000_rename_com_ticket_model_terms.rb`.

### visitor_sign_up_flow_statuses

Source: `db/com_ticket_structure.sql:751`. Machines: .

```sql
CREATE TABLE visitor_sign_up_flow_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.visitor_sign_up_flow_statuses
    ADD CONSTRAINT visitor_sign_up_flow_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/com_tickets_migrate/20260530031000_rename_com_ticket_model_terms.rb`, `db/com_tickets_migrate/20260616150010_add_on_delete_actions_to_visitor_ticket_foreign_keys.rb`.

### visitor_sign_up_flows

Source: `db/com_ticket_structure.sql:779`. Machines: `idp-visitor-sign-up`, `idp-visitor-sign-up-cleanup`.

```sql
CREATE TABLE visitor_sign_up_flows (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    principal_id bigint,
    token_id bigint,
    state character varying NOT NULL,
    step character varying NOT NULL,
    return_to text,
    nonce_digest character varying NOT NULL,
    issued_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    completed_at timestamp(6) with time zone,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    status_id bigint DEFAULT 10 NOT NULL,
    entry_method character varying NOT NULL,
    pending_contact_type character varying,
    pending_contact_id bigint,
    social_provider character varying,
    completed_requirements jsonb DEFAULT '{}'::jsonb NOT NULL,
    failed_at timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    checkpoint_version integer DEFAULT 0 NOT NULL,
    cleanup_attempted_at timestamp(6) with time zone,
    cleanup_completed_at timestamp(6) with time zone,
    cleanup_error_code character varying,
    pending_passkey_registration_id bigint,
    cleanup_attempts_count integer DEFAULT 0 NOT NULL,
    cleanup_status_id bigint DEFAULT 10 NOT NULL,
    result_digest character varying(64),
    result_generation integer DEFAULT 0 NOT NULL,
    result_expires_at timestamp(6) with time zone,
    base_finalized_at timestamp(6) with time zone,
    authentication_method character varying,
    authentication_event_at timestamp(6) with time zone,
    CONSTRAINT chk_com_sign_up_sequence_tickets_lifetime_order CHECK ((issued_at < expires_at)),
    CONSTRAINT chk_com_sign_up_sequence_tickets_retention_order CHECK ((discard_at <= purge_eligible_at)),
    CONSTRAINT visitor_sign_up_flows_authentication_evidence_valid CHECK ((((authentication_method IS NULL) AND (authentication_event_at IS NULL)) OR (((authentication_method)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'secret'::character varying, 'passkey'::character varying, 'totp'::character varying, 'google'::character varying, 'apple'::character varying, 'entra'::character varying])::text[])) AND (authentication_event_at IS NOT NULL) AND (principal_id IS NOT NULL)))),
    CONSTRAINT visitor_sign_up_flows_base_finalization_valid CHECK (((base_finalized_at IS NULL) OR ((token_id IS NOT NULL) AND (result_digest IS NOT NULL)))),
    CONSTRAINT visitor_sign_up_flows_evidence_complete CHECK (((authentication_event_at IS NULL) OR (authentication_method IS NOT NULL))),
    CONSTRAINT visitor_sign_up_flows_result_complete CHECK (((result_generation = 0) OR ((result_digest IS NOT NULL) AND (result_expires_at IS NOT NULL) AND (authentication_event_at IS NOT NULL)))),
    CONSTRAINT visitor_sign_up_flows_result_delivery_valid CHECK ((((result_digest IS NULL) AND (result_expires_at IS NULL) AND (result_generation = 0)) OR ((length((result_digest)::text) = 64) AND (result_expires_at IS NOT NULL) AND (result_generation > 0) AND (authentication_event_at IS NOT NULL)))),
    CONSTRAINT visitor_sign_up_flows_result_generation_valid CHECK ((result_generation >= 0))
);
ALTER TABLE ONLY public.visitor_sign_up_flows
    ADD CONSTRAINT visitor_sign_up_flows_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.visitor_sign_up_flows
    ADD CONSTRAINT fk_rails_85a641d47f FOREIGN KEY (token_id) REFERENCES public.visitor_tokens(id) ON DELETE RESTRICT;
ALTER TABLE ONLY public.visitor_sign_up_flows
    ADD CONSTRAINT fk_rails_8cef237db7 FOREIGN KEY (status_id) REFERENCES public.visitor_sign_up_flow_statuses(id) ON DELETE RESTRICT NOT VALID;
ALTER TABLE ONLY public.visitor_sign_up_flows
    ADD CONSTRAINT fk_rails_cf6ee54a77 FOREIGN KEY (cleanup_status_id) REFERENCES public.visitor_sign_up_flow_cleanup_statuses(id) NOT VALID;
```

Migration provenance: `db/com_tickets_migrate/20260616150006_validate_add_entry_method_not_null_to_visitor_sign_up_flows.rb`, `db/com_tickets_migrate/20260525200000_drop_cleanup_token_from_visitor_sign_up_cycles.rb`, `db/com_tickets_migrate/20261003175643_bind_visitor_local_authentication_results.rb`, `db/com_tickets_migrate/20260520143006_rename_com_ticket_tables_to_model_conventions.rb`, `db/com_tickets_migrate/20260920152000_restrict_visitor_sign_up_flow_token_delete.rb`, `db/com_tickets_migrate/20260530031000_rename_com_ticket_model_terms.rb`, `db/com_tickets_migrate/20260525210000_create_visitor_sign_up_cycle_cleanup_statuses.rb`, `db/com_tickets_migrate/20260525131500_restrict_visitor_sign_up_cycle_token_delete.rb`, `db/com_tickets_migrate/20260920152001_validate_restrict_visitor_sign_up_flow_token_delete.rb`, `db/com_tickets_migrate/20260616150001_add_entry_method_not_null_to_visitor_sign_up_flows.rb`, `db/com_tickets_migrate/20260921133000_rename_com_ticket_retention_columns_to_semantic_names.rb`, `db/com_tickets_migrate/20260525123000_add_checkpoint_version_to_visitor_sign_up_cycles.rb`, `db/com_tickets_migrate/20260616150010_add_on_delete_actions_to_visitor_ticket_foreign_keys.rb`, `db/com_tickets_migrate/20260525124500_add_cleanup_state_to_visitor_sign_up_cycles.rb`, `db/com_tickets_migrate/20260616150020_remove_redundant_com_ticket_indexes.rb`, `db/com_tickets_migrate/20261003181718_preserve_visitor_local_authentication_context.rb`, `db/com_tickets_migrate/20260525200500_add_cleanup_attempts_count_to_visitor_sign_up_cycles.rb`.

### visitor_statuses

Source: `db/com_zenith_structure.sql:2737`. Machines: .

```sql
CREATE TABLE visitor_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.visitor_statuses
    ADD CONSTRAINT visitor_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/com_zenith_migrate/20260511223458_create_client_visitors.rb`, `db/com_zenith_migrate/20260519161002_rename_com_rp_tables.rb`, `db/com_zenith_migrate/20260511223500_seed_client_visitor_statuses.rb`, `db/com_zenith_migrate/20260511223457_create_client_visitor_statuses.rb`, `db/com_principals_migrate/20260513130000_rename_customer_actor_to_visitor.rb`, `db/com_principals_migrate/20260518181000_validate_remaining_com_principal_foreign_keys.rb`.

### visitor_step_up_ceremony_transactions

Source: `db/com_ticket_structure.sql:850`. Machines: `idp-visitor-step-up-ceremony`.

```sql
CREATE TABLE visitor_step_up_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    required_scope character varying NOT NULL,
    required_aal character varying NOT NULL,
    allowed_methods text NOT NULL,
    resource_ref character varying,
    return_to character varying,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    grant_jti character varying NOT NULL,
    result_jti character varying,
    method character varying,
    aal character varying,
    verified_at timestamp(6) with time zone,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    phishing_resistant_required boolean DEFAULT false NOT NULL,
    phishing_resistant boolean DEFAULT false NOT NULL,
    purpose character varying DEFAULT 'step_up'::character varying NOT NULL,
    result_digest character varying(64),
    result_generation integer DEFAULT 0 NOT NULL,
    result_expires_at timestamp(6) with time zone,
    canceled_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    verified_credential_ref character varying,
    CONSTRAINT visitor_step_up_purpose_valid CHECK (((purpose)::text = ANY ((ARRAY['step_up'::character varying, 'reauthentication'::character varying, 'bootstrap'::character varying, 'credential_registration'::character varying, 'credential_change'::character varying])::text[]))),
    CONSTRAINT visitor_step_up_result_valid CHECK (((result_generation >= 0) AND (((result_digest IS NULL) AND (result_expires_at IS NULL) AND (result_generation = 0)) OR ((result_digest IS NOT NULL) AND ((result_digest)::text ~ '^[0-9a-f]{64}$'::text) AND (result_expires_at IS NOT NULL) AND (result_generation > 0) AND (verified_at IS NOT NULL))))),
    CONSTRAINT visitor_step_up_status_valid CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'verified'::character varying, 'consumed'::character varying, 'canceled'::character varying, 'expired'::character varying, 'revoked'::character varying])::text[]))),
    CONSTRAINT visitor_step_up_terminal_valid CHECK ((((canceled_at IS NULL) OR ((status)::text = 'canceled'::text)) AND ((revoked_at IS NULL) OR ((status)::text = 'revoked'::text)) AND (((status)::text <> 'revoked'::text) OR (revoked_at IS NOT NULL)) AND (((status)::text <> 'verified'::text) OR ((verified_at IS NOT NULL) AND (method IS NOT NULL) AND (aal IS NOT NULL))))),
    CONSTRAINT visitor_step_up_verified_credential_present CHECK ((((status)::text <> 'verified'::text) OR (((purpose)::text = ANY ((ARRAY['bootstrap'::character varying, 'credential_registration'::character varying])::text[])) AND (verified_credential_ref IS NULL) AND ((aal)::text = 'none'::text) AND ((required_aal)::text = 'none'::text) AND (phishing_resistant IS FALSE) AND (phishing_resistant_required IS FALSE) AND ((method)::text = ANY ((ARRAY['passkey'::character varying, 'totp'::character varying])::text[]))) OR (((purpose)::text <> ALL ((ARRAY['bootstrap'::character varying, 'credential_registration'::character varying])::text[])) AND (verified_credential_ref IS NOT NULL) AND (length((verified_credential_ref)::text) > 0))))
);
ALTER TABLE ONLY public.visitor_step_up_ceremony_transactions
    ADD CONSTRAINT visitor_step_up_ceremony_transactions_pkey PRIMARY KEY (id);
```

Migration provenance: `db/com_tickets_migrate/20260603122002_create_visitor_step_up_ceremony_transactions.rb`, `db/com_tickets_migrate/20261003183734_bind_visitor_opaque_step_up_ceremonies.rb`, `db/com_tickets_migrate/20261003215022_bind_visitor_credential_ceremonies_to_base_authority.rb`, `db/com_tickets_migrate/20261003185507_bind_visitor_verified_step_up_credential.rb`, `db/com_tickets_migrate/20261003221639_separate_visitor_registration_evidence_from_step_up_credential.rb`, `db/com_tickets_migrate/20260831064103_add_phishing_resistance_to_visitor_step_up_ceremony_transactions.rb`.

### visitor_step_up_sessions

Source: `db/com_ticket_structure.sql:912`. Machines: `idp-visitor-step-up-session`, `idp-visitor-step-up-passkey-challenge`, `idp-visitor-step-up-email-challenge`.

```sql
CREATE TABLE visitor_step_up_sessions (
    id bigint NOT NULL,
    attempt_count integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    visitor_token_id bigint NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    method character varying,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    return_to text NOT NULL,
    scope character varying NOT NULL,
    status character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    verified_at timestamp(6) with time zone,
    step_up_ceremony_transaction_ref character varying,
    passkey_challenge text,
    passkey_challenge_ref character varying,
    passkey_rp_id character varying,
    passkey_origin character varying,
    passkey_challenge_expires_at timestamp(6) with time zone,
    passkey_challenge_consumed_at timestamp(6) with time zone,
    email_credential_ref character varying,
    email_code_digest character varying(64),
    email_code_generation integer DEFAULT 0 NOT NULL,
    email_code_issued_at timestamp(6) with time zone,
    email_code_expires_at timestamp(6) with time zone,
    email_code_consumed_at timestamp(6) with time zone,
    email_delivery_state character varying,
    CONSTRAINT visitor_step_up_challenge_bound CHECK (((passkey_challenge IS NULL) OR ((step_up_ceremony_transaction_ref IS NOT NULL) AND (passkey_challenge_ref IS NOT NULL) AND (passkey_rp_id IS NOT NULL) AND (passkey_origin IS NOT NULL) AND (passkey_challenge_expires_at IS NOT NULL) AND (passkey_challenge_expires_at <= discard_at)))),
    CONSTRAINT visitor_step_up_email_generation_valid CHECK ((((email_code_generation = 0) AND (email_credential_ref IS NULL) AND (email_code_digest IS NULL) AND (email_code_issued_at IS NULL) AND (email_code_expires_at IS NULL) AND (email_code_consumed_at IS NULL) AND (email_delivery_state IS NULL)) OR ((email_code_generation > 0) AND (email_credential_ref IS NOT NULL) AND (length((email_credential_ref)::text) > 0) AND (email_code_digest IS NOT NULL) AND ((email_code_digest)::text ~ '^[0-9a-f]{64}$'::text) AND (email_code_issued_at IS NOT NULL) AND (email_code_expires_at IS NOT NULL) AND (email_code_expires_at > email_code_issued_at) AND (email_code_expires_at <= (email_code_issued_at + '00:10:00'::interval)) AND (email_delivery_state IS NOT NULL) AND ((email_delivery_state)::text = ANY ((ARRAY['pending'::character varying, 'delivered'::character varying, 'failed'::character varying])::text[])) AND ((email_code_consumed_at IS NULL) OR (((email_delivery_state)::text = 'delivered'::text) AND (email_code_consumed_at >= email_code_issued_at) AND (email_code_consumed_at < email_code_expires_at))))))
);
ALTER TABLE ONLY public.visitor_step_up_sessions
    ADD CONSTRAINT visitor_step_up_sessions_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.visitor_step_up_sessions
    ADD CONSTRAINT fk_rails_b5a90759d5 FOREIGN KEY (step_up_ceremony_transaction_ref) REFERENCES public.visitor_step_up_ceremony_transactions(transaction_id) ON DELETE RESTRICT;
ALTER TABLE ONLY public.visitor_step_up_sessions
    ADD CONSTRAINT fk_rails_cd1cdc6b2d FOREIGN KEY (visitor_token_id) REFERENCES public.visitor_tokens(id) ON DELETE CASCADE NOT VALID;
```

Migration provenance: `db/com_tickets_migrate/20261003183734_bind_visitor_opaque_step_up_ceremonies.rb`, `db/com_tickets_migrate/20260518085549_rename_visitor_reauth_sessions_to_step_up_sessions.rb`, `db/com_tickets_migrate/20260921133000_rename_com_ticket_retention_columns_to_semantic_names.rb`, `db/com_tickets_migrate/20261003202134_bind_visitor_step_up_email_challenge.rb`.

### visitor_telephone_ceremony_transactions

Source: `db/com_ticket_structure.sql:967`. Machines: `idp-visitor-telephone-ceremony`.

```sql
CREATE TABLE visitor_telephone_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    operation character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    grant_jti character varying NOT NULL,
    result_jti character varying,
    telephone_candidate_ref character varying,
    normalized_number_digest character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);
ALTER TABLE ONLY public.visitor_telephone_ceremony_transactions
    ADD CONSTRAINT visitor_telephone_ceremony_transactions_pkey PRIMARY KEY (id);
```

Migration provenance: `db/com_tickets_migrate/20260603120002_create_visitor_telephone_ceremony_transactions.rb`.

### visitor_telephone_statuses

Source: `db/com_zenith_structure.sql:2765`. Machines: .

```sql
CREATE TABLE visitor_telephone_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.visitor_telephone_statuses
    ADD CONSTRAINT visitor_telephone_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/com_principals_migrate/20260513130000_rename_customer_actor_to_visitor.rb`.

### visitor_telephones

Source: `db/com_zenith_structure.sql:2793`. Machines: `idp-visitor-telephone-otp`, `idp-visitor-telephone-credential`.

```sql
CREATE TABLE visitor_telephones (
    id bigint NOT NULL,
    number character varying DEFAULT ''::character varying NOT NULL,
    number_digest character varying,
    locked_at timestamp(6) with time zone DEFAULT '-infinity'::timestamp with time zone NOT NULL,
    otp_attempts_count integer DEFAULT 0 NOT NULL,
    otp_counter text DEFAULT ''::text NOT NULL,
    otp_expires_at timestamp(6) with time zone DEFAULT '-infinity'::timestamp with time zone NOT NULL,
    otp_private_key character varying DEFAULT ''::character varying NOT NULL,
    public_id character varying(21) NOT NULL,
    visitor_id bigint NOT NULL,
    visitor_telephone_status_id bigint DEFAULT 1 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL
);
ALTER TABLE ONLY public.visitor_telephones
    ADD CONSTRAINT visitor_telephones_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.visitor_telephones
    ADD CONSTRAINT fk_rails_2de4d12c9f FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);
ALTER TABLE ONLY public.visitor_telephones
    ADD CONSTRAINT fk_rails_c534739d95 FOREIGN KEY (visitor_telephone_status_id) REFERENCES public.visitor_telephone_statuses(id);
```

Migration provenance: `db/com_zenith_migrate/20260921133000_rename_com_zenith_retention_columns_to_semantic_names.rb`, `db/com_principals_migrate/20260525131000_scope_visitor_contact_identifier_uniqueness_to_active_records.rb`, `db/com_principals_migrate/20260513130000_rename_customer_actor_to_visitor.rb`, `db/com_principals_migrate/20260518163000_remove_encrypted_identifier_lookup_indexes_from_visitor_identities.rb`, `db/com_principals_migrate/20260525120000_add_retention_to_visitor_sign_up_artifacts.rb`.

### visitor_token_binding_methods

Source: `db/com_ticket_structure.sql:1010`. Machines: .

```sql
CREATE TABLE visitor_token_binding_methods (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.visitor_token_binding_methods
    ADD CONSTRAINT visitor_token_binding_methods_pkey PRIMARY KEY (id);
```

Migration provenance: `db/com_tickets_migrate/20260513130000_rename_customer_actor_to_visitor.rb`.

### visitor_token_dbsc_statuses

Source: `db/com_ticket_structure.sql:1038`. Machines: .

```sql
CREATE TABLE visitor_token_dbsc_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.visitor_token_dbsc_statuses
    ADD CONSTRAINT visitor_token_dbsc_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/com_tickets_migrate/20260513130000_rename_customer_actor_to_visitor.rb`.

### visitor_token_kinds

Source: `db/com_ticket_structure.sql:1066`. Machines: .

```sql
CREATE TABLE visitor_token_kinds (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.visitor_token_kinds
    ADD CONSTRAINT visitor_token_kinds_pkey PRIMARY KEY (id);
```

Migration provenance: `db/com_tickets_migrate/20260513130000_rename_customer_actor_to_visitor.rb`.

### visitor_token_statuses

Source: `db/com_ticket_structure.sql:1094`. Machines: .

```sql
CREATE TABLE visitor_token_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.visitor_token_statuses
    ADD CONSTRAINT visitor_token_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/com_tickets_migrate/20260513130000_rename_customer_actor_to_visitor.rb`.

### visitor_tokens

Source: `db/com_ticket_structure.sql:1122`. Machines: `idp-visitor-token`, `idp-visitor-dbsc`.

```sql
CREATE TABLE visitor_tokens (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    visitor_id bigint NOT NULL,
    visitor_token_binding_method_id bigint DEFAULT 0 NOT NULL,
    visitor_token_dbsc_status_id bigint DEFAULT 0 NOT NULL,
    visitor_token_kind_id bigint DEFAULT 1 NOT NULL,
    visitor_token_status_id bigint DEFAULT 1 NOT NULL,
    dbsc_challenge text,
    dbsc_challenge_issued_at timestamp(6) with time zone,
    dbsc_public_key jsonb,
    dbsc_session_id character varying,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    last_step_up_at timestamp(6) with time zone,
    last_step_up_scope character varying,
    last_used_at timestamp(6) with time zone,
    public_id character varying(21) DEFAULT ''::character varying NOT NULL,
    refresh_token_digest bytea,
    refresh_token_family_id character varying,
    refresh_token_generation integer DEFAULT 0 NOT NULL,
    rotated_at timestamp(6) with time zone,
    updated_at timestamp(6) with time zone NOT NULL,
    dpop_jkt character varying,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    oidc_connection_id bigint,
    oidc_client_id character varying(64),
    oidc_scope character varying,
    oidc_sid uuid DEFAULT gen_random_uuid(),
    oidc_jti uuid DEFAULT gen_random_uuid(),
    device_session_id bigint,
    last_step_up_aal character varying,
    last_step_up_method character varying,
    last_step_up_purpose character varying,
    last_step_up_audience character varying,
    last_step_up_session_public_id character varying,
    selected_account_public_id character varying,
    selected_collective_public_id character varying,
    selected_collective_unit_public_id character varying,
    selected_at timestamp(6) with time zone,
    established_authentication_method character varying,
    last_step_up_phishing_resistant boolean DEFAULT false NOT NULL,
    authentication_event_at timestamp(6) with time zone,
    root_login_established_at timestamp with time zone,
    CONSTRAINT chk_customer_tokens_kind_id_positive CHECK ((visitor_token_kind_id >= 0)),
    CONSTRAINT chk_customer_tokens_status_id_positive CHECK ((visitor_token_status_id >= 0)),
    CONSTRAINT chk_visitor_tokens_established_authentication_method CHECK (((established_authentication_method IS NULL) OR ((established_authentication_method)::text = ANY ((ARRAY['email'::character varying, 'telephone'::character varying, 'secret'::character varying, 'passkey'::character varying])::text[]))))
);
ALTER TABLE ONLY public.visitor_tokens
    ADD CONSTRAINT visitor_tokens_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.visitor_tokens
    ADD CONSTRAINT fk_customer_tokens_on_customer_token_binding_method_id FOREIGN KEY (visitor_token_binding_method_id) REFERENCES public.visitor_token_binding_methods(id) NOT VALID;
ALTER TABLE ONLY public.visitor_tokens
    ADD CONSTRAINT fk_customer_tokens_on_customer_token_dbsc_status_id FOREIGN KEY (visitor_token_dbsc_status_id) REFERENCES public.visitor_token_dbsc_statuses(id) NOT VALID;
ALTER TABLE ONLY public.visitor_tokens
    ADD CONSTRAINT fk_customer_tokens_on_customer_token_kind_id FOREIGN KEY (visitor_token_kind_id) REFERENCES public.visitor_token_kinds(id) NOT VALID;
ALTER TABLE ONLY public.visitor_tokens
    ADD CONSTRAINT fk_customer_tokens_on_customer_token_status_id FOREIGN KEY (visitor_token_status_id) REFERENCES public.visitor_token_statuses(id) NOT VALID;
ALTER TABLE ONLY public.visitor_tokens
    ADD CONSTRAINT fk_visitor_tokens_on_device_session_id FOREIGN KEY (device_session_id) REFERENCES public.visitor_device_sessions(id) ON DELETE RESTRICT;
ALTER TABLE ONLY public.visitor_tokens
    ADD CONSTRAINT fk_visitor_tokens_on_visitor_id_and_device_session_id FOREIGN KEY (visitor_id, device_session_id) REFERENCES public.visitor_device_sessions(visitor_id, id) ON DELETE RESTRICT;
```

Migration provenance: `db/com_tickets_migrate/20260528183002_add_strict_step_up_state_to_visitor_tokens.rb`, `db/com_tickets_migrate/20260924151000_add_visitor_device_session_token_foreign_keys.rb`, `db/com_tickets_migrate/20260519092001_create_visitor_sign_out_cycles.rb`, `db/com_tickets_migrate/20260924150000_add_visitor_token_device_session_reference_index.rb`, `db/com_tickets_migrate/20260915160000_add_authentication_event_at_to_visitor_tokens.rb`, `db/com_tickets_migrate/20260920152000_restrict_visitor_sign_up_flow_token_delete.rb`, `db/com_tickets_migrate/20260924155000_add_visitor_token_device_session_actor_foreign_key.rb`, `db/com_tickets_migrate/20260727100001_validate_established_authentication_method_on_visitor_tokens.rb`, `db/com_tickets_migrate/20260831064132_add_last_step_up_phishing_resistant_to_visitor_tokens.rb`, `db/com_tickets_migrate/20260924156000_validate_visitor_token_device_session_actor_foreign_key.rb`, `db/com_tickets_migrate/20260513130000_rename_customer_actor_to_visitor.rb`, `db/com_tickets_migrate/20260520190002_create_device_sessions_for_visitor_tokens.rb`, `db/com_tickets_migrate/20260727100000_add_established_authentication_method_to_visitor_tokens.rb`, `db/com_tickets_migrate/20260525131500_restrict_visitor_sign_up_cycle_token_delete.rb`, `db/com_tickets_migrate/20260920152001_validate_restrict_visitor_sign_up_flow_token_delete.rb`, `db/com_tickets_migrate/20260921133000_rename_com_ticket_retention_columns_to_semantic_names.rb`, `db/com_tickets_migrate/20260526120102_remove_device_id_from_com_tickets.rb`, `db/com_tickets_migrate/20260518020002_create_visitor_oidc_connections.rb`, `db/com_tickets_migrate/20260616150010_add_on_delete_actions_to_visitor_ticket_foreign_keys.rb`, `db/com_tickets_migrate/20260518084935_create_com_sign_sequence_tickets.rb`, `db/com_tickets_migrate/20260519110001_add_oidc_identifiers_to_visitor_tokens.rb`, `db/com_tickets_migrate/20260517120002_add_single_column_seek_indexes_to_visitor_tokens.rb`, `db/com_tickets_migrate/20260519111001_remove_session_id_from_visitor_tokens.rb`, `db/com_tickets_migrate/20260924152000_validate_visitor_token_device_session_reference.rb`, `db/com_tickets_migrate/20260606120001_add_selected_context_to_visitor_tokens.rb`, `db/com_tickets_migrate/20261002120000_add_root_login_established_at_to_visitor_tokens.rb`.

### visitor_visibilities

Source: `db/com_zenith_structure.sql:2835`. Machines: .

```sql
CREATE TABLE visitor_visibilities (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.visitor_visibilities
    ADD CONSTRAINT visitor_visibilities_pkey PRIMARY KEY (id);
```

Migration provenance: `db/com_principals_migrate/20260513130000_rename_customer_actor_to_visitor.rb`, `db/com_principals_migrate/20260518181000_validate_remaining_com_principal_foreign_keys.rb`.

### visitor_withdrawal_ceremonies

Source: `db/com_zenith_structure.sql:2863`. Machines: `idp-visitor-withdrawal-ceremony`.

```sql
CREATE TABLE visitor_withdrawal_ceremonies (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    visitor_id bigint NOT NULL,
    purpose character varying NOT NULL,
    status_id integer DEFAULT 1 NOT NULL,
    token_digest bytea NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    ip_digest bytea,
    user_agent_digest bytea,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);
ALTER TABLE ONLY public.visitor_withdrawal_ceremonies
    ADD CONSTRAINT visitor_withdrawal_ceremonies_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.visitor_withdrawal_ceremonies
    ADD CONSTRAINT fk_rails_5cdc4d0fad FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);
```

Migration provenance: `db/com_principals_migrate/20260703010000_create_visitor_withdrawal_ceremonies.rb`.

### visitor_withdrawal_flow_events

Source: `db/com_zenith_structure.sql:2904`. Machines: .

```sql
CREATE TABLE visitor_withdrawal_flow_events (
    id bigint NOT NULL,
    visitor_withdrawal_flow_id bigint NOT NULL,
    visitor_id bigint NOT NULL,
    from_status_id bigint,
    to_status_id bigint NOT NULL,
    occurred_at timestamp(6) with time zone NOT NULL,
    token_public_id character varying(64) DEFAULT ''::character varying NOT NULL,
    reason character varying(64) DEFAULT ''::character varying NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);
ALTER TABLE ONLY public.visitor_withdrawal_flow_events
    ADD CONSTRAINT visitor_withdrawal_flow_events_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.visitor_withdrawal_flow_events
    ADD CONSTRAINT fk_rails_241fa58f6a FOREIGN KEY (visitor_id) REFERENCES public.visitors(id) ON DELETE CASCADE NOT VALID;
ALTER TABLE ONLY public.visitor_withdrawal_flow_events
    ADD CONSTRAINT fk_rails_4d4952ecfc FOREIGN KEY (to_status_id) REFERENCES public.visitor_withdrawal_flow_statuses(id) ON DELETE RESTRICT NOT VALID;
ALTER TABLE ONLY public.visitor_withdrawal_flow_events
    ADD CONSTRAINT fk_rails_606617dd12 FOREIGN KEY (visitor_withdrawal_flow_id) REFERENCES public.visitor_withdrawal_flows(id) NOT VALID;
ALTER TABLE ONLY public.visitor_withdrawal_flow_events
    ADD CONSTRAINT fk_rails_8ff74bc1cb FOREIGN KEY (from_status_id) REFERENCES public.visitor_withdrawal_flow_statuses(id) ON DELETE RESTRICT NOT VALID;
```

Migration provenance: `db/com_principals_migrate/20260530032500_rename_visitor_withdrawal_flow_tables.rb`, `db/com_principals_migrate/20260616150010_add_on_delete_actions_to_visitor_principal_foreign_keys.rb`.

### visitor_withdrawal_flow_statuses

Source: `db/com_zenith_structure.sql:2942`. Machines: .

```sql
CREATE TABLE visitor_withdrawal_flow_statuses (
    id bigint NOT NULL
);
ALTER TABLE ONLY public.visitor_withdrawal_flow_statuses
    ADD CONSTRAINT visitor_withdrawal_flow_statuses_pkey PRIMARY KEY (id);
```

Migration provenance: `db/com_principals_migrate/20260530032500_rename_visitor_withdrawal_flow_tables.rb`, `db/com_principals_migrate/20260616150010_add_on_delete_actions_to_visitor_principal_foreign_keys.rb`.

### visitor_withdrawal_flows

Source: `db/com_zenith_structure.sql:2970`. Machines: `idp-visitor-withdrawal`.

```sql
CREATE TABLE visitor_withdrawal_flows (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    visitor_id bigint NOT NULL,
    status_id bigint DEFAULT 10 NOT NULL,
    began_at timestamp(6) with time zone NOT NULL,
    completed_at timestamp(6) with time zone,
    failed_at timestamp(6) with time zone,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_visitor_withdrawal_cycles_retention_order CHECK ((discard_at <= purge_eligible_at))
);
ALTER TABLE ONLY public.visitor_withdrawal_flows
    ADD CONSTRAINT visitor_withdrawal_flows_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.visitor_withdrawal_flows
    ADD CONSTRAINT fk_rails_3e7b55d34f FOREIGN KEY (visitor_id) REFERENCES public.visitors(id) NOT VALID;
ALTER TABLE ONLY public.visitor_withdrawal_flows
    ADD CONSTRAINT fk_rails_8021cd7888 FOREIGN KEY (status_id) REFERENCES public.visitor_withdrawal_flow_statuses(id) NOT VALID;
```

Migration provenance: `db/com_zenith_migrate/20260921133000_rename_com_zenith_retention_columns_to_semantic_names.rb`, `db/com_principals_migrate/20260530032500_rename_visitor_withdrawal_flow_tables.rb`, `db/com_principals_migrate/20260519094001_create_visitor_withdrawal_cycles.rb`.

### visitors

Source: `db/com_zenith_structure.sql:3009`. Machines: `idp-visitor-administrative-access`, `idp-visitor-actor-withdrawal`, `idp-visitor-mfa-readiness`.

```sql
CREATE TABLE visitors (
    id bigint NOT NULL,
    deactivated_at timestamp(6) with time zone,
    purge_eligible_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    mfa_level_enabled boolean DEFAULT false NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    status_id bigint DEFAULT 2 NOT NULL,
    visibility_id bigint DEFAULT 1 NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    withdrawn_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp without time zone,
    withdrawal_started_at timestamp(6) with time zone,
    discard_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    mfa_level_id bigint DEFAULT 0 NOT NULL,
    mfa_status_id bigint DEFAULT 5 NOT NULL,
    terminated_at timestamp(6) with time zone,
    birthdate text,
    access_state character varying DEFAULT 'enabled'::character varying NOT NULL,
    admin_locked_at timestamp(6) with time zone,
    admin_locked_by_operator_id bigint,
    admin_locked_reason_code character varying,
    admin_locked_reason_note text,
    token_valid_after_at timestamp(6) with time zone,
    reactivated_at timestamp(6) with time zone,
    webauthn_user_handle character varying NOT NULL,
    CONSTRAINT chk_customers_retention_order CHECK ((discard_at <= purge_eligible_at)),
    CONSTRAINT chk_visitors_access_state CHECK (((access_state)::text = ANY ((ARRAY['enabled'::character varying, 'admin_locked'::character varying])::text[]))),
    CONSTRAINT chk_visitors_admin_locked_reason_code CHECK (((admin_locked_reason_code IS NULL) OR ((admin_locked_reason_code)::text = ANY ((ARRAY['abuse'::character varying, 'security_incident'::character varying, 'chargeback'::character varying, 'terms_violation'::character varying, 'support_request'::character varying, 'legal_hold'::character varying, 'operator_error_recovery'::character varying, 'other'::character varying])::text[])))),
    CONSTRAINT chk_visitors_birthdate_length CHECK (((birthdate IS NULL) OR (char_length(birthdate) <= 1000)))
);
ALTER TABLE ONLY public.visitors
    ADD CONSTRAINT visitors_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.visitors
    ADD CONSTRAINT fk_rails_15c7fee824 FOREIGN KEY (mfa_level_id) REFERENCES public.visitor_mfa_levels(id);
ALTER TABLE ONLY public.visitors
    ADD CONSTRAINT fk_rails_6e2a03b63d FOREIGN KEY (mfa_status_id) REFERENCES public.visitor_mfa_statuses(id);
ALTER TABLE ONLY public.visitors
    ADD CONSTRAINT fk_rails_b66f17957a FOREIGN KEY (status_id) REFERENCES public.visitor_statuses(id);
ALTER TABLE ONLY public.visitors
    ADD CONSTRAINT fk_rails_d25b75677b FOREIGN KEY (visibility_id) REFERENCES public.visitor_visibilities(id);
```

Migration provenance: `db/com_zenith_migrate/20260511223458_create_client_visitors.rb`, `db/com_zenith_migrate/20260519161002_rename_com_rp_tables.rb`, `db/com_zenith_migrate/20260917120001_create_com_authority_relations.rb`, `db/com_zenith_migrate/20260921133000_rename_com_zenith_retention_columns_to_semantic_names.rb`, `db/com_principals_migrate/20260616150010_add_on_delete_actions_to_visitor_principal_foreign_keys.rb`, `db/com_principals_migrate/20260530032400_rename_visitor_mfa_enabled_column.rb`, `db/com_principals_migrate/20260518120000_add_terminated_at_to_visitors.rb`, `db/com_principals_migrate/20260518170001_validate_visitors_birthdate_length.rb`, `db/com_principals_migrate/20260528162002_harden_visitor_lifecycle_and_mfa_constraints.rb`, `db/com_principals_migrate/20260513130000_rename_customer_actor_to_visitor.rb`, `db/com_principals_migrate/20260514143000_default_visitor_multi_factor_status_to_unconfigured.rb`, `db/com_principals_migrate/20260614090001_validate_administrative_access_lock_on_visitors.rb`, `db/com_principals_migrate/20260719100001_add_webauthn_user_handle_to_visitors.rb`, `db/com_principals_migrate/20260530032100_rename_visitor_mfa_columns.rb`, `db/com_principals_migrate/20260518121000_create_visitor_preferences.rb`, `db/com_principals_migrate/20260519173000_create_visitor_banners.rb`, `db/com_principals_migrate/20260519094001_create_visitor_withdrawal_cycles.rb`, `db/com_principals_migrate/20260614090000_add_administrative_access_lock_to_visitors.rb`, `db/com_principals_migrate/20260514140000_add_multi_factor_status_reference_to_visitors.rb`, `db/com_principals_migrate/20260518181000_validate_remaining_com_principal_foreign_keys.rb`, `db/com_principals_migrate/20260518170000_add_birthdate_to_visitors.rb`, `db/com_principals_migrate/20260513161000_add_multi_factor_reference_to_visitors.rb`, `db/com_principals_migrate/20260518180000_add_discarded_at_index_to_visitors.rb`, `db/app_principals_migrate/20260518180001_backfill_and_default_users_purged_at.rb`.

## Non-SQL owners

- `idp-shared-sequence-carrier`: None (Rails session); no SQL PK/state FK/CHECK/default applies. See its transition section for session key / Valkey lifecycle and TTL.
- `idp-shared-authorization-code`: None (Valkey); no SQL PK/state FK/CHECK/default applies. See its transition section for session key / Valkey lifecycle and TTL.
- `idp-shared-opaque-admission`: None (Valkey); no SQL PK/state FK/CHECK/default applies. See its transition section for session key / Valkey lifecycle and TTL.
- `idp-shared-webauthn-challenge`: None (Rails session); no SQL PK/state FK/CHECK/default applies. See its transition section for session key / Valkey lifecycle and TTL.
- `idp-shared-sign-out-notice`: None (Valkey); no SQL PK/state FK/CHECK/default applies. See its transition section for session key / Valkey lifecycle and TTL.

## Schema/model observations

- Sign-in/sign-up retain `status_id`, `state`, and `step`; model consistency and any checked-in CHECKs are distinct evidence. Historical migration constraints are not assumed present when absent from the current structure.
- OperatorPasskey SQL default is 0; current model explicitly defaults ACTIVE=1. OperatorPasskeyStatus declares only1/2. The source annotation claiming default1 is not the SQL evidence.
- ClientSecretCredential current rebuild owns confirmation/claim/revocation facts without a state-reference FK. Legacy SecretCredentialStatus and old status writers/tests do not describe this rebuilt storage. WithdrawalPersonalDataAnonymizer still names `user_secret_status_id`; compatibility with the current Client model is UNCONFIRMED.
- OperatorEntraIdentity inherits OrgRpRecord and OrgRpRecord currently inherits the consolidated OrgZenithRecord connection owner, matching org_zenith structure. Semantic class names do not imply separate databases.
- Timestamp-derived machines can overlap; no mutually exclusive status enum or FK is invented for them.
