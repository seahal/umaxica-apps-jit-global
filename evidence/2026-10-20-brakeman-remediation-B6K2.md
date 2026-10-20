# Brakeman findings remediation verification

Date: 2026-10-20. Git commit: `2b23e9d20c61c695a5eb2353cbca70f9d900d3f4`. The worktree contained
pre-existing uncommitted changes, including test database topology, dependencies and test support.
This verification also includes the uncommitted remediation. Those existing changes were retained;
this result describes the combined worktree, not HEAD alone.

## Observations

- Baseline: `bin/brakeman -A -f json -o /tmp/umaxica-brakeman.json --quiet`, exit 3: 63 warnings,
  zero scan errors (Authentication 1, UnsafeReflection 1, SQL 1, VerbConfusion 1, UnscopedFind 59).
- Final: `bin/brakeman -A --quiet`, exit 0, Brakeman 8.1.0, Rails 8.2.0.alpha: 943 controllers, 932
  models, 114 templates, 86 checks, zero warnings and zero scan errors. `config/brakeman.yml`
  retains all checks, all confidence levels and failure on warnings/errors; no warning suppression,
  ignore entry or scanner patch was added.
- `RAILS_ENV=test bin/rails runner 'ActiveRecord::Migration.check_all_pending!; puts "All configured test migrations are current"'`:
  exit 0 before test preparation. The catalog read also succeeded with the consolidated credential.
- The first ordinary test invocation stopped before tests because the inherited
  `POSTGRESQL_TEST_PREPARE_DATABASES` contained retired ticket-database names. The successful
  invocations set that variable for the subprocess only from the 32 writable databases in
  `ActiveRecord::Base.configurations.configs_for(env_name: "test")`, rejecting replicas, and set
  `PARALLEL_WORKERS=1`. Existing catalog guards remained active. No persistent environment
  configuration or database topology was changed by this remediation.
- Final combined targeted test run: `bin/rails test` with the 25 files below, seed 9772: **251 runs,
  1,566 assertions, zero failures, zero errors, zero skips**, 16.030 seconds.
- Targeted RuboCop: 32 changed Ruby files, zero offenses. `git diff --check`: passed.
- After the final readability changes, the affected job, purge and email-delivery tests passed
  again: seed 64567, 35 runs, 166 assertions, zero failures/errors/skips. The final scanner rerun at
  14:37:50 UTC again returned zero warnings/errors and exit 0; RuboCop again found no offenses.
- Intermediate `reload_<association>` implementation failed strict-loading tests and was replaced
  with explicit association scope queries. Strict loading remains enabled. Final tests above passed.

## Finding inventory and disposition

Line numbers identify the baseline scan. Every original finding is accounted for below; counts sum
to 63. These are source-level dispositions, not claims that all 63 were exploitable vulnerabilities.
Each fixed association query resets its cached scope, queries explicitly without a cached target,
and preserves the previous strict or nullable missing-record behavior.

