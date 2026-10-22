# Org consolidation implementation and Claude Code handoff

Outcome: **PARTIAL / BLOCKED**. This change delivers a security hold and removes the unsafe legacy
invitation write/provisioning path. It does not claim complete Organization model consolidation.

## A. Implementation

The existing org selector/bootstrap configuration already uses Agent / Bureau / BureauUnit /
AgentMembership. Legacy invitation acceptance instead bootstrapped a new default Bureau without
resolving its stored organization target. Acceptance now validates the code then explicitly refuses
before writes. New JOIN requests and invitation issuance also refuse. Stored approved JOIN execution
returns the refusal without recording execution. Existing invitation routes and inline feedback
are preserved. Principal, RP Account, Identity, Persona, Assignment, Membership and Ownership remain
independent; no inferred mapping or new Grant/Transfer feature was added.

The legacy registration/compensation implementation and Organization owner lookup were removed.
There is no new path for either registration or existing-user participation until their authority
and target contracts are settled. This intentionally suspends legacy org invitation admission.

## B. Changed files

Model / Concern / Policy / Controller / Operation / Job / Migration: no production files changed
in these categories. No model, table, FK, fixture or retention registration was deleted.

Services:

- app/services/org_invitation_service.rb — refuse new issuance; remove legacy creation implementation.
- app/services/org_operator_lifecycle_invitation_acceptance.rb — preserve code validation; refuse
  admission; remove Principal/account/identity-graph writes and compensating destruction.
- app/services/org_operator_lifecycle_request_create.rb — refuse JOIN before legacy ownership lookup.
- app/services/org_operator_lifecycle_execute.rb — expose issuance refusal through existing Result.

Tests:

- test/services/org/operator_lifecycle/invitation_acceptance_test.rb
- test/services/org/operator_lifecycle/request_create_test.rb
- test/services/org/operator_lifecycle/execute_test.rb
- test/services/org/invitation_service_test.rb
- test/operations/org/operator_lifecycle/invitation_issuer_test.rb
- test/controllers/auth/org/up/invitations_controller_test.rb

Docs and handoff:

- docs/architecture/persona-organization-authority.md
- docs/checklists/authorization.md (AUTHZ-7)
- docs/mermaid/idp-operator-organization-invitation.mmd
- docs/mermaid/idp-state-machine-transition-inventory.md
- specs/org-organization-consolidation/spec.md, inventory.md, report.md
- evidence/2026-10-20-org-organization-consolidation-Q7M2.md

Pre-existing edits to adr/identity-centric-aaa-architecture.md and
adr/surface-account-collective-model-naming.md were read and preserved, not authored by this task.

## C. Legacy model disposition

[The inventory](inventory.md) lists every requested model/table with classification, consumers,
local counts, FKs, migration provenance and exit conditions. OperatorOrganization/OrganizationStatus,
Department/DepartmentStatus and Division/DivisionStatus remain migration evidence. Workspace account
models remain held due to association/purge/data obligations. Invitation and JOIN functionality need
migration. Other operator lifecycle responsibilities remain retained. No item is falsely classified
as fully retired; old model references still exist in the retained association graph and purge job.

## D. Data migration

org_zenith: no new migration or backfill. op_base_org: no new migration or backfill. Schemas and
historical migrations are unchanged; no DROP or destructive data operation was executed.
Development business-row counts were zero, but production counts, external consumers and retention
are unverified. Reintroducing the old acceptance implementation would reopen wrong-organization
provisioning; recovery must preserve the refusal until a reviewed replacement is ready.

## E. Verification

[Evidence](../../evidence/2026-10-20-org-organization-consolidation-Q7M2.md) gives commands, the
command-local test DB allowlist, Red/Green observations and every failed/unexecuted check.

- Final focused tests: 72 runs, 308 assertions, no failures/errors/skips.
- Broader regressions: 77 runs, 512 assertions, one root-login failure; reproduced on original HEAD.
- Zeitwerk, routes, schema-drift check, scoped RuboCop, frozen directives and diff check passed.
- database_consistency failed with many findings; baseline also fails, with differing output.
- CI's repository knowledge command is missing. Full CI/full suites were not run.

## F. Blockers and remaining work

1. Define a reviewed target Bureau/Unit and invitation issuer authorization. A legacy organization
   ID or legacy operator_id cannot establish Bureau ownership or membership.
2. Define role/grant semantics, email possession/recipient binding, separate authenticated
   existing-user participation, resend/replay behavior and cross-DB idempotent recovery. No default
   Bureau creation is an acceptable substitute.
3. Obtain production data lineage, counts, retention and external-reader/writer disposition plus
   approved risk/recovery before destructive migrations. Resolve old model association and purge
   dependencies before deleting Ruby classes.
4. Account/Collective naming remains in shared internal APIs, persisted session fields and public
   request aliases. Complete its consumer/compatibility inventory before changing those contracts.
5. The Entra root-login replay failure exists at baseline. database_consistency findings and the
   missing repository-knowledge CI command remain outside this security slice.
6. Edge was inspected at one remote HEAD; deployed and external SQL consumers are not certified absent.

## G. Independent acceptance handoff

Before commit: febec3225cc9a0cfa53b9cbe817d20d366aba5a2.
After commit: no new commit; same HEAD plus the listed uncommitted patch. The user's ADR edits
must stay separate. No merge, release, deployment or external write was performed.

Review the four services first. Confirm no OrgOperatorLifecycleInvitationAcceptance branch can
create/consume/provision, and no service issuance or lifecycle JOIN success can bypass the hold.
Review the changed tests for expiry boundaries, repeated submissions, coincident IDs, existing email,
route preservation and unchanged other lifecycle actions. Re-run the focused command from evidence
serially against the verified local test DBs. Check org model and selector/switcher tests to confirm
cross-Bureau unit refusal and membership/ownership separation remain covered. Then independently
address the failed root-login regression and consistency findings before claiming complete readiness.

Deleted models/tables: none. Held targets: all listed in inventory. Formal Ownership / Grant /
TransferRequest / AuthorityCutover models, app Member and Avatar behavior are preserved.

Acceptance disposition: AC-1 through AC-4 implemented with focused evidence. AC-5 has a bounded
local inventory with production/external deletion gates still open. AC-6 remains unfulfilled.
Do not mark the specification closed or the overall consolidation complete.
