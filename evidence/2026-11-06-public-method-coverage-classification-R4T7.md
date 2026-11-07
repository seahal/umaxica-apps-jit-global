# Public-method coverage classification (2026-11-06)

Input: `tmp/uncovered-public-methods-2026-11-06.tsv` (390 rows, 06:32 UTC coverage snapshot). The categories below describe the snapshot. Later focused tests are noted separately and do not rewrite the source inventory. H-2 behavior evidence is `evidence/2026-11-06-handoff-h2-1714-6K2Q.md`.

## Counts and category rules

| Category | Count | Rule |
|---|---:|---|
| A | 171 | A current production route/caller exists; the snapshot has no executed test for the method. Add a behavior test through the public entrypoint. |
| B | 51 | A request test targets the flow but fails before this method is reached; add no success-path coverage until that blocker is resolved. |
| C | 117 | No reachable production entrypoint/caller was found; keep the method and record it as a deletion-review candidate only. |
| D | 51 | O-12 RP flow must refuse without mutation; test refusal only and never add an RP success path. |

For B, H-2 usually records file-level counts rather than action-level IDs; the association is provisional where called out by the original audit. C rows 15 and 20 have a route mapping, but the controller before-action always advances or rejects the sequence before the action body can run. C row 261 is the included-model class helper: production calls use the module-level `AuthAdmissionBinding.browser_digest`, not this unreferenced class helper. C row 365 is a private module helper, not a public method; the fixed static client store sets `token_endpoint_auth_method` for every registered client, so `OidcClientRegistry.find` never reaches its metadata fallback. Keep it for deletion review; do not use reflection or test-only seams to force coverage.

## Full row classification

