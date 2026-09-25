# PostgreSQL Integrity Current Static Inventory

This inventory was derived from checked-in structure snapshots and application model files at commit `2b027d5b38989d3068e4620262bfa6c6fde8df41` with uncommitted changes present. The table classifications remain static and are not proof of runtime use. The historic F-01–F-21 audit report was not attached. A subsequent read-only live catalog and aggregate violation check is recorded in `evidence/2026-09-24-postgresql-live-integrity-D8M4.md`.

Classification is conservative: `ACTIVE_APP` means a model file has an explicit or inferred table mapping; it does not prove runtime traffic. `LEGACY_CANDIDATE` means the table name itself uses a legacy prefix. `THIRD_PARTY` covers Rails metadata and recognized gem tables. All other tables are `UNCERTAIN` in this static snapshot. The later live audit traced all 70 model-free candidates to application creation or rename migrations and classified them as owned; current runtime use remains unverified. No table is safe to remove based on this inventory.

| Snapshot | Tables | ACTIVE_APP | LEGACY_CANDIDATE | THIRD_PARTY | UNCERTAIN | NOT VALID constraints in dump |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `app_setting_structure.sql` | 29 | 27 | 0 | 2 | 0 | 9 |
| `app_signal_structure.sql` | 4 | 2 | 0 | 2 | 0 | 1 |
| `app_ticket_structure.sql` | 40 | 38 | 0 | 2 | 0 | 17 |
| `app_zenith_structure.sql` | 113 | 98 | 3 | 2 | 10 | 6 |
| `avatar_structure.sql` | 47 | 33 | 0 | 2 | 12 | 4 |
| `chronicle_structure.sql` | 60 | 22 | 0 | 2 | 36 | 23 |
| `com_setting_structure.sql` | 29 | 27 | 0 | 2 | 0 | 13 |
| `com_signal_structure.sql` | 3 | 1 | 0 | 2 | 0 | 0 |
| `com_ticket_structure.sql` | 28 | 26 | 0 | 2 | 0 | 17 |
| `com_zenith_structure.sql` | 84 | 82 | 0 | 2 | 0 | 6 |
| `occurrence_structure.sql` | 54 | 52 | 0 | 2 | 0 | 63 |
| `org_setting_structure.sql` | 29 | 27 | 0 | 2 | 0 | 13 |
| `org_signal_structure.sql` | 4 | 2 | 0 | 2 | 0 | 1 |
| `org_ticket_structure.sql` | 29 | 27 | 0 | 2 | 0 | 17 |
| `org_zenith_structure.sql` | 99 | 84 | 1 | 2 | 12 | 13 |
| `publishing_structure.sql` | 159 | 157 | 0 | 2 | 0 | 0 |
| `queue_structure.sql` | 15 | 0 | 0 | 15 | 0 | 0 |
| `search_structure.sql` | 2 | 0 | 0 | 2 | 0 | 0 |
| `storage_structure.sql` | 2 | 0 | 0 | 2 | 0 | 0 |
| `structure.sql` | 8 | 0 | 0 | 8 | 0 | 0 |

Total: 838 tables; 203 `NOT VALID` constraints in the snapshots. These are static counts, not counts of live invalid constraints.

A comparison of the full normalized `CREATE INDEX` definitions within each snapshot found no
exact duplicate index definitions under different names. This does not prove that prefix or
expression indexes are redundant, nor that the live catalog matches the snapshots. The one-column
token device-session indexes in the three ticket databases are replaced by composite indexes with
the same leading key as part of the separately approved reference migration.

The `queue`, `search`, `storage`, and primary `structure.sql` snapshots contain only recognized framework/gem tables under this classification. The other snapshots are logical application databases; the live development catalog observations are recorded separately in evidence. No shared database was changed.

## Finding disposition from the available evidence

The original report is unavailable, so these are prompt-category dispositions rather than a recovered historic object-by-object finding map. For F-01/F-02/F-15, the named ticket targets are `app_ticket.client_tokens/client_device_sessions`, `com_ticket.visitor_tokens/visitor_device_sessions`, and `org_ticket.operator_tokens/operator_device_sessions`. Their local migrations were applied and verified on three isolated task-owned databases; shared databases remain unchanged.

| Finding | Target category | Static disposition |
| --- | --- | --- |
| F-01 | same-database references | CONFIRMED for three ticket token/session pairs; other targets NOT_VERIFIED |
| F-02 | reference ownership and lifecycle | CONFIRMED for three ticket token/session pairs; other targets NOT_VERIFIED |
| F-03 | existing unvalidated constraints | CONFIRMED for 203 constraints in 14 development databases; migration pending shape approval |
| F-04 | finite state values | NOT_VERIFIED |
| F-05 | finite kind values | NOT_VERIFIED |
| F-06 | column nullability and ranges | NOT_VERIFIED |
| F-07 | column lengths and storage formats | NOT_VERIFIED |
| F-08 | index coverage | NOT_VERIFIED |
| F-09 | partitioning | OUT_OF_SCOPE |
| F-10 | index redundancy and roles | NOT_VERIFIED |
| F-11 | preference consolidation | OUT_OF_SCOPE |
| F-12 | bytea and public identifier contracts | NOT_VERIFIED |
| F-13 | JSON structure contracts | NOT_VERIFIED |
| F-14 | index coverage and cost | NOT_VERIFIED |
| F-15 | same-session and same-actor references | CONFIRMED for three ticket token/session pairs; other targets NOT_VERIFIED |
| F-16 | self-replacement creation contract | NOT_VERIFIED |
| F-17 | legacy table candidates | NEEDS_DECISION for named candidates; other targets NOT_VERIFIED |
| F-18 | legacy column candidates | NEEDS_DECISION for named candidates; other targets NOT_VERIFIED |
| F-19 | legacy type changes | NEEDS_DECISION for named candidates; other targets NOT_VERIFIED |
| F-20 | legacy removal | NEEDS_DECISION for named candidates; other targets NOT_VERIFIED |
| F-21 | existing unvalidated constraints | CONFIRMED for the same 203 constraints; migration pending shape approval |

