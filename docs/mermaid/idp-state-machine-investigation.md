# Investigation, scope and verification record

## Checkout and protection

Inspected current checkout, including user changes, on 2026-10-05 at `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`, branch `feature`. The user explicitly approved this checkout despite requested GitHub URL / origin mismatch. Initial `git status --short`, `git rev-parse HEAD`, and `git branch --show-current` were captured before documentation edits. Existing dirty files were preserved; no reset, checkout, restore, stash, overwrite of user changes, worktree, commit, push, PR or remote mutation was performed.

Initial content hashes cover 8,758 existing non-`docs/mermaid` files, including existing user changes. Final comparison is recorded below. Existing twelve `sign-*.mmd` diagrams were preserved. Only new `docs/mermaid/idp-*` documents and `docs/mermaid/README.md` belong to this investigation. User's explicit documentation-only path restriction overrides the repository's general evidence-directory convention; verification is recorded here.

## What is counted

Phase A used "machine" as shorthand for a stored or controlled authentication state axis. Phase B separates STATE_MACHINE, WORKFLOW_STATE, STATUS_AXIS, DERIVED_STATE and CANDIDATE; consult the classification inventory. The inventory includes nine sign-flow models, shared concern implementations instantiated per realm, stored outcome axes on those flows, credentials and eligibility, and one-time session/Valkey transports. It does not assert that 126 classes named StateMachine exist. Current SignInStateMachine is result classification/metadata; FlowSignIn and controllers own the durable transitions. Multiple machines can share one fact table, and timestamps can define overlapping predicates rather than an exclusive enum. Diagram starts mean observed creation or explicitly described model entry, not proof that every HTTP path is reachable. Terminal markers mean absorbing transitions within the documented API (or explicitly labeled proof usability); public setters that can rewrite terminal states are shown and qualified.

## Discovery and evidence ordering

1. Whole-repository candidate search preceded Mermaid writing. Initial runtime candidate search retained 28,744 matching lines and 448 candidate files. A final whole-repository search excluding generated diagrams retained 210,906 lines, including database, models, services, operations, controllers, concerns, jobs, tests and existing architecture material.
2. DB ownership was resolved from all checked-in `db/*_structure.sql` files and matching migrations before individual transition extraction. SQL, not model annotation, supplies types/defaults/CHECK/FKs. Reference records/constants supply state ID meanings; actual seeded rows and live FK validation remain UNCONFIRMED.
3. README candidate inventory was created first. Each individual machine then received its diagram, transition table, guard/effect/test/caller observations and immediate structural check. Later discovery expanded the inventory before adding new diagrams. Shared implementation evidence was reused only when each concrete realm includer and storage was confirmed.
4. Searches included `StateMachine`, `state_machine`, `status_id`, `state_id`, `*_flow_statuses`, `*_flow_states`, `*_flows`, `transition`, `advance`, `cancel`, `expire`, `complete`, `failed`, `halt`, `checkpoint`, `step`, `state`; additional searches covered timestamps, direct assignments, `update!`, `update_columns`, `update_column`, `update_all`, callback writers, result generation, replay and locks. Final mutation search in `app config lib` retained 2,120 lines. Searches were not restricted to classes named StateMachine.
5. Tests were read as expectations and boundary evidence; no test suite, Rails boot, DB mutation, background job, provider request or production verification was run. Source paths in the transition inventory were checked for existence. Test assertions are not treated as successful test execution.

Representative commands actually used:

```bash
rg -n -i --glob '!docs/mermaid/**' --glob '!node_modules/**' --glob '!vendor/**' 'StateMachine|state_machine|status_id|state_id|[a-z_]+_flow_statuses|[a-z_]+_flow_states|[a-z_]+_flows|transition|advance|cancel|expire|complete|failed|halt|checkpoint|step|state' .
rg -n '(state|status|step|consumed_at|revoked_at|completed_at|canceled_at|cancelled_at)\s*(=|:)|update_columns|update_column\(|update_all' app config lib
rg --files app test db lib config
```

## Candidate dispositions outside individual machines

