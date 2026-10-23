# G-1 full test baseline for the authentication cycle

- Date: 2026-10-22 UTC (2026-10-23 JST).
- Commit: `6e4d70d0b0799a4ef9bd9fc4cea2c21d4b3eca72`.
- Worktree: this cycle's working documents are gitignored. While the run took place, another
  session had uncommitted changes in `config/locales/{jp,us}/{ja,en}.yml`,
  `app/views/pwa/offline.html.erb`, `adr/pwa-offline-route-exception.md`,
  `test/controllers/pwa_endpoints_test.rb` and a backlog file; they may have affected the result.
  No application code was changed by this session.

## Test database rebuild (owner-approved)

A first run on the existing test databases gave 18447 runs, 119 failures, 250 errors; 232 errors
were `Couldn't find Op{App,Com,Org}ProtocolEpoch with 'id'=1` and 11 were
`identifier rotation function owner is invalid`. A read-only count showed 0 rows in all three
`Op*ProtocolEpoch` tables: the databases had been built from `db/*_structure.sql`
(`docs/operations/db-workflow.md`, Troubleshooting). That run is not a baseline.

With the owner's approval the test databases were rebuilt from migrations only, using the sequence
in `docs/operations/db-workflow.md`:

```bash
RAILS_ENV=test bin/rails db:drop db:create
RAILS_ENV=test bin/rails runner '
  ActiveRecord::Tasks::DatabaseTasks.with_temporary_pool_for_each(env: "test") do |pool|
    next if pool.db_config.replica?
    ActiveRecord::Tasks::DatabaseTasks.migrate(skip_initialize: true)
  end'
```

32 writable databases were dropped and created (`POSTGRESQL_TEST_PREPARE_DATABASES` matched
`.env.container.devcontainer`); replica databases were not touched; worker clones are rebuilt by
`ParallelTestDatabaseCloner` because the base OID is part of its stamp. Afterwards each
`Op*ProtocolEpoch` table held 1 row and `git status db/` showed no change.

## Baseline

`bin/rails test`: **18448 runs, 161125 assertions, 77 failures, 2 errors, 0 skips** (7 min 20 s).

The two errors: `PG::UniqueViolation` on `op_protocol_epochs_pkey` (a test inserting epoch id 1,
which now exists) and `Couldn't find ClientEmail with [WHERE "client_emails"."public_id" IS NULL]`
(`Base::App::Verification::SetupsControllerTest`). Causes of the failures were not analysed in this
record; the 2026-10-21 groups G1–G6 (session fixation containment) are the expected majority.

Failures and errors per test class:

```
      9 SocialAuthLoginTest
      9 BaseStepUpIntentAuthorityTest
      8 TelephoneSignupSourceProofRetryTest
      8 TelephoneSignupHttpDeliveryTest
      4 SocialAuthAppFlowContractTest
      4 ContactRegistrationOtpBootstrapReceiptRecoveryTest
      4 AppleAuthTest
      3 OidcResultCsrfTransportTest
      3 BaseOauthAuthorizationSurfacesTest
      2 LocalAuthenticationBoundaryTest
      2 EmailSignupBaseRootCompletionTest
      2 BaseDashboardPasskeyLoginJourneyTest
      2 Base::App::Verification::SetupsControllerTest
      2 Base::App::Social::AuthenticationsControllerTest
      2 AppleSocialFlowsTest
      1 Security::AcmeRenameInventoryTest
      1 OrgRootLoginEstablishmentTest
      1 OrgOidcAuthHandoffRootCompletionTest
      1 OmniauthCallbacksTest
      1 OidcResultBrowserBindingTest
      1 OidcInitiatedSignInCompletionTest
      1 BaseOrgDashboardLocalLoginJourneyTest
      1 BaseOauthOidcAuthorityTest
      1 Base::Com::Identity::Emails::RegistrationsControllerTest
      1 Auth::Org::Sign::In::Emergency::PasskeysControllerTest
      1 ArchitectureBaselineTest
      1 AppSecretRootLoginConcurrencyTest
      1 AppSecretParallelLoginTest
      1 AppSecretLoginJourneyTest
      1 AppPasskeySecretSessionStepUpTest
```

Failing locations (`bin/rails test` re-run lines):