The development catalog contains 203 `NOT VALID` definitions, matching the snapshot count. All 101 affected development tables were empty, so the read-only aggregate check's zero violations are vacuous and do not establish populated-data compatibility. Formal validation and other environments remain separate decisions. No full duplicate index definitions were found in the snapshots; the later live audit identified four same-key PK index pairs in `com_zenith` for review. Partitioning and preference consolidation are deferred by the task; legacy-named or model-free tables are not removal candidates without use evidence.
## Table inventory

## app_setting_structure.sql

### ACTIVE_APP (27)

- `public.app_preference_adult_content_gate_options`, `public.app_preference_adult_content_gates`, `public.app_preference_binding_methods`, `public.app_preference_cookies`, `public.app_preference_currencies`, `public.app_preference_currency_options`, `public.app_preference_date_format_options`, `public.app_preference_date_formats`
- `public.app_preference_dbsc_statuses`, `public.app_preference_densities`, `public.app_preference_density_options`, `public.app_preference_language_options`, `public.app_preference_languages`, `public.app_preference_motion_options`, `public.app_preference_motions`, `public.app_preference_page_size_options`
- `public.app_preference_page_sizes`, `public.app_preference_region_options`, `public.app_preference_regions`, `public.app_preference_statuses`, `public.app_preference_theme_options`, `public.app_preference_themes`, `public.app_preference_time_format_options`, `public.app_preference_time_formats`
- `public.app_preference_timezone_options`, `public.app_preference_timezones`, `public.app_preferences`

### THIRD_PARTY (2)

- `public.ar_internal_metadata`, `public.schema_migrations`

## app_signal_structure.sql

### ACTIVE_APP (2)

- `public.client_notification_records`, `public.member_notifications`

### THIRD_PARTY (2)

- `public.ar_internal_metadata`, `public.schema_migrations`

## app_ticket_structure.sql

### ACTIVE_APP (38)

- `public.acme_logout_transactions`, `public.client_auth_ceremony_sessions`, `public.client_device_sessions`, `public.client_dpop_proof_states`, `public.client_email_ceremony_transactions`, `public.client_oauth_callback_states`, `public.client_oidc_authorization_transactions`, `public.client_oidc_connections`
- `public.client_passkey_ceremony_transactions`, `public.client_rp_sessions`, `public.client_secret_credential_ceremony_transactions`, `public.client_session_limit_resolution_transactions`, `public.client_sign_in_flow_statuses`, `public.client_sign_in_flows`, `public.client_sign_out_flow_kinds`, `public.client_sign_out_flow_statuses`
- `public.client_sign_out_flows`, `public.client_sign_up_flow_cleanup_statuses`, `public.client_sign_up_flow_statuses`, `public.client_sign_up_flows`, `public.client_social_ceremony_transactions`, `public.client_step_up_ceremony_transactions`, `public.client_step_up_sessions`, `public.client_telephone_ceremony_transactions`
- `public.client_token_binding_methods`, `public.client_token_dbsc_statuses`, `public.client_token_kinds`, `public.client_token_statuses`, `public.client_tokens`, `public.client_totp_ceremony_transactions`, `public.client_verifications`, `public.identity_secret_credential_ceremony_candidates`
- `public.identity_social_ceremony_candidates`, `public.identity_totp_ceremony_candidates`, `public.logout_transactions`, `public.security_consumed_jtis`, `public.security_one_time_reveals`, `public.turnstile_replays`

### THIRD_PARTY (2)

- `public.ar_internal_metadata`, `public.schema_migrations`

## app_zenith_structure.sql

### ACTIVE_APP (98)

