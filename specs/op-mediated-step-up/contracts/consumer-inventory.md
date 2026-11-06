# Consumer inventory of the Base-mediated step-up (plan unit 0)

Date: 2026-11-03. Revision 3 (revision 2 answered `review-3.md`; revision 3 adds the attribution
consumers read by `review-4.md`). Status: draft for Codex review and owner acceptance; documents
only. Method: `rg` over `app/` in the working tree at HEAD
`efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8` (extensive uncommitted work present). Dispositions are
proposals.

## 1. Summary

1. Evidence store today: the Base root token. `ClientToken` and `OperatorToken` carry the
   `last_step_up_*` columns (`last_step_up_at`, `_scope`, `_method`, `_purpose`, `_audience`,
   `_session_public_id`, `_phishing_resistant`, `_user_verified`, `_credential_ref`,
   `_full_reauthentication`, `_resource_ref`, `_tenant_ref`, deprecated `_aal`). One writer:
   `IdentityStepUpCeremonyFreshnessCommitter`
   (`app/operations/identity_step_up_ceremony_freshness_committer.rb:399-411`).
2. Lexical footprint: `rg -l 'StepUpResolver|last_step_up_|consume_step_up_evidence!' app` lists 48
   files (section 2). This is a footprint, not proof that each file is a reachable final writer.
3. Consumption: 22 invocation sites of `consume_step_up_evidence!` (23 matches minus the definition
   at `app/models/concerns/token_status_management.rb:97`). Revision 1 counted 23 and missed eight
   files; both corrected (section 3).
4. The new evidence is the verified OP access-token event (contract section 5). Every row in
   families F1 to F4 moves to that evidence in one cutover; no second runtime evidence authority
   remains.
5. Absence of a literal `*_required: true` does not prove a condition is unused (section 5).

## 2. Footprint by family (48 files)

Families follow `review-3.md` work package 4. "Role": W writer, C consumes (invokes consumption), R
reads or checks evidence, P policy, G gate, M model or value, X ceremony machinery.