| TSV row | Class | Source location | Method |
|---:|:---:|---|---|
| 1 | A | `app/adapters/avatar_authority_client.rb:58` | `AvatarAuthorityClient#accept_transfer` |
| 2 | A | `app/adapters/avatar_authority_client.rb:62` | `AvatarAuthorityClient#cancel_transfer` |
| 3 | A | `app/adapters/avatar_authority_client.rb:99` | `AvatarAuthorityClient#destroy_selected_avatar` |
| 4 | C | `app/adapters/mcp_liveness_tool.rb:22` | `McpLivenessTool#call` |
| 5 | C | `app/adapters/mcp_service_info_tool.rb:21` | `McpServiceInfoTool#call` |
| 6 | C | `app/adapters/mcp_version_tool.rb:24` | `McpVersionTool#call` |
| 7 | C | `app/adapters/oidc_op_jwks_client.rb:31` | `OidcOpJwksClient::Lookup#invalid?` |
| 8 | C | `app/adapters/processor_erasure_notification_adapter.rb:7` | `ProcessorErasureNotificationAdapter#retry_policy` |
| 9 | C | `app/adapters/processor_erasure_notification_adapter.rb:11` | `ProcessorErasureNotificationAdapter#dispatch` |
| 10 | C | `app/adapters/processor_erasure_notification_adapter.rb:15` | `ProcessorErasureNotificationAdapter#verify_receipt` |
| 11 | A | `app/adapters/visa_sensitive_admission_client.rb:99` | `VisaSensitiveAdmissionClient#confirm_browser!` |
| 12 | C | `app/consumers/totp_window_consumer.rb:18` | `TotpWindowConsumer::Result#revoked?` |
| 13 | C | `app/consumers/totp_window_consumer.rb:20` | `TotpWindowConsumer::Result#credential_required?` |
| 14 | C | `app/controllers/auth/app/settings/removals_controller.rb:23` | `Auth::App::Settings::RemovalsController#create` |
| 15 | C | `app/controllers/auth/app/sign/in/checks_controller.rb:23` | `Auth::App::Sign::In::ChecksController#show` |
| 16 | B | `app/controllers/auth/app/sign/up/check/telephone/passkeys_controller.rb:62` | `Auth::App::Sign::Up::Check::Telephone::PasskeysController#destroy` |
| 17 | B | `app/controllers/auth/app/sign/up/check/telephone/secrets_controller.rb:104` | `Auth::App::Sign::Up::Check::Telephone::SecretsController#reattempt` |
| 18 | B | `app/controllers/auth/app/sign/up/check/telephone/secrets_controller.rb:123` | `Auth::App::Sign::Up::Check::Telephone::SecretsController#destroy` |
| 19 | C | `app/controllers/auth/org/application_controller.rb:98` | `Auth::Org::ApplicationController#acme_authority_host` |
| 20 | C | `app/controllers/auth/org/sign/in/checks_controller.rb:23` | `Auth::Org::Sign::In::ChecksController#show` |
| 21 | A | `app/controllers/base/app/api/v0/avatar/avatar_ownership_transfers_controller.rb:33` | `Base::App::Api::V0::Avatar::AvatarOwnershipTransfersController#create` |
| 22 | A | `app/controllers/base/app/api/v0/avatar/avatar_ownership_transfers_controller.rb:71` | `Base::App::Api::V0::Avatar::AvatarOwnershipTransfersController#accept` |
| 23 | A | `app/controllers/base/app/api/v0/avatar/avatar_ownership_transfers_controller.rb:107` | `Base::App::Api::V0::Avatar::AvatarOwnershipTransfersController#cancel` |
| 24 | A | `app/controllers/base/app/api/v0/avatar/switchers_controller.rb:33` | `Base::App::Api::V0::Avatar::SwitchersController#show` |
| 25 | A | `app/controllers/base/app/api/v0/avatar/switchers_controller.rb:38` | `Base::App::Api::V0::Avatar::SwitchersController#update` |
| 26 | D | `app/controllers/base/app/api/v0/identity/selections_controller.rb:24` | `Base::App::Api::V0::Identity::SelectionsController#show` |
| 27 | B | `app/controllers/base/app/api/v0/identity/standings_controller.rb:34` | `Base::App::Api::V0::Identity::StandingsController#show` |
| 28 | A | `app/controllers/base/app/api/v0/preferences/web_pushes_controller.rb:26` | `Base::App::Api::V0::Preferences::WebPushesController#show` |
| 29 | A | `app/controllers/base/app/api/v0/preferences/web_pushes_controller.rb:30` | `Base::App::Api::V0::Preferences::WebPushesController#update` |
| 30 | B | `app/controllers/base/app/application_controller.rb:53` | `Base::App::ApplicationController#base_admission_surface_name` |
| 31 | A | `app/controllers/base/app/avatar_ownership_transfers_controller.rb:18` | `Base::App::AvatarOwnershipTransfersController#create` |
| 32 | A | `app/controllers/base/app/avatar_ownership_transfers_controller.rb:27` | `Base::App::AvatarOwnershipTransfersController#accept` |
| 33 | A | `app/controllers/base/app/avatar_ownership_transfers_controller.rb:31` | `Base::App::AvatarOwnershipTransfersController#cancel` |
| 34 | B | `app/controllers/base/app/billings_controller.rb:12` | `Base::App::BillingsController#index` |
| 35 | D | `app/controllers/base/app/identity/emails/redeliveries_controller.rb:21` | `Base::App::Identity::Emails::RedeliveriesController#create` |
| 36 | D | `app/controllers/base/app/identity/emails/registrations_controller.rb:30` | `Base::App::Identity::Emails::RegistrationsController#new` |
| 37 | D | `app/controllers/base/app/identity/emails/registrations_controller.rb:32` | `Base::App::Identity::Emails::RegistrationsController#edit` |
| 38 | D | `app/controllers/base/app/identity/emails/registrations_controller.rb:34` | `Base::App::Identity::Emails::RegistrationsController#create` |
| 39 | D | `app/controllers/base/app/identity/emails/registrations_controller.rb:36` | `Base::App::Identity::Emails::RegistrationsController#update` |
| 40 | D | `app/controllers/base/app/identity/emails/registrations_controller.rb:42` | `Base::App::Identity::Emails::RegistrationsController#resend` |
| 41 | B | `app/controllers/base/app/identity/emails_controller.rb:31` | `Base::App::Identity::EmailsController#update` |
| 42 | B | `app/controllers/base/app/identity/emails_controller.rb:60` | `Base::App::Identity::EmailsController#destroy` |
| 43 | A | `app/controllers/base/app/identity/mfa/challenges_controller.rb:16` | `Base::App::Identity::Mfa::ChallengesController#show` |
| 44 | A | `app/controllers/base/app/identity/privacy/erasure/statuses_controller.rb:22` | `Base::App::Identity::Privacy::Erasure::StatusesController#show` |
| 45 | A | `app/controllers/base/app/identity/recoveries_controller.rb:16` | `Base::App::Identity::RecoveriesController#show` |
| 46 | D | `app/controllers/base/app/identity/revocations/others_controller.rb:14` | `Base::App::Identity::Revocations::OthersController#create` |
| 47 | A | `app/controllers/base/app/identity/sensitive_admission_confirmations_controller.rb:13` | `Base::App::Identity::SensitiveAdmissionConfirmationsController#show` |
| 48 | A | `app/controllers/base/app/identity/sensitive_admission_confirmations_controller.rb:23` | `Base::App::Identity::SensitiveAdmissionConfirmationsController#create` |
| 49 | D | `app/controllers/base/app/identity/sessions_controller.rb:15` | `Base::App::Identity::SessionsController#index` |
| 50 | D | `app/controllers/base/app/identity/sessions_controller.rb:21` | `Base::App::Identity::SessionsController#show` |
| 51 | D | `app/controllers/base/app/identity/sessions_controller.rb:35` | `Base::App::Identity::SessionsController#destroy` |
| 52 | B | `app/controllers/base/app/identity/standings_controller.rb:18` | `Base::App::Identity::StandingsController#show` |
| 53 | D | `app/controllers/base/app/identity/telephones/registrations_controller.rb:25` | `Base::App::Identity::Telephones::RegistrationsController#new` |
| 54 | D | `app/controllers/base/app/identity/telephones/registrations_controller.rb:31` | `Base::App::Identity::Telephones::RegistrationsController#edit` |
| 55 | D | `app/controllers/base/app/identity/telephones/registrations_controller.rb:42` | `Base::App::Identity::Telephones::RegistrationsController#create` |
| 56 | D | `app/controllers/base/app/identity/telephones/registrations_controller.rb:74` | `Base::App::Identity::Telephones::RegistrationsController#update` |
| 57 | B | `app/controllers/base/app/identity/telephones_controller.rb:23` | `Base::App::Identity::TelephonesController#index` |
| 58 | B | `app/controllers/base/app/identity/telephones_controller.rb:29` | `Base::App::Identity::TelephonesController#new` |
| 59 | B | `app/controllers/base/app/identity/telephones_controller.rb:40` | `Base::App::Identity::TelephonesController#create` |
| 60 | B | `app/controllers/base/app/identity/telephones_controller.rb:53` | `Base::App::Identity::TelephonesController#destroy` |
| 61 | A | `app/controllers/base/app/identity/totps_controller.rb:18` | `Base::App::Identity::TotpsController#index` |
| 62 | B | `app/controllers/base/app/identity/totps_controller.rb:46` | `Base::App::Identity::TotpsController#create` |
| 63 | B | `app/controllers/base/app/identity/withdrawals_controller.rb:25` | `Base::App::Identity::WithdrawalsController#new` |
| 64 | B | `app/controllers/base/app/identity/withdrawals_controller.rb:37` | `Base::App::Identity::WithdrawalsController#update` |
| 65 | C | `app/controllers/base/app/mcps_controller.rb:18` | `Base::App::McpsController#create` |
| 66 | D | `app/controllers/base/app/secret_issuances_controller.rb:20` | `Base::App::SecretIssuancesController#show` |
| 67 | D | `app/controllers/base/app/secret_issuances_controller.rb:40` | `Base::App::SecretIssuancesController#update` |
| 68 | D | `app/controllers/base/app/secret_issuances_controller.rb:61` | `Base::App::SecretIssuancesController#destroy` |
| 69 | D | `app/controllers/base/app/secret_issuances_controller.rb:72` | `Base::App::SecretIssuancesController#reattempt` |
| 70 | D | `app/controllers/base/app/secret_presentations_controller.rb:9` | `Base::App::SecretPresentationsController#create` |
| 71 | D | `app/controllers/base/app/secrets_controller.rb:26` | `Base::App::SecretsController#index` |
| 72 | D | `app/controllers/base/app/secrets_controller.rb:38` | `Base::App::SecretsController#show` |
| 73 | D | `app/controllers/base/app/secrets_controller.rb:43` | `Base::App::SecretsController#new` |
| 74 | D | `app/controllers/base/app/secrets_controller.rb:55` | `Base::App::SecretsController#edit` |
| 75 | D | `app/controllers/base/app/secrets_controller.rb:60` | `Base::App::SecretsController#create` |
| 76 | D | `app/controllers/base/app/secrets_controller.rb:75` | `Base::App::SecretsController#update` |
| 77 | D | `app/controllers/base/app/secrets_controller.rb:85` | `Base::App::SecretsController#destroy` |
| 78 | A | `app/controllers/base/app/sign_outs_controller.rb:25` | `Base::App::SignOutsController#show` |
| 79 | D | `app/controllers/base/app/verification/cancellations_controller.rb:13` | `Base::App::Verification::CancellationsController#create` |
| 80 | D | `app/controllers/base/app/verification/completions_controller.rb:13` | `Base::App::Verification::CompletionsController#show` |
| 81 | D | `app/controllers/base/app/verification/completions_controller.rb:18` | `Base::App::Verification::CompletionsController#create` |
| 82 | D | `app/controllers/base/app/verification/oidc/callbacks_controller.rb:16` | `Base::App::Verification::Oidc::CallbacksController#show` |
| 83 | D | `app/controllers/base/app/verification/setups_controller.rb:20` | `Base::App::Verification::SetupsController#show` |
| 84 | D | `app/controllers/base/app/verification/setups_controller.rb:36` | `Base::App::Verification::SetupsController#create` |
| 85 | A | `app/controllers/base/org/api/v0/avatar/avatar_ownership_transfers_controller.rb:71` | `Base::Org::Api::V0::Avatar::AvatarOwnershipTransfersController#accept` |
| 86 | A | `app/controllers/base/org/api/v0/avatar/avatar_ownership_transfers_controller.rb:107` | `Base::Org::Api::V0::Avatar::AvatarOwnershipTransfersController#cancel` |
| 87 | A | `app/controllers/base/org/api/v0/avatar/selected_avatars_controller.rb:68` | `Base::Org::Api::V0::Avatar::SelectedAvatarsController#destroy` |
| 88 | B | `app/controllers/base/org/api/v0/identity/standings_controller.rb:34` | `Base::Org::Api::V0::Identity::StandingsController#show` |
| 89 | A | `app/controllers/base/org/api/v0/membership/directory_controller.rb:95` | `Base::Org::Api::V0::Membership::DirectoryController#authorization` |
| 90 | A | `app/controllers/base/org/api/v0/preferences/web_pushes_controller.rb:26` | `Base::Org::Api::V0::Preferences::WebPushesController#show` |
| 91 | A | `app/controllers/base/org/api/v0/preferences/web_pushes_controller.rb:30` | `Base::Org::Api::V0::Preferences::WebPushesController#update` |
| 92 | A | `app/controllers/base/org/api/v0/support/enforcement_cases/appeal_reviews_controller.rb:50` | `Base::Org::Api::V0::Support::EnforcementCases::AppealReviewsController#new` |
| 93 | A | `app/controllers/base/org/api/v0/support/enforcement_cases/approvals_controller.rb:55` | `Base::Org::Api::V0::Support::EnforcementCases::ApprovalsController#new` |
| 94 | A | `app/controllers/base/org/api/v0/support/enforcement_cases/releases_controller.rb:55` | `Base::Org::Api::V0::Support::EnforcementCases::ReleasesController#new` |
| 95 | B | `app/controllers/base/org/api/v0/support/enforcement_cases_controller.rb:70` | `Base::Org::Api::V0::Support::EnforcementCasesController#show` |
| 96 | B | `app/controllers/base/org/api/v0/support/enforcement_cases_controller.rb:81` | `Base::Org::Api::V0::Support::EnforcementCasesController#new` |
| 97 | A | `app/controllers/base/org/application_controller.rb:54` | `Base::Org::ApplicationController#base_admission_surface_name` |
| 98 | A | `app/controllers/base/org/audit_controller.rb:10` | `Base::Org::AuditController#index` |
| 99 | A | `app/controllers/base/org/avatar_ownership_transfers_controller.rb:27` | `Base::Org::AvatarOwnershipTransfersController#accept` |
| 100 | A | `app/controllers/base/org/avatar_ownership_transfers_controller.rb:31` | `Base::Org::AvatarOwnershipTransfersController#cancel` |
| 101 | A | `app/controllers/base/org/avatars_controller.rb:55` | `Base::Org::AvatarsController#destroy` |
| 102 | A | `app/controllers/base/org/billing_controller.rb:10` | `Base::Org::BillingController#index` |
| 103 | A | `app/controllers/base/org/iam/grants/revocations_controller.rb:24` | `Base::Org::Iam::Grants::RevocationsController#new` |
| 104 | A | `app/controllers/base/org/iam_controller.rb:13` | `Base::Org::IamController#index` |
| 105 | A | `app/controllers/base/org/identity/birthdates_controller.rb:17` | `Base::Org::Identity::BirthdatesController#show` |
| 106 | B | `app/controllers/base/org/identity/emails/registrations_controller.rb:27` | `Base::Org::Identity::Emails::RegistrationsController#new` |
| 107 | B | `app/controllers/base/org/identity/emails/registrations_controller.rb:33` | `Base::Org::Identity::Emails::RegistrationsController#edit` |
| 108 | B | `app/controllers/base/org/identity/emails/registrations_controller.rb:43` | `Base::Org::Identity::Emails::RegistrationsController#create` |
| 109 | B | `app/controllers/base/org/identity/emails/registrations_controller.rb:88` | `Base::Org::Identity::Emails::RegistrationsController#update` |
| 110 | B | `app/controllers/base/org/identity/emails_controller.rb:18` | `Base::Org::Identity::EmailsController#index` |
| 111 | B | `app/controllers/base/org/identity/emails_controller.rb:23` | `Base::Org::Identity::EmailsController#edit` |
| 112 | B | `app/controllers/base/org/identity/emails_controller.rb:50` | `Base::Org::Identity::EmailsController#destroy` |
| 113 | D | `app/controllers/base/org/identity/removals_controller.rb:13` | `Base::Org::Identity::RemovalsController#create` |
| 114 | D | `app/controllers/base/org/identity/revocations/others_controller.rb:11` | `Base::Org::Identity::Revocations::OthersController#create` |
| 115 | D | `app/controllers/base/org/identity/secret_credentials_controller.rb:28` | `Base::Org::Identity::SecretCredentialsController#index` |
| 116 | D | `app/controllers/base/org/identity/secret_credentials_controller.rb:34` | `Base::Org::Identity::SecretCredentialsController#show` |
| 117 | D | `app/controllers/base/org/identity/secret_credentials_controller.rb:39` | `Base::Org::Identity::SecretCredentialsController#new` |
| 118 | D | `app/controllers/base/org/identity/secret_credentials_controller.rb:52` | `Base::Org::Identity::SecretCredentialsController#edit` |
| 119 | D | `app/controllers/base/org/identity/secret_credentials_controller.rb:57` | `Base::Org::Identity::SecretCredentialsController#create` |
| 120 | D | `app/controllers/base/org/identity/secret_credentials_controller.rb:118` | `Base::Org::Identity::SecretCredentialsController#destroy` |
| 121 | D | `app/controllers/base/org/identity/sessions_controller.rb:17` | `Base::Org::Identity::SessionsController#index` |
| 122 | D | `app/controllers/base/org/identity/sessions_controller.rb:23` | `Base::Org::Identity::SessionsController#show` |
| 123 | D | `app/controllers/base/org/identity/sessions_controller.rb:35` | `Base::Org::Identity::SessionsController#destroy` |
| 124 | B | `app/controllers/base/org/identity/standings_controller.rb:18` | `Base::Org::Identity::StandingsController#show` |
| 125 | A | `app/controllers/base/org/identity/telephones/registrations_controller.rb:30` | `Base::Org::Identity::Telephones::RegistrationsController#new` |
| 126 | A | `app/controllers/base/org/identity/telephones/registrations_controller.rb:36` | `Base::Org::Identity::Telephones::RegistrationsController#edit` |
| 127 | D | `app/controllers/base/org/identity/telephones/registrations_controller.rb:46` | `Base::Org::Identity::Telephones::RegistrationsController#create` |
| 128 | D | `app/controllers/base/org/identity/telephones/registrations_controller.rb:83` | `Base::Org::Identity::Telephones::RegistrationsController#update` |
| 129 | A | `app/controllers/base/org/identity/telephones_controller.rb:25` | `Base::Org::Identity::TelephonesController#index` |
| 130 | A | `app/controllers/base/org/identity/telephones_controller.rb:31` | `Base::Org::Identity::TelephonesController#new` |
| 131 | A | `app/controllers/base/org/identity/telephones_controller.rb:36` | `Base::Org::Identity::TelephonesController#edit` |
| 132 | D | `app/controllers/base/org/identity/telephones_controller.rb:42` | `Base::Org::Identity::TelephonesController#create` |
| 133 | C | `app/controllers/base/org/mcps_controller.rb:18` | `Base::Org::McpsController#create` |
| 134 | A | `app/controllers/base/org/selectors_controller.rb:12` | `Base::Org::SelectorsController#show` |
| 135 | D | `app/controllers/base/org/selectors_controller.rb:21` | `Base::Org::SelectorsController#update` |
| 136 | A | `app/controllers/base/org/settings_controller.rb:12` | `Base::Org::SettingsController#show` |
| 137 | B | `app/controllers/base/org/sign_outs_controller.rb:25` | `Base::Org::SignOutsController#show` |
| 138 | B | `app/controllers/base/org/support/enforcement_cases_controller.rb:31` | `Base::Org::Support::EnforcementCasesController#show` |
| 139 | A | `app/controllers/base/org/system_controller.rb:10` | `Base::Org::SystemController#index` |
| 140 | A | `app/controllers/base/org/verification/cancellations_controller.rb:13` | `Base::Org::Verification::CancellationsController#create` |
| 141 | A | `app/controllers/base/org/verification/completions_controller.rb:13` | `Base::Org::Verification::CompletionsController#show` |
| 142 | A | `app/controllers/base/org/verification/completions_controller.rb:18` | `Base::Org::Verification::CompletionsController#create` |
| 143 | A | `app/controllers/base/org/verification/oidc/callbacks_controller.rb:16` | `Base::Org::Verification::Oidc::CallbacksController#show` |
| 144 | A | `app/controllers/base/org/welcomes_controller.rb:12` | `Base::Org::WelcomesController#show` |
| 145 | A | `app/controllers/concerns/authentication_base.rb:245` | `AuthenticationBase#current_account` |
| 146 | C | `app/controllers/concerns/authentication_base.rb:271` | `AuthenticationBase#parse_authentication_event_at` |
| 147 | C | `app/controllers/concerns/authentication_base.rb:911` | `AuthenticationBase#resource_class` |
| 148 | C | `app/controllers/concerns/authentication_base.rb:915` | `AuthenticationBase#token_class` |
| 149 | C | `app/controllers/concerns/authentication_base.rb:919` | `AuthenticationBase#audit_class` |
| 150 | C | `app/controllers/concerns/authentication_base.rb:923` | `AuthenticationBase#resource_type` |
| 151 | C | `app/controllers/concerns/authentication_base.rb:927` | `AuthenticationBase#resource_foreign_key` |
| 152 | C | `app/controllers/concerns/authentication_base.rb:931` | `AuthenticationBase#sign_in_url_with_pt` |
| 153 | C | `app/controllers/concerns/authentication_base.rb:942` | `AuthenticationBase#am_i_user?` |
| 154 | C | `app/controllers/concerns/authentication_base.rb:946` | `AuthenticationBase#am_i_operator?` |
| 155 | C | `app/controllers/concerns/authentication_base.rb:950` | `AuthenticationBase#am_i_owner?` |
| 156 | C | `app/controllers/concerns/authentication_jwt_configuration.rb:65` | `AuthenticationJwtConfiguration#public_key` |
| 157 | A | `app/controllers/concerns/authentication_sequence_gate.rb:247` | `AuthenticationSequenceGate#sign_in_sequence_required_for_participant?` |
| 158 | A | `app/controllers/concerns/authentication_token_service.rb:21` | `AuthenticationTokenService#decode_allow_expired` |
| 159 | C | `app/controllers/concerns/base_admission_browser_binding.rb:53` | `BaseAdmissionBrowserBinding#require_base_admission_browser_nonce!` |
| 160 | A | `app/controllers/concerns/base_ceremony_binding_confirmation.rb:35` | `BaseCeremonyBindingConfirmation#create` |
| 161 | A | `app/controllers/concerns/base_identity_passkey_management.rb:10` | `BaseIdentityPasskeyManagement#index` |
| 162 | A | `app/controllers/concerns/base_sign_in_limitations.rb:13` | `BaseSignInLimitations#show` |
| 163 | A | `app/controllers/concerns/base_sign_in_limitations.rb:20` | `BaseSignInLimitations#update` |
| 164 | A | `app/controllers/concerns/base_sign_in_limitations.rb:43` | `BaseSignInLimitations#destroy` |
| 165 | A | `app/controllers/concerns/base_step_up_cancellation.rb:11` | `BaseStepUpCancellation#show` |
| 166 | A | `app/controllers/concerns/base_step_up_completion.rb:11` | `BaseStepUpCompletion#show` |
| 167 | A | `app/controllers/concerns/browser_rp_authentication.rb:54` | `BrowserRpAuthentication::ClassMethods#access_policy_rules` |
| 168 | A | `app/controllers/concerns/browser_rp_authentication.rb:58` | `BrowserRpAuthentication::ClassMethods#access_policy` |
| 169 | A | `app/controllers/concerns/browser_rp_authentication.rb:76` | `BrowserRpAuthentication::ClassMethods#local_authentication_mode_rules` |
| 170 | A | `app/controllers/concerns/browser_rp_authentication.rb:131` | `BrowserRpAuthentication#current_account` |
| 171 | A | `app/controllers/concerns/browser_rp_authentication.rb:143` | `BrowserRpAuthentication#active_client?` |
| 172 | A | `app/controllers/concerns/browser_rp_authentication.rb:147` | `BrowserRpAuthentication#active_operator?` |
| 173 | A | `app/controllers/concerns/browser_rp_authentication.rb:151` | `BrowserRpAuthentication#logged_in_client?` |
| 174 | A | `app/controllers/concerns/browser_rp_authentication.rb:155` | `BrowserRpAuthentication#logged_in_operator?` |
| 175 | A | `app/controllers/concerns/browser_rp_authentication.rb:159` | `BrowserRpAuthentication#am_i_client?` |
| 176 | A | `app/controllers/concerns/browser_rp_authentication.rb:163` | `BrowserRpAuthentication#am_i_user?` |
| 177 | A | `app/controllers/concerns/browser_rp_authentication.rb:167` | `BrowserRpAuthentication#am_i_operator?` |
| 178 | A | `app/controllers/concerns/browser_rp_authentication.rb:171` | `BrowserRpAuthentication#am_i_staff?` |
| 179 | A | `app/controllers/concerns/browser_rp_authentication.rb:240` | `BrowserRpAuthentication#access_policy_context` |
| 180 | A | `app/controllers/concerns/browser_rp_authentication.rb:251` | `BrowserRpAuthentication#access_policy_allows?` |
| 181 | A | `app/controllers/concerns/browser_rp_authentication.rb:255` | `BrowserRpAuthentication#policy_for_authentication_mode` |
| 182 | A | `app/controllers/concerns/browser_rp_authentication.rb:261` | `BrowserRpAuthentication#access_policy_options_for` |
| 183 | A | `app/controllers/concerns/oauth_authorize_rate_limit.rb:12` | `OauthAuthorizeRateLimit#show` |
| 184 | B | `app/controllers/concerns/org_support_session_revocation_page.rb:20` | `OrgSupportSessionRevocationPage::InvalidRevocationInput#initialize` |
| 185 | A | `app/controllers/concerns/promotional_email_unsubscribe_actions.rb:15` | `PromotionalEmailUnsubscribeActions#edit` |
| 186 | B | `app/controllers/concerns/sign_email_registration_flow.rb:14` | `SignEmailRegistrationFlow#new` |
| 187 | B | `app/controllers/concerns/sign_email_registration_flow.rb:20` | `SignEmailRegistrationFlow#edit` |
| 188 | B | `app/controllers/concerns/sign_email_registration_flow.rb:29` | `SignEmailRegistrationFlow#create` |
| 189 | B | `app/controllers/concerns/sign_email_registration_flow.rb:68` | `SignEmailRegistrationFlow#update` |
| 190 | B | `app/controllers/concerns/sign_email_registration_flow.rb:106` | `SignEmailRegistrationFlow#resend` |
| 191 | A | `app/controllers/concerns/sign_entry_classification.rb:90` | `SignEntryClassification::ClassMethods#sign_entry_standby_only?` |
| 192 | A | `app/controllers/concerns/sign_entry_classification.rb:100` | `SignEntryClassification::ClassMethods#sign_entry_classification_reason` |
| 193 | A | `app/controllers/concerns/sign_entry_classification.rb:108` | `SignEntryClassification::ClassMethods#sign_entry_classification_overrides` |
| 194 | B | `app/controllers/concerns/sign_oidc_logout.rb:22` | `SignOidcLogout#show` |
| 195 | B | `app/controllers/concerns/sign_oidc_logout.rb:26` | `SignOidcLogout#create` |
| 196 | A | `app/controllers/concerns/verification_base.rb:34` | `VerificationBase#verification_scope` |
| 197 | B | `app/controllers/concerns/verification_base.rb:134` | `VerificationBase#require_step_up_unless_bootstrap!` |
| 198 | A | `app/controllers/core/app/application_controller.rb:97` | `Core::App::ApplicationController#oidc_sign_host` |
| 199 | A | `app/controllers/core/app/application_controller.rb:105` | `Core::App::ApplicationController#oidc_acme_host` |
| 200 | B | `app/controllers/core/app/sign/outs_controller.rb:22` | `Core::App::Sign::OutsController#show` |
| 201 | A | `app/controllers/core/org/application_controller.rb:96` | `Core::Org::ApplicationController#oidc_sign_host` |
| 202 | A | `app/controllers/core/org/application_controller.rb:104` | `Core::Org::ApplicationController#oidc_acme_host` |
| 203 | A | `app/controllers/edit/org/csp_violation_reports_controller.rb:15` | `Edit::Org::CspViolationReportsController#create` |
| 204 | A | `app/controllers/palm/app/application_controller.rb:105` | `Palm::App::ApplicationController#oidc_sign_host` |
| 205 | A | `app/controllers/palm/app/application_controller.rb:113` | `Palm::App::ApplicationController#oidc_acme_host` |
| 206 | A | `app/controllers/palm/app/sign/outs_controller.rb:28` | `Palm::App::Sign::OutsController#new` |
| 207 | A | `app/controllers/tech/org/application_controller.rb:90` | `Tech::Org::ApplicationController#oidc_sign_host` |
| 208 | A | `app/controllers/tech/org/application_controller.rb:94` | `Tech::Org::ApplicationController#oidc_acme_host` |
| 209 | A | `app/controllers/tech/org/csp_violation_reports_controller.rb:15` | `Tech::Org::CspViolationReportsController#create` |
| 210 | B | `app/controllers/tech/org/sign/outs_controller.rb:22` | `Tech::Org::Sign::OutsController#show` |
| 211 | A | `app/controllers/visa/app/api/v0/sensitive_admission_sessions_controller.rb:21` | `Visa::App::Api::V0::SensitiveAdmissionSessionsController#create` |
| 212 | A | `app/controllers/visa/app/oauth/userinfos_controller.rb:35` | `Visa::App::Oauth::UserinfosController#create` |
| 213 | B | `app/controllers/visa/app/oidc/logouts/completions_controller.rb:18` | `Visa::App::Oidc::Logouts::CompletionsController#show` |
| 214 | A | `app/controllers/visa/org/api/v0/sensitive_admission_sessions_controller.rb:21` | `Visa::Org::Api::V0::SensitiveAdmissionSessionsController#create` |
| 215 | B | `app/controllers/visa/org/api/v0/sensitive_admissions_controller.rb:20` | `Visa::Org::Api::V0::SensitiveAdmissionsController#create` |
| 216 | A | `app/controllers/warp/app/application_controller.rb:92` | `Warp::App::ApplicationController#oidc_sign_host` |
| 217 | A | `app/controllers/warp/app/application_controller.rb:100` | `Warp::App::ApplicationController#oidc_acme_host` |
| 218 | C | `app/controllers/warp/app/mcps_controller.rb:18` | `Warp::App::McpsController#create` |
| 219 | B | `app/controllers/warp/app/sign/outs_controller.rb:26` | `Warp::App::Sign::OutsController#show` |
| 220 | A | `app/controllers/warp/org/application_controller.rb:91` | `Warp::Org::ApplicationController#oidc_sign_host` |
| 221 | A | `app/controllers/warp/org/application_controller.rb:99` | `Warp::Org::ApplicationController#oidc_acme_host` |
| 222 | C | `app/controllers/warp/org/mcps_controller.rb:18` | `Warp::Org::McpsController#create` |
| 223 | A | `app/errors/blank_public_identifier_error.rb:13` | `BlankPublicIdentifierError#initialize` |
| 224 | A | `app/errors/blank_public_identifier_error.rb:18` | `BlankPublicIdentifierError#message` |
| 225 | A | `app/jobs/op_identity_event_delivery_job.rb:15` | `OpIdentityEventDeliveryJob#perform` |
| 226 | A | `app/jobs/rp_step_up_dispatch_recovery_job.rb:8` | `RpStepUpDispatchRecoveryJob#perform` |
| 227 | C | `app/lib/sign_up_otp_code_digest.rb:10` | `SignUpOtpCodeDigest#for` |
| 228 | A | `app/mailers/email/com/alert_mailer.rb:8` | `Email::Com::AlertMailer#notice` |
| 229 | C | `app/models/actor.rb:209` | `Actor#visitor` |
| 230 | A | `app/models/actor/authentication.rb:42` | `Actor::Authentication#authentication_context` |
| 231 | C | `app/models/actor/configuration.rb:26` | `Actor::Configuration::NullValue#configured?` |
| 232 | C | `app/models/actor/step_up.rb:28` | `Actor::StepUp#null` |
| 233 | C | `app/models/agent_authority_cutover.rb:15` | `#<Class:AgentAuthorityCutover(id: integer, cutover_at: datetime, created_at: datetime, updated_at: datetime)>#establish!` |
| 234 | A | `app/models/agent_authority_cutover.rb:20` | `AgentAuthorityCutover#readonly?` |
| 235 | A | `app/models/agent_lifecycle.rb:15` | `AgentLifecycle#active?` |
| 236 | C | `app/models/app_preference_adult_content_gate.rb:35` | `AppPreferenceAdultContentGate#approved?` |
| 237 | C | `app/models/app_preference_adult_content_gate.rb:37` | `AppPreferenceAdultContentGate#denied?` |
| 238 | C | `app/models/app_preference_adult_content_gate.rb:39` | `AppPreferenceAdultContentGate#enabled?` |
| 239 | C | `app/models/app_preference_adult_content_gate_option.rb:24` | `#<Class:AppPreferenceAdultContentGateOption(id: integer)>#ensure_defaults!` |
| 240 | C | `app/models/avatar_bureau_agent_grant.rb:41` | `AvatarBureauAgentGrant#effective_at?` |
| 241 | C | `app/models/avatar_enterprise_persona_grant.rb:42` | `AvatarEnterprisePersonaGrant#effective_at?` |
| 242 | C | `app/models/avatar_group_concrete_ownership_period.rb:20` | `AvatarGroupConcreteOwnershipPeriod#current?` |
| 243 | B | `app/models/avatar_ownership_cutover.rb:23` | `#<Class:AvatarOwnershipCutover(id: integer, cutover_at: datetime, created_at: datetime, updated_at: datetime)>#current` |
| 244 | C | `app/models/avatar_ownership_period_source.rb:26` | `AvatarOwnershipPeriodSource#all_for` |
| 245 | C | `app/models/bureau_authority_cutover.rb:15` | `#<Class:BureauAuthorityCutover(id: integer, cutover_at: datetime, created_at: datetime, updated_at: datetime)>#establish!` |
| 246 | A | `app/models/bureau_authority_cutover.rb:20` | `BureauAuthorityCutover#readonly?` |
| 247 | A | `app/models/bureau_lifecycle.rb:15` | `BureauLifecycle#active?` |
| 248 | C | `app/models/client_oidc_connection.rb:38` | `ClientOidcConnection#actor` |
| 249 | C | `app/models/client_preference_adult_content_gate.rb:35` | `ClientPreferenceAdultContentGate#approved?` |
| 250 | C | `app/models/client_preference_adult_content_gate.rb:37` | `ClientPreferenceAdultContentGate#denied?` |
| 251 | C | `app/models/client_preference_adult_content_gate.rb:39` | `ClientPreferenceAdultContentGate#enabled?` |
| 252 | C | `app/models/client_preference_adult_content_gate_option.rb:24` | `#<Class:ClientPreferenceAdultContentGateOption(id: integer)>#ensure_defaults!` |
| 253 | A | `app/models/client_registration_completion_method.rb:13` | `ClientRegistrationCompletionMethod#readonly?` |
| 254 | A | `app/models/client_totp_credential.rb:76` | `#<Class:ClientTotpCredential(id: integer, created_at: datetime, last_otp_at: datetime, private_key: string, public_id: string, title: string, updated_at: datetime, user_id: integer, user_identity_totp_credential_status_id: integer, otp_attempts_count: integer)>#slot_consuming_status_ids` |
| 255 | C | `app/models/client_totp_credential.rb:105` | `ClientTotpCredential#inactive?` |
| 256 | C | `app/models/client_totp_credential.rb:121` | `ClientTotpCredential#slot_consuming?` |
| 257 | A | `app/models/client_visa_social_link_admission.rb:8` | `#<Class:ClientVisaSocialLinkAdmission(id: integer, public_ref: string, oidc_authorization_transaction_id: integer, social_ceremony_transaction_id: integer, step_up_ceremony_transaction_id: integer, auth_admission_binding_id: integer, realm: string, client_id: string, actor_subject: string, grant_sid: string, rp_session_ref: string, rp_session_expires_at: datetime, browser_binding_digest: string, purpose: string, provider: string, event_jti: string, event_auth_time: integer, event_acr: string, event_amr: jsonb, status: string, expires_at: datetime, created_at: datetime, updated_at: datetime)>#connection_owner` |
| 258 | C | `app/models/com_preference_adult_content_gate.rb:35` | `ComPreferenceAdultContentGate#approved?` |
| 259 | C | `app/models/com_preference_adult_content_gate.rb:37` | `ComPreferenceAdultContentGate#denied?` |
| 260 | C | `app/models/com_preference_adult_content_gate.rb:39` | `ComPreferenceAdultContentGate#enabled?` |
| 261 | C | `app/models/concerns/auth_admission_binding.rb:58` | `AuthAdmissionBinding::ClassMethods#browser_digest` |
| 262 | C | `app/models/concerns/auth_admission_binding.rb:106` | `AuthAdmissionBinding#redeemed_or_switched?` |
| 263 | C | `app/models/concerns/auth_ceremony_session.rb:226` | `AuthCeremonySession#revoked?` |
| 264 | C | `app/models/concerns/auth_ceremony_session.rb:230` | `AuthCeremonySession#replaced?` |
| 265 | C | `app/models/concerns/banner_model.rb:23` | `BannerModel#actor` |
| 266 | D | `app/models/concerns/operator_secret_credential_kinds.rb:18` | `OperatorSecretCredentialKinds#one_time_secret_credential?` |
| 267 | C | `app/models/concerns/publishing_family_taxonomy_assignment.rb:17` | `PublishingFamilyTaxonomyAssignment::ClassMethods#expected_kind` |
| 268 | A | `app/models/concerns/publishing_family_taxonomy_assignment.rb:20` | `PublishingFamilyTaxonomyAssignment#structural_kind` |
| 269 | D | `app/models/concerns/secret_credential.rb:106` | `SecretCredential#used?` |
| 270 | D | `app/models/concerns/secret_credential.rb:114` | `SecretCredential#expired?` |
| 271 | C | `app/models/concerns/session_limit_resolution_transactionable.rb:85` | `SessionLimitResolutionTransactionable::ClassMethods#resolution_state_class` |
| 272 | C | `app/models/concerns/session_limit_resolution_transactionable.rb:162` | `SessionLimitResolutionTransactionable::ClassMethods#find_by_challenge` |
| 273 | C | `app/models/concerns/sign_flow_status_backed.rb:16` | `SignFlowStatusBacked::ClassMethods#status_ids_for` |
| 274 | C | `app/models/concerns/sign_flow_status_backed.rb:30` | `SignFlowStatusBacked#status_ids_for` |
| 275 | C | `app/models/concerns/sign_flow_status_backed.rb:38` | `SignFlowStatusBacked#can_transition_to?` |
| 276 | C | `app/models/concerns/sign_in_flow.rb:35` | `SignInFlow#state_ids_for` |
| 277 | C | `app/models/concerns/sign_up_flow_ticket.rb:37` | `SignUpFlowTicket::ClassMethods#cleanup_status_class` |
| 278 | C | `app/models/enterprise_authority_cutover.rb:15` | `#<Class:EnterpriseAuthorityCutover(id: integer, cutover_at: datetime, created_at: datetime, updated_at: datetime)>#establish!` |
| 279 | A | `app/models/enterprise_authority_cutover.rb:20` | `EnterpriseAuthorityCutover#readonly?` |
| 280 | A | `app/models/enterprise_lifecycle.rb:15` | `EnterpriseLifecycle#active?` |
| 281 | A | `app/models/logout_transaction.rb:145` | `#<Class:LogoutTransaction(id: integer, public_id: string, token_digest: binary, issuer: string, audience: string, purpose: string, expires_at: datetime, consumed_at: datetime, revoked_at: datetime, failed_at: datetime, failure_code: string, lock_version: integer, created_at: datetime, updated_at: datetime)>#public_id_collision?` |
| 282 | A | `app/models/op_org_authority_stop_participant.rb:20` | `OpOrgAuthorityStopParticipant#final?` |
| 283 | B | `app/models/operator_email.rb:88` | `OperatorEmail#finalize_email_registration!` |
| 284 | C | `app/models/operator_lifecycle_request.rb:93` | `OperatorLifecycleRequest#withdraw?` |
| 285 | C | `app/models/operator_lifecycle_request.rb:95` | `OperatorLifecycleRequest#suspend?` |
| 286 | C | `app/models/operator_lifecycle_request.rb:97` | `OperatorLifecycleRequest#terminate?` |
| 287 | C | `app/models/operator_lifecycle_request.rb:99` | `OperatorLifecycleRequest#restore?` |
| 288 | A | `app/models/operator_oidc_connection.rb:38` | `OperatorOidcConnection#actor` |
| 289 | C | `app/models/operator_preference_adult_content_gate.rb:35` | `OperatorPreferenceAdultContentGate#approved?` |
| 290 | C | `app/models/operator_preference_adult_content_gate.rb:37` | `OperatorPreferenceAdultContentGate#denied?` |
| 291 | C | `app/models/operator_preference_adult_content_gate.rb:39` | `OperatorPreferenceAdultContentGate#enabled?` |
| 292 | B | `app/models/operator_preference_adult_content_gate_option.rb:24` | `#<Class:OperatorPreferenceAdultContentGateOption(id: integer)>#ensure_defaults!` |
| 293 | B | `app/models/operator_telephone.rb:81` | `OperatorTelephone#finalize_telephone_registration!` |
| 294 | C | `app/models/org_preference_adult_content_gate.rb:35` | `OrgPreferenceAdultContentGate#approved?` |
| 295 | C | `app/models/org_preference_adult_content_gate.rb:37` | `OrgPreferenceAdultContentGate#denied?` |
| 296 | C | `app/models/org_preference_adult_content_gate.rb:39` | `OrgPreferenceAdultContentGate#enabled?` |
| 297 | B | `app/models/org_preference_adult_content_gate_option.rb:24` | `#<Class:OrgPreferenceAdultContentGateOption(id: integer)>#ensure_defaults!` |
| 298 | A | `app/models/publishing/content_families.rb:235` | `Publishing::ContentFamilies#entry_class_for_revision` |
| 299 | A | `app/models/publishing/content_families.rb:243` | `Publishing::ContentFamilies#entry_class_for_version` |
| 300 | C | `app/models/rp_base_app_callback_state.rb:22` | `RpBaseAppCallbackState#consumed?` |
| 301 | C | `app/models/rp_base_org_callback_state.rb:22` | `RpBaseOrgCallbackState#consumed?` |
| 302 | C | `app/models/rp_core_app_callback_state.rb:22` | `RpCoreAppCallbackState#consumed?` |
| 303 | C | `app/models/rp_core_org_callback_state.rb:22` | `RpCoreOrgCallbackState#consumed?` |
| 304 | C | `app/models/rp_edit_org_callback_state.rb:22` | `RpEditOrgCallbackState#consumed?` |
| 305 | C | `app/models/rp_palm_app_callback_state.rb:22` | `RpPalmAppCallbackState#consumed?` |
| 306 | C | `app/models/rp_tech_org_callback_state.rb:22` | `RpTechOrgCallbackState#consumed?` |
| 307 | C | `app/models/rp_warp_app_callback_state.rb:22` | `RpWarpAppCallbackState#consumed?` |
| 308 | C | `app/models/rp_warp_org_callback_state.rb:22` | `RpWarpOrgCallbackState#consumed?` |
| 309 | A | `app/notifiers/notify/org/otp_notifier.rb:12` | `Notify::Org::OtpNotifier#otp_delivery_surface` |
| 310 | A | `app/operations/authority_owner_cutover_guard.rb:33` | `AuthorityOwnerCutoverGuard::Result#cutover_established?` |
| 311 | C | `app/operations/authority_owner_family_cutover_operation.rb:21` | `AuthorityOwnerFamilyCutoverOperation::CutoverRejected#initialize` |
| 312 | A | `app/operations/avatar_concrete_ownership_backfill_operation.rb:19` | `AvatarConcreteOwnershipBackfillOperation::Result#to_h` |
| 313 | A | `app/operations/avatar_concrete_ownership_backfill_operation.rb:21` | `AvatarConcreteOwnershipBackfillOperation::Result#to_json` |
| 314 | A | `app/operations/avatar_group_concrete_ownership_backfill_operation.rb:16` | `AvatarGroupConcreteOwnershipBackfillOperation::Result#to_h` |
| 315 | A | `app/operations/avatar_group_concrete_ownership_backfill_operation.rb:18` | `AvatarGroupConcreteOwnershipBackfillOperation::Result#to_json` |
| 316 | C | `app/operations/avatar_ownership_cutover_operation.rb:11` | `AvatarOwnershipCutoverOperation::Result#established?` |
| 317 | C | `app/operations/avatar_ownership_cutover_operation.rb:15` | `AvatarOwnershipCutoverOperation::Result#blocked?` |
| 318 | A | `app/operations/avatar_ownership_cutover_operation.rb:19` | `AvatarOwnershipCutoverOperation::Result#to_h` |
| 319 | A | `app/operations/avatar_ownership_cutover_operation.rb:28` | `AvatarOwnershipCutoverOperation::Result#to_json` |
| 320 | C | `app/operations/base_step_up_admission_issuer.rb:35` | `BaseStepUpAdmissionIssuer#restart_binding_for_form!` |
| 321 | C | `app/operations/identity_email_bootstrap_committer.rb:12` | `IdentityEmailBootstrapCommitter#call!` |
| 322 | A | `app/operations/identity_passkey_ceremony_result_issuer.rb:7` | `IdentityPasskeyCeremonyResultIssuer::Candidate#initialize` |
| 323 | A | `app/operations/identity_social_ceremony_transaction_purger.rb:13` | `IdentitySocialCeremonyTransactionPurger#initialize` |
| 324 | A | `app/operations/identity_social_ceremony_transaction_purger.rb:18` | `IdentitySocialCeremonyTransactionPurger#call` |
| 325 | A | `app/operations/visa_sensitive_admission_browser_confirmer.rb:15` | `VisaSensitiveAdmissionBrowserConfirmer#call!` |
| 326 | A | `app/operations/visa_sensitive_admission_browser_confirmer.rb:24` | `VisaSensitiveAdmissionBrowserConfirmer#initialize` |
| 327 | A | `app/operations/visa_sensitive_admission_browser_confirmer.rb:35` | `VisaSensitiveAdmissionBrowserConfirmer#call` |
| 328 | C | `app/presenters/auth/app/settings/activity_log_presenter.rb:53` | `Auth::App::Settings::ActivityLogPresenter#activities` |
| 329 | B | `app/presenters/base/identity/activity_log_presenter.rb:40` | `Base::Identity::ActivityLogPresenter#operator_events` |
| 330 | A | `app/queries/avatar_group_ownership_transition_inventory_query.rb:27` | `AvatarGroupOwnershipTransitionInventoryQuery::Result#to_h` |
| 331 | C | `app/queries/avatar_group_ownership_transition_inventory_query.rb:29` | `AvatarGroupOwnershipTransitionInventoryQuery::Result#to_json` |
| 332 | A | `app/queries/avatar_ownership_transition_inventory_query.rb:22` | `AvatarOwnershipTransitionInventoryQuery::Result#selection_complete?` |
| 333 | C | `app/queries/avatar_ownership_transition_inventory_query.rb:26` | `AvatarOwnershipTransitionInventoryQuery::Result#blocking?` |
| 334 | A | `app/queries/avatar_ownership_transition_inventory_query.rb:30` | `AvatarOwnershipTransitionInventoryQuery::Result#to_h` |
| 335 | C | `app/queries/avatar_ownership_transition_inventory_query.rb:32` | `AvatarOwnershipTransitionInventoryQuery::Result#to_json` |
| 336 | A | `app/queries/identifier_contract_inventory_query.rb:170` | `IdentifierContractInventoryQuery::Result#to_h` |
| 337 | A | `app/queries/identifier_contract_inventory_query.rb:172` | `IdentifierContractInventoryQuery::Result#to_json` |
| 338 | A | `app/queries/identifier_contract_inventory_query.rb:178` | `IdentifierContractInventoryQuery#call` |
| 339 | A | `app/queries/publishing_published_entries_query.rb:7` | `PublishingPublishedEntriesQuery#call` |
| 340 | B | `app/resolvers/account_standing_resolver.rb:8` | `AccountStandingResolver#call` |
| 341 | A | `app/services/base_auth_admission_coordinator.rb:168` | `BaseAuthAdmissionCoordinator#validate_registration_restart_browser!` |
| 342 | A | `app/services/identity_social_ceremony_candidate_store.rb:26` | `IdentitySocialCeremonyCandidateStore#fetch_consumed!` |
| 343 | A | `app/services/identity_social_ceremony_candidate_store.rb:85` | `IdentitySocialCeremonyCandidateStore#fetch_consumed!` |
| 344 | C | `app/services/identity_step_up_ceremony_replay_store.rb:26` | `IdentityStepUpCeremonyReplayStore#find_transaction!` |
| 345 | C | `app/services/identity_step_up_ceremony_replay_store.rb:30` | `IdentityStepUpCeremonyReplayStore#latest_pending_for` |
| 346 | C | `app/services/identity_step_up_ceremony_replay_store.rb:34` | `IdentityStepUpCeremonyReplayStore#consumed?` |
| 347 | A | `app/services/sign_secret_record_event.rb:7` | `SignSecretRecordEvent#call` |
| 348 | A | `app/services/sign_secret_record_event.rb:11` | `SignSecretRecordEvent#initialize` |
| 349 | A | `app/services/sign_secret_record_event.rb:17` | `SignSecretRecordEvent#call` |
| 350 | C | `app/values/actor_values_context.rb:114` | `ActorValuesContext#anonymous?` |
| 351 | A | `app/values/actor_values_context.rb:120` | `ActorValuesContext#visitor?` |
| 352 | C | `app/values/browser_session_security_context.rb:17` | `BrowserSessionSecurityContext#active?` |
| 353 | C | `app/values/email_sign_up_otp_issue_result.rb:9` | `EmailSignUpOtpIssueResult#inspect` |
| 354 | C | `app/values/external_authentication/link_result.rb:13` | `ExternalAuthentication::LinkResult#linked?` |
| 355 | C | `app/values/identity_social_ceremony_contract.rb:52` | `IdentitySocialCeremonyContract#sign_issuer` |
| 356 | C | `app/values/identity_social_ceremony_contract.rb:60` | `IdentitySocialCeremonyContract#acme_audience` |
| 357 | C | `app/values/identity_social_ceremony_contract.rb:62` | `IdentitySocialCeremonyContract#sign_issuer_id` |
| 358 | C | `app/values/identity_social_ceremony_grant.rb:55` | `IdentitySocialCeremonyGrant#fetch` |
| 359 | A | `app/values/identity_social_ceremony_grant.rb:57` | `IdentitySocialCeremonyGrant#expires_at` |
| 360 | C | `app/values/identity_step_up_ceremony_contract.rb:95` | `IdentityStepUpCeremonyContract#base_issuer_id` |
| 361 | C | `app/values/identity_step_up_ceremony_grant.rb:59` | `IdentityStepUpCeremonyGrant#full_reauthentication_required?` |
| 362 | C | `app/values/identity_step_up_ceremony_grant.rb:61` | `IdentityStepUpCeremonyGrant#phishing_resistant_required?` |
| 363 | C | `app/values/identity_step_up_ceremony_result.rb:50` | `IdentityStepUpCeremonyResult#phishing_resistant?` |
| 364 | A | `app/values/oidc_client_assertion_jwt.rb:14` | `OidcClientAssertionJwt::VerificationResult#step_up_claims_present?` |
| 365 | C | `app/values/oidc_client_registry.rb:256` | `OidcClientRegistry#metadata_auth_method` |
| 366 | C | `app/values/oidc_client_registry.rb:282` | `OidcClientRegistry#normalize_host` |
| 367 | C | `app/values/rp_cell_binding.rb:64` | `RpCellBinding#connections` |
| 368 | C | `app/values/rp_deployment_binding_value.rb:51` | `RpDeploymentBindingValue#catalog` |
| 369 | C | `app/values/sign_in_path_refusal_value.rb:82` | `SignInPathRefusalValue#protocol?` |
| 370 | C | `app/values/telephone_sign_up_otp_issue_result.rb:11` | `TelephoneSignUpOtpIssueResult#inspect` |
| 371 | C | `app/values/webauthn/authentication_context.rb:46` | `Webauthn::AuthenticationContext#phishing_resistant?` |
| 372 | A | `app/values/webauthn/surface.rb:36` | `Webauthn::Surface#ceremony_transaction_class` |
| 373 | A | `app/values/webauthn/uv_policy.rb:49` | `Webauthn::UvPolicy#all` |
| 374 | B | `lib/architecture_baseline.rb:45` | `ArchitectureBaseline#write` |
| 375 | A | `lib/config_values_host_family_values.rb:83` | `ConfigValues::HostFamilyValues#docs_origins` |
| 376 | A | `lib/config_values_host_family_values.rb:87` | `ConfigValues::HostFamilyValues#news_origins` |
| 377 | A | `lib/jit_security_jwt_registry.rb:304` | `JitSecurityJwtRegistry#private_env_name_for` |
| 378 | A | `lib/jit_security_turnstile_config.rb:15` | `JitSecurityTurnstileConfig#visible_site_key` |
| 379 | A | `lib/jit_security_turnstile_config.rb:27` | `JitSecurityTurnstileConfig#stealth_secret_key` |
| 380 | A | `lib/object_storage_shrine_configuration.rb:146` | `ObjectStorage::ShrineConfiguration#s3_compatible_storage` |
| 381 | A | `lib/rails_performance_store_resilience.rb:33` | `RailsPerformanceStoreResilience::UtilsPatch#save_to_redis` |
| 382 | A | `lib/runtime_role.rb:53` | `RuntimeRole#cell_connection` |
| 383 | A | `lib/runtime_role.rb:62` | `RuntimeRole#rp_private_env_names` |
| 384 | A | `lib/umaxica/test_environment/database_safety.rb:41` | `Umaxica::TestEnvironment::DatabaseSafety#report` |
| 385 | A | `lib/umaxica/test_environment/database_safety.rb:182` | `Umaxica::TestEnvironment::DatabaseSafety#query_catalog!` |
| 386 | A | `lib/umaxica/valkey/namespaces.rb:29` | `Umaxica::Valkey::Namespaces#rp_refresh` |
| 387 | A | `lib/umaxica/valkey/responsibility_urls.rb:46` | `Umaxica::Valkey::ResponsibilityUrls#require_url` |
| 388 | A | `lib/umaxica/valkey/settings.rb:89` | `Umaxica::Valkey::Settings#performance` |
| 389 | A | `lib/umaxica/valkey/settings.rb:93` | `Umaxica::Valkey::Settings#coverband` |
| 390 | A | `lib/umaxica/valkey/settings.rb:97` | `Umaxica::Valkey::Settings#[]` |