- `public.app_enforcement_appeals`, `public.app_enforcement_authentication_method_effects`, `public.app_enforcement_cases`, `public.app_enforcement_identifier_effects`, `public.app_enforcement_principal_effects`, `public.app_enforcement_principal_links`, `public.client_accounts`, `public.client_apple_notification_events`
- `public.client_authority_locks`, `public.client_banners`, `public.client_bulletins`, `public.client_email_statuses`, `public.client_emails`, `public.client_enforcement_recovery_ceremonies`, `public.client_external_identities`, `public.client_identities`
- `public.client_identity_states`, `public.client_member_deletions`, `public.client_member_discoveries`, `public.client_member_impersonations`, `public.client_member_observations`, `public.client_member_revocations`, `public.client_member_suspensions`, `public.client_members`
- `public.client_memberships`, `public.client_mfa_levels`, `public.client_mfa_statuses`, `public.client_passkey_statuses`, `public.client_passkeys`, `public.client_persona_administration_grants`, `public.client_persona_delegation_grants`, `public.client_persona_ownership_transfer_requests`
- `public.client_persona_ownerships`, `public.client_persona_usage_grants`, `public.client_persona_view_grants`, `public.client_preference_adult_content_gate_options`, `public.client_preference_adult_content_gates`, `public.client_preference_currencies`, `public.client_preference_currency_options`, `public.client_preference_date_format_options`
- `public.client_preference_date_formats`, `public.client_preference_densities`, `public.client_preference_density_options`, `public.client_preference_language_options`, `public.client_preference_languages`, `public.client_preference_motion_options`, `public.client_preference_motions`, `public.client_preference_page_size_options`
- `public.client_preference_page_sizes`, `public.client_preference_region_options`, `public.client_preference_regions`, `public.client_preference_theme_options`, `public.client_preference_themes`, `public.client_preference_time_format_options`, `public.client_preference_time_formats`, `public.client_preference_timezone_options`
- `public.client_preference_timezones`, `public.client_preferences`, `public.client_privacy_request_statuses`, `public.client_privacy_requests`, `public.client_processor_erasure_notification_attempts`, `public.client_processor_erasure_notification_statuses`, `public.client_processor_erasure_notifications`, `public.client_profile_statuses`
- `public.client_profiles`, `public.client_retention_hold_statuses`, `public.client_retention_holds`, `public.client_secret_credential_kinds`, `public.client_secret_credential_statuses`, `public.client_secret_credentials`, `public.client_statuses`, `public.client_telephone_statuses`
- `public.client_telephones`, `public.client_totp_credential_statuses`, `public.client_totp_credentials`, `public.client_visibilities`, `public.client_withdrawal_ceremonies`, `public.client_withdrawal_flow_events`, `public.client_withdrawal_flow_statuses`, `public.client_withdrawal_flows`
- `public.clients`, `public.core_app_client_bridges`, `public.enterprise_administration_grants`, `public.enterprise_delegation_grants`, `public.enterprise_ownership_transfer_requests`, `public.enterprise_ownerships`, `public.enterprise_unit_closures`, `public.enterprise_units`
- `public.enterprise_view_grants`, `public.enterprises`, `public.member_statuses`, `public.members`, `public.persona_assignments`, `public.persona_membership_kinds`, `public.persona_membership_revoke_reasons`, `public.persona_membership_states`
- `public.persona_memberships`, `public.personas`

### LEGACY_CANDIDATE (3)

- `public.legacy_replaced_client_banners`, `public.legacy_replaced_client_statuses`, `public.legacy_replaced_clients`

### THIRD_PARTY (2)

- `public.ar_internal_metadata`, `public.schema_migrations`

### UNCERTAIN (10)

- `public.accounts`, `public.apple_auths`, `public.roles`, `public.user_client_deletions`, `public.user_client_discoveries`, `public.user_client_impersonations`, `public.user_client_observations`, `public.user_client_revocations`
- `public.user_client_suspensions`, `public.user_clients`

## avatar_structure.sql

### ACTIVE_APP (33)

- `public.avatar_agent_bindings`, `public.avatar_assignments`, `public.avatar_blocks`, `public.avatar_capabilities`, `public.avatar_follows`, `public.avatar_groups`, `public.avatar_individual_bindings`, `public.avatar_lifecycle_events`
- `public.avatar_lifecycle_states`, `public.avatar_membership_statuses`, `public.avatar_memberships`, `public.avatar_moniker_statuses`, `public.avatar_monikers`, `public.avatar_mutes`, `public.avatar_ownership_periods`, `public.avatar_ownership_statuses`
- `public.avatar_permissions`, `public.avatar_persona_bindings`, `public.avatar_role_permissions`, `public.avatar_roles`, `public.avatars`, `public.group_avatar_memberships`, `public.handle_assignment_statuses`, `public.handle_assignments`
- `public.handle_statuses`, `public.handles`, `public.member_avatar_accesses`, `public.member_avatar_deletions`, `public.member_avatar_extractions`, `public.member_avatar_impersonations`, `public.member_avatar_oversights`, `public.member_avatar_suspensions`
- `public.member_avatar_visibilities`

### THIRD_PARTY (2)

- `public.ar_internal_metadata`, `public.schema_migrations`

### UNCERTAIN (12)

- `public.client_avatar_accesses`, `public.client_avatar_deletions`, `public.client_avatar_extractions`, `public.client_avatar_impersonations`, `public.client_avatar_oversights`, `public.client_avatar_suspensions`, `public.client_avatar_visibilities`, `public.post_review_statuses`
- `public.post_reviews`, `public.post_statuses`, `public.post_versions`, `public.posts`

## chronicle_structure.sql

### ACTIVE_APP (22)

