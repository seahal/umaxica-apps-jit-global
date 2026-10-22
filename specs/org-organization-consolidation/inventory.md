# Org legacy disposition inventory

Status: partial inventory; retirement is held. Inspected 2026-10-20 against
`febec3225cc9a0cfa53b9cbe817d20d366aba5a2` plus the in-scope uncommitted changes.

Classification: 1 = retireable after dependencies are resolved; 2 = migrate function;
3 = retain migration evidence; 4 = deletion held because verification is incomplete.
No production database was queried. Empty development data is not production clearance.

## Models and operations

| Candidate | Classification / disposition | Observed consumers and reason | Remaining dependency / exit condition |
| --- | --- | --- | --- |
| OperatorOrganization | 3, retained | Maps organizations; Department.workspace, Division.organization and OrganizationStatus.organizations remain; JOIN authorization read removed | Retire connected hierarchy after reviewed data/reference disposition; no mapping to Bureau is inferred |
| OrganizationStatus | 3, retained | Organization status association and migration/fixture evidence | organizations FK; also has an inconsistent departments inverse (department_status belongs to DepartmentStatus), left for retirement |
| Department | 3, retained | Self hierarchy; OperatorOrganization; OperatorWorkspaceAccount.department and Department legacy account relations | Legacy workspace account retention graph and FK dependency |
| DepartmentStatus | 3, retained | Department status reference and fixtures | departments FK |
| Division | 3, retained | Organization/status association and fixtures | organizations and division_statuses FKs |
| DivisionStatus | 3, retained | Division reference status | divisions FK |
| OperatorWorkspaceAccount | 4, held | Operator associations, Department associations, Retainable and RetentionPurgeJob allowlist | Resolve retained production rows/purge duties before removing class, association or job registration |
| OperatorWorkspaceAccountMembership | 4, held | Operator.staff_operators and account.staff_operators; association-backed destruction | Resolve operator/account FKs and retained membership data |
| OperatorWorkspaceAccountStatus | 4, held | Account.status and legacy_operator_department_accounts FK | Resolve both table families |
| OperatorLifecycleRequest | 2, migrate org JOIN; retain other lifecycle actions | Request/create/approve/reject/execute services and policies; no controller caller identified in app/config/lib search | JOIN creation refused; withdraw/suspend/terminate/restore contracts and retained request history remain |
| OrganizationInvitation | 2, migration required | Reachable Auth org invitation GET/POST, registration policy and retained-record validation/consumption | Target Bureau/Unit, issuance authorization, role/grant semantics, existing-user participation and cross-DB recovery need accepted design |
| OrgOperatorLifecycleInvitationAcceptance | 2, admission held | Auth org POST still calls it; now validation plus explicit refusal | Unsafe provisioning/compensation implementation removed; do not reopen before invitation design is settled |
| OrgOperatorLifecycleInvitationIssuer / OrgInvitationService.create | 2, issuance held | Lifecycle execute calls issuer then service; writes removed and result is failure | Preserve refusal for stored approved JOIN requests until replacement; no public issuance controller found |
| OrgOperatorLifecycleRequestCreate | 2, JOIN held | Former last service read of OperatorOrganization.owner field removed | Other lifecycle requests still supported; current JOIN authority is unresolved |
| OrgOperatorLifecycleApprove / Reject / Execute / Result | 4, retained | Existing lifecycle policies/tests, durable statuses and principal/session/Entra effects | Cannot equate all operator lifecycle actions with organization membership or delete retained history |
| Empty legacy model policies | 4, retained | Policies exist for hierarchy, invitations and workspace account models | Remove with their owning model graph after retention/authority disposition; no blanket policy deletion |

No class or table was deleted. Only the unsafe invitation issuance/provisioning implementation and
legacy JOIN ownership read were removed. A lack of controller callers does not establish absence
of task, deployment or external consumers.

## Physical tables and local data

Model inheritance and actual PostgreSQL catalog agree: OrgPrincipalRecord and OrgRpRecord inherit
OrgZenithRecord, whose writer is org_zenith. OpBaseOrgRecord uses op_base_org. Schema comment labels
such as org_principal are historical and are not a connection source of truth.

Read-only counts on primary in development_org_zenith_db:

| Table | Rows | Disposition |
| --- | ---: | --- |
| organizations | 0 | 3; retain hierarchy evidence pending production disposition |
| organization_statuses | 1 | 3; status FK target |
| departments | 0 | 3; hierarchy and account FK target |
| department_statuses | 4 | 3; reference data |
| divisions | 0 | 3; hierarchy |
| division_statuses | 4 | 3; reference data |
| operator_workspace_accounts | 0 | 4; retention consumer remains |
| operator_workspace_account_memberships | 0 | 4; association/FK graph |
| operator_workspace_account_statuses | 2 | 4; two account table families reference it |
| workspaces | 0 | 4; model-less table, user_workspaces FK target |
| workspace_statuses | 2 | 4; model-less reference table |
| user_workspaces | 0 | 4; model-less table, FK to workspaces |
| staff_operators | 0 | 4; physical historical join, references legacy_operator_department_accounts |
| legacy_operator_department_accounts | 0 | 4; physical old account table, references departments/statuses/operators |
| operator_lifecycle_requests | 0 | 2; retained workflow implementation |

Read-only count in development_op_base_org_db: organization_invitations = 0 (classification 2).
These observations do not classify any production table as safe to DROP.

Catalog FK findings: departments.workspace_id SET NULL to organizations; department self-parent FK;
divisions to organizations/statuses; workspace accounts.department_id SET NULL; account/staff/status
RESTRICT; workspace memberships account CASCADE NOT VALID; historical staff_operators CASCADE to
legacy_operator_department_accounts and operators; user_workspaces to workspaces. No FK behavior was
changed. The historical NOT VALID FK is a follow-up validation risk, not authorization for CASCADE.
The model-less legacy account graph prevents treating model deletion as schema deletion.

Migration provenance includes 20260201190010_convert_operator_pks (historical hierarchy rebuild),
20260514113000_align_operator_model_table_names (legacy account rename),
20260519172002_create_operator_workspace_account_tables, 20260518130000_create_operator_lifecycle_requests,
20260501000000_load_initial_org_ticket_schema (op_base_org invitation table), and
20261019120006/7 org Zenith FK creation/validation. Historical migrations are untouched.
AuthorityOwnerMigrationInventory inventories the six current authority families, not a reviewed
legacy Organization-to-Bureau mapping; its existence does not authorize legacy conversion.

## Current runtime and naming boundaries

AcmeSelectorSurfaceConfig.org already selects Agent, AgentAssignment, Bureau, BureauUnit and
AgentMembership. BaseSelectorBootstrapAuthority provisions those models. AcmeSelectableContext and
BaseSwitcherAuthority use that configured membership graph. New invitation acceptance no longer
calls the default bootstrap as a substitute for joining the invited organization.

The internal Account/Collective vocabulary in AcmeSelectorSurfaceConfig,
BaseSelectorBootstrapAuthority, AcmeSelectableContext, BaseSwitcherAuthority, CollectiveUnit and
CollectiveMembership remains naming debt. It spans all surfaces and selected_* persisted session
columns, aliases and existing public request fields; renaming it safely requires an explicit caller
and wire-contract inventory. No global replacement was performed. OperatorAccount is an RP Account,
not a Persona alias, and remains independent. Membership is not Ownership; formal Ownership, Grant,
TransferRequest and AuthorityCutover models are preserved. organization_entra_connections and its
state/identity consumers remain separate authentication tenant configuration, not a legacy hierarchy
candidate selected by its name.

## Search coverage and limits

Searched app, lib, config, test and db (including migrations and checked-in SQL dumps) for exact old
classes, associations and table names; inspected retention allowlist, current selector/bootstrap and
switcher implementations, concrete membership model and same-Bureau FK. Production SQL, deployed
jobs, external SQL clients, runtime dynamic resolution and historical data lineage are not certified
absent. Old model associations, fixtures, tests and migration history remain intentionally visible.

Read-only Edge checkout: seahal/umaxica-apps-edge HEAD
185dd076404011ed391b2b550091be3fd7939ba0. Exact searches for OperatorOrganization,
OrganizationInvitation, operator_workspace, departments, divisions and staff_operators found no
matches. General organization/membership/invitation searches found proxy/documentation prose, not
an Organization ID mapping. This is one remote snapshot, not deployed-contract approval. Local
feature takes precedence; origin currently names seahal/umaxica-app-jit.

## Removal gates

For each retained table, establish production counts, authoritative data owner, external readers and
writers, retention/audit obligations, an explicit migration or archival disposition, integrity queries,
and approved risk/recovery. Then remove the owning associations/purge registrations and classes in
coherent slices, using new migrations rather than rewriting history. No speculative DROP migration
is supplied. Sign-up participation remains blocked until its target and authority decisions are made.