- Visitor OAuth callback: no concrete VisitorOauthCallbackState model/table was found. It is not inferred from Client/Operator naming. Operator callback model exists; normal production provider wiring remains qualified in its transition section.
- `SignAppInEmailAuthenticationState`: existing/dummy address fork carrier, not an independent authoritative authentication lifecycle. Store/clear methods and Auth app email controller wiring were inspected; actual OTP/SignInFlow transitions are indexed.
- `SignUpSessionState`, `SignInCycleLocator`, pending-MFA session keys, and `SessionLimitGate`: browser locators/bindings/cancellation helpers. They mirror durable authority; pending MFA cancellation fails the main sign-in flow. Session-limit nonce TTL900s does not create another durable status machine. SignInSequenceCarrier is separately indexed because it explicitly owns state/terminal_state and progression APIs.
- `SignInOtpResendState`: encrypted, surface-bound stateless capability TTL30m; issue/parse has no stored consumption or transition. It is not an OTP lifecycle state.
- `SecurityConsumedJti`, DPoP JTI records and Turnstile replay records: append-only unique replay ledgers, not mutable lifecycle machines. DPoP nonce consumption is separately indexed.
- `ClientSecretSignInReceipt`: immutable successful commit evidence, with before-create validation of completed flow and root-login facts; no transition or production creator found. `ClientSecretAuditOutbox`: append-only source audit facts; declared event names do not prove those events or corresponding credential transitions are wired. Both are included as supporting storage below.
- Client/Visitor/Operator identity lookup statuses and Visitor/Operator actor status: fixed creation classifications; no existing-row production transition owner located. Client actor signup9->10 is indexed separately. Runtime identity eligibility is not inferred from a lookup named state.
- `OrganizationEntraConnection`: configuration mapping retained for older provisioned records; current Org Entra resolver uses pinned tenant and identity mapping, not connection lifecycle. `OperatorGoogleIdentity`, workspace/department accounts and legacy actors: retained schema/models do not demonstrate a current authentication state transition path; current provider authority is separately indexed. Runtime use beyond observed readers is UNCONFIRMED.
- `SingleUseToken` on preference refresh: browser preference transport, not authenticated actor/root authority. It supports preference DBSC ownership; TTL400days, used_at lock consumption and rotation create a new preference row. Preference DBSC is indexed because it shares the actual device-binding concern with authentication tokens.
- Privacy requests, processor erasure notifications and retention holds: privacy/retention domain lifecycles. Recovery queries/cancels received privacy requests, so their dependency is noted on actor withdrawal; they are not relabeled authentication ceremonies.
- Avatar/agent/persona/company/bureau/enterprise/individual lifecycle, ownership transfers, memberships, handles, profiles, occurrences, consent/configuration lookups and jobs/queues: domain/infrastructure state candidates outside IdP authentication progression. Their actual state columns remain discoverable in the candidate disposition table; no future authentication vocabulary is applied.
- Enforcement effect records: principal/method/identifier policy data with timestamps and parent FK, controlled by Case apply/end/supersession; no independent event graph. Their DB topology and eligibility relationship are retained under indexed Case machines.

See [SQL candidate disposition](./idp-state-machine-candidate-disposition.md) for every checked-in table with a state/status-like column, including lookup/event and out-of-scope candidates.

## High-value transition observations

| Family | Current observations |
| --- | --- |
| Sign-in (all realms) | COMPLETED100/FAILED900; no stored expiry/cancel. Cancellation of pending MFA uses FAILED. status/state/step duplicated. Legacy controller directly moves SELECTOR_PENDING65->DASHBOARD_PENDING70 outside model map. Named dashboard helper asks COMPLETED with dashboard step, conflicting with model step validation; current SQL lacks the historical canonical-step CHECK. Model and named completion source sets differ. |
| Sign-up | Client/Visitor FAILED900/EXPIRED910/CANCELLED920 with limited cancel/expiry source set. Finalize failure can leave state unchanged; failed/stopped handoff leaves FINALIZED70. Job selects later active states whose expire transition is unavailable. Operator schema has only COMPLETED100 terminal; HTTP signup route progress UNCONFIRMED; synthetic concern tests use other IDs. Named FlowSignUp helpers can leave nonblank legacy state inconsistent. |
| Sign-out | REQUESTED10->ACCESS_DISCARDED20->LOGICALLY_REVOKED30->AWAITING_EXPIRY40->COMPLETED100 or FAILED900. Awaiting expiry is completed immediately by current logout orchestration; no flow TTL state. UI cancel removes pending browser transport before flow commit. Generic transition_to! lacks the named API's lock. |
| Auth / child ceremonies | Auth timestamps enforce at-most-one terminal with SQL; rotation and evidence are bound/locked. Child ceremonies pending->consumed, unique result JTI, TTL predicate. Contact/credential principal commit may follow ticket burn; no distributed atomicity assumed. |
| Step-up | Parent pending/verified/consumed/canceled/expired/revoked differs from session PENDING/VERIFIED. Parent stored expired occurs on cancellation-at-TTL. Public API lacks verified-only guard, but revoked timestamp CHECK blocks terminal rewrite. VERIFIED session writer/legacy completion caller UNKNOWN. Challenge burn precedes mismatch; email generation/delivery state is independent. |
| Root/RP/DBSC | Status plus TTL/discard/rotation and root-parent usability share admission authority. Public root promote/restrict may rewrite statuses; discarded/rotated proof still fails usability. DBSC FAILED/REVOKE IDs have no production setter located. RP retirement depends on observed maximum access-token expiry; unknown maximum keeps row occupying capacity. |
| Credentials / MFA projection | Removal guards last method and uses direct status updates; anonymizer can rewrite retained histories. Operator Passkey SQLdefault0 differs from modelACTIVE1. Current Client Secret is fact-based; presentation/claim writers UNKNOWN and older writers/tests conflict. Operator Secret alias is confirmed. TOTP failures100 revoke; replay uses last_otp_at. MFA projection refresh is calculated/saved without lock/CAS. |
| Eligibility / enforcement | Administrative access, actor withdrawal timestamps, actor status and Entra entitlement are separate axes. Entra revoked can activate explicitly. End Case writes ended_at while leaving state active; narrow apply failure writes failed, which active-only reconciliation omits. Appeal decision commits before end side effects; redaction can hide it from state-based retry selection. |
| Short-lived transport | Valkey Lua CAS has one winner; code replay tombstone differs from missing result. Opaque admission relies on Redis TTL, not logical expires_at in Lua. Session WebAuthn delete-before-check burns refusal but has no request-level CAS guarantee. |