- `public.account_access_events`, `public.app_preference_chronicle_events`, `public.app_preference_chronicle_levels`, `public.app_preference_chronicles`, `public.chronicle_outbox_entries`, `public.chronicle_retention_policies`, `public.chronicle_visibilities`, `public.chronicle_visibility_contexts`
- `public.chronicles`, `public.client_chronicle_events`, `public.client_chronicle_levels`, `public.client_chronicles`, `public.com_preference_chronicle_events`, `public.com_preference_chronicle_levels`, `public.com_preference_chronicles`, `public.enforcement_events`
- `public.operator_chronicle_events`, `public.operator_chronicle_levels`, `public.operator_chronicles`, `public.org_preference_chronicle_events`, `public.org_preference_chronicle_levels`, `public.org_preference_chronicles`

### THIRD_PARTY (2)

- `public.ar_internal_metadata`, `public.schema_migrations`

### UNCERTAIN (36)

- `public.app_document_audit_events`, `public.app_document_audit_levels`, `public.app_document_audits`, `public.app_document_behavior_events`, `public.app_document_behavior_levels`, `public.app_document_behaviors`, `public.app_timeline_audit_events`, `public.app_timeline_audit_levels`
- `public.app_timeline_audits`, `public.app_timeline_behavior_events`, `public.app_timeline_behavior_levels`, `public.app_timeline_behaviors`, `public.com_document_audit_events`, `public.com_document_audit_levels`, `public.com_document_audits`, `public.com_document_behavior_events`
- `public.com_document_behavior_levels`, `public.com_document_behaviors`, `public.com_timeline_audit_events`, `public.com_timeline_audit_levels`, `public.com_timeline_audits`, `public.com_timeline_behavior_events`, `public.com_timeline_behavior_levels`, `public.com_timeline_behaviors`
- `public.org_document_audit_events`, `public.org_document_audit_levels`, `public.org_document_audits`, `public.org_document_behavior_events`, `public.org_document_behavior_levels`, `public.org_document_behaviors`, `public.org_timeline_audit_events`, `public.org_timeline_audit_levels`
- `public.org_timeline_audits`, `public.org_timeline_behavior_events`, `public.org_timeline_behavior_levels`, `public.org_timeline_behaviors`

## com_setting_structure.sql

### ACTIVE_APP (27)

- `public.com_preference_adult_content_gate_options`, `public.com_preference_adult_content_gates`, `public.com_preference_binding_methods`, `public.com_preference_cookies`, `public.com_preference_currencies`, `public.com_preference_currency_options`, `public.com_preference_date_format_options`, `public.com_preference_date_formats`
- `public.com_preference_dbsc_statuses`, `public.com_preference_densities`, `public.com_preference_density_options`, `public.com_preference_language_options`, `public.com_preference_languages`, `public.com_preference_motion_options`, `public.com_preference_motions`, `public.com_preference_page_size_options`
- `public.com_preference_page_sizes`, `public.com_preference_region_options`, `public.com_preference_regions`, `public.com_preference_statuses`, `public.com_preference_theme_options`, `public.com_preference_themes`, `public.com_preference_time_format_options`, `public.com_preference_time_formats`
- `public.com_preference_timezone_options`, `public.com_preference_timezones`, `public.com_preferences`

### THIRD_PARTY (2)

- `public.ar_internal_metadata`, `public.schema_migrations`

## com_signal_structure.sql

### ACTIVE_APP (1)

- `public.visitor_notification_records`

### THIRD_PARTY (2)

- `public.ar_internal_metadata`, `public.schema_migrations`

## com_ticket_structure.sql

### ACTIVE_APP (26)

- `public.visitor_verifications`, `public.visitor_auth_ceremony_sessions`, `public.visitor_device_sessions`, `public.visitor_dpop_proof_states`, `public.visitor_email_ceremony_transactions`, `public.visitor_oidc_authorization_transactions`, `public.visitor_oidc_connections`, `public.visitor_passkey_ceremony_transactions`
- `public.visitor_rp_sessions`, `public.visitor_secret_credential_ceremony_transactions`, `public.visitor_sign_in_flow_statuses`, `public.visitor_sign_in_flows`, `public.visitor_sign_out_flow_kinds`, `public.visitor_sign_out_flow_statuses`, `public.visitor_sign_out_flows`, `public.visitor_sign_up_flow_cleanup_statuses`
- `public.visitor_sign_up_flow_statuses`, `public.visitor_sign_up_flows`, `public.visitor_step_up_ceremony_transactions`, `public.visitor_step_up_sessions`, `public.visitor_telephone_ceremony_transactions`, `public.visitor_token_binding_methods`, `public.visitor_token_dbsc_statuses`, `public.visitor_token_kinds`
- `public.visitor_token_statuses`, `public.visitor_tokens`

### THIRD_PARTY (2)

- `public.ar_internal_metadata`, `public.schema_migrations`

## com_zenith_structure.sql

### ACTIVE_APP (82)

