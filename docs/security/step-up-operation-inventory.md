# Step-Up Operation Inventory

This inventory records the step-up operations that are in the current Rails implementation. The
runtime requirement is owned by the Base action policy and is carried through the Base admission,
Auth ceremony, result delivery, Base acceptance, and the protected mutation. The scope catalog is
only a destination validator; it is not a policy source.

## Requirement vocabulary

| Requirement | Current contract | Deadline / binding | First registration | Additional registration | Unavailable method |
| --- | --- | --- | --- | --- | --- |
| Normal step-up | The operation's explicit scope, non-empty allowed methods, phishing-resistance and user-verification booleans, and a fresh event | 15 minutes; actor, resource, tenant, session and transaction bindings are checked at admission and mutation | Uses the separate `bootstrap` transaction only when the actor has no credential history | Uses `credential_registration` and an independent step-up where the operation requires it | Recomputed from active credentials; no method is silently substituted |
| Full reauthentication | `purpose: reauthentication` and `full_reauthentication_required: true`; the event is not interchangeable with ordinary freshness | The same current actor/resource/tenant and session checks apply; a successful full reauthentication replaces the root token under the session-reset contract | Never satisfied by registration evidence | Never satisfied by registration evidence | Refuse and require the configured full ceremony |
| First authenticator | `step_up_required: false`, `purpose: bootstrap`, explicit actor/session/transaction binding, and no freshness grant | Issuance only: no Secret-established session, no emergency session, usable session, and `root_login_established_at` younger than 10 minutes; exact boundary is stale | `StepUpBootstrapEligibilityQuery` requires no credential history and `login_allowed?` | Not eligible after credential history exists | Generic refusal with sign-in-again guidance when stale or ineligible |
| Additional authenticator | `step_up_required: false`, `purpose: credential_registration`, explicit registration scope and method | The registration transaction is separate from the step-up event and cannot create freshness | Not applicable | The proposed credential must be verified in a new transaction before the protected operation proceeds | The caller must choose an active configured method; no registration evidence is promoted to authority |

All missing, invalid, contradictory, or legacy assurance-level requirements fail closed. Explicit
`false` is distinct from omission. A URL pattern validates only the stored destination and never
selects the requirement.

## Operation matrix

| Surface | Actor / resource | Operation | Current caller and scope | Current protection | Target evidence / behavior | Unavailable-method behavior |
| --- | --- | --- | --- | --- | --- |
| app | Client / own identity | Google and Apple link or unlink | `Auth::App::Settings::{Googles,Apples}Controller`, `social_link` / `social_unlink` | Step-up before mutation | Normal step-up; provider identity itself is not evidence | Available methods are recomputed and the operation is refused when none remain |
| app | Client / own identity | Passkey creation, update, removal | Base/Auth identity and passkey controllers, `settings_passkey` | Bootstrap for the first credential; step-up for existing credentials | Registration and ordinary step-up remain separate | Registration entry is available only through configured bootstrap rules; no credential is silently selected |
| app | Client / own identity | TOTP creation and removal | Base/Auth TOTP controllers, `settings_totp` | Bootstrap for first TOTP; step-up for later changes | TOTP enrollment does not grant step-up freshness | Only active app TOTP is offered and permanent credential lock is respected |
| app | Client / own identity | Email and telephone change or removal | Base identity controllers, `settings_email` / `settings_telephone` | Step-up and contact verification as applicable | Contact evidence remains bound to actor, candidate, flow and browser | Delivery or verification failure is a real refusal; old binding remains effective |
| app | Client / own sessions | Revoke another session or all sessions | Base revocation controller, `session_revoke_all` | Step-up | The protected mutation rechecks current session and target ownership | No session mutation occurs without a current step-up |
| app | Client / own account | Withdrawal | Base withdrawal controller, `withdrawal` | Step-up and existing Action Policy | Current account/resource policy is re-evaluated immediately before commit | Refuse; no partial withdrawal state is created |
| app | Client / own avatar | Avatar ownership transfer request, accept, cancel | Base avatar transfer controller, `avatar_transfer_*` | Step-up per transition | Each transition has its own scope and resource binding | Refuse the transition; do not reuse another transition's proof |
| app | Client / own Secret | Secret issuance and presentation | Base Secret controllers, `settings_secret_credential` or `settings_passkey` | Existing explicit step-up and Secret-specific rules | Secret management never treats Secret possession as step-up evidence | Secret session and missing configured method remain distinct refusals |
| com | Visitor / own identity | Passkey creation, email change, Secret removal | Base/Auth COM identity controllers | Bootstrap for first eligible authenticator; normal step-up thereafter | COM method set excludes TOTP and social scopes | No TOTP fallback; available COM methods are recomputed |
| com | Visitor / own sessions | Revoke another session or all sessions | Base COM revocation controller, `session_revoke_all` | Step-up | Target session ownership is rechecked at mutation | Refuse without revoking a session |
| com | Visitor / own account | Withdrawal and birthdate-sensitive operations | Base COM identity controllers, `withdrawal` / `settings_birthdate` | Existing step-up and Action Policy | Current visitor/resource policy is evaluated again | Refuse with no partial mutation |
| org | Operator / own identity | Passkey creation, removal and email/telephone changes | Base/Auth ORG identity controllers | Passkey-only bootstrap or normal step-up | Emergency sessions cannot initiate or satisfy step-up | No email/TOTP substitute; emergency mode remains unavailable |
| org | Operator / own sessions | Revoke sessions | Base ORG revocation controller, `session_revoke_all` | Step-up | Operator and selected session ownership are rechecked | Refuse with no session mutation |
| org | Operator / governed resource | IAM grants and revocations | `Base::Org::Iam::*`, `operator_capability` | Existing Action Policy plus step-up | Capability, tenant and target resource are re-evaluated | Refuse without changing the grant |
| org | Operator / support resource | Client/visitor session revocation | `Base::Org::Support::*`, `support_session_revoke` | Existing support authorization plus step-up | Target actor, tenant and session are rechecked | Refuse without revoking the target |
| org | Operator / enforcement case | Apply, approve, release and appeal review | `Base::Org::Support::EnforcementCases::*`, `enforcement_case_*` | Existing enforcement authorization plus step-up | Case, tenant and operator capability are re-evaluated | Refuse without changing the case |
| all | Current actor / current resource | Verification receiver | `VerificationBase`, `BaseStepUpCompletion` | Requirement travels through admission, Auth, result and final mutation | The current policy may strengthen the accepted snapshot; it may not be weakened by an older one | Stale, future, revoked, incomplete or mixed evidence is refused and requires a new ceremony |