| Baseline file                                                         | Lines                              | Count | Investigation and change                                                                                                                                       |
| --------------------------------------------------------------------- | ---------------------------------- | ----: | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `app/controllers/base/app/groups_controller.rb`                       | 31                                 |     1 | False-positive SQL classification: this was an HTTP adapter method, not Active Record group. Rename adapter and caller to fetch_group; preserve URL encoding.  |
| `app/controllers/base/org/api/v0/support/accounts_controller.rb`      | 96                                 |     1 | Chronicle-to-actor association only after the fixed Operator type check; authorized account and audit subject/action scope remain.                             |
| `app/controllers/concerns/authentication_sequence_gate.rb`            | 627, 628, 629                      |     3 | Flow-to-principal association; final root-login establishment checks remain in log_in.                                                                         |
| `app/controllers/concerns/oidc_rp_identity_provisioning.rb`           | 90, 92, 94                         |     3 | Binding-to-identity association; exact issuer/subject/audience binding and authoritative-resource comparison remain.                                           |
| `app/controllers/concerns/org_owner_page_relay.rb`                    | 29                                 |     1 | Confirmed verb selection defect: HEAD selected POST. Route HEAD through GET, preserving owner response authorization.                                          |
| `app/controllers/concerns/passkey_sign_in_flow.rb`                    | 142, 143, 144                      |     3 | Credential-to-owner association; actor/challenge binding, owner locks and assertion verification remain.                                                       |
| `app/controllers/concerns/preference_adoption.rb`                     | 409, 410, 411                      |     3 | Preference-to-owner association; age gating still uses that owner.                                                                                             |
| `app/controllers/concerns/publishing_authority_api_endpoint.rb`       | 51                                 |     1 | Replace allowlisted string constantization with twelve explicit class references. No arbitrary class-name injection was established in the original allowlist. |
| `app/jobs/processor_erasure_notification_job.rb`                      | 118, 119, 121, 122, 130, 131       |     6 | Notification-to-privacy-request-to-subject associations; typed surface selection and existing attempt lifecycle remain.                                        |
| `app/models/client_secret_sign_in_receipt.rb`                         | 22                                 |     1 | Flow-to-token association plus principal ID filter; commit timestamp, claim and ceremony validation remain.                                                    |
| `app/models/concerns/auth_email_otp_challenge.rb`                     | 307, 309                           |     2 | Contact-to-owner association; effective contact, destination binding and ceremony checks remain.                                                               |
| `app/operations/authority_owner_direct_binding_backfill_operation.rb` | 133, 134, 135                      |     3 | Resource-to-identity association; explicit owner, cross-surface rejection and locked candidate revalidation remain.                                            |
| `app/operations/client_secret_passkey_reservation_issuer.rb`          | 193                                |     1 | Issuance-to-client association; sign-up flow reference and principal filter remain on the locked issuance query.                                               |
| `app/operations/email_identifier_purger.rb`                           | 10, 11, 12                         |     3 | Contact-to-owner association; locked reread, owner mismatch refusal, retention and enforcement checks remain.                                                  |
| `app/operations/identity_social_ceremony_final_committer.rb`          | 74                                 |     1 | External-identity-to-client association; consumed result, flow principal/provider scope and provider subject checks remain.                                    |
| `app/operations/identity_step_up_email_delivery_recorder.rb`          | 84, 87                             |     2 | Contact-to-owner association; actor/session/transaction ownership and generation checks remain under locks.                                                    |
| `app/operations/refresh_token_reuse_activity_recorder.rb`             | 38, 45, 52                         |     3 | Token-to-owner association; existing surface-specific audit target and metadata allowlist remain.                                                              |
| `app/operations/rp_session_revoker.rb`                                | 135, 137, 139                      |     3 | Device-session token collection plus current token ID; device-first locking and missing-root refusal remain.                                                   |
| `app/operations/telephone_identifier_purger.rb`                       | 10, 11, 12                         |     3 | Contact-to-owner association; strict missing-record behavior and locked purge eligibility checks remain.                                                       |
| `app/queries/client_secret_identity_resolver_query.rb`                | 18, 24                             |     2 | Effective contact-to-client association; blind-index resolution and exactly-one-client requirement remain.                                                     |
| `app/queries/oidc_refresh_delivery_query.rb`                          | 62, 63, 64                         |     3 | Root-token-to-owner association; client assertion, resolved refresh credential and actor epoch lock remain.                                                    |
| `app/services/base_auth_admission_coordinator.rb`                     | 1182, 1183, 1184, 1244, 1245, 1246 |     6 | Binding-to-base-token and token-to-owner associations; session usability, parent and actor/session binding checks remain.                                      |
| `app/services/group_avatar_memberships/detach.rb`                     | 32                                 |     1 | Membership-to-avatar association; surface/account/current-owner checks and permission rechecks under locks remain.                                             |
| `app/services/group_avatar_memberships/reorder.rb`                    | 33                                 |     1 | Membership-to-avatar association; account/current-owner checks and permission rechecks under locks remain.                                                     |
| `app/services/oidc_token_exchange_coordinator.rb`                     | 1186, 1188, 1190                   |     3 | Device-session token collection plus current token ID; epoch and current-root checks under existing locks remain.                                              |
| `app/services/sign_up_termination.rb`                                 | 112, 113                           |     2 | Flow-to-principal association; existing terminal event and cleanup orchestration remain.                                                                       |
| `lib/umaxica/test_environment/database_safety.rb`                     | 23                                 |     1 | Fixed local test credential duplicated Rails database configuration; reuse the configured credential. No production secret exposure was established.           |

## Targeted test files

The successful combined invocation used the following file arguments:

- `test/adapters/domain_authority_protocol_test.rb`
- `test/controllers/base/org/api/v0/publishing/entries_controller_test.rb`
- `test/services/group_avatar_memberships_test.rb`
- `test/models/client_secret_sign_in_receipt_test.rb`
- `test/operations/rp_session_revoker_test.rb`
- `test/controllers/base/app/groups_controller_test.rb`
- `test/controllers/concerns/browser_rp_authentication_test.rb`
- `test/jobs/processor_erasure_notification_job_test.rb`
- `test/operations/authority_owner_direct_binding_backfill_operation_test.rb`
- `test/operations/identity_step_up_email_delivery_recorder_test.rb`
- `test/operations/refresh_token_reuse_activity_recorder_test.rb`
- `test/models/auth_email_otp_challenge_test.rb`
- `test/services/sign_up_termination_idempotence_test.rb`
- `test/unit/oidc_refresh_delivery_receipt_test.rb`
- `test/unit/security/identity_authority_inversion_guard_test.rb`
- `test/controllers/base/org/support_relay_test.rb`
- `test/operations/client_secret_passkey_reservation_issuer_test.rb`
- `test/operations/dead_identifier_purge_test.rb`
- `test/services/base_auth_admission_coordinator_test.rb`
- `test/services/base_auth_admission_cancellation_test.rb`
- `test/services/oidc_token_exchange_boundary_test.rb`
- `test/controllers/concerns/passkey_sign_in_flow_refusals_test.rb`
- `test/models/oidc_identity_binding_test.rb`
- `test/integration/preference_adoption_on_sign_in_test.rb`
- `test/integration/warp_com_preference_adoption_test.rb`

New coverage exercises all twelve Publishing cells, route rejection of unknown/empty cells,
unauthenticated callers, suspended-operator policy denial, escaped group references and owner
refusals, GET/HEAD/POST owner relay selection, and stale cached owner scope refusal in email purge.
The relay test exercises the existing public action's orchestration with the remote owner replaced;
it does not claim to exercise browser admission. Existing Browser RP request tests ran separately in
the same combined invocation.

The full Rails suite, concurrency suites, deployment and production requests were not run. This
record establishes the scanner and targeted local behavior only. No database migration, schema
change, production operation, audit-history rewrite or external write was introduced.