- `public.action_push_native_devices`, `public.com_enforcement_appeals`, `public.com_enforcement_authentication_method_effects`, `public.com_enforcement_cases`, `public.com_enforcement_identifier_effects`, `public.com_enforcement_principal_effects`, `public.com_enforcement_principal_links`, `public.companies`
- `public.company_administration_grants`, `public.company_delegation_grants`, `public.company_ownership_transfer_requests`, `public.company_ownerships`, `public.company_unit_closures`, `public.company_units`, `public.company_view_grants`, `public.core_com_visitor_bridges`
- `public.individual_administration_grants`, `public.individual_assignments`, `public.individual_delegation_grants`, `public.individual_membership_kinds`, `public.individual_membership_revoke_reasons`, `public.individual_membership_states`, `public.individual_memberships`, `public.individual_ownership_transfer_requests`
- `public.individual_ownerships`, `public.individual_usage_grants`, `public.individual_view_grants`, `public.individuals`, `public.visitor_accounts`, `public.visitor_authority_locks`, `public.visitor_banners`, `public.visitor_email_statuses`
- `public.visitor_emails`, `public.visitor_enforcement_recovery_ceremonies`, `public.visitor_identities`, `public.visitor_identity_states`, `public.visitor_mfa_levels`, `public.visitor_mfa_statuses`, `public.visitor_passkey_statuses`, `public.visitor_passkeys`
- `public.visitor_preference_adult_content_gate_options`, `public.visitor_preference_adult_content_gates`, `public.visitor_preference_currencies`, `public.visitor_preference_currency_options`, `public.visitor_preference_date_format_options`, `public.visitor_preference_date_formats`, `public.visitor_preference_densities`, `public.visitor_preference_density_options`
- `public.visitor_preference_language_options`, `public.visitor_preference_languages`, `public.visitor_preference_motion_options`, `public.visitor_preference_motions`, `public.visitor_preference_page_size_options`, `public.visitor_preference_page_sizes`, `public.visitor_preference_region_options`, `public.visitor_preference_regions`
- `public.visitor_preference_theme_options`, `public.visitor_preference_themes`, `public.visitor_preference_time_format_options`, `public.visitor_preference_time_formats`, `public.visitor_preference_timezone_options`, `public.visitor_preference_timezones`, `public.visitor_preferences`, `public.visitor_privacy_request_statuses`
- `public.visitor_privacy_requests`, `public.visitor_processor_erasure_notification_attempts`, `public.visitor_processor_erasure_notification_statuses`, `public.visitor_processor_erasure_notifications`, `public.visitor_retention_hold_statuses`, `public.visitor_retention_holds`, `public.visitor_secret_credential_kinds`, `public.visitor_secret_credential_statuses`
- `public.visitor_secret_credentials`, `public.visitor_statuses`, `public.visitor_telephone_statuses`, `public.visitor_telephones`, `public.visitor_visibilities`, `public.visitor_withdrawal_ceremonies`, `public.visitor_withdrawal_flow_events`, `public.visitor_withdrawal_flow_statuses`
- `public.visitor_withdrawal_flows`, `public.visitors`

### THIRD_PARTY (2)

- `public.ar_internal_metadata`, `public.schema_migrations`

## occurrence_structure.sql

### ACTIVE_APP (52)

- `public.area_client_occurrences`, `public.area_domain_occurrences`, `public.area_email_occurrences`, `public.area_ip_occurrences`, `public.area_occurrence_statuses`, `public.area_occurrences`, `public.area_operator_occurrences`, `public.area_telephone_occurrences`
- `public.area_visitor_occurrences`, `public.area_zip_occurrences`, `public.client_occurrence_statuses`, `public.client_occurrences`, `public.client_zip_occurrences`, `public.domain_client_occurrences`, `public.domain_email_occurrences`, `public.domain_ip_occurrences`
- `public.domain_occurrence_statuses`, `public.domain_occurrences`, `public.domain_operator_occurrences`, `public.domain_telephone_occurrences`, `public.domain_zip_occurrences`, `public.email_client_occurrences`, `public.email_ip_occurrences`, `public.email_occurrence_statuses`
- `public.email_occurrences`, `public.email_operator_occurrences`, `public.email_telephone_occurrences`, `public.email_visitor_occurrences`, `public.email_zip_occurrences`, `public.ip_client_occurrences`, `public.ip_occurrence_statuses`, `public.ip_occurrences`
- `public.ip_operator_occurrences`, `public.ip_telephone_occurrences`, `public.ip_visitor_occurrences`, `public.ip_zip_occurrences`, `public.jwt_anomaly_events`, `public.jwt_occurrence_statuses`, `public.jwt_occurrences`, `public.operator_client_occurrences`
- `public.operator_occurrence_statuses`, `public.operator_occurrences`, `public.operator_telephone_occurrences`, `public.operator_zip_occurrences`, `public.telephone_client_occurrences`, `public.telephone_occurrence_statuses`, `public.telephone_occurrences`, `public.telephone_zip_occurrences`
- `public.visitor_occurrence_statuses`, `public.visitor_occurrences`, `public.zip_occurrence_statuses`, `public.zip_occurrences`

### THIRD_PARTY (2)

- `public.ar_internal_metadata`, `public.schema_migrations`

## org_setting_structure.sql

### ACTIVE_APP (27)