| Family                                       | File                                                                      | Role                                                                                 | Surface |
| -------------------------------------------- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ | ------- |
| F1 credential, contact, Secret               | `app/operations/client_secret_manual_issuance_invalidator.rb`             | R                                                                                    | APP     |
| F1                                           | `app/operations/client_secret_manual_reattempt_issuer.rb`                 | R                                                                                    | APP     |
| F1                                           | `app/operations/client_secret_manual_reservation_issuer.rb`               | R                                                                                    | APP     |
| F1                                           | `app/operations/client_secret_name_committer.rb`                          | R, C (l.84)                                                                          | APP     |
| F1                                           | `app/operations/client_secret_passkey_reservation_issuer.rb`              | R (also builds a retained `credential_registration` transaction, l.364)              | APP     |
| F1                                           | `app/operations/client_secret_presentation_issuer.rb`                     | R                                                                                    | APP     |
| F1                                           | `app/operations/client_secret_revocation_committer.rb`                    | R, C (l.84)                                                                          | APP     |
| F1                                           | `app/operations/client_secret_storage_confirmation_committer.rb`          | R, C (l.129)                                                                         | APP     |
| F1                                           | `app/operations/identity_credential_removal_committer.rb`                 | R                                                                                    | APP     |
| F1                                           | `app/operations/identity_email_preference_committer.rb`                   | R, C (l.111)                                                                         | APP     |
| F1                                           | `app/operations/identity_passkey_name_committer.rb`                       | C (l.88)                                                                             | APP     |
| F1                                           | `app/operations/identity_passkey_registration_final_committer.rb`         | C (l.232)                                                                            | APP     |
| F1                                           | `app/operations/identity_totp_enrollment_final_committer.rb`              | R, C (l.142; scope from the transaction, l.135-138)                                  | APP     |
| F1                                           | `app/operations/identity_totp_name_committer.rb`                          | R, C (l.90)                                                                          | APP     |
| F1                                           | `app/policies/client_passkey_policy.rb`                                   | P (also a UV-verified passkey record check, l.67, retained)                          | APP     |
| F1                                           | `app/policies/operator_passkey_policy.rb`                                 | P (passkey only)                                                                     | ORG     |
| F1                                           | `app/services/operator_secret_credentials_create.rb`                      | R, C (l.122)                                                                         | ORG     |
| F1                                           | `app/services/operator_secret_credentials_update.rb`                      | R, C (l.93)                                                                          | ORG     |
| F1                                           | `app/services/operator_secret_credentials_destroy.rb`                     | R                                                                                    | ORG     |
| F2 social, registration prerequisites        | `app/controllers/concerns/sign_social_authentication_endpoint.rb`         | R, C (l.73)                                                                          | APP     |
| F2                                           | `app/controllers/concerns/social_auth.rb`                                 | R (copies `last_step_up_at`, l.205)                                                  | APP     |
| F2                                           | `app/controllers/auth/app/social/link_completions_controller.rb`          | C (l.78)                                                                             | APP     |
| F2                                           | `app/operations/email_credential_registration_otp_finalizer.rb`           | R, C unless bootstrap (l.139)                                                        | APP     |
| F2                                           | `app/operations/telephone_credential_registration_otp_finalizer.rb`       | R, C (l.89)                                                                          | APP     |
| F2                                           | `app/operations/operator_email_registration_otp_finalizer.rb`             | R, C (l.62)                                                                          | ORG     |
| F2                                           | `app/operations/operator_telephone_registration_otp_finalizer.rb`         | R, C (l.64)                                                                          | ORG     |
| F3 session, withdrawal, security transitions | `app/operations/authentication_other_sessions_revoker.rb`                 | R, C (l.54)                                                                          | APP     |
| F3                                           | `app/controllers/concerns/authentication_session_revoker.rb`              | R (not read)                                                                         | both    |
| F3                                           | `app/services/credential_security_transition.rb`                          | R (one reference)                                                                    | APP     |
| F3                                           | `app/models/client.rb`                                                    | R (not read)                                                                         | APP     |
| F3                                           | `app/controllers/concerns/authentication_base.rb`                         | R (not read)                                                                         | both    |
| F4 avatar, ORG enforcement, capability       | `app/controllers/concerns/avatar_authority_api_endpoint.rb`               | G on the root token (l.99-114); owner API                                            | both    |
| F4                                           | `app/controllers/concerns/owner_page_responses.rb`                        | G, JSON 403 (l.46-61)                                                                | both    |
| F4                                           | `app/operations/avatar_ownership_transfers/operation.rb`                  | R, C (l.46)                                                                          | both    |
| F4                                           | `app/operations/enforcement_case_apply_operation.rb`                      | C (l.41; operator token check l.88)                                                  | ORG     |
| F4                                           | `app/operations/enforcement_case_end_operation.rb`                        | C (l.93; l.115)                                                                      | ORG     |
| F4                                           | `app/models/concerns/enforcement_appeal.rb`                               | C (l.64; l.82)                                                                       | ORG     |
| F4                                           | `app/controllers/base/org/api/v0/support/enforcement_cases_controller.rb` | G, C (l.106; `require_step_up!` l.133)                                               | ORG     |
| Infrastructure                               | `app/controllers/concerns/actor_support.rb`                               | M (request snapshot)                                                                 | both    |
| Infrastructure                               | `app/models/actor.rb`                                                     | M (`Actor::StepUp`, `step_up_fresh?`, `requires_step_up?`; a pushed snapshot reader) | both    |
| Infrastructure                               | `app/models/concerns/token_status_management.rb`                          | M (columns, consumption l.97, revocation l.115)                                      | both    |
| Infrastructure                               | `app/models/client_token.rb`, `app/models/operator_token.rb`              | M (columns)                                                                          | both    |
| Infrastructure                               | `app/resolvers/step_up_resolver.rb`                                       | M (resolver; maxima 15 and 5 minutes, l.7-9)                                         | both    |
| Infrastructure                               | `app/controllers/concerns/verification_base.rb`                           | G (l.94-109; forwards requirement parameters, l.120-132)                             | both    |
| Ceremony                                     | `app/controllers/concerns/base_step_up_intent.rb`                         | X                                                                                    | both    |
| Ceremony                                     | `app/operations/base_step_up_admission_issuer.rb`                         | X                                                                                    | both    |
| Ceremony                                     | `app/operations/identity_step_up_ceremony_freshness_committer.rb`         | W, X (dynamic requirements and full reauthentication, l.332-375)                     | both    |

## 3. The 22 consumption sites

`operator_email_registration_otp_finalizer.rb:62`,
`identity_totp_enrollment_final_committer.rb:142`, `operator_secret_credentials_create.rb:122`,
`avatar_ownership_transfers/operation.rb:46`, `client_secret_storage_confirmation_committer.rb:129`,
`identity_email_preference_committer.rb:111`, `client_secret_revocation_committer.rb:84`,
`client_secret_name_committer.rb:84`, `operator_telephone_registration_otp_finalizer.rb:64`,
`operator_secret_credentials_update.rb:93`, `enforcement_appeal.rb:64`,
`identity_totp_name_committer.rb:90`, `identity_passkey_name_committer.rb:88`,
`telephone_credential_registration_otp_finalizer.rb:89`,
`authentication_other_sessions_revoker.rb:54`, `email_credential_registration_otp_finalizer.rb:139`,
`enforcement_case_end_operation.rb:93`, `identity_passkey_registration_final_committer.rb:232`,
`enforcement_case_apply_operation.rb:41`, `sign_social_authentication_endpoint.rb:73`,
`auth/app/social/link_completions_controller.rb:78`,
`base/org/api/v0/support/enforcement_cases_controller.rb:106`.

Each site is replaced by a check of the validated evidence (contract section 5). Removing the
consumption call must not remove the operation's own transaction, idempotency, candidate single use,
ownership, no-lockout or authorization checks (O-4).

## 4. Ceremony machinery outside the footprint

