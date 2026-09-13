# Principal / Zenith Membership and Organization Placement

> **Global / Regional ownership settled (2026-09-08):** `adr/global-regional-database-ownership.md`
> fixes `app_zenith` / `org_zenith` / `com_zenith` as **Global-only** databases holding Global
> canonical Account / Identity / Organization authority. `Member`, `ClientMembership`, and
> `Organization` are Global; the decomposition this document audits
> (`adr/member-client-membership-organization-decomposition-before-placement.md`) is an internal
> Global matter and does not move those rows to a Regional database. The "regional-ready" and
> "future regional" placement targets below are superseded: regional-ready data lives in the
> Regional repository's own application database, not in a `*_principal` key here.

## Purpose

This document audits the ambiguous placement cluster around `Member`, `ClientMembership`, and
`Organization`.

This is a classification document, not a migration plan. It does not authorize table movement,
database renames, model renames, connection-key edits, route/controller/service work, or behavior
changes.

See also:
[ADR: Decompose Member, ClientMembership, and Organization Before Placement Migration](../../adr/member-client-membership-organization-decomposition-before-placement.md)

Current storage, semantic ownership, target authority placement, and regional-ready placement are
separate facts. Current database name is evidence of current storage only.

## Context

Current placement rules:

- `zenith` is the target canonical placement for Principal / Identity / Account / Organization
  authority.
- `principal` is retained compatibility storage and may later host regional-ready application data.
- `principal` is not required to become empty.
- `principal` must not be treated as canonical authority just because of its name.
- Avatar remains a separate actor-authority boundary in this phase.
- Ticket, session, ceremony, logout, and OAuth transaction data is out of scope.
- Preference and settings data is out of scope.

## Classification Rules

Use these categories when classifying a row or row portion.

semantic_class:

- `global_authority`
- `account_authority`
- `identity_binding`
- `organization_authority`
- `runtime_actor`
- `credential`
- `contact_recovery`
- `session_token`
- `ceremony_transaction`
- `membership`
- `assignment`
- `bridge`
- `projection`
- `regional_ready`
- `transitional`
- `unknown`

target_placement:

- `zenith`
- `retained_principal`
- `ticket`
- `setting`
- `avatar`
- `current_storage`
- `future_regional`
- `out_of_scope`
- `unknown`

decision_status:

- `settled`
- `candidate`
- `transitional`
- `excluded`
- `unknown`

Important rules:

- Do not infer authority ownership from the current database name.
- Do not infer regional-readiness from the current database name.
- Do not classify token, session, ceremony, or OAuth transaction rows as authority placement.
- Do not classify Avatar rows as part of this placement.
- If a model has credential, contact, recovery, session, or lifecycle semantics, mark those
  semantics explicitly.

## Current Implementation Snapshot