These are static observations and boundary risks, not reproduced defects. A missing cancel path is not automatically a bug, especially after irreversible commit.

## Current versus accepted target contract

`adr/idp-flow-lifecycle-vocabulary.md` is accepted as documentation/target vocabulary (2026-10-01), and `adr/idp-flow-state-machine-lifecycle.md` as a future implementation contract (2026-10-02). Both explicitly distinguish accepted design from current migrated runtime.

- Target lifecycle ACTIVE/COMPLETED/CANCELLED/EXPIRED/HALTED and flow-specific phase separation is not implemented universally. Current phases are often stored as status plus duplicated strings; FAILED900 remains current. No HALTED state is imported into current diagrams.
- Target canonical start/advance/back/cancel/external_result/complete/expire/halt differs from current named helpers, service events, callbacks, timestamp setters and outcome classes. An external callback is not renamed external_result.
- Target one state_id with per-flow reference table differs from current status_id + state + step and fact-derived/Valkey/session state. Current FK direction and NOT VALID status are preserved.
- Target absorbing terminals differ from broad public setters, admin reactivation, session carrier finish rewriting, and declared status IDs without production writers. DB CHECK rejection is separated from API guard absence.
- Current Operator sign-up vocabulary/schema is smaller than Client/Visitor; current SignInStateMachine is not a single unified executor. Existing accepted ADR does not justify adding runtime edges.

No target diagram, implementation diff plan or remediation is produced.

## Mermaid validation

No repository Mermaid validation command or installed parser/CLI was found. `mmdc` is unavailable; package.json has no Mermaid validation script; repository node_modules and inspected cache/system/temp locations contain no usable Mermaid or Mermaid CLI package. No dependency was added and no remote parser was used.

Every new individual `.mmd` was immediately checked for expected diagram header, balanced labels/quotes/brackets and obvious structure, then self-reviewed against sources; later edits were rechecked. Both overview files received the same checks. This is **limited structural inspection, not Mermaid syntax/parser or rendering validation**. Parser/render validation is UNCONFIRMED. In particular, renderer size limits and layout/readability for the 126-machine overview are unverified; individual diagrams and inventory remain the detailed review surface.

Tests were read, not executed. Live schema, seeded state rows, deployment wiring, external providers, Redis operation and concurrency under the running application are UNCONFIRMED. Concurrency assertions in tests are identified as expectations only.

## Adversarial review record

The cross-document review checked non-StateMachine implementations, controller/service direct mutation, background expiry/cleanup/reconciliation, SQL CHECK/ID/FK direction, declared-only and test-only states, terminal reactivation, replay, duplicate state, current versus target vocabulary, and outcome/state separation. Corrections were made only to diagrams/inventory:

- Removed public revoked step-up rewrite edges after confirming SQL terminal CHECK rejects them.
- Added legacy SELECTOR->DASHBOARD controller writer, MFA cancellation->FAILED, credential anonymizer writes and Secret mismatch failure threshold.
- Corrected Operator Secret concrete alias evidence; corrected source paths against the filesystem.
- Corrected semantic OrgRpRecord ownership to consolidated OrgZenithRecord; actor/Entra share that DB, while ticket/audit boundaries still require separate analysis.
- Kept declared states with UNKNOWN incoming setter isolated instead of inventing edges (e.g. DBSC FAILED/REVOKE, session VERIFIED, Case ended, appeal under_review, operator signup terminal omissions, current Client Secret presentation/claim).
- Distinguished current model step validation from historical migration CHECK absent from current structure.
- Matched every machine diagram edge to a transition inventory row and every indexed machine to one individual diagram; source paths and state-reference ownership were checked.

