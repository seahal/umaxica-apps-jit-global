# Org Organization consolidation

Status: implementing

Authority: user instruction, 2026-10-20. Scope is the first org consolidation cycle.

## Contract and scope

Use Agent / Bureau / BureauUnit / AgentMembership, preserving Principal, RP Identity,
Assignment, Ownership, Grant and Lifecycle boundaries. Existing accepted naming and
owner-authority ADRs remain authoritative. app Member and Avatar redesign are excluded.

The observed invitation admission ignores the legacy organization reference and bootstraps
an unrelated Bureau. The user explicitly requires refusal when the target/authority contract
cannot be established. Preserve the HTTP route, validation and stored invitations, but refuse
legacy issuance and acceptance before writes until a reviewed Bureau-targeted invitation
contract exists. This is a security hold, not completed invitation migration.

## Acceptance

- AC-1: Legacy invitation acceptance refuses without creating Principal, RP Account, Identity,
  Agent, Bureau, Unit, Assignment or Membership, and without consuming the invitation.
- AC-2: Missing, unknown, consumed and expired codes remain explicit failures; repeat submissions
  cannot add authority. An existing Operator email does not turn registration into participation.
- AC-3: Issuance cannot create new legacy invitations, including approved lifecycle JOIN execution.
- AC-4: Existing invitation GET/POST routes remain available; POST renders the refusal inline.
- AC-5: Inventory and classify old models/tables and actual dependencies. Retain data and purge
  ownership until production counts, retention, external references and recovery are established.
- AC-6: Complete org runtime consolidation and safe retirement, with appropriate model, authorization,
  selector/switcher and authentication regressions. This remains open while migration blockers exist.

## Order and verification

Inventory consumers and DB topology; express the security refusal in public-boundary tests;
observe Red; implement minimum refusal and remove the unsafe provisioning/compensation path;
run focused tests, then org model/selector/switcher/lifecycle checks and autoload/routes/schema checks.
Record actual results and handoff in evidence. No destructive migration is authorized by this spec.

## Open decisions

No reviewed legacy Organization-to-Bureau mapping, invitation target Unit, current issuance authority,
role-to-grant mapping, existing-user participation protocol or cross-DB recovery contract is established.
Never infer an owner from membership or identify Bureau by a coincident legacy numeric ID.