- `public.org_preference_adult_content_gate_options`, `public.org_preference_adult_content_gates`, `public.org_preference_binding_methods`, `public.org_preference_cookies`, `public.org_preference_currencies`, `public.org_preference_currency_options`, `public.org_preference_date_format_options`, `public.org_preference_date_formats`
- `public.org_preference_dbsc_statuses`, `public.org_preference_densities`, `public.org_preference_density_options`, `public.org_preference_language_options`, `public.org_preference_languages`, `public.org_preference_motion_options`, `public.org_preference_motions`, `public.org_preference_page_size_options`
- `public.org_preference_page_sizes`, `public.org_preference_region_options`, `public.org_preference_regions`, `public.org_preference_statuses`, `public.org_preference_theme_options`, `public.org_preference_themes`, `public.org_preference_time_format_options`, `public.org_preference_time_formats`
- `public.org_preference_timezone_options`, `public.org_preference_timezones`, `public.org_preferences`

### THIRD_PARTY (2)

- `public.ar_internal_metadata`, `public.schema_migrations`

## org_signal_structure.sql

### ACTIVE_APP (2)

- `public.operator_notification_records`, `public.operator_notifications`

### THIRD_PARTY (2)

- `public.ar_internal_metadata`, `public.schema_migrations`

## org_ticket_structure.sql

### ACTIVE_APP (27)

- `public.operator_auth_ceremony_sessions`, `public.operator_device_sessions`, `public.operator_dpop_proof_states`, `public.operator_email_ceremony_transactions`, `public.operator_oauth_callback_states`, `public.operator_oidc_authorization_transactions`, `public.operator_oidc_connections`, `public.operator_passkey_ceremony_transactions`
- `public.operator_rp_sessions`, `public.operator_secret_credential_ceremony_transactions`, `public.operator_sign_in_flow_statuses`, `public.operator_sign_in_flows`, `public.operator_sign_out_flow_kinds`, `public.operator_sign_out_flow_statuses`, `public.operator_sign_out_flows`, `public.operator_sign_up_flow_statuses`
- `public.operator_sign_up_flows`, `public.operator_step_up_ceremony_transactions`, `public.operator_step_up_sessions`, `public.operator_telephone_ceremony_transactions`, `public.operator_token_binding_methods`, `public.operator_token_dbsc_statuses`, `public.operator_token_kinds`, `public.operator_token_statuses`
- `public.operator_tokens`, `public.operator_verifications`, `public.organization_invitations`

### THIRD_PARTY (2)

- `public.ar_internal_metadata`, `public.schema_migrations`

## org_zenith_structure.sql

### ACTIVE_APP (84)

- `public.agent_administration_grants`, `public.agent_assignments`, `public.agent_delegation_grants`, `public.agent_membership_kinds`, `public.agent_membership_revoke_reasons`, `public.agent_membership_states`, `public.agent_memberships`, `public.agent_ownership_transfer_requests`
- `public.agent_ownerships`, `public.agent_usage_grants`, `public.agent_view_grants`, `public.agents`, `public.bureau_administration_grants`, `public.bureau_delegation_grants`, `public.bureau_ownership_transfer_requests`, `public.bureau_ownerships`
- `public.bureau_unit_closures`, `public.bureau_units`, `public.bureau_view_grants`, `public.bureaus`, `public.core_org_operator_bridges`, `public.department_statuses`, `public.departments`, `public.division_statuses`
- `public.divisions`, `public.operator_accounts`, `public.operator_authority_locks`, `public.operator_banners`, `public.operator_bulletins`, `public.operator_email_statuses`, `public.operator_emails`, `public.operator_entra_identities`
- `public.operator_entra_identity_states`, `public.operator_identities`, `public.operator_identity_states`, `public.operator_lifecycle_requests`, `public.operator_mfa_levels`, `public.operator_mfa_statuses`, `public.operator_passkey_statuses`, `public.operator_passkeys`
- `public.operator_preference_adult_content_gate_options`, `public.operator_preference_adult_content_gates`, `public.operator_preference_currencies`, `public.operator_preference_currency_options`, `public.operator_preference_date_format_options`, `public.operator_preference_date_formats`, `public.operator_preference_densities`, `public.operator_preference_density_options`
- `public.operator_preference_language_options`, `public.operator_preference_languages`, `public.operator_preference_motion_options`, `public.operator_preference_motions`, `public.operator_preference_page_size_options`, `public.operator_preference_page_sizes`, `public.operator_preference_region_options`, `public.operator_preference_regions`
- `public.operator_preference_theme_options`, `public.operator_preference_themes`, `public.operator_preference_time_format_options`, `public.operator_preference_time_formats`, `public.operator_preference_timezone_options`, `public.operator_preference_timezones`, `public.operator_preferences`, `public.operator_secret_credential_kinds`
- `public.operator_secret_credential_statuses`, `public.operator_secret_credentials`, `public.operator_statuses`, `public.operator_telephone_statuses`, `public.operator_telephones`, `public.operator_visibilities`, `public.operator_workspace_account_memberships`, `public.operator_workspace_account_statuses`
- `public.operator_workspace_accounts`, `public.operators`, `public.org_enforcement_appeals`, `public.org_enforcement_authentication_method_effects`, `public.org_enforcement_cases`, `public.org_enforcement_identifier_effects`, `public.org_enforcement_principal_effects`, `public.org_enforcement_principal_links`
- `public.organization_entra_connection_states`, `public.organization_entra_connections`, `public.organization_statuses`, `public.organizations`

