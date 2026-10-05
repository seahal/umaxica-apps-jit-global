# State/status SQL candidate disposition

Discovery across all checked-in structures; current data, actual reference rows and runtime wiring are UNCONFIRMED. Indexed machines are linked in README. Unindexed columns are retained here as domain/lookup/event candidates rather than omitted. Table-name classification alone never creates a transition. Timestamp-only authentication candidates were independently searched in Ruby and are indexed in README.

| Table | State/status-like columns | Disposition | SQL source |
| --- | --- | --- | --- |
| account_access_events | previous_access_state, next_access_state | Recorded event/history; not independent authentication progression | db/chronicle_structure.sql:35 |
| acme_logout_transactions | callback_state, status | Indexed: idp-shared-acme-logout | db/app_ticket_structure.sql:49 |
| agent_lifecycles | state, state_changed_at | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/org_zenith_structure.sql:208 |
| agent_memberships | membership_state_id | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/org_zenith_structure.sql:326 |
| agent_ownership_transfer_requests | status | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/org_zenith_structure.sql:370 |
| app_enforcement_appeals | state, statement | Indexed: idp-client-enforcement-appeal | db/app_zenith_structure.sql:146 |
| app_enforcement_cases | state | Indexed: idp-client-enforcement-case | db/app_zenith_structure.sql:227 |
| app_preferences | dbsc_status_id, status_id | Indexed: idp-client-preference-dbsc | db/app_setting_structure.sql:830 |
| area_occurrences | status_id | Recorded event/history; not independent authentication progression | db/occurrence_structure.sql:217 |
| avatar_groups | state | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/avatar_structure.sql:251 |
| avatar_lifecycle_events | from_state_key, to_state_key | Recorded event/history; not independent authentication progression | db/avatar_structure.sql:327 |
| avatar_memberships | avatar_membership_status_id | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/avatar_structure.sql:435 |
| avatar_ownership_periods | avatar_ownership_status_id | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/avatar_structure.sql:544 |
| avatar_ownership_transfers | state | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/avatar_structure.sql:612 |
| avatars | avatar_status_id, lifecycle_state_id | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/avatar_structure.sql:790 |
| blazer_checks | state | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/structure.sql:33 |
| blazer_queries | statement, status | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/structure.sql:137 |
| bureau_lifecycles | state, state_changed_at | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/org_zenith_structure.sql:658 |
| bureau_ownership_transfer_requests | status | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/org_zenith_structure.sql:692 |
| chronicle_outbox_entries | status | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/chronicle_structure.sql:582 |
| client_apple_notification_events | status | Indexed: idp-client-apple-notification | db/app_zenith_structure.sql:498 |
| client_device_sessions | status_id | Indexed: idp-client-device-session | db/app_ticket_structure.sql:156 |
| client_email_ceremony_transactions | status | Indexed: idp-client-email-ceremony, idp-client-email-verification-challenge | db/app_ticket_structure.sql:237 |
| client_emails | user_email_status_id | Indexed: idp-client-email-otp, idp-client-email-credential | db/app_zenith_structure.sql:674 |
| client_enforcement_recovery_ceremonies | status_id | Indexed: idp-client-enforcement-recovery-ceremony | db/app_zenith_structure.sql:726 |
| client_external_identities | state | Indexed: idp-client-external-identity | db/app_zenith_structure.sql:765 |
| client_identities | status_id | Lookup/configuration candidate; no current existing-row authentication transition writer found; runtime reachability UNCONFIRMED | db/app_zenith_structure.sql:807 |
| client_oauth_callback_states | state_digest | Indexed: idp-client-oauth-callback | db/app_ticket_structure.sql:322 |
| client_occurrences | status_id | Recorded event/history; not independent authentication progression | db/occurrence_structure.sql:411 |
| client_oidc_authorization_transactions | state, status | Indexed: idp-client-oidc-authorization | db/app_ticket_structure.sql:358 |
| client_passkey_ceremony_transactions | status | Indexed: idp-client-passkey-ceremony | db/app_ticket_structure.sql:455 |
| client_passkeys | status_id, backup_state | Indexed: idp-client-passkey-credential | db/app_zenith_structure.sql:1215 |
| client_persona_lifecycles | state, state_changed_at | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/app_zenith_structure.sql:1361 |
| client_persona_ownership_transfer_requests | status | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/app_zenith_structure.sql:1395 |
| client_privacy_requests | status_id | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/app_zenith_structure.sql:2277 |
| client_processor_erasure_notifications | status_id | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/app_zenith_structure.sql:2403 |
| client_profiles | client_status_id, status_id | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/app_zenith_structure.sql:2481 |
| client_retention_holds | status_id | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/app_zenith_structure.sql:2547 |
| client_rp_sessions | last_logout_status | Indexed: idp-client-rp-session | db/app_ticket_structure.sql:501 |
| client_secret_credential_ceremony_transactions | status | Indexed: idp-client-secret-credential-ceremony | db/app_ticket_structure.sql:551 |
| client_session_limit_resolution_transactions | status | Indexed: idp-client-session-limit-resolution | db/app_ticket_structure.sql:632 |
| client_sign_in_flows | state, status_id | Indexed: idp-client-sign-in, idp-client-local-result-delivery | db/app_ticket_structure.sql:703 |
| client_sign_out_flows | status_id | Indexed: idp-client-sign-out | db/app_ticket_structure.sql:822 |
| client_sign_up_flows | state, status_id, cleanup_status_id | Indexed: idp-client-sign-up, idp-client-sign-up-cleanup | db/app_ticket_structure.sql:927 |
| client_social_ceremony_transactions | status | Indexed: idp-client-social-ceremony | db/app_ticket_structure.sql:998 |
| client_step_up_ceremony_transactions | status | Indexed: idp-client-step-up-ceremony | db/app_ticket_structure.sql:1044 |
| client_step_up_sessions | status, email_delivery_state | Indexed: idp-client-step-up-session, idp-client-step-up-passkey-challenge, idp-client-step-up-email-challenge | db/app_ticket_structure.sql:1106 |
| client_telephone_ceremony_transactions | status | Indexed: idp-client-telephone-ceremony | db/app_ticket_structure.sql:1161 |
| client_telephones | user_identity_telephone_status_id | Indexed: idp-client-telephone-otp, idp-client-telephone-credential | db/app_zenith_structure.sql:2787 |
| client_tokens | user_token_dbsc_status_id, user_token_status_id | Indexed: idp-client-token, idp-client-dbsc | db/app_ticket_structure.sql:1316 |
| client_totp_ceremony_transactions | status | Indexed: idp-client-totp-ceremony | db/app_ticket_structure.sql:1389 |
| client_totp_credentials | user_identity_totp_credential_status_id | Indexed: idp-client-totp-credential | db/app_zenith_structure.sql:2857 |
| client_withdrawal_ceremonies | status_id | Indexed: idp-client-withdrawal-ceremony | db/app_zenith_structure.sql:2923 |
| client_withdrawal_flow_events | from_status_id, to_status_id | Recorded event/history; not independent authentication progression | db/app_zenith_structure.sql:2964 |
| client_withdrawal_flows | status_id | Indexed: idp-client-withdrawal | db/app_zenith_structure.sql:3030 |
| clients | status_id, mfa_status_id, access_state | Indexed: idp-client-administrative-access, idp-client-actor-withdrawal, idp-client-actor-provisioning, idp-client-mfa-readiness | db/app_zenith_structure.sql:3069 |
| com_enforcement_appeals | state, statement | Indexed: idp-visitor-enforcement-appeal | db/com_zenith_structure.sql:82 |
| com_enforcement_cases | state | Indexed: idp-visitor-enforcement-case | db/com_zenith_structure.sql:162 |
| com_preferences | dbsc_status_id, status_id | Indexed: idp-visitor-preference-dbsc | db/com_setting_structure.sql:842 |
| company_lifecycles | state, state_changed_at | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/com_zenith_structure.sql:482 |
| company_ownership_transfer_requests | status | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/com_zenith_structure.sql:516 |
| departments | department_status_id | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/org_zenith_structure.sql:972 |
| divisions | division_status_id | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/org_zenith_structure.sql:1034 |
| domain_occurrences | status_id | Recorded event/history; not independent authentication progression | db/occurrence_structure.sql:606 |
| email_occurrences | status_id | Recorded event/history; not independent authentication progression | db/occurrence_structure.sql:831 |
| enterprise_lifecycles | state, state_changed_at | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/app_zenith_structure.sql:3259 |
| enterprise_ownership_transfer_requests | status | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/app_zenith_structure.sql:3293 |
| group_avatar_memberships | state | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/avatar_structure.sql:1057 |
| handle_assignments | handle_assignment_status_id | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/avatar_structure.sql:1127 |
| handles | handle_status_id | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/avatar_structure.sql:1192 |
| individual_lifecycles | state, state_changed_at | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/com_zenith_structure.sql:866 |
| individual_memberships | membership_state_id | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/com_zenith_structure.sql:984 |
| individual_ownership_transfer_requests | status | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/com_zenith_structure.sql:1028 |
| ip_occurrences | status_id | Recorded event/history; not independent authentication progression | db/occurrence_structure.sql:1057 |
| jwt_occurrences | status_id | Recorded event/history; not independent authentication progression | db/occurrence_structure.sql:1294 |
| legacy_operator_department_accounts | status_id | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/org_zenith_structure.sql:1067 |
| legacy_replaced_clients | client_status_id, status_id | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/app_zenith_structure.sql:3574 |
| members | status_id | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/app_zenith_structure.sql:3641 |
| operator_device_sessions | status_id | Indexed: idp-operator-device-session | db/org_ticket_structure.sql:113 |
| operator_email_ceremony_transactions | status | Indexed: idp-operator-email-ceremony, idp-operator-email-verification-challenge | db/org_ticket_structure.sql:194 |
| operator_emails | staff_identity_email_status_id | Indexed: idp-operator-email-otp, idp-operator-email-credential | db/org_zenith_structure.sql:1315 |
| operator_entra_identities | status_id | Indexed: idp-operator-entra-identity | db/org_zenith_structure.sql:1360 |
| operator_google_identities | status_id | Lookup/configuration candidate; no current existing-row authentication transition writer found; runtime reachability UNCONFIRMED | db/org_zenith_structure.sql:1427 |
| operator_identities | status_id | Lookup/configuration candidate; no current existing-row authentication transition writer found; runtime reachability UNCONFIRMED | db/org_zenith_structure.sql:1493 |
| operator_lifecycle_requests | status | Indexed: idp-operator-operator-lifecycle | db/org_zenith_structure.sql:1559 |
| operator_oauth_callback_states | state_digest | Indexed: idp-operator-oauth-callback | db/org_ticket_structure.sql:246 |
| operator_occurrences | status_id | Recorded event/history; not independent authentication progression | db/occurrence_structure.sql:1393 |
| operator_oidc_authorization_transactions | state, status | Indexed: idp-operator-oidc-authorization | db/org_ticket_structure.sql:282 |
| operator_passkey_ceremony_transactions | status | Indexed: idp-operator-passkey-ceremony | db/org_ticket_structure.sql:379 |
| operator_passkeys | status_id, backup_state | Indexed: idp-operator-passkey-credential | db/org_zenith_structure.sql:1691 |
| operator_rp_sessions | last_logout_status | Indexed: idp-operator-rp-session | db/org_ticket_structure.sql:425 |
| operator_secret_credential_ceremony_transactions | status | Indexed: idp-operator-secret-credential-ceremony | db/org_ticket_structure.sql:475 |
| operator_secret_credentials | staff_identity_secret_status_id | Indexed: idp-operator-secret-credential | db/org_zenith_structure.sql:2502 |
| operator_sign_in_flows | state, status_id | Indexed: idp-operator-sign-in, idp-operator-local-result-delivery | db/org_ticket_structure.sql:546 |
| operator_sign_out_flows | status_id | Indexed: idp-operator-sign-out | db/org_ticket_structure.sql:665 |
| operator_sign_up_flows | state, status_id | Indexed: idp-operator-sign-up | db/org_ticket_structure.sql:742 |
| operator_step_up_ceremony_transactions | status | Indexed: idp-operator-step-up-ceremony | db/org_ticket_structure.sql:799 |
| operator_step_up_sessions | status | Indexed: idp-operator-step-up-session, idp-operator-step-up-passkey-challenge | db/org_ticket_structure.sql:861 |
| operator_telephone_ceremony_transactions | status | Indexed: idp-operator-telephone-ceremony | db/org_ticket_structure.sql:908 |
| operator_telephones | staff_identity_telephone_status_id | Indexed: idp-operator-telephone-otp, idp-operator-telephone-credential | db/org_zenith_structure.sql:2617 |
| operator_tokens | staff_token_dbsc_status_id, staff_token_status_id | Indexed: idp-operator-token, idp-operator-dbsc | db/org_ticket_structure.sql:1063 |
| operator_workspace_accounts | status_id | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/org_zenith_structure.sql:2744 |
| operators | status_id, mfa_status_id, access_state | Indexed: idp-operator-administrative-access, idp-operator-actor-withdrawal, idp-operator-mfa-readiness | db/org_zenith_structure.sql:2780 |
| org_enforcement_appeals | state, statement | Indexed: idp-operator-enforcement-appeal | db/org_zenith_structure.sql:2838 |
| org_enforcement_cases | state | Indexed: idp-operator-enforcement-case | db/org_zenith_structure.sql:2918 |
| org_preferences | dbsc_status_id, status_id | Indexed: idp-operator-preference-dbsc | db/org_setting_structure.sql:842 |
| organization_entra_connections | status_id | Lookup/configuration candidate; no current existing-row authentication transition writer found; runtime reachability UNCONFIRMED | db/org_zenith_structure.sql:3135 |
| organizations | workspace_status_id | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/org_zenith_structure.sql:3201 |
| persona_memberships | membership_state_id | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/app_zenith_structure.sql:3797 |
| post_reviews | post_review_status_id | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/avatar_structure.sql:1480 |
| posts | post_status_id | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/avatar_structure.sql:1586 |
| publishing_docs_app_entry_slugs | state | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/publishing_structure.sql:234 |
| publishing_docs_com_entry_slugs | state | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/publishing_structure.sql:812 |
| publishing_docs_org_entry_slugs | state | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/publishing_structure.sql:1390 |
| publishing_help_app_entry_slugs | state | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/publishing_structure.sql:1968 |
| publishing_help_com_entry_slugs | state | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/publishing_structure.sql:2546 |
| publishing_help_org_entry_slugs | state | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/publishing_structure.sql:3124 |
| publishing_info_app_entry_slugs | state | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/publishing_structure.sql:3702 |
| publishing_info_com_entry_slugs | state | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/publishing_structure.sql:4280 |
| publishing_info_org_entry_slugs | state | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/publishing_structure.sql:4858 |
| publishing_news_app_entry_slugs | state | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/publishing_structure.sql:5485 |
| publishing_news_com_entry_slugs | state | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/publishing_structure.sql:6063 |
| publishing_news_org_entry_slugs | state | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/publishing_structure.sql:6641 |
| telephone_occurrences | status_id | Recorded event/history; not independent authentication progression | db/occurrence_structure.sql:1565 |
| visitor_device_sessions | status_id | Indexed: idp-visitor-device-session | db/com_ticket_structure.sql:158 |
| visitor_email_ceremony_transactions | status | Indexed: idp-visitor-email-ceremony, idp-visitor-email-verification-challenge | db/com_ticket_structure.sql:239 |
| visitor_emails | visitor_email_status_id | Indexed: idp-visitor-email-otp, idp-visitor-email-credential | db/com_zenith_structure.sql:1344 |
| visitor_enforcement_recovery_ceremonies | status_id | Indexed: idp-visitor-enforcement-recovery-ceremony | db/com_zenith_structure.sql:1396 |
| visitor_identities | status_id | Lookup/configuration candidate; no current existing-row authentication transition writer found; runtime reachability UNCONFIRMED | db/com_zenith_structure.sql:1435 |
| visitor_occurrences | status_id | Recorded event/history; not independent authentication progression | db/occurrence_structure.sql:1664 |
| visitor_oidc_authorization_transactions | state, status | Indexed: idp-visitor-oidc-authorization | db/com_ticket_structure.sql:291 |
| visitor_passkey_ceremony_transactions | status | Indexed: idp-visitor-passkey-ceremony | db/com_ticket_structure.sql:388 |
| visitor_passkeys | status_id, backup_state | Indexed: idp-visitor-passkey-credential | db/com_zenith_structure.sql:1585 |
| visitor_privacy_requests | status_id | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/com_zenith_structure.sql:2372 |
| visitor_processor_erasure_notifications | status_id | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/com_zenith_structure.sql:2498 |
| visitor_retention_holds | status_id | Outside IdP/authentication progression: domain/infrastructure candidate; no transition imported into this scope | db/com_zenith_structure.sql:2577 |
| visitor_rp_sessions | last_logout_status | Indexed: idp-visitor-rp-session | db/com_ticket_structure.sql:434 |
| visitor_secret_credential_ceremony_transactions | status | Indexed: idp-visitor-secret-credential-ceremony | db/com_ticket_structure.sql:484 |
| visitor_secret_credentials | visitor_secret_credential_status_id | Indexed: idp-visitor-secret-credential | db/com_zenith_structure.sql:2677 |
| visitor_sign_in_flows | state, status_id | Indexed: idp-visitor-sign-in, idp-visitor-local-result-delivery | db/com_ticket_structure.sql:555 |
| visitor_sign_out_flows | status_id | Indexed: idp-visitor-sign-out | db/com_ticket_structure.sql:674 |
| visitor_sign_up_flows | state, status_id, cleanup_status_id | Indexed: idp-visitor-sign-up, idp-visitor-sign-up-cleanup | db/com_ticket_structure.sql:779 |
| visitor_step_up_ceremony_transactions | status | Indexed: idp-visitor-step-up-ceremony | db/com_ticket_structure.sql:850 |
| visitor_step_up_sessions | status, email_delivery_state | Indexed: idp-visitor-step-up-session, idp-visitor-step-up-passkey-challenge, idp-visitor-step-up-email-challenge | db/com_ticket_structure.sql:912 |
| visitor_telephone_ceremony_transactions | status | Indexed: idp-visitor-telephone-ceremony | db/com_ticket_structure.sql:967 |
| visitor_telephones | visitor_telephone_status_id | Indexed: idp-visitor-telephone-otp, idp-visitor-telephone-credential | db/com_zenith_structure.sql:2793 |
| visitor_tokens | visitor_token_dbsc_status_id, visitor_token_status_id | Indexed: idp-visitor-token, idp-visitor-dbsc | db/com_ticket_structure.sql:1122 |
| visitor_withdrawal_ceremonies | status_id | Indexed: idp-visitor-withdrawal-ceremony | db/com_zenith_structure.sql:2863 |
| visitor_withdrawal_flow_events | from_status_id, to_status_id | Recorded event/history; not independent authentication progression | db/com_zenith_structure.sql:2904 |
| visitor_withdrawal_flows | status_id | Indexed: idp-visitor-withdrawal | db/com_zenith_structure.sql:2970 |
| visitors | status_id, mfa_status_id, access_state | Indexed: idp-visitor-administrative-access, idp-visitor-actor-withdrawal, idp-visitor-mfa-readiness | db/com_zenith_structure.sql:3009 |
| zip_occurrences | status_id | Recorded event/history; not independent authentication progression | db/occurrence_structure.sql:1731 |

## Supporting authentication fact tables

- `client_secret_sign_in_receipts`: immutable commit evidence; no progression API or production creation caller confirmed.
- `client_secret_audit_outboxes`: immutable source audit facts and delivery metadata; event names do not imply implemented credential transitions.
- DPoP JTI / SecurityConsumedJti / Turnstile replay ledgers: insert-only replay evidence; nonce-use machine separately indexed.
- Sign/withdrawal event tables: previous/next FK references audit a transition, not an additional current-state authority.