## Scope and destination catalog

The current scope catalog is in `app/values/step_up_scope_catalog.rb`. The management destinations
for passkeys and TOTP are `/identity/passkeys` and `/identity/totps`; the catalog only checks that a
stored return target belongs to the scope. It does not decide allowed methods, assurance, actor,
resource, tenant, or reauthentication policy.

## AAL removal ledger

The following production files were identified by the exact retirement search:

```text
app/controllers/base/app/avatar_ownership_transfers_controller.rb
app/controllers/base/org/avatar_ownership_transfers_controller.rb
app/controllers/concerns/actor_support.rb
app/controllers/concerns/verification_base.rb
app/controllers/concerns/verification_step_up_guard.rb
app/models/actor/step_up.rb
app/models/client_step_up_ceremony_transaction.rb
app/models/client_token.rb
app/models/concerns/step_up_ceremony_transactionable.rb
app/models/operator_step_up_ceremony_transaction.rb
app/models/operator_token.rb
app/models/visitor_step_up_ceremony_transaction.rb
app/models/visitor_token.rb
app/operations/base_step_up_admission_issuer.rb
app/operations/identity_passkey_registration_final_committer.rb
app/operations/identity_step_up_ceremony_freshness_committer.rb
app/operations/identity_step_up_ceremony_grant_issuer.rb
app/operations/identity_totp_enrollment_final_committer.rb
app/operations/identity_totp_enrollment_issuer.rb
app/operations/identity_totp_enrollment_verification_committer.rb
app/queries/identity_totp_enrollment_query.rb
app/resolvers/step_up_resolver.rb
app/values/identity_step_up_ceremony_contract.rb
app/values/identity_step_up_ceremony_grant.rb
app/values/identity_step_up_ceremony_result.rb
app/values/step_up_requirement.rb
```

| Legacy AAL item | Treatment | Removal condition |
| --- | --- | --- |
| `required_aal` requirement input and transaction label | No authorization; an explicit non-`none` demand is rejected as an unsupported contract. The database label remains for migration compatibility. | Remove after all historical transaction rows and external compatibility fixtures are retired and the per-realm columns can be dropped safely. |
| `aal` verified-event label | No authorization; retained as a deprecated ceremony label while explicit UV, resistance, time and credential evidence are authoritative. | Remove after the label ledger and signed legacy fixtures have no operational consumers. |
| `last_step_up_aal` token label | No resolver or policy read; retained only as a deprecated historical label during data migration. | Remove after all root freshness rows carry the explicit evidence carrier and old tokens have naturally expired or been reissued. |
| `SUPPORTED_AALS`, `aal_matches?`, `aal_rank`, `aal_supported?`, `achieved_aal` | Removed from runtime authorization APIs. | No production references remain outside this ledger and deprecation comments. |
| External OIDC `acr` | Preserved as an external authentication-context claim; it is not translated into the internal step-up policy. | Only an explicitly accepted OIDC claims migration may change it. |

## Traceability status

| Requirement | Source | Implementation | Test evidence | Status |
| --- | --- | --- | --- | --- |
| Strict requirement and explicit booleans | D-70, `StepUpRequirement` | `app/values/step_up_requirement.rb` | Requirement, resolver, admission and wire contract tests | PASS in Phase 15 targeted run |
| One-event evidence and current-policy recheck | D-71 | Ceremony transaction, result wire, Base freshness committer | Freshness, resolver, credential and policy-change tests | PASS in Phase 15 targeted run |
| Bootstrap separation | D-72 | `BaseStepUpAdmissionIssuer`, bootstrap eligibility query | Bootstrap admission and registration tests | PASS for the existing issuance boundary; rechecked in Phase 15 |
| Terminal transaction transitions | D-73 | `StepUpCeremonyTransactionable` | Transition contract tests | PASS for the existing transition boundary; rechecked in Phase 15 |
| AAL retirement | D-74 | AAL removal ledger and explicit requirement fields | Legacy-label, signed-tampering and resolver tests | PASS in Phase 15 targeted run |