## B test files

Existing failing tests associated with B methods; do not add duplicate tests while these flows fail:

- `test/controllers/auth/sign_up_checkpoint_cancellation_test.rb`
- `test/integration/telephone_signup_source_proof_retry_test.rb`
- `test/controllers/base/identity_read_only_pages_test.rb`
- `test/controllers/base/app/verification/setups_controller_test.rb`
- `test/controllers/base/app/billings_controller_test.rb`
- `test/controllers/base/app/identity/emails_controller_test.rb`
- `test/controllers/base/app/identity/telephones_controller_test.rb`
- `test/integration/app_passkey_secret_session_step_up_test.rb`
- `test/controllers/base/app/identity/withdrawals_controller_test.rb`
- `test/controllers/base/org/support/enforcement_cases_controller_test.rb`
- `test/controllers/base/org/identity/emails/registrations_controller_test.rb`
- `test/integration/identity_settings_page_coverage_test.rb`
- `test/integration/oidc_rp_logout_edit_return_test.rb`
- `test/controllers/base/org/support/session_revocations_test.rb`
- `test/integration/oidc_current_device_logout_test.rb`
- `test/integration/oidc_rp_logout_registered_rp_matrix_test.rb`
- `test/operations/avatar_ownership_cutover_operation_test.rb`
- `test/tooling/architecture_baseline_test.rb`
- `test/controllers/visa/org/sensitive_admission_api_coverage_test.rb` — the new authenticated request receives 503 from `ActiveRecord::StrictLoadingViolationError` in `authenticate_base_caller!`, before `SensitiveAdmissionsController#create` runs.