### LEGACY_CANDIDATE (1)

- `public.legacy_operator_department_accounts`

### THIRD_PARTY (2)

- `public.ar_internal_metadata`, `public.schema_migrations`

### UNCERTAIN (12)

- `public.operator_google_identities`, `public.operator_google_identity_statuses`, `public.role_assignments`, `public.staff_identity_audit_events`, `public.staff_identity_audits`, `public.staff_identity_passkeys`, `public.staff_identity_statuses`, `public.staff_operators`
- `public.staff_recovery_codes`, `public.user_workspaces`, `public.workspace_statuses`, `public.workspaces`

## publishing_structure.sql

### ACTIVE_APP (157)

- `public.publishing_docs_app_entries`, `public.publishing_docs_app_entry_revisions`, `public.publishing_docs_app_entry_slugs`, `public.publishing_docs_app_entry_versions`, `public.publishing_docs_app_publications`, `public.publishing_docs_app_revision_media_usages`, `public.publishing_docs_app_revision_multiple_taxonomy_assignments`, `public.publishing_docs_app_revision_single_taxonomy_assignments`
- `public.publishing_docs_app_taxonomy_terms`, `public.publishing_docs_app_version_media_usages`, `public.publishing_docs_app_version_multiple_taxonomy_assignments`, `public.publishing_docs_app_version_single_taxonomy_assignments`, `public.publishing_docs_app_vocabularies`, `public.publishing_docs_com_entries`, `public.publishing_docs_com_entry_revisions`, `public.publishing_docs_com_entry_slugs`
- `public.publishing_docs_com_entry_versions`, `public.publishing_docs_com_publications`, `public.publishing_docs_com_revision_media_usages`, `public.publishing_docs_com_revision_multiple_taxonomy_assignments`, `public.publishing_docs_com_revision_single_taxonomy_assignments`, `public.publishing_docs_com_taxonomy_terms`, `public.publishing_docs_com_version_media_usages`, `public.publishing_docs_com_version_multiple_taxonomy_assignments`
- `public.publishing_docs_com_version_single_taxonomy_assignments`, `public.publishing_docs_com_vocabularies`, `public.publishing_docs_org_entries`, `public.publishing_docs_org_entry_revisions`, `public.publishing_docs_org_entry_slugs`, `public.publishing_docs_org_entry_versions`, `public.publishing_docs_org_publications`, `public.publishing_docs_org_revision_media_usages`
- `public.publishing_docs_org_revision_multiple_taxonomy_assignments`, `public.publishing_docs_org_revision_single_taxonomy_assignments`, `public.publishing_docs_org_taxonomy_terms`, `public.publishing_docs_org_version_media_usages`, `public.publishing_docs_org_version_multiple_taxonomy_assignments`, `public.publishing_docs_org_version_single_taxonomy_assignments`, `public.publishing_docs_org_vocabularies`, `public.publishing_help_app_entries`
- `public.publishing_help_app_entry_revisions`, `public.publishing_help_app_entry_slugs`, `public.publishing_help_app_entry_versions`, `public.publishing_help_app_publications`, `public.publishing_help_app_revision_media_usages`, `public.publishing_help_app_revision_multiple_taxonomy_assignments`, `public.publishing_help_app_revision_single_taxonomy_assignments`, `public.publishing_help_app_taxonomy_terms`
- `public.publishing_help_app_version_media_usages`, `public.publishing_help_app_version_multiple_taxonomy_assignments`, `public.publishing_help_app_version_single_taxonomy_assignments`, `public.publishing_help_app_vocabularies`, `public.publishing_help_com_entries`, `public.publishing_help_com_entry_revisions`, `public.publishing_help_com_entry_slugs`, `public.publishing_help_com_entry_versions`
- `public.publishing_help_com_publications`, `public.publishing_help_com_revision_media_usages`, `public.publishing_help_com_revision_multiple_taxonomy_assignments`, `public.publishing_help_com_revision_single_taxonomy_assignments`, `public.publishing_help_com_taxonomy_terms`, `public.publishing_help_com_version_media_usages`, `public.publishing_help_com_version_multiple_taxonomy_assignments`, `public.publishing_help_com_version_single_taxonomy_assignments`
- `public.publishing_help_com_vocabularies`, `public.publishing_help_org_entries`, `public.publishing_help_org_entry_revisions`, `public.publishing_help_org_entry_slugs`, `public.publishing_help_org_entry_versions`, `public.publishing_help_org_publications`, `public.publishing_help_org_revision_media_usages`, `public.publishing_help_org_revision_multiple_taxonomy_assignments`
- `public.publishing_help_org_revision_single_taxonomy_assignments`, `public.publishing_help_org_taxonomy_terms`, `public.publishing_help_org_version_media_usages`, `public.publishing_help_org_version_multiple_taxonomy_assignments`, `public.publishing_help_org_version_single_taxonomy_assignments`, `public.publishing_help_org_vocabularies`, `public.publishing_info_app_entries`, `public.publishing_info_app_entry_revisions`
- `public.publishing_info_app_entry_slugs`, `public.publishing_info_app_entry_versions`, `public.publishing_info_app_publications`, `public.publishing_info_app_revision_media_usages`, `public.publishing_info_app_revision_multiple_taxonomy_assignments`, `public.publishing_info_app_revision_single_taxonomy_assignments`, `public.publishing_info_app_taxonomy_terms`, `public.publishing_info_app_version_media_usages`
- `public.publishing_info_app_version_multiple_taxonomy_assignments`, `public.publishing_info_app_version_single_taxonomy_assignments`, `public.publishing_info_app_vocabularies`, `public.publishing_info_com_entries`, `public.publishing_info_com_entry_revisions`, `public.publishing_info_com_entry_slugs`, `public.publishing_info_com_entry_versions`, `public.publishing_info_com_publications`
- `public.publishing_info_com_revision_media_usages`, `public.publishing_info_com_revision_multiple_taxonomy_assignments`, `public.publishing_info_com_revision_single_taxonomy_assignments`, `public.publishing_info_com_taxonomy_terms`, `public.publishing_info_com_version_media_usages`, `public.publishing_info_com_version_multiple_taxonomy_assignments`, `public.publishing_info_com_version_single_taxonomy_assignments`, `public.publishing_info_com_vocabularies`
- `public.publishing_info_org_entries`, `public.publishing_info_org_entry_revisions`, `public.publishing_info_org_entry_slugs`, `public.publishing_info_org_entry_versions`, `public.publishing_info_org_publications`, `public.publishing_info_org_revision_media_usages`, `public.publishing_info_org_revision_multiple_taxonomy_assignments`, `public.publishing_info_org_revision_single_taxonomy_assignments`
- `public.publishing_info_org_taxonomy_terms`, `public.publishing_info_org_version_media_usages`, `public.publishing_info_org_version_multiple_taxonomy_assignments`, `public.publishing_info_org_version_single_taxonomy_assignments`, `public.publishing_info_org_vocabularies`, `public.publishing_media_files`, `public.publishing_news_app_entries`, `public.publishing_news_app_entry_revisions`
- `public.publishing_news_app_entry_slugs`, `public.publishing_news_app_entry_versions`, `public.publishing_news_app_publications`, `public.publishing_news_app_revision_media_usages`, `public.publishing_news_app_revision_multiple_taxonomy_assignments`, `public.publishing_news_app_revision_single_taxonomy_assignments`, `public.publishing_news_app_taxonomy_terms`, `public.publishing_news_app_version_media_usages`
- `public.publishing_news_app_version_multiple_taxonomy_assignments`, `public.publishing_news_app_version_single_taxonomy_assignments`, `public.publishing_news_app_vocabularies`, `public.publishing_news_com_entries`, `public.publishing_news_com_entry_revisions`, `public.publishing_news_com_entry_slugs`, `public.publishing_news_com_entry_versions`, `public.publishing_news_com_publications`
- `public.publishing_news_com_revision_media_usages`, `public.publishing_news_com_revision_multiple_taxonomy_assignments`, `public.publishing_news_com_revision_single_taxonomy_assignments`, `public.publishing_news_com_taxonomy_terms`, `public.publishing_news_com_version_media_usages`, `public.publishing_news_com_version_multiple_taxonomy_assignments`, `public.publishing_news_com_version_single_taxonomy_assignments`, `public.publishing_news_com_vocabularies`
- `public.publishing_news_org_entries`, `public.publishing_news_org_entry_revisions`, `public.publishing_news_org_entry_slugs`, `public.publishing_news_org_entry_versions`, `public.publishing_news_org_publications`, `public.publishing_news_org_revision_media_usages`, `public.publishing_news_org_revision_multiple_taxonomy_assignments`, `public.publishing_news_org_revision_single_taxonomy_assignments`
- `public.publishing_news_org_taxonomy_terms`, `public.publishing_news_org_version_media_usages`, `public.publishing_news_org_version_multiple_taxonomy_assignments`, `public.publishing_news_org_version_single_taxonomy_assignments`, `public.publishing_news_org_vocabularies`