## Boundary evidence

All lines in the overview describe orchestration/read dependencies, not FK. Shared operations are traced through concrete per-realm configuration/includers; a schema/model alone does not prove HTTP reachability.

| From machine | Relationship | To machine | Source |
| --- | --- | --- | --- |
| idp-client-sign-in | Auth admits Base-issued local flow | idp-client-auth-ceremony-session | app/controllers/concerns/auth_ceremony_admission.rb |
| idp-client-auth-ceremony-session | Auth evidence / generation delivery | idp-client-local-result-delivery | app/controllers/concerns/auth_local_result_handoff.rb |
| idp-client-local-result-delivery | Base commit rechecks flow and finalizes login | idp-client-sign-in | app/operations/local_authentication_session_committer.rb |
| idp-client-sign-in | successful root log_in establishes token | idp-client-token | app/controllers/concerns/authentication_base.rb |
| idp-client-oidc-authorization | Auth admits Base-issued OIDC transaction | idp-client-auth-ceremony-session | app/controllers/concerns/auth_ceremony_admission.rb |
| idp-client-oidc-authorization | Base finalize establishes root browser session | idp-client-token | app/controllers/base/app/oauth/authorizations_controller.rb |
| idp-client-oidc-authorization | grant claim creates RP session under root lock | idp-client-rp-session | app/services/oidc_token_exchange_coordinator.rb |
| idp-client-token | Base bound proof admission | idp-client-step-up-ceremony | app/operations/base_step_up_admission_issuer.rb |
| idp-client-step-up-ceremony | Base persists pending session binding | idp-client-step-up-session | app/operations/base_step_up_admission_issuer.rb |
| idp-client-step-up-session | stores bound one-use assertion challenge | idp-client-step-up-passkey-challenge | app/models/concerns/step_up_session_consumable.rb |
| idp-client-step-up-passkey-challenge | accepted assertion records parent proof | idp-client-step-up-ceremony | app/operations/identity_step_up_passkey_verification_committer.rb |
| idp-client-step-up-session | current generation email code delivery | idp-client-step-up-email-challenge | app/models/concerns/step_up_email_challenge.rb |
| idp-client-step-up-email-challenge | accepted delivered code records proof | idp-client-step-up-ceremony | app/models/concerns/step_up_email_challenge.rb |
| idp-client-email-ceremony | Base result consumer commits credential | idp-client-email-credential | app/operations/identity_email_ceremony_final_committer.rb |
| idp-client-telephone-ceremony | Base result consumer commits credential | idp-client-telephone-credential | app/operations/identity_telephone_ceremony_final_committer.rb |
| idp-client-passkey-ceremony | Base result consumer commits credential | idp-client-passkey-credential | app/operations/identity_passkey_ceremony_final_committer.rb |
| idp-client-email-ceremony | independent EVP outcome axis on same row | idp-client-email-verification-challenge | app/models/concerns/email_verification_challengeable.rb |
| idp-client-email-credential | contact row owns OTP proof and lock | idp-client-email-otp | app/models/concerns/email.rb |
| idp-client-telephone-credential | contact row owns OTP proof and lock | idp-client-telephone-otp | app/models/concerns/telephone.rb |
| idp-client-token | token owns device binding registration axis | idp-client-dbsc | app/controllers/concerns/authentication_token_service.rb |
| idp-client-token | root usability gates RP authority | idp-client-rp-session | app/models/concerns/rp_session.rb |
| idp-client-sign-out | logout logical revocation | idp-client-token | app/controllers/concerns/authentication_logout_current_session.rb |
| idp-client-sign-out | issue/consume logout transport | idp-shared-sign-out-notice | app/controllers/concerns/sign_out_notice.rb |
| idp-client-rp-session | RP logout launcher issues ordered boundary | idp-shared-acme-logout | app/controllers/concerns/oidc_rp_logout_launcher.rb |
| idp-client-actor-withdrawal | deactivation revokes root sessions | idp-client-token | app/services/withdrawal_lifecycle.rb |
| idp-client-enforcement-case | apply/end locks or refcount-unlocks actor | idp-client-administrative-access | app/operations/enforcement_case_apply_operation.rb / app/operations/enforcement_case_end_operation.rb |
| idp-client-enforcement-case | method/principal eligibility query gates proof | idp-client-sign-in | app/models/concerns/enforcement_case_applicable.rb |
| idp-client-enforcement-appeal | approved decision ends Case; convergence retries | idp-client-enforcement-case | app/models/concerns/enforcement_appeal.rb |
| idp-client-administrative-access | admin lock revokes sessions | idp-client-token | app/services/administrative_access_lock.rb |
| idp-client-sign-up | accepted signup handoff; separate durable sign-in | idp-client-sign-in | app/controllers/concerns/sign_up_sequence_controller_support.rb |
| idp-client-sign-up | terminal cancellation/failure/expiry schedules cleanup | idp-client-sign-up-cleanup | app/services/sign_up_termination.rb |
| idp-client-actor-withdrawal | request/discard/recover/terminate records durable flow | idp-client-withdrawal | app/services/withdrawal_lifecycle.rb |
| idp-client-withdrawal-ceremony | restricted withdrawal proof authorizes recovery/termination | idp-client-actor-withdrawal | app/controllers/concerns/withdrawal_ceremony_authentication.rb |
| idp-client-enforcement-recovery-ceremony | verified recovery ends security_lock case | idp-client-enforcement-case | app/controllers/concerns/enforcement_recovery_ceremony_flow.rb |
| idp-visitor-sign-in | Auth admits Base-issued local flow | idp-visitor-auth-ceremony-session | app/controllers/concerns/auth_ceremony_admission.rb |
| idp-visitor-auth-ceremony-session | Auth evidence / generation delivery | idp-visitor-local-result-delivery | app/controllers/concerns/auth_local_result_handoff.rb |
| idp-visitor-local-result-delivery | Base commit rechecks flow and finalizes login | idp-visitor-sign-in | app/operations/local_authentication_session_committer.rb |
| idp-visitor-sign-in | successful root log_in establishes token | idp-visitor-token | app/controllers/concerns/authentication_base.rb |
| idp-visitor-oidc-authorization | Auth admits Base-issued OIDC transaction | idp-visitor-auth-ceremony-session | app/controllers/concerns/auth_ceremony_admission.rb |
| idp-visitor-oidc-authorization | Base finalize establishes root browser session | idp-visitor-token | app/controllers/base/com/oauth/authorizations_controller.rb |
| idp-visitor-oidc-authorization | grant claim creates RP session under root lock | idp-visitor-rp-session | app/services/oidc_token_exchange_coordinator.rb |
| idp-visitor-token | Base bound proof admission | idp-visitor-step-up-ceremony | app/operations/base_step_up_admission_issuer.rb |
| idp-visitor-step-up-ceremony | Base persists pending session binding | idp-visitor-step-up-session | app/operations/base_step_up_admission_issuer.rb |
| idp-visitor-step-up-session | stores bound one-use assertion challenge | idp-visitor-step-up-passkey-challenge | app/models/concerns/step_up_session_consumable.rb |
| idp-visitor-step-up-passkey-challenge | accepted assertion records parent proof | idp-visitor-step-up-ceremony | app/operations/identity_step_up_passkey_verification_committer.rb |
| idp-visitor-step-up-session | current generation email code delivery | idp-visitor-step-up-email-challenge | app/models/concerns/step_up_email_challenge.rb |
| idp-visitor-step-up-email-challenge | accepted delivered code records proof | idp-visitor-step-up-ceremony | app/models/concerns/step_up_email_challenge.rb |
| idp-visitor-email-ceremony | Base result consumer commits credential | idp-visitor-email-credential | app/operations/identity_email_ceremony_final_committer.rb |
| idp-visitor-telephone-ceremony | Base result consumer commits credential | idp-visitor-telephone-credential | app/operations/identity_telephone_ceremony_final_committer.rb |
| idp-visitor-passkey-ceremony | Base result consumer commits credential | idp-visitor-passkey-credential | app/operations/identity_passkey_ceremony_final_committer.rb |
| idp-visitor-email-ceremony | independent EVP outcome axis on same row | idp-visitor-email-verification-challenge | app/models/concerns/email_verification_challengeable.rb |
| idp-visitor-email-credential | contact row owns OTP proof and lock | idp-visitor-email-otp | app/models/concerns/email.rb |
| idp-visitor-telephone-credential | contact row owns OTP proof and lock | idp-visitor-telephone-otp | app/models/concerns/telephone.rb |
| idp-visitor-token | token owns device binding registration axis | idp-visitor-dbsc | app/controllers/concerns/authentication_token_service.rb |
| idp-visitor-token | root usability gates RP authority | idp-visitor-rp-session | app/models/concerns/rp_session.rb |
| idp-visitor-sign-out | logout logical revocation | idp-visitor-token | app/controllers/concerns/authentication_logout_current_session.rb |
| idp-visitor-sign-out | issue/consume logout transport | idp-shared-sign-out-notice | app/controllers/concerns/sign_out_notice.rb |
| idp-visitor-rp-session | RP logout launcher issues ordered boundary | idp-shared-acme-logout | app/controllers/concerns/oidc_rp_logout_launcher.rb |
| idp-visitor-actor-withdrawal | deactivation revokes root sessions | idp-visitor-token | app/services/withdrawal_lifecycle.rb |
| idp-visitor-enforcement-case | apply/end locks or refcount-unlocks actor | idp-visitor-administrative-access | app/operations/enforcement_case_apply_operation.rb / app/operations/enforcement_case_end_operation.rb |
| idp-visitor-enforcement-case | method/principal eligibility query gates proof | idp-visitor-sign-in | app/models/concerns/enforcement_case_applicable.rb |
| idp-visitor-enforcement-appeal | approved decision ends Case; convergence retries | idp-visitor-enforcement-case | app/models/concerns/enforcement_appeal.rb |
| idp-visitor-administrative-access | admin lock revokes sessions | idp-visitor-token | app/services/administrative_access_lock.rb |
| idp-visitor-sign-up | accepted signup handoff; separate durable sign-in | idp-visitor-sign-in | app/controllers/concerns/sign_up_sequence_controller_support.rb |
| idp-visitor-sign-up | terminal cancellation/failure/expiry schedules cleanup | idp-visitor-sign-up-cleanup | app/services/sign_up_termination.rb |
| idp-visitor-actor-withdrawal | request/discard/recover/terminate records durable flow | idp-visitor-withdrawal | app/services/withdrawal_lifecycle.rb |
| idp-visitor-withdrawal-ceremony | restricted withdrawal proof authorizes recovery/termination | idp-visitor-actor-withdrawal | app/controllers/concerns/withdrawal_ceremony_authentication.rb |
| idp-visitor-enforcement-recovery-ceremony | verified recovery ends security_lock case | idp-visitor-enforcement-case | app/controllers/concerns/enforcement_recovery_ceremony_flow.rb |
| idp-operator-sign-in | Auth admits Base-issued local flow | idp-operator-auth-ceremony-session | app/controllers/concerns/auth_ceremony_admission.rb |
| idp-operator-auth-ceremony-session | Auth evidence / generation delivery | idp-operator-local-result-delivery | app/controllers/concerns/auth_local_result_handoff.rb |
| idp-operator-local-result-delivery | Base commit rechecks flow and finalizes login | idp-operator-sign-in | app/operations/local_authentication_session_committer.rb |
| idp-operator-sign-in | successful root log_in establishes token | idp-operator-token | app/controllers/concerns/authentication_base.rb |
| idp-operator-oidc-authorization | Auth admits Base-issued OIDC transaction | idp-operator-auth-ceremony-session | app/controllers/concerns/auth_ceremony_admission.rb |
| idp-operator-oidc-authorization | Base finalize establishes root browser session | idp-operator-token | app/controllers/base/org/oauth/authorizations_controller.rb |
| idp-operator-oidc-authorization | grant claim creates RP session under root lock | idp-operator-rp-session | app/services/oidc_token_exchange_coordinator.rb |
| idp-operator-token | Base bound proof admission | idp-operator-step-up-ceremony | app/operations/base_step_up_admission_issuer.rb |
| idp-operator-step-up-ceremony | Base persists pending session binding | idp-operator-step-up-session | app/operations/base_step_up_admission_issuer.rb |
| idp-operator-step-up-session | stores bound one-use assertion challenge | idp-operator-step-up-passkey-challenge | app/models/concerns/step_up_session_consumable.rb |
| idp-operator-step-up-passkey-challenge | accepted assertion records parent proof | idp-operator-step-up-ceremony | app/operations/identity_step_up_passkey_verification_committer.rb |
| idp-operator-email-ceremony | Base result consumer commits credential | idp-operator-email-credential | app/operations/identity_email_ceremony_final_committer.rb |
| idp-operator-telephone-ceremony | Base result consumer commits credential | idp-operator-telephone-credential | app/operations/identity_telephone_ceremony_final_committer.rb |
| idp-operator-passkey-ceremony | Base result consumer commits credential | idp-operator-passkey-credential | app/operations/identity_passkey_ceremony_final_committer.rb |
| idp-operator-email-ceremony | independent EVP outcome axis on same row | idp-operator-email-verification-challenge | app/models/concerns/email_verification_challengeable.rb |
| idp-operator-email-credential | contact row owns OTP proof and lock | idp-operator-email-otp | app/models/concerns/email.rb |
| idp-operator-telephone-credential | contact row owns OTP proof and lock | idp-operator-telephone-otp | app/models/concerns/telephone.rb |
| idp-operator-token | token owns device binding registration axis | idp-operator-dbsc | app/controllers/concerns/authentication_token_service.rb |
| idp-operator-token | root usability gates RP authority | idp-operator-rp-session | app/models/concerns/rp_session.rb |
| idp-operator-sign-out | logout logical revocation | idp-operator-token | app/controllers/concerns/authentication_logout_current_session.rb |
| idp-operator-sign-out | issue/consume logout transport | idp-shared-sign-out-notice | app/controllers/concerns/sign_out_notice.rb |
| idp-operator-rp-session | RP logout launcher issues ordered boundary | idp-shared-acme-logout | app/controllers/concerns/oidc_rp_logout_launcher.rb |
| idp-operator-actor-withdrawal | deactivation revokes root sessions | idp-operator-token | app/services/org_operator_lifecycle_execute.rb |
| idp-operator-enforcement-case | apply/end locks or refcount-unlocks actor | idp-operator-administrative-access | app/operations/enforcement_case_apply_operation.rb / app/operations/enforcement_case_end_operation.rb |
| idp-operator-enforcement-case | method/principal eligibility query gates proof | idp-operator-sign-in | app/models/concerns/enforcement_case_applicable.rb |
| idp-operator-enforcement-appeal | approved decision ends Case; convergence retries | idp-operator-enforcement-case | app/models/concerns/enforcement_appeal.rb |
| idp-operator-administrative-access | admin lock revokes sessions | idp-operator-token | app/services/administrative_access_lock.rb |
| idp-client-oauth-callback | provider-bound callback creates signed social result | idp-client-social-ceremony | app/controllers/concerns/social_omniauth_callback_flow.rb |
| idp-client-social-ceremony | verified provider candidate transport | idp-identity-social-candidate | app/services/identity_social_ceremony_candidate_store.rb |
| idp-client-social-ceremony | Base social final commit | idp-client-external-identity | app/operations/identity_social_ceremony_final_committer.rb |
| idp-client-apple-notification | verified event updates entitlement and revokes sessions | idp-client-external-identity | app/services/external_authentication_apple_notification_processor.rb |
| idp-client-apple-notification | applied provider revocation ends sessions | idp-client-token | app/services/external_authentication_apple_notification_processor.rb |
| idp-client-session-limit-resolution | capacity selection resumes Base finalization | idp-client-oidc-authorization | app/controllers/base/app/sign/in/limitations_controller.rb |
| idp-client-step-up-ceremony | registration owns enrollment candidate | idp-identity-totp-enrollment | app/operations/identity_totp_enrollment_issuer.rb |
| idp-identity-totp-enrollment | Base final commit consumes proof and creates credential | idp-client-totp-credential | app/operations/identity_totp_enrollment_final_committer.rb |
| idp-client-totp-ceremony | child transaction candidate binding | idp-identity-totp-enrollment | app/operations/identity_totp_enrollment_issuer.rb |
| idp-client-secret-issuance | reservation and storage confirmation own candidates | idp-client-secret-credential | app/operations/client_secret_manual_reservation_issuer.rb / app/operations/client_secret_storage_confirmation_committer.rb |
| idp-operator-operator-lifecycle | approved join issues invitation | idp-operator-organization-invitation | app/services/org_operator_lifecycle_execute.rb |
| idp-operator-operator-lifecycle | withdraw/suspend/terminate/restore facts | idp-operator-actor-withdrawal | app/services/org_operator_lifecycle_execute.rb |
| idp-operator-operator-lifecycle | withdraw/suspend/terminate entitlement; restore separate | idp-operator-entra-identity | app/services/org_operator_lifecycle_execute.rb |
| idp-operator-entra-identity | Entra resolver requires ACTIVE mapping | idp-operator-sign-in | app/resolvers/external_sign_in/org_entra_resolver.rb |
| idp-shared-opaque-admission | purpose/binding code resolves durable authority | idp-client-auth-ceremony-session | app/services/base_auth_admission_coordinator.rb |
| idp-shared-opaque-admission | purpose/binding code resolves durable authority | idp-client-local-result-delivery | app/services/base_auth_admission_coordinator.rb |
| idp-shared-opaque-admission | purpose/binding code resolves durable authority | idp-client-oidc-authorization | app/services/base_auth_admission_coordinator.rb |
| idp-shared-opaque-admission | purpose/binding code resolves durable authority | idp-client-step-up-ceremony | app/services/base_auth_admission_coordinator.rb |
| idp-client-secret-credential-ceremony | temporary signed-result candidate | idp-identity-secret-credential-candidate | app/services/identity_secret_credential_ceremony_candidate_store.rb |
| idp-shared-authorization-code | legacy exchange one-time code then RP creation | idp-client-rp-session | app/services/oidc_token_exchange_coordinator.rb |
| idp-shared-opaque-admission | purpose/binding code resolves durable authority | idp-visitor-auth-ceremony-session | app/services/base_auth_admission_coordinator.rb |
| idp-shared-opaque-admission | purpose/binding code resolves durable authority | idp-visitor-local-result-delivery | app/services/base_auth_admission_coordinator.rb |
| idp-shared-opaque-admission | purpose/binding code resolves durable authority | idp-visitor-oidc-authorization | app/services/base_auth_admission_coordinator.rb |
| idp-shared-opaque-admission | purpose/binding code resolves durable authority | idp-visitor-step-up-ceremony | app/services/base_auth_admission_coordinator.rb |
| idp-visitor-secret-credential-ceremony | temporary signed-result candidate | idp-identity-secret-credential-candidate | app/services/identity_secret_credential_ceremony_candidate_store.rb |
| idp-shared-authorization-code | legacy exchange one-time code then RP creation | idp-visitor-rp-session | app/services/oidc_token_exchange_coordinator.rb |
| idp-shared-opaque-admission | purpose/binding code resolves durable authority | idp-operator-auth-ceremony-session | app/services/base_auth_admission_coordinator.rb |
| idp-shared-opaque-admission | purpose/binding code resolves durable authority | idp-operator-local-result-delivery | app/services/base_auth_admission_coordinator.rb |
| idp-shared-opaque-admission | purpose/binding code resolves durable authority | idp-operator-oidc-authorization | app/services/base_auth_admission_coordinator.rb |
| idp-shared-opaque-admission | purpose/binding code resolves durable authority | idp-operator-step-up-ceremony | app/services/base_auth_admission_coordinator.rb |
| idp-operator-secret-credential-ceremony | temporary signed-result candidate | idp-identity-secret-credential-candidate | app/services/identity_secret_credential_ceremony_candidate_store.rb |
| idp-shared-authorization-code | legacy exchange one-time code then RP creation | idp-operator-rp-session | app/services/oidc_token_exchange_coordinator.rb |
| idp-client-passkey-credential | credential after_commit refreshes capability projection | idp-client-mfa-readiness | app/models/concerns/mfa_status_credential.rb |
| idp-client-email-credential | credential after_commit refreshes capability projection | idp-client-mfa-readiness | app/models/concerns/mfa_status_credential.rb |
| idp-client-telephone-credential | credential after_commit refreshes capability projection | idp-client-mfa-readiness | app/models/concerns/mfa_status_credential.rb |
| idp-client-totp-credential | credential after_commit refreshes capability projection | idp-client-mfa-readiness | app/models/concerns/mfa_status_credential.rb |
| idp-visitor-passkey-credential | credential after_commit refreshes capability projection | idp-visitor-mfa-readiness | app/models/concerns/mfa_status_credential.rb |
| idp-visitor-email-credential | credential after_commit refreshes capability projection | idp-visitor-mfa-readiness | app/models/concerns/mfa_status_credential.rb |
| idp-visitor-telephone-credential | credential after_commit refreshes capability projection | idp-visitor-mfa-readiness | app/models/concerns/mfa_status_credential.rb |
| idp-operator-passkey-credential | credential after_commit refreshes capability projection | idp-operator-mfa-readiness | app/models/concerns/mfa_status_credential.rb |
| idp-operator-email-credential | credential after_commit refreshes capability projection | idp-operator-mfa-readiness | app/models/concerns/mfa_status_credential.rb |
| idp-operator-telephone-credential | credential after_commit refreshes capability projection | idp-operator-mfa-readiness | app/models/concerns/mfa_status_credential.rb |