```
test/controllers/auth/org/in/emergency/passkeys_controller_test.rb:169
test/controllers/base/app/social/authentications_controller_test.rb:215
test/controllers/base/app/social/authentications_controller_test.rb:531
test/controllers/base/app/verification/setups_controller_test.rb:276
test/controllers/base/app/verification/setups_controller_test.rb:355
test/controllers/base/com/identity/emails/registrations_controller_test.rb:528
test/controllers/base/oauth_authorization_surfaces_test.rb:1197
test/controllers/base/oauth_authorization_surfaces_test.rb:2487
test/controllers/base/oauth_authorization_surfaces_test.rb:688
test/controllers/base/oauth_oidc_authority_test.rb:1699
test/controllers/base/oidc_result_browser_binding_test.rb:6
test/controllers/base/oidc_result_csrf_transport_test.rb:8
test/controllers/base/oidc_result_csrf_transport_test.rb:8
test/controllers/base/oidc_result_csrf_transport_test.rb:8
test/controllers/base/step_up_intent_authority_test.rb:16
test/controllers/base/step_up_intent_authority_test.rb:16
test/controllers/base/step_up_intent_authority_test.rb:16
test/controllers/base/step_up_intent_authority_test.rb:282
test/controllers/base/step_up_intent_authority_test.rb:282
test/controllers/base/step_up_intent_authority_test.rb:282
test/controllers/base/step_up_intent_authority_test.rb:568
test/controllers/base/step_up_intent_authority_test.rb:677
test/controllers/base/step_up_intent_authority_test.rb:784
test/integration/app_passkey_secret_session_step_up_test.rb:16
test/integration/app_secret_login_journey_test.rb:648
test/integration/app_secret_parallel_login_test.rb:415
test/integration/app_secret_root_login_concurrency_test.rb:32
test/integration/apple_auth_test.rb:1288
test/integration/apple_auth_test.rb:1718
test/integration/apple_auth_test.rb:30
test/integration/apple_auth_test.rb:842
test/integration/apple_social_flows_test.rb:39
test/integration/apple_social_flows_test.rb:623
test/integration/base_dashboard_passkey_login_journey_test.rb:29
test/integration/base_dashboard_passkey_login_journey_test.rb:29
test/integration/base_org_dashboard_local_login_journey_test.rb:31
test/integration/contact_registration_otp_bootstrap_receipt_recovery_test.rb:12
test/integration/contact_registration_otp_bootstrap_receipt_recovery_test.rb:12
test/integration/contact_registration_otp_bootstrap_receipt_recovery_test.rb:12
test/integration/contact_registration_otp_bootstrap_receipt_recovery_test.rb:12
test/integration/email_signup_base_root_completion_test.rb:21
test/integration/email_signup_base_root_completion_test.rb:21
test/integration/local_authentication_boundary_test.rb:1215
test/integration/local_authentication_boundary_test.rb:789
test/integration/oidc_initiated_sign_in_completion_test.rb:284
test/integration/omniauth_callbacks_test.rb:948
test/integration/org_oidc_auth_handoff_root_completion_test.rb:12
test/integration/org_root_login_establishment_test.rb:14
test/integration/social_auth_app_flow_contract_test.rb:1480
test/integration/social_auth_app_flow_contract_test.rb:1870
test/integration/social_auth_app_flow_contract_test.rb:48
test/integration/social_auth_app_flow_contract_test.rb:764
test/integration/social_auth_login_test.rb:1690
test/integration/social_auth_login_test.rb:2124
test/integration/social_auth_login_test.rb:3748
test/integration/social_auth_login_test.rb:4220
test/integration/social_auth_login_test.rb:4665
test/integration/social_auth_login_test.rb:5115
test/integration/social_auth_login_test.rb:548
test/integration/social_auth_login_test.rb:7402
test/integration/social_auth_login_test.rb:97
test/integration/telephone_signup_http_delivery_test.rb:22
test/integration/telephone_signup_http_delivery_test.rb:22
test/integration/telephone_signup_http_delivery_test.rb:22
test/integration/telephone_signup_http_delivery_test.rb:22
test/integration/telephone_signup_http_delivery_test.rb:22
test/integration/telephone_signup_http_delivery_test.rb:22
test/integration/telephone_signup_http_delivery_test.rb:22
test/integration/telephone_signup_http_delivery_test.rb:22
test/integration/telephone_signup_source_proof_retry_test.rb:27
test/integration/telephone_signup_source_proof_retry_test.rb:27
test/integration/telephone_signup_source_proof_retry_test.rb:27
test/integration/telephone_signup_source_proof_retry_test.rb:27
test/integration/telephone_signup_source_proof_retry_test.rb:27
test/integration/telephone_signup_source_proof_retry_test.rb:27
test/integration/telephone_signup_source_proof_retry_test.rb:27
test/integration/telephone_signup_source_proof_retry_test.rb:27
test/tooling/architecture_baseline_test.rb:42
test/unit/security/acme_rename_inventory_test.rb:36
```