### THIRD_PARTY (2)

- `public.ar_internal_metadata`, `public.schema_migrations`

## queue_structure.sql

### THIRD_PARTY (15)

- `public.ar_internal_metadata`, `public.schema_migrations`, `public.solid_queue_batch_executions`, `public.solid_queue_batches`, `public.solid_queue_blocked_executions`, `public.solid_queue_claimed_executions`, `public.solid_queue_failed_executions`, `public.solid_queue_jobs`
- `public.solid_queue_pauses`, `public.solid_queue_processes`, `public.solid_queue_ready_executions`, `public.solid_queue_recurring_executions`, `public.solid_queue_recurring_tasks`, `public.solid_queue_scheduled_executions`, `public.solid_queue_semaphores`

## search_structure.sql

### THIRD_PARTY (2)

- `public.ar_internal_metadata`, `public.schema_migrations`

## storage_structure.sql

### THIRD_PARTY (2)

- `public.ar_internal_metadata`, `public.schema_migrations`

## structure.sql

### THIRD_PARTY (8)

- `public.ar_internal_metadata`, `public.blazer_checks`, `public.blazer_dashboard_queries`, `public.blazer_dashboards`, `public.blazer_queries`, `public.flipper_features`, `public.flipper_gates`, `public.schema_migrations`