## A rows with later test additions

These A rows have a later public test or test addition in the current dirty worktree. The incomplete focused batch reached rows 1–3, 11, 87, 101, 158, 225, 254, 323–327, 341, and 347–349; the remaining listed rows still need full-suite confirmation. Row 3 is reached by a test that currently fails at the expected HTTP response, so it is not a passing coverage result.

1, 2, 3, 11, 21, 22, 23, 24, 25, 31, 32, 33, 47, 48, 85, 86, 87, 99, 100, 101, 134, 158, 161, 225, 254, 323, 324, 325, 326, 327, 341, 347, 348, 349

## C candidates

No C method was deleted. Review these definitions with their owners before any removal:

- TSV row 4: `app/adapters/mcp_liveness_tool.rb:22` — `McpLivenessTool#call`
- TSV row 5: `app/adapters/mcp_service_info_tool.rb:21` — `McpServiceInfoTool#call`
- TSV row 6: `app/adapters/mcp_version_tool.rb:24` — `McpVersionTool#call`
- TSV row 7: `app/adapters/oidc_op_jwks_client.rb:31` — `OidcOpJwksClient::Lookup#invalid?`
- TSV row 8: `app/adapters/processor_erasure_notification_adapter.rb:7` — `ProcessorErasureNotificationAdapter#retry_policy`
- TSV row 9: `app/adapters/processor_erasure_notification_adapter.rb:11` — `ProcessorErasureNotificationAdapter#dispatch`
- TSV row 10: `app/adapters/processor_erasure_notification_adapter.rb:15` — `ProcessorErasureNotificationAdapter#verify_receipt`
- TSV row 12: `app/consumers/totp_window_consumer.rb:18` — `TotpWindowConsumer::Result#revoked?`
- TSV row 13: `app/consumers/totp_window_consumer.rb:20` — `TotpWindowConsumer::Result#credential_required?`
- TSV row 14: `app/controllers/auth/app/settings/removals_controller.rb:23` — `Auth::App::Settings::RemovalsController#create`
- TSV row 15: `app/controllers/auth/app/sign/in/checks_controller.rb:23` — `Auth::App::Sign::In::ChecksController#show`
- TSV row 19: `app/controllers/auth/org/application_controller.rb:98` — `Auth::Org::ApplicationController#acme_authority_host`
- TSV row 20: `app/controllers/auth/org/sign/in/checks_controller.rb:23` — `Auth::Org::Sign::In::ChecksController#show`
- TSV row 365: `app/values/oidc_client_registry.rb:256` — `OidcClientRegistry#metadata_auth_method` (private; the fixed static registry makes this metadata fallback unreachable for its registered clients)
- TSV row 65: `app/controllers/base/app/mcps_controller.rb:18` — `Base::App::McpsController#create`
- TSV row 133: `app/controllers/base/org/mcps_controller.rb:18` — `Base::Org::McpsController#create`
- TSV row 146: `app/controllers/concerns/authentication_base.rb:271` — `AuthenticationBase#parse_authentication_event_at`
- TSV row 147: `app/controllers/concerns/authentication_base.rb:911` — `AuthenticationBase#resource_class`
- TSV row 148: `app/controllers/concerns/authentication_base.rb:915` — `AuthenticationBase#token_class`
- TSV row 149: `app/controllers/concerns/authentication_base.rb:919` — `AuthenticationBase#audit_class`
- TSV row 150: `app/controllers/concerns/authentication_base.rb:923` — `AuthenticationBase#resource_type`
- TSV row 151: `app/controllers/concerns/authentication_base.rb:927` — `AuthenticationBase#resource_foreign_key`
- TSV row 152: `app/controllers/concerns/authentication_base.rb:931` — `AuthenticationBase#sign_in_url_with_pt`
- TSV row 153: `app/controllers/concerns/authentication_base.rb:942` — `AuthenticationBase#am_i_user?`
- TSV row 154: `app/controllers/concerns/authentication_base.rb:946` — `AuthenticationBase#am_i_operator?`
- TSV row 155: `app/controllers/concerns/authentication_base.rb:950` — `AuthenticationBase#am_i_owner?`
- TSV row 156: `app/controllers/concerns/authentication_jwt_configuration.rb:65` — `AuthenticationJwtConfiguration#public_key`
- TSV row 159: `app/controllers/concerns/base_admission_browser_binding.rb:53` — `BaseAdmissionBrowserBinding#require_base_admission_browser_nonce!`
- TSV row 218: `app/controllers/warp/app/mcps_controller.rb:18` — `Warp::App::McpsController#create`
- TSV row 222: `app/controllers/warp/org/mcps_controller.rb:18` — `Warp::Org::McpsController#create`
- TSV row 227: `app/lib/sign_up_otp_code_digest.rb:10` — `SignUpOtpCodeDigest#for`
- TSV row 229: `app/models/actor.rb:209` — `Actor#visitor`
- TSV row 231: `app/models/actor/configuration.rb:26` — `Actor::Configuration::NullValue#configured?`
- TSV row 232: `app/models/actor/step_up.rb:28` — `Actor::StepUp#null`
- TSV row 233: `app/models/agent_authority_cutover.rb:15` — `#<Class:AgentAuthorityCutover(id: integer, cutover_at: datetime, created_at: datetime, updated_at: datetime)>#establish!`
- TSV row 236: `app/models/app_preference_adult_content_gate.rb:35` — `AppPreferenceAdultContentGate#approved?`
- TSV row 237: `app/models/app_preference_adult_content_gate.rb:37` — `AppPreferenceAdultContentGate#denied?`
- TSV row 238: `app/models/app_preference_adult_content_gate.rb:39` — `AppPreferenceAdultContentGate#enabled?`
- TSV row 239: `app/models/app_preference_adult_content_gate_option.rb:24` — `#<Class:AppPreferenceAdultContentGateOption(id: integer)>#ensure_defaults!`
- TSV row 240: `app/models/avatar_bureau_agent_grant.rb:41` — `AvatarBureauAgentGrant#effective_at?`
- TSV row 241: `app/models/avatar_enterprise_persona_grant.rb:42` — `AvatarEnterprisePersonaGrant#effective_at?`
- TSV row 242: `app/models/avatar_group_concrete_ownership_period.rb:20` — `AvatarGroupConcreteOwnershipPeriod#current?`
- TSV row 244: `app/models/avatar_ownership_period_source.rb:26` — `AvatarOwnershipPeriodSource#all_for`
- TSV row 245: `app/models/bureau_authority_cutover.rb:15` — `#<Class:BureauAuthorityCutover(id: integer, cutover_at: datetime, created_at: datetime, updated_at: datetime)>#establish!`
- TSV row 248: `app/models/client_oidc_connection.rb:38` — `ClientOidcConnection#actor`
- TSV row 249: `app/models/client_preference_adult_content_gate.rb:35` — `ClientPreferenceAdultContentGate#approved?`
- TSV row 250: `app/models/client_preference_adult_content_gate.rb:37` — `ClientPreferenceAdultContentGate#denied?`
- TSV row 251: `app/models/client_preference_adult_content_gate.rb:39` — `ClientPreferenceAdultContentGate#enabled?`
- TSV row 252: `app/models/client_preference_adult_content_gate_option.rb:24` — `#<Class:ClientPreferenceAdultContentGateOption(id: integer)>#ensure_defaults!`
- TSV row 255: `app/models/client_totp_credential.rb:105` — `ClientTotpCredential#inactive?`
- TSV row 256: `app/models/client_totp_credential.rb:121` — `ClientTotpCredential#slot_consuming?`
- TSV row 258: `app/models/com_preference_adult_content_gate.rb:35` — `ComPreferenceAdultContentGate#approved?`
- TSV row 259: `app/models/com_preference_adult_content_gate.rb:37` — `ComPreferenceAdultContentGate#denied?`
- TSV row 260: `app/models/com_preference_adult_content_gate.rb:39` — `ComPreferenceAdultContentGate#enabled?`
- TSV row 261: `app/models/concerns/auth_admission_binding.rb:58` — `AuthAdmissionBinding::ClassMethods#browser_digest`
- TSV row 262: `app/models/concerns/auth_admission_binding.rb:106` — `AuthAdmissionBinding#redeemed_or_switched?`
- TSV row 263: `app/models/concerns/auth_ceremony_session.rb:226` — `AuthCeremonySession#revoked?`
- TSV row 264: `app/models/concerns/auth_ceremony_session.rb:230` — `AuthCeremonySession#replaced?`
- TSV row 265: `app/models/concerns/banner_model.rb:23` — `BannerModel#actor`
- TSV row 267: `app/models/concerns/publishing_family_taxonomy_assignment.rb:17` — `PublishingFamilyTaxonomyAssignment::ClassMethods#expected_kind`
- TSV row 271: `app/models/concerns/session_limit_resolution_transactionable.rb:85` — `SessionLimitResolutionTransactionable::ClassMethods#resolution_state_class`
- TSV row 272: `app/models/concerns/session_limit_resolution_transactionable.rb:162` — `SessionLimitResolutionTransactionable::ClassMethods#find_by_challenge`
- TSV row 273: `app/models/concerns/sign_flow_status_backed.rb:16` — `SignFlowStatusBacked::ClassMethods#status_ids_for`
- TSV row 274: `app/models/concerns/sign_flow_status_backed.rb:30` — `SignFlowStatusBacked#status_ids_for`
- TSV row 275: `app/models/concerns/sign_flow_status_backed.rb:38` — `SignFlowStatusBacked#can_transition_to?`
- TSV row 276: `app/models/concerns/sign_in_flow.rb:35` — `SignInFlow#state_ids_for`
- TSV row 277: `app/models/concerns/sign_up_flow_ticket.rb:37` — `SignUpFlowTicket::ClassMethods#cleanup_status_class`
- TSV row 278: `app/models/enterprise_authority_cutover.rb:15` — `#<Class:EnterpriseAuthorityCutover(id: integer, cutover_at: datetime, created_at: datetime, updated_at: datetime)>#establish!`
- TSV row 284: `app/models/operator_lifecycle_request.rb:93` — `OperatorLifecycleRequest#withdraw?`
- TSV row 285: `app/models/operator_lifecycle_request.rb:95` — `OperatorLifecycleRequest#suspend?`
- TSV row 286: `app/models/operator_lifecycle_request.rb:97` — `OperatorLifecycleRequest#terminate?`
- TSV row 287: `app/models/operator_lifecycle_request.rb:99` — `OperatorLifecycleRequest#restore?`
- TSV row 289: `app/models/operator_preference_adult_content_gate.rb:35` — `OperatorPreferenceAdultContentGate#approved?`
- TSV row 290: `app/models/operator_preference_adult_content_gate.rb:37` — `OperatorPreferenceAdultContentGate#denied?`
- TSV row 291: `app/models/operator_preference_adult_content_gate.rb:39` — `OperatorPreferenceAdultContentGate#enabled?`
- TSV row 294: `app/models/org_preference_adult_content_gate.rb:35` — `OrgPreferenceAdultContentGate#approved?`
- TSV row 295: `app/models/org_preference_adult_content_gate.rb:37` — `OrgPreferenceAdultContentGate#denied?`
- TSV row 296: `app/models/org_preference_adult_content_gate.rb:39` — `OrgPreferenceAdultContentGate#enabled?`
- TSV row 300: `app/models/rp_base_app_callback_state.rb:22` — `RpBaseAppCallbackState#consumed?`
- TSV row 301: `app/models/rp_base_org_callback_state.rb:22` — `RpBaseOrgCallbackState#consumed?`
- TSV row 302: `app/models/rp_core_app_callback_state.rb:22` — `RpCoreAppCallbackState#consumed?`
- TSV row 303: `app/models/rp_core_org_callback_state.rb:22` — `RpCoreOrgCallbackState#consumed?`
- TSV row 304: `app/models/rp_edit_org_callback_state.rb:22` — `RpEditOrgCallbackState#consumed?`
- TSV row 305: `app/models/rp_palm_app_callback_state.rb:22` — `RpPalmAppCallbackState#consumed?`
- TSV row 306: `app/models/rp_tech_org_callback_state.rb:22` — `RpTechOrgCallbackState#consumed?`
- TSV row 307: `app/models/rp_warp_app_callback_state.rb:22` — `RpWarpAppCallbackState#consumed?`
- TSV row 308: `app/models/rp_warp_org_callback_state.rb:22` — `RpWarpOrgCallbackState#consumed?`
- TSV row 311: `app/operations/authority_owner_family_cutover_operation.rb:21` — `AuthorityOwnerFamilyCutoverOperation::CutoverRejected#initialize`
- TSV row 316: `app/operations/avatar_ownership_cutover_operation.rb:11` — `AvatarOwnershipCutoverOperation::Result#established?`
- TSV row 317: `app/operations/avatar_ownership_cutover_operation.rb:15` — `AvatarOwnershipCutoverOperation::Result#blocked?`
- TSV row 320: `app/operations/base_step_up_admission_issuer.rb:35` — `BaseStepUpAdmissionIssuer#restart_binding_for_form!`
- TSV row 321: `app/operations/identity_email_bootstrap_committer.rb:12` — `IdentityEmailBootstrapCommitter#call!`
- TSV row 328: `app/presenters/auth/app/settings/activity_log_presenter.rb:53` — `Auth::App::Settings::ActivityLogPresenter#activities`
- TSV row 331: `app/queries/avatar_group_ownership_transition_inventory_query.rb:29` — `AvatarGroupOwnershipTransitionInventoryQuery::Result#to_json`
- TSV row 333: `app/queries/avatar_ownership_transition_inventory_query.rb:26` — `AvatarOwnershipTransitionInventoryQuery::Result#blocking?`
- TSV row 335: `app/queries/avatar_ownership_transition_inventory_query.rb:32` — `AvatarOwnershipTransitionInventoryQuery::Result#to_json`
- TSV row 344: `app/services/identity_step_up_ceremony_replay_store.rb:26` — `IdentityStepUpCeremonyReplayStore#find_transaction!`
- TSV row 345: `app/services/identity_step_up_ceremony_replay_store.rb:30` — `IdentityStepUpCeremonyReplayStore#latest_pending_for`
- TSV row 346: `app/services/identity_step_up_ceremony_replay_store.rb:34` — `IdentityStepUpCeremonyReplayStore#consumed?`
- TSV row 350: `app/values/actor_values_context.rb:114` — `ActorValuesContext#anonymous?`
- TSV row 352: `app/values/browser_session_security_context.rb:17` — `BrowserSessionSecurityContext#active?`
- TSV row 353: `app/values/email_sign_up_otp_issue_result.rb:9` — `EmailSignUpOtpIssueResult#inspect`
- TSV row 354: `app/values/external_authentication/link_result.rb:13` — `ExternalAuthentication::LinkResult#linked?`
- TSV row 355: `app/values/identity_social_ceremony_contract.rb:52` — `IdentitySocialCeremonyContract#sign_issuer`
- TSV row 356: `app/values/identity_social_ceremony_contract.rb:60` — `IdentitySocialCeremonyContract#acme_audience`
- TSV row 357: `app/values/identity_social_ceremony_contract.rb:62` — `IdentitySocialCeremonyContract#sign_issuer_id`
- TSV row 358: `app/values/identity_social_ceremony_grant.rb:55` — `IdentitySocialCeremonyGrant#fetch`
- TSV row 360: `app/values/identity_step_up_ceremony_contract.rb:95` — `IdentityStepUpCeremonyContract#base_issuer_id`
- TSV row 361: `app/values/identity_step_up_ceremony_grant.rb:59` — `IdentityStepUpCeremonyGrant#full_reauthentication_required?`
- TSV row 362: `app/values/identity_step_up_ceremony_grant.rb:61` — `IdentityStepUpCeremonyGrant#phishing_resistant_required?`
- TSV row 363: `app/values/identity_step_up_ceremony_result.rb:50` — `IdentityStepUpCeremonyResult#phishing_resistant?`
- TSV row 366: `app/values/oidc_client_registry.rb:282` — `OidcClientRegistry#normalize_host`
- TSV row 367: `app/values/rp_cell_binding.rb:64` — `RpCellBinding#connections`
- TSV row 368: `app/values/rp_deployment_binding_value.rb:51` — `RpDeploymentBindingValue#catalog`
- TSV row 369: `app/values/sign_in_path_refusal_value.rb:82` — `SignInPathRefusalValue#protocol?`
- TSV row 370: `app/values/telephone_sign_up_otp_issue_result.rb:11` — `TelephoneSignUpOtpIssueResult#inspect`
- TSV row 371: `app/values/webauthn/authentication_context.rb:46` — `Webauthn::AuthenticationContext#phishing_resistant?`

## D refusal-only methods

| TSV rows | Surface and feature family | Required test shape |
|---|---|---|
| 26 | APP identity selection API | Refusal and unchanged RP/OP selection. |
| 46, 49–51 | APP other-session revocation and session inventory | Refusal and unchanged session state. |
| 66–77 | APP Secret issuance, presentation and management | RP refusal and no mutation only. |
| 79–84 | APP verification/cancellation/bootstrap | RP refusal and no mutation only. |
| 113–123 | ORG identity removal, other-session revocation, Secret credentials and sessions | RP refusal and no mutation only. |
| 132 | ORG telephone creation | RP refusal and no mutation only. |
| 135 | ORG selector update after selection | Redirect/refusal and unchanged selection; `/switcher` remains the switch path. |
| 35–40, 53–56, 127–128 | APP and ORG contact registration under the accepted interim fail-closed boundary | Refusal and no candidate, OTP, job, or contact mutation. Do not add success-flow tests until the accepted owner API and source receipt work is implemented. |
| 266, 269–270 | ORG one-time Secret predicate and APP Secret credential predicates | Do not add RP success paths; verify only the accepted refusal contract. |