| model                                                                                               | file                                                  | table                                                         | current DB / connection | superclass           | semantic role observed                                                                        | notes                                                                                                                                                |
| --------------------------------------------------------------------------------------------------- | ----------------------------------------------------- | ------------------------------------------------------------- | ----------------------- | -------------------- | --------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Member`                                                                                            | `app/models/member.rb`                                | `members`                                                     | `app_principal`         | `AppPrincipalRecord` | account-like transitional row                                                                 | Includes `Account`; belongs to `Client` through `user`; links to Avatar governance and client-member history.                                        |
| `ClientMembership`                                                                                  | `app/models/client_membership.rb`                     | `client_memberships`                                          | `app_principal`         | `AppPrincipalRecord` | membership / transitional join                                                                | Joins `Client` to `workspace_id`; stores `joined_at` and `left_at`; no observed model association for workspace.                                     |
| `Organization`                                                                                      | `app/models/organization.rb`                          | `organizations`                                               | `org_principal`         | `OrgPrincipalRecord` | org-principal hierarchy container                                                             | Has `domain`, `name`, status, parent, department, operator columns; owns divisions and departments.                                                  |
| `Client`                                                                                            | `app/models/client.rb`                                | `clients`                                                     | `app_principal`         | `AppPrincipalRecord` | runtime actor with mixed identity, credential, contact, lifecycle, and session-adjacent state | Includes `Identity`; owns emails, telephones, passkeys, secret credentials, OIDC connections, tokens, device sessions, memberships, and member rows. |
| `Visitor`                                                                                           | `app/models/visitor.rb`                               | `visitors`                                                    | `com_principal`         | `ComPrincipalRecord` | runtime actor with mixed identity, credential, contact, lifecycle, and session-adjacent state | Includes `Identity`; owns visitor contact and credential rows and ticket-side OIDC/session rows.                                                     |
| `Operator`                                                                                          | `app/models/operator.rb`                              | `operators`                                                   | `org_principal`         | `OrgPrincipalRecord` | runtime actor with mixed identity, credential, contact, lifecycle, and session-adjacent state | Includes `Identity`; owns operator contact and credential rows, OIDC/session rows, and workspace-account links.                                      |
| `Persona`                                                                                           | `app/models/persona.rb`                               | `personas`                                                    | `app_zenith`            | `AppRpRecord`        | account authority                                                                             | Includes `Account`; belongs to `ClientIdentity`; has assignments and memberships.                                                                    |
| `Agent`                                                                                             | `app/models/agent.rb`                                 | `agents`                                                      | `org_zenith`            | `OrgRpRecord`        | account authority                                                                             | Includes `Account`; belongs to `OperatorIdentity`; has assignments and memberships.                                                                  |
| `Individual`                                                                                        | `app/models/individual.rb`                            | `individuals`                                                 | `com_zenith`            | `ComRpRecord`        | account authority                                                                             | Includes `Account`; belongs to `VisitorIdentity`; has assignments and memberships.                                                                   |
| `ClientIdentity`                                                                                    | `app/models/client_identity.rb`                       | `client_identities`                                           | `app_zenith`            | `AppRpRecord`        | identity binding                                                                              | Stores issuer, subject, audience, source record, and authentication timestamp.                                                                       |
| `OperatorIdentity`                                                                                  | `app/models/operator_identity.rb`                     | `operator_identities`                                         | `org_zenith`            | `OrgRpRecord`        | identity binding                                                                              | Stores issuer, subject, audience, source record, and authentication timestamp.                                                                       |
| `VisitorIdentity`                                                                                   | `app/models/visitor_identity.rb`                      | `visitor_identities`                                          | `com_zenith`            | `ComRpRecord`        | identity binding                                                                              | Stores issuer, subject, audience, source record, and authentication timestamp.                                                                       |
| `ClientAccount`                                                                                     | `app/models/client_account.rb`                        | `client_accounts`                                             | `app_zenith`            | `AppRpRecord`        | RP account projection                                                                         | One row per `Client`; not the canonical `Account` domain model.                                                                                      |
| `OperatorAccount`                                                                                   | `app/models/operator_account.rb`                      | `operator_accounts`                                           | `org_zenith`            | `OrgRpRecord`        | RP account projection                                                                         | One row per `Operator`; not the canonical `Account` domain model.                                                                                    |
| `VisitorAccount`                                                                                    | `app/models/visitor_account.rb`                       | `visitor_accounts`                                            | `com_zenith`            | `ComRpRecord`        | RP account projection                                                                         | One row per `Visitor`; not the canonical `Account` domain model.                                                                                     |
| `PersonaMembership`                                                                                 | `app/models/persona_membership.rb`                    | `persona_memberships`                                         | `app_zenith`            | `AppRpRecord`        | membership                                                                                    | Account-to-enterprise/unit membership with grant, approval, revoke, kind, state, and active-primary semantics.                                       |
| `AgentMembership`                                                                                   | `app/models/agent_membership.rb`                      | `agent_memberships`                                           | `org_zenith`            | `OrgRpRecord`        | membership                                                                                    | Account-to-bureau/unit membership with grant, approval, revoke, kind, state, and active-primary semantics.                                           |
| `IndividualMembership`                                                                              | `app/models/individual_membership.rb`                 | `individual_memberships`                                      | `com_zenith`            | `ComRpRecord`        | membership                                                                                    | Account-to-company/unit membership with grant, approval, revoke, kind, state, and active-primary semantics.                                          |
| `PersonaAssignment`                                                                                 | `app/models/persona_assignment.rb`                    | `persona_assignments`                                         | `app_zenith`            | `AppRpRecord`        | assignment                                                                                    | Identity-to-account access assignment with assigned/revoked timestamps.                                                                              |
| `AgentAssignment`                                                                                   | `app/models/agent_assignment.rb`                      | `agent_assignments`                                           | `org_zenith`            | `OrgRpRecord`        | assignment                                                                                    | Identity-to-account access assignment with assigned/revoked timestamps.                                                                              |
| `IndividualAssignment`                                                                              | `app/models/individual_assignment.rb`                 | `individual_assignments`                                      | `com_zenith`            | `ComRpRecord`        | assignment                                                                                    | Identity-to-account access assignment with assigned/revoked timestamps.                                                                              |
| `OperatorWorkspaceAccount`                                                                          | `app/models/operator_workspace_account.rb`            | `operator_workspace_accounts`                                 | `org_zenith`            | `OrgRpRecord`        | legacy account-like transitional row                                                          | Includes `Account`; belongs to `Operator` and `Department`; overlaps with `Agent` direction.                                                         |
| `OperatorWorkspaceAccountMembership`                                                                | `app/models/operator_workspace_account_membership.rb` | `operator_workspace_account_memberships`                      | `org_zenith`            | `OrgRpRecord`        | transitional membership join                                                                  | Joins `Operator` to `OperatorWorkspaceAccount`.                                                                                                      |
| `ClientOidcConnection`                                                                              | `app/models/client_oidc_connection.rb`                | `client_oidc_connections`                                     | `app_ticket`            | `AppTicketRecord`    | long-lived OIDC connection / session-adjacent row                                             | Has `last_used_at`, `revoked_at`, `scope`, and token links; not an authorization transaction.                                                        |
| `OperatorOidcConnection`                                                                            | `app/models/operator_oidc_connection.rb`              | `operator_oidc_connections`                                   | `org_ticket`            | `OrgTicketRecord`    | long-lived OIDC connection / session-adjacent row                                             | Has `last_used_at`, `revoked_at`, `scope`, and token links; not an authorization transaction.                                                        |
| `VisitorOidcConnection`                                                                             | `app/models/visitor_oidc_connection.rb`               | `visitor_oidc_connections`                                    | `com_ticket`            | `ComTicketRecord`    | long-lived OIDC connection / session-adjacent row                                             | Has `last_used_at`, `revoked_at`, `scope`, and token links; not an authorization transaction.                                                        |
| `ClientEmail`, `ClientTelephone`, `ClientPasskey`, `ClientSecretCredential`, `ClientTotpCredential` | `app/models/client_*.rb`                              | various                                                       | `app_principal`         | `AppPrincipalRecord` | credential / contact / recovery                                                               | Tied to `Client`; include OTP, passkey, password digest, status, retention, and recovery-validation behavior.                                        |
| `OperatorEmail`, `OperatorTelephone`, `OperatorPasskey`, `OperatorSecretCredential`                 | `app/models/operator_*.rb`                            | various                                                       | `org_principal`         | `OrgPrincipalRecord` | credential / contact / recovery                                                               | Tied to `Operator`; include OTP, passkey, password digest, status, retention, and recovery behavior.                                                 |
| `VisitorEmail`, `VisitorTelephone`, `VisitorPasskey`, `VisitorSecretCredential`                     | `app/models/visitor_*.rb`                             | various                                                       | `com_principal`         | `ComPrincipalRecord` | credential / contact / recovery                                                               | Tied to `Visitor`; include OTP, passkey, password digest, status, retention, and recovery-validation behavior.                                       |
| `Enterprise` / `EnterpriseUnit` / `EnterpriseUnitClosure`                                           | `app/models/enterprise*.rb`                           | `enterprises`, `enterprise_units`, `enterprise_unit_closures` | `app_zenith`            | `AppRpRecord`        | organization authority                                                                        | App-side organization hierarchy.                                                                                                                     |
| `Bureau` / `BureauUnit` / `BureauUnitClosure`                                                       | `app/models/bureau*.rb`                               | `bureaus`, `bureau_units`, `bureau_unit_closures`             | `org_zenith`            | `OrgRpRecord`        | organization authority                                                                        | Org-side organization hierarchy.                                                                                                                     |
| `Company` / `CompanyUnit` / `CompanyUnitClosure`                                                    | `app/models/company*.rb`                              | `companies`, `company_units`, `company_unit_closures`         | `com_zenith`            | `ComRpRecord`        | organization authority                                                                        | Com-side organization hierarchy.                                                                                                                     |

## Member

| aspect                                  | finding                                                                                                                                                                         | evidence                                                              | implication                                                                                |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| Current database                        | `app_principal`                                                                                                                                                                 | Schema comment and `Member < AppPrincipalRecord`.                     | Current storage is retained principal, not proof of authority ownership.                   |
| Base class                              | `AppPrincipalRecord`                                                                                                                                                            | Model inheritance.                                                    | It is not currently a zenith row.                                                          |
| Associations                            | Belongs to `Client` through `user`; has many Avatars and Avatar governance rows; has many client-member event rows; has many `Client` rows through `client_members`.            | `member.rb` associations.                                             | The row bridges old app principal/member/avatar concepts.                                  |
| Account behavior                        | Includes `Account`.                                                                                                                                                             | `include ::Account`.                                                  | It behaves like an account-like row but is not automatically the target canonical Account. |
| Overlap with `Persona`                  | Both include `Account` and carry moniker/public-id shape. `Persona` is in `app_zenith` and belongs to `ClientIdentity`; `Member` is in `app_principal` and belongs to `Client`. | `member.rb`, `persona.rb`, dictionary account definition.             | `Member` overlaps with the canonical app Account direction but remains transitional.       |
| Runtime actor use                       | Belongs to the runtime actor `Client`; does not itself include `Identity`.                                                                                                      | `belongs_to :user, class_name: "Client"` and no `include ::Identity`. | Do not classify `Member` as the runtime login actor.                                       |
| Authority-suggesting columns            | `public_id`, `moniker`, status, and `Account` concern.                                                                                                                          | Schema comment and concern include.                                   | These suggest account-authority semantics, but they are mixed with legacy bridge links.    |
| Regional-ready indicators               | App-principal placement and lifecycle/retention fields may make it retained-principal compatible if treated as application state.                                               | `discarded_at`, `purged_at`, principal storage.                       | This is a candidate direction only; database name alone is not enough.                     |
| Lifecycle/contact/credential indicators | `discarded_at`, `purged_at`, status; no direct credential/contact columns observed.                                                                                             | Schema comment.                                                       | Lifecycle exists; credential/contact authority is on `Client`-owned rows, not `Member`.    |
| Not concluded                           | Whether `Member` should be decomposed, retired, retained, or migrated is not decided here.                                                                                      | Existing docs call this the main ambiguity cluster.                   | A later ADR and migration plan are required before movement.                               |

Recommended classification:

- semantic_class: `account_authority`, `bridge`, `transitional`
- target_placement: `unknown` with `zenith` and `retained_principal` both still possible by row
  portion
- decision_status: `transitional`
- reason: `Member` has account-like semantics and legacy bridge responsibilities, but current code
  also ties it to `Client` and Avatar governance. It should be decomposed or explicitly retired
  before any wholesale placement decision.

## ClientMembership

| aspect                             | finding                                                                                                                                                                            | evidence                                                                | implication                                                                                                  |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Current database                   | `app_principal`                                                                                                                                                                    | Schema comment and `ClientMembership < AppPrincipalRecord`.             | Current storage is retained principal, not proof of target ownership.                                        |
| Base class                         | `AppPrincipalRecord`                                                                                                                                                               | Model inheritance.                                                      | It is not currently a zenith membership row.                                                                 |
| Joined models                      | Belongs to `Client`; stores `workspace_id` without an observed model association.                                                                                                  | `belongs_to :user, class_name: "Client"` and `workspace_id` validation. | It joins runtime actor to a workspace-shaped identifier, not the current `Persona`/`Enterprise` graph.       |
| Membership authority vs history    | Stores `joined_at`, `left_at`, and uniqueness by `user_id` / `workspace_id`.                                                                                                       | Schema comment and uniqueness validation.                               | It has membership/history shape but lacks the richer grant/approval/revoke semantics of zenith memberships.  |
| Overlap with `PersonaMembership`   | Both are membership-shaped. `PersonaMembership` joins `Persona` to `Enterprise` and unit with grant/approval/revoke metadata; `ClientMembership` joins `Client` to a workspace id. | `client_membership.rb`, `persona_membership.rb`.                        | It may map to future zenith membership, regional membership, or compatibility bridge, but not automatically. |
| Overlap with `PersonaAssignment`   | `PersonaAssignment` assigns `ClientIdentity` to `Persona`; `ClientMembership` does not assign identity access to account.                                                          | `persona_assignment.rb`.                                                | Do not treat `ClientMembership` as identity-to-account assignment.                                           |
| Global authority vs regional-ready | Ambiguous. It is principal-side and actor/workspace-shaped, but may encode membership state.                                                                                       | Current placement and columns.                                          | Candidate for decomposition into authority membership and retained application state.                        |
| Not concluded                      | Whether `workspace_id` maps to `Enterprise`, legacy `Member`, Avatar operation, or regional application scope is not established here.                                             | No direct workspace association in the model.                           | Treat as transitional compatibility state until a mapping ADR exists.                                        |

Recommended classification:

- semantic_class: `membership`, `bridge`, `transitional`
- target_placement: `unknown`
- decision_status: `transitional`
- reason: `ClientMembership` is a membership-shaped compatibility row, but its endpoint is a raw
  `workspace_id` rather than a current zenith organization/account model. It needs mapping before
  placement.

## Organization

| aspect                                           | finding                                                                                                                         | evidence                                                                       | implication                                                                                |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------ |
| Current database                                 | `org_principal`                                                                                                                 | Schema comment and `Organization < OrgPrincipalRecord`.                        | Current storage is org principal, not proof of canonical authority ownership.              |
| Base class                                       | `OrgPrincipalRecord`                                                                                                            | Model inheritance.                                                             | It is not currently in `org_zenith`.                                                       |
| Current representation                           | Org-principal hierarchy container with `domain`, `name`, parent/status/operator/department columns.                             | `organization.rb` schema and validations.                                      | It has organization-authority shape and principal-side runtime-container history.          |
| Relationships                                    | Has many `Division` rows and has many `Department` rows as `workspace`.                                                         | `organization.rb`.                                                             | It overlaps legacy workspace/division/department naming.                                   |
| Overlap with `Bureau` / `Company` / `Enterprise` | `Bureau`, `Company`, and `Enterprise` are zenith-side collective/organization hierarchy roots with unit/closure models.         | `bureau.rb`, `company.rb`, `enterprise.rb`, dictionary.                        | The target organization-authority direction is already represented in zenith-side models.  |
| Global authority                                 | `domain`, `name`, status, parent hierarchy, and uniqueness suggest authority-like organization semantics.                       | Schema and validations.                                                        | Candidate for zenith organization-authority placement or mapping to `Bureau` shape.        |
| Regional-ready application boundary              | Org-principal placement and workspace/container naming may also make parts of it regional-ready application state.              | `workspace_status_id`, department/division links, prior workspace terminology. | Do not move wholesale until authority vs operational container portions are separated.     |
| Credential/session/lifecycle coupling            | No direct credential/session associations observed in `Organization`; status exists.                                            | `organization.rb`.                                                             | Credential/session rows are not part of this model, but lifecycle/status semantics remain. |
| Not concluded                                    | Whether this legacy `Organization` maps to `Bureau`, becomes a retained application container, or is decomposed is not decided. | Current docs identify it as ambiguity zone.                                    | Later ADR required before movement.                                                        |

Recommended classification:

- semantic_class: `organization_authority`, `regional_ready`, `transitional`
- target_placement: `unknown` with `zenith` as the likely authority target for the authority portion
  and `retained_principal` / `future_regional` possible for operational-container portions
- decision_status: `candidate`
- reason: `Organization` has authority-like organization columns and hierarchy links, but its legacy
  org-principal workspace/container role must be separated from canonical zenith organization
  authority before migration.

## Runtime Actor Rows

`Client`, `Visitor`, and `Operator` currently live in principal-like databases. They may hold
runtime actor, credential, contact/recovery, lifecycle, and session-adjacent state. Do not
automatically classify an entire runtime actor model as zenith authority.

Separate authority identity/account meaning from runtime actor and operational state. These rows are
candidates for decomposition, not wholesale movement.

| model      | current DB      | observed responsibilities                                                                                                                                                     | authority portion?                                                                   | regional-ready portion?                                                                                                | excluded portion?                                                               | recommended status                                          |
| ---------- | --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| `Client`   | `app_principal` | Runtime login actor, public id, lifecycle, MFA state, access lock, credentials/contact ownership, OIDC connection links, token/device-session links, member/membership links. | Identity/runtime actor portion may require binding to zenith identity/account graph. | Lifecycle and app-operational actor state may remain retained-principal or future-regional after decomposition.        | Credentials, contact/recovery, tokens, device sessions, ceremony/session state. | Decompose before movement; do not move wholesale to zenith. |
| `Visitor`  | `com_principal` | Runtime login actor, public id, lifecycle, MFA state, access lock, credentials/contact ownership, OIDC connection links, token/device-session links.                          | Identity/runtime actor portion may require binding to zenith identity/account graph. | Visitor lifecycle and operational state may remain retained-principal or future-regional after decomposition.          | Credentials, contact/recovery, tokens, device sessions, ceremony/session state. | Decompose before movement; do not move wholesale to zenith. |
| `Operator` | `org_principal` | Runtime login actor, public id, lifecycle, MFA state, access lock, credentials/contact ownership, OIDC connection links, token/device-session links, workspace-account links. | Identity/runtime actor portion may require binding to zenith identity/account graph. | Operator lifecycle and operational console state may remain retained-principal or future-regional after decomposition. | Credentials, contact/recovery, tokens, device sessions, ceremony/session state. | Decompose before movement; do not move wholesale to zenith. |

## Credential / Contact / Recovery Rows

Credential, contact, and recovery rows related to `Client`, `Visitor`, and `Operator` are not
automatically part of Principal / Identity / Account / Organization authority placement. They may
remain in principal, ticket, or credential-specific storage depending on existing boundaries. Do not
move them into `zenith` by default.

| model/group                                                                   | current DB                               | role                                                                   | target placement | decision status | notes                                                                                                            |
| ----------------------------------------------------------------------------- | ---------------------------------------- | ---------------------------------------------------------------------- | ---------------- | --------------- | ---------------------------------------------------------------------------------------------------------------- |
| `ClientEmail`, `ClientTelephone`                                              | `app_principal`                          | Contact and OTP verification state                                     | `out_of_scope`   | `excluded`      | Includes address/number digests, OTP counters, verification token digest, status, retention.                     |
| `ClientPasskey`, `ClientSecretCredential`, `ClientTotpCredential`             | `app_principal`                          | Authentication credential and recovery-gated secret/TOTP/passkey state | `out_of_scope`   | `excluded`      | Credentials are tied to runtime actor and MFA/recovery behavior.                                                 |
| `OperatorEmail`, `OperatorTelephone`                                          | `org_principal`                          | Contact and OTP verification state                                     | `out_of_scope`   | `excluded`      | Contact rows are not organization/account authority placement.                                                   |
| `OperatorPasskey`, `OperatorSecretCredential`, `staff_recovery_codes` history | `org_principal`                          | Authentication credential and recovery state                           | `out_of_scope`   | `excluded`      | Recovery-code migrations exist historically; credential placement needs a separate credential boundary decision. |
| `VisitorEmail`, `VisitorTelephone`                                            | `com_principal`                          | Contact and OTP verification state                                     | `out_of_scope`   | `excluded`      | Contact rows are not account/organization authority placement.                                                   |
| `VisitorPasskey`, `VisitorSecretCredential`                                   | `com_principal`                          | Authentication credential and recovery-gated secret/passkey state      | `out_of_scope`   | `excluded`      | Credential placement is separate from zenith authority placement.                                                |
| Email/telephone/secret/passkey ceremony transaction rows                      | `app_ticket`, `org_ticket`, `com_ticket` | Ceremony transaction state                                             | `out_of_scope`   | `excluded`      | Ticket-side ceremony rows are explicitly outside this pass.                                                      |

## OIDC Connection Rows

Distinguish long-lived connection/config rows from short-lived OAuth transaction rows. Do not
confuse OIDC connection rows with authorization transactions, tokens, sessions, or ceremonies.

| model                                  | current DB   | long-lived or transaction?                 | possible target                                                     | decision status | notes                                                                                                                           |
| -------------------------------------- | ------------ | ------------------------------------------ | ------------------------------------------------------------------- | --------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `ClientOidcConnection`                 | `app_ticket` | Long-lived connection/session-adjacent row | `unknown`; possible future authority candidate after separate audit | `candidate`     | Stores actor, client id, scope, last-used, revoked; links to tokens. Current ticket placement argues against moving by default. |
| `OperatorOidcConnection`               | `org_ticket` | Long-lived connection/session-adjacent row | `unknown`; possible future authority candidate after separate audit | `candidate`     | Stores actor, client id, scope, last-used, revoked; links to tokens. Current ticket placement argues against moving by default. |
| `VisitorOidcConnection`                | `com_ticket` | Long-lived connection/session-adjacent row | `unknown`; possible future authority candidate after separate audit | `candidate`     | Stores actor, client id, scope, last-used, revoked; links to tokens. Current ticket placement argues against moving by default. |
| `ClientOidcAuthorizationTransaction`   | `app_ticket` | Transaction                                | `out_of_scope`                                                      | `excluded`      | OAuth transaction row, not authority placement.                                                                                 |
| `OperatorOidcAuthorizationTransaction` | `org_ticket` | Transaction                                | `out_of_scope`                                                      | `excluded`      | OAuth transaction row, not authority placement.                                                                                 |
| `VisitorOidcAuthorizationTransaction`  | `com_ticket` | Transaction                                | `out_of_scope`                                                      | `excluded`      | OAuth transaction row, not authority placement.                                                                                 |

## Relationship to Zenith Account Graph

| principal-side item                  | zenith-side related item                          | overlap                                                                    | difference                                                                                                                                            | likely direction                                                                                                |
| ------------------------------------ | ------------------------------------------------- | -------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `Member`                             | `Persona`                                         | Both are app account-like rows and include `Account`.                      | `Persona` belongs to `ClientIdentity` in `app_zenith`; `Member` belongs to `Client` in `app_principal` and links to legacy Avatar/client-member rows. | Decompose or map account-authority portion toward `Persona`; retain/retire compatibility portions deliberately. |
| `ClientMembership`                   | `PersonaMembership`                               | Both are membership-shaped.                                                | `PersonaMembership` joins `Persona` to `Enterprise`/unit with grant/revoke metadata; `ClientMembership` joins `Client` to raw `workspace_id`.         | Decide whether it maps to zenith membership, regional membership, or bridge state.                              |
| `ClientMembership`                   | `PersonaAssignment`                               | Both involve account access graph.                                         | `PersonaAssignment` assigns `ClientIdentity` to `Persona`; `ClientMembership` is actor/workspace membership.                                          | Do not treat as assignment without a mapping decision.                                                          |
| `Organization`                       | `Bureau` / `BureauUnit`                           | Both represent org-side organization hierarchy.                            | `Organization` is legacy org-principal workspace/container shape; `Bureau` is org-zenith canonical hierarchy root with units/closures.                | Candidate mapping toward `Bureau` authority after decomposition.                                                |
| `Organization`                       | `Enterprise` / `Company`                          | Shared organization/collective pattern.                                    | Surface-specific canonical roots live in each zenith DB; legacy `Organization` is org-principal only.                                                 | Use as pattern evidence, not direct cross-surface table movement.                                               |
| `Client`                             | `ClientIdentity`, `ClientAccount`, `Persona`      | Runtime actor links to identity binding, RP projection, and account graph. | `Client` owns credentials/lifecycle/session-adjacent links; zenith rows separate identity binding/account/projection.                                 | Decompose, then bind authority portions to zenith graph.                                                        |
| `Operator`                           | `OperatorIdentity`, `OperatorAccount`, `Agent`    | Runtime actor links to identity binding, RP projection, and account graph. | `Operator` owns credentials/lifecycle/session-adjacent links; `Agent` is canonical org account.                                                       | Decompose, then bind authority portions to zenith graph.                                                        |
| `Visitor`                            | `VisitorIdentity`, `VisitorAccount`, `Individual` | Runtime actor links to identity binding, RP projection, and account graph. | `Visitor` owns credentials/lifecycle/session-adjacent links; `Individual` is canonical com account.                                                   | Decompose, then bind authority portions to zenith graph.                                                        |
| `OperatorWorkspaceAccount`           | `Agent`                                           | Both are org account-like and include `Account`.                           | `OperatorWorkspaceAccount` is legacy workspace-account shape tied to `Operator` and `Department`; `Agent` belongs to `OperatorIdentity`.              | Transitional candidate; likely retire/map to `Agent` after explicit decision.                                   |
| `OperatorWorkspaceAccountMembership` | `AgentMembership`                                 | Both are membership-shaped.                                                | Workspace-account membership joins operator to legacy account; `AgentMembership` joins `Agent` to `Bureau`/unit with membership semantics.            | Transitional bridge until legacy workspace-account direction is resolved.                                       |

## Recommended Placement Matrix

| item                                                      | current placement                                                         | semantic classification                                             | recommended target                                           | decision status | rationale                                                                                  |
| --------------------------------------------------------- | ------------------------------------------------------------------------- | ------------------------------------------------------------------- | ------------------------------------------------------------ | --------------- | ------------------------------------------------------------------------------------------ |
| `Member`                                                  | `app_principal`                                                           | `account_authority`, `bridge`, `transitional`                       | `unknown`                                                    | `transitional`  | Account-like but mixed with legacy `Client` and Avatar bridge/governance responsibilities. |
| `ClientMembership`                                        | `app_principal`                                                           | `membership`, `bridge`, `transitional`                              | `unknown`                                                    | `transitional`  | Membership-shaped raw workspace join needs mapping before movement.                        |
| `Organization`                                            | `org_principal`                                                           | `organization_authority`, `regional_ready`, `transitional`          | `unknown`                                                    | `candidate`     | Authority-like organization data overlaps legacy workspace/container role.                 |
| `Client`                                                  | `app_principal`                                                           | `runtime_actor`, `credential`, `contact_recovery`, `regional_ready` | `retained_principal` / `future_regional` after decomposition | `candidate`     | Mixed runtime actor row; do not move wholesale.                                            |
| `Visitor`                                                 | `com_principal`                                                           | `runtime_actor`, `credential`, `contact_recovery`, `regional_ready` | `retained_principal` / `future_regional` after decomposition | `candidate`     | Mixed runtime actor row; do not move wholesale.                                            |
| `Operator`                                                | `org_principal`                                                           | `runtime_actor`, `credential`, `contact_recovery`, `regional_ready` | `retained_principal` / `future_regional` after decomposition | `candidate`     | Mixed runtime actor row; do not move wholesale.                                            |
| `ClientOidcConnection`                                    | `app_ticket`                                                              | `session_token`, `bridge`, `unknown`                                | `unknown`                                                    | `candidate`     | Long-lived connection row, but ticket-side and token-linked.                               |
| `OperatorOidcConnection`                                  | `org_ticket`                                                              | `session_token`, `bridge`, `unknown`                                | `unknown`                                                    | `candidate`     | Long-lived connection row, but ticket-side and token-linked.                               |
| `VisitorOidcConnection`                                   | `com_ticket`                                                              | `session_token`, `bridge`, `unknown`                                | `unknown`                                                    | `candidate`     | Long-lived connection row, but ticket-side and token-linked.                               |
| Credential/contact/recovery groups                        | `app_principal`, `org_principal`, `com_principal`, ticket ceremony tables | `credential`, `contact_recovery`, `ceremony_transaction`            | `out_of_scope`                                               | `excluded`      | Credential and ceremony placement is separate from account/organization authority.         |
| `Persona`                                                 | `app_zenith`                                                              | `account_authority`                                                 | `zenith`                                                     | `settled`       | Canonical app Account row.                                                                 |
| `Agent`                                                   | `org_zenith`                                                              | `account_authority`                                                 | `zenith`                                                     | `settled`       | Canonical org Account row.                                                                 |
| `Individual`                                              | `com_zenith`                                                              | `account_authority`                                                 | `zenith`                                                     | `settled`       | Canonical com Account row.                                                                 |
| `ClientIdentity` / `OperatorIdentity` / `VisitorIdentity` | surface `*_zenith`                                                        | `identity_binding`                                                  | `zenith`                                                     | `settled`       | Identity binding rows, not runtime actors.                                                 |
| `ClientAccount` / `OperatorAccount` / `VisitorAccount`    | surface `*_zenith`                                                        | `projection`                                                        | `zenith` / `current_storage`                                 | `settled`       | RP account projections, not canonical Account model.                                       |
| `PersonaMembership`                                       | `app_zenith`                                                              | `membership`                                                        | `zenith`                                                     | `candidate`     | Account-to-enterprise membership/history shape.                                            |
| `AgentMembership`                                         | `org_zenith`                                                              | `membership`                                                        | `zenith`                                                     | `candidate`     | Account-to-bureau membership/history shape.                                                |
| `IndividualMembership`                                    | `com_zenith`                                                              | `membership`                                                        | `zenith`                                                     | `candidate`     | Account-to-company membership/history shape.                                               |
| `PersonaAssignment`                                       | `app_zenith`                                                              | `assignment`                                                        | `zenith`                                                     | `settled`       | Identity-to-account assignment.                                                            |
| `AgentAssignment`                                         | `org_zenith`                                                              | `assignment`                                                        | `zenith`                                                     | `settled`       | Identity-to-account assignment.                                                            |
| `IndividualAssignment`                                    | `com_zenith`                                                              | `assignment`                                                        | `zenith`                                                     | `settled`       | Identity-to-account assignment.                                                            |
| `Enterprise` / `EnterpriseUnit` / `EnterpriseUnitClosure` | `app_zenith`                                                              | `organization_authority`                                            | `zenith`                                                     | `settled`       | App-side organization hierarchy.                                                           |
| `Bureau` / `BureauUnit` / `BureauUnitClosure`             | `org_zenith`                                                              | `organization_authority`                                            | `zenith`                                                     | `settled`       | Org-side organization hierarchy.                                                           |
| `Company` / `CompanyUnit` / `CompanyUnitClosure`          | `com_zenith`                                                              | `organization_authority`                                            | `zenith`                                                     | `settled`       | Com-side organization hierarchy.                                                           |
| `OperatorWorkspaceAccount`                                | `org_zenith`                                                              | `account_authority`, `transitional`                                 | `unknown`                                                    | `transitional`  | Legacy account-like row overlaps `Agent` but is not resolved here.                         |
| `OperatorWorkspaceAccountMembership`                      | `org_zenith`                                                              | `membership`, `bridge`, `transitional`                              | `unknown`                                                    | `transitional`  | Legacy workspace-account membership overlaps `AgentMembership` direction.                  |
| Avatar rows and Avatar organization fields                | `avatar`                                                                  | `avatar`                                                            | `avatar`                                                     | `excluded`      | Avatar remains separate in this phase.                                                     |

## Findings

Clearly zenith authority:

- `Persona`, `Agent`, and `Individual` are current zenith account-authority rows.
- `ClientIdentity`, `OperatorIdentity`, and `VisitorIdentity` are current zenith identity-binding
  rows.
- `PersonaAssignment`, `AgentAssignment`, and `IndividualAssignment` are current zenith
  identity-to-account assignment rows.
- `Enterprise`, `Bureau`, `Company`, and their unit/closure models are current zenith organization
  hierarchy rows.

Clearly out of scope:

- Credential, contact, recovery, session, token, ceremony, logout, and OAuth authorization
  transaction rows.
- Preference/settings rows.
- Avatar rows and Avatar social graph/authority rows.

Good retained-principal or future-regional candidates:

- Runtime actor lifecycle and operational state on `Client`, `Visitor`, and `Operator`, after
  authority, credential, contact/recovery, and session portions are separated.
- Legacy principal-side rows whose remaining meaning is application state rather than global
  authority, after explicit decomposition.

Needs decomposition before movement:

- `Member`, because it mixes account-like semantics with legacy `Client` and Avatar bridge behavior.
- `ClientMembership`, because it is membership-shaped but does not map directly to the current
  `Persona` / `Enterprise` membership graph.
- `Organization`, because it has organization-authority shape and legacy org-principal
  workspace/container shape.
- `Client`, `Visitor`, and `Operator`, because each mixes runtime actor, credential/contact,
  lifecycle, and session-adjacent responsibilities.

Unresolved:

- Whether `Member` should be decomposed, retired, retained, or mapped to `Persona`.
- Whether `ClientMembership` maps to zenith membership, regional membership, or compatibility
  bridge.
- Whether legacy `Organization` maps toward `Bureau` authority or remains as a retained/future
  regional application container.
- Whether long-lived OIDC connection rows should remain ticket-side or gain a separate authority
  placement.
- How `OperatorWorkspaceAccount` and `OperatorWorkspaceAccountMembership` retire or map into `Agent`
  / `AgentMembership`.

## Anti-Rules

- Do not move a model to `zenith` just because its name sounds like Account, Identity, Principal, or
  Organization.
- Do not leave a model in `principal` and call it authority just because the database name is
  `principal`.
- Do not classify credential, session, token, ceremony, logout, or OAuth transaction rows as
  authority placement.
- Do not mix Avatar relocation into this placement.
- Do not treat regional-ready placement as final regional sharding.
- Do not use this document as authorization to migrate tables.

## Future Work Checklist

- [ ] Decide whether `Member` should be decomposed, retired, retained, or moved.
- [ ] Decide whether `ClientMembership` should map to zenith membership, regional membership, or
      compatibility bridge.
- [ ] Decide whether `Organization` should move toward zenith organization authority or become a
      regional application container.
- [ ] Audit OIDC connection rows separately from OAuth transaction rows.
- [ ] Decompose runtime actor models into authority, credential, lifecycle, and regional portions
      before any movement.
- [ ] Add ADR before any table movement.
- [ ] Add migration plan only after classification is accepted.
- [ ] Keep Avatar and ticket/session/ceremony out of this pass.

## Validation

Before accepting this document, verify:

- `docs/index.md` links this document.
- This document does not claim `principal` is empty.
- This document does not claim `principal` remains canonical authority.
- This document does not imply Avatar moves to `zenith`.
- This document does not move ticket/session/ceremony/OAuth transaction data into authority
  placement.
- This document does not authorize migrations.
- No application code, schema, migration, route, controller, service, policy, model connection, or
  test files were changed for this classification pass.