| File                                                                                                                                                   | Role                                                                 | Proposed disposition                                                                      |
| ------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| `app/controllers/concerns/base_step_up_completion.rb`                                                                                                  | completion; calls `BaseSelfRpCredentialIssuer` (l.145-160)           | replace for ordinary step-up                                                              |
| `app/operations/base_self_rp_credential_issuer.rb`                                                                                                     | claims update plus refresh exchange                                  | remove for ordinary step-up                                                               |
| `app/operations/base_step_up_cancel_and_start_committer.rb`                                                                                            | restart                                                              | replace with the new start and cancel                                                     |
| `app/controllers/concerns/base_step_up_cancellation.rb`, `app/operations/identity_step_up_ceremony_cancellation_committer.rb`                          | cancellation                                                         | replace with the state writers of contract section 7                                      |
| `app/services/base_auth_admission_coordinator.rb`                                                                                                      | admission and result machinery shared with sign-in and bootstrap     | remove only the ordinary step-up branches                                                 |
| `app/controllers/concerns/auth_step_up_result_handoff.rb`; Auth `verification/handoffs`, `registration/handoffs`, `settings/totps/handoffs`            | result handoff                                                       | replace the ordinary handoff; registration and TOTP enrollment stay                       |
| `app/controllers/base/{app,org}/verifications_controller.rb`                                                                                           | start page and start                                                 | rewrite on the routes of contract section 11                                              |
| `app/controllers/base/{app,org}/verification/completions_controller.rb`                                                                                | completion (APP also dispatches bootstrap and registration, l.31-43) | replace the ordinary part with the new callback                                           |
| `app/controllers/base/{app,org}/verification/setups_controller.rb`, `cancellations_controller.rb`                                                      | bootstrap setup, cancellation                                        | setup stays; cancellation follows the new contract                                        |
| Auth `verification/*` controllers (app and org)                                                                                                        | ceremony pages                                                       | adapt to the OP-mediated contract; setups stay                                            |
| `app/models/concerns/step_up_ceremony_transactionable.rb`, `client_step_up_ceremony_transaction.rb`, `client_step_up_session.rb`, `operator_step_up_*` | old ceremony state keyed to the root token                           | keep for retained purposes; ordinary step-up moves to the new tables                      |
| `app/controllers/concerns/verification_step_up_guard.rb`, `verification_client.rb`, `verification_operator.rb`                                         | delegate to `VerificationBase` (read by Codex)                       | adapt the shared gate; keep bootstrap entry semantics                                     |
| `app/models/concerns/verification_cookieable.rb`                                                                                                       | host-only cookie-name API with an old verification-record reader     | do not remove until its model and reader consumers are mapped                             |
| `app/values/step_up_scope_catalog.rb`                                                                                                                  | scope to return-path map                                             | keep where retained flows validate return targets or need operation and audit names (O-2) |

## 5. Conditions to classify before deletion (RV-80)

- `VerificationBase` forwards requirement parameters (`verification_base.rb:120-132`), and the
  freshness committer checks dynamic requirements and the full-reauthentication purpose
  (`:332-375`). Full reauthentication is a retained purpose and keeps its checks.
- `ClientPasskeyPolicy` also requires a UV-verified passkey record (`client_passkey_policy.rb:67`);
  that is credential eligibility, not step-up freshness, and stays.
- `ClientPasskeyPolicy#management_credential` selects the credential of the last step-up from
  `last_step_up_method` and `last_step_up_credential_ref` (`client_passkey_policy.rb:60-83`);
  disposition in contract section 9 (the step-up credential's continued activity is no longer
  required; the managed credential's eligibility stays).
- Attribution readers, not freshness gates: `authentication_session_revoker.rb:42` (TOTP-attributed
  root revocation), `client.rb:459-460` (configured methods), `authentication_base.rb:2804-2810`
  (session-issuance attribution). See contract section 9; none is deleted with the ordinary gate.
- The scope-binding and per-call method lists of the ordinary requirement are replaced by the single
  class and the server-side method enforcement of AC-16; nothing else is dropped implicitly.

## 6. Retained flows

| Flow                          | Where                                                                                                   | Why it stays                                                                                                   |
| ----------------------------- | ------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| First-authenticator bootstrap | `StepUpBootstrapEligibilityQuery`, `base_step_up_admission_issuer.rb:198-205`, the `setups` controllers | no authenticator to step up with; primary-login anchor                                                         |
| Credential registration       | `purpose: "credential_registration"` paths                                                              | registration evidence is not step-up freshness; its existing step-up prerequisite migrates to the new evidence |
| Full reauthentication         | the `reauthentication` purpose (`identity_step_up_ceremony_freshness_committer.rb:54-56`)               | not ordinary step-up                                                                                           |
| Emergency and Secret refusals | `base_step_up_admission_issuer.rb:99,195`                                                               | unchanged                                                                                                      |

## 7. Not verified

Reachability of each row through HTTP; the exact test list per row (only file counts are known:
`StepUpResolver` 23, `StepUpRequirement` 86, `BaseStepUpAdmissionIssuer` 60).