## Final local safety checks

- `git diff --check -- docs/mermaid`: passed (no output).
- All134 newly created files additionally passed `git diff --no-index --check /dev/null <file>` whitespace checks, because ordinary git diff does not inspect untracked content.
- `git status --short` and `git diff --name-only`: inspected against initial snapshot. Outside-docs status is byte-for-byte unchanged; all new status entries are under docs/mermaid. Existing implementation/migration/test changes in git diff predate this task and are not reported as this task's edits.
- SHA256 comparison of all8,758 initial protected files: zero changed or missing files.
- 126 indexed machines each have exactly one diagram and transition section; all128 new Mermaid files passed limited structural checks;910 diagram edges correspond to910 inventory rows. All cited Ruby source/test paths and artifact links exist. State ID cross-check against mapped reference constants found no mismatch.
- Runtime implementation, migrations, tests and existing user changes untouched. GitHub untouched. No git worktree. No new dependency, commit, push or PR.
- Mermaid parser/render and runtime/tests remain unverified, as described above.

## Phase B verification

Phase B verification results, summarized in the [README](./README.md), supersede Phase A counts:128 axes and130 CURRENT Mermaid files. Real parser validation was deferred by the user; writer coverage remains OPEN. Confirmed additional writers and storage corrections are reflected in the diagrams and inventory. No TARGET design or implementation planning has begun.
