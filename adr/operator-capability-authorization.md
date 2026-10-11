# ADR: Operator Capability Authorization

**Status:** Proposed (draft, 2026-09-19). Nothing here is implemented, and the open questions in
the matrix are not yet decided.

## Context

Org operations that act on other principals, such as enforcement, forced session revocation, and
operator lifecycle approval, have no capability model today. The facts below were established
against commit `281dd792e`; evidence is in
`evidence/2026-09-19-action-policy-sustainability-audit-K4TW.md`.

- `Operator` defines none of `has_role?`, `operator_or_manager?`, `can_view?`, `can_edit?`, or
  `can_contribute?`. The `ApplicationPolicy` helpers built on them (`operator?`, `manager?`,
  `editor?`, `contributor?`, `viewer?`, `operator_or_manager?`, `can_*?`) are unusable. They are
  legacy, not a specification, and this ADR does not treat their names as role definitions.
- `OrgStaffPolicy` delegates to those predicates, so it denies every operator. The staff console
  landing pages (IAM, billing, audit, configuration, system, support) are closed to everyone. This
  is pinned as fail-closed by `test/controllers/base/org/staff_console_pages_test.rb`.
- `EnforcementCasePolicy` and `{Client,Visitor,Operator}Policy#purge_sessions?` allow any
  authenticated operator. `EnforcementCasePolicy#approve?` adds only "not the operator who applied
  it".
- The enforcement controllers require Step-Up with the scopes `enforcement_case_apply`,
  `enforcement_case_approve`, `enforcement_case_release`, and `enforcement_case_review_appeal`. None
  of these is in `StepUpScopeCatalog::ORG`. The verification ceremony rejects an uncatalogued scope
  (`SignVerificationStepUpSessionStore`), so no operator can satisfy them in production, and the
  enforcement endpoints, including `index` and `show`, are unreachable. Tests reach them only by
  writing Step-Up columns directly. **Adding these scopes to the catalog before this ADR is decided
  would open enforcement to every operator.**
- Forced session revocation (`Base::Org::Support::{Clients,Visitors,Operators}::SessionsController`)
  requires Step-Up with `session_revoke_all`, which is catalogued, so it is reachable. Any operator
  who completes Step-Up can revoke any client's, visitor's, or other operator's sessions.
- `OperatorLifecycleRequestPolicy` is referenced nowhere and has no route. Its `approve?` would let
  any other operator approve any request. It must not be reused as a template.
- An organization structure exists: `Operator` has `bureau_ownerships`,
  `bureau_administration_grants`, `bureau_delegation_grants`, and `bureau_view_grants`. No support
  policy consults it, and whether those grants should carry support capabilities is undecided.
- Emergency sessions follow the ordinary policy rules and cannot perform Step-Up
  (`docs/security/org-emergency-access.md`). Every operation below that requires Step-Up is
  therefore unavailable in Emergency mode without any separate rule.

## Decision drivers

- Authorize by capability per operation, not by role name. Roles, if any, are later groupings of
  capabilities.
- Default deny: a capability that has not been granted denies.
- The disciplinary and cross-principal operations are the highest-risk surface on the org side.
- Keep the Step-Up and Emergency semantics already in place.

## Capability matrix

"Current" is what the code does today. "Open" marks a decision this ADR still needs.

| Operation                                  | Resource                        | Read / mutate | Organization boundary      | Self | Another operator | Destructive / disciplinary | Session revocation | Four-eyes                                   | Emergency                   | Step-Up                                  | Audit                                  |
| ------------------------------------------ | ------------------------------- | ------------- | -------------------------- | ---- | ---------------- | -------------------------- | ------------------ | ------------------------------------------- | --------------------------- | ---------------------------------------- | -------------------------------------- |
| List / show enforcement cases              | EnforcementCase                 | read          | Open                       | Open | Open             | no                         | no                 | no                                          | unavailable (Step-Up)       | Current: `enforcement_case_apply`; Open  | Open                                   |
| Apply enforcement                          | EnforcementCase, target account | mutate        | Open                       | Open | Open             | yes                        | Open               | Current: only when `requires_approval?`     | unavailable (Step-Up)       | Current: required                        | Current: `write_audit_event_once!`     |
| Approve pending enforcement                | EnforcementCase                 | mutate        | Open                       | n/a  | Open             | yes                        | Open               | Current: approver differs from applier      | unavailable (Step-Up)       | Current: required                        | Open                                   |
| Release enforcement                        | EnforcementCase                 | mutate        | Open                       | Open | Open             | yes                        | no                 | Open                                        | unavailable (Step-Up)       | Current: required                        | Open                                   |
| Review appeal                              | EnforcementCase appeal          | mutate        | Open                       | Open | Open             | yes                        | no                 | Open                                        | unavailable (Step-Up)       | Current: required                        | Open                                   |
| Revoke a client's / visitor's sessions     | Client, Visitor tokens          | mutate        | n/a (not org principals)   | n/a  | n/a              | yes                        | yes                | Open                                        | unavailable (Step-Up)       | Current: `session_revoke_all`            | Current: `AccountAccessEvent`          |
| Revoke another operator's sessions         | Operator tokens                 | mutate        | Open                       | Open | Open             | yes                        | yes                | Open                                        | unavailable (Step-Up)       | Current: `session_revoke_all`            | Current: `AccountAccessEvent`          |
| Approve operator lifecycle request         | OperatorLifecycleRequest        | mutate        | Open                       | no (current rule) | Open | yes                     | Open               | Open                                        | Open                        | Open (`operator_lifecycle` is catalogued) | Open                                   |
| IAM / billing / audit / configuration / system / support console | console pages | read (landing) | Open                  | Open | Open             | no                         | no                 | no                                          | Open                        | Open                                     | Open                                   |

## Open questions

1. What grants a capability? Choose between an explicit operator capability table and deriving
   capabilities from the existing bureau grants.
2. Organization boundary: may an operator act only on principals linked to bureaus they administer,
   or platform-wide? Clients and visitors are not org principals, so a platform-wide support
   capability may be needed for them.
3. Operator-to-operator actions: may an operator enforce against or revoke the sessions of another
   operator? Of an operator with equal or higher capability? Of themselves?
4. Which disciplinary operations need four-eyes approval? Is today's `requires_approval?` rule the
   whole answer?
5. Should reading enforcement cases need Step-Up, or only mutating them?
6. What audit record must each mutation leave? Approval, release, and appeal review currently have
   no confirmed audit write.
7. Do the staff console pages become reachable, and under which capability?

## Consequences

- No operator capability is implemented until the open questions are decided. Until then:
  - The enforcement Step-Up scopes stay out of `StepUpScopeCatalog`.
  - `OrgStaffPolicy` stays fail-closed.
  - `OperatorLifecycleRequestPolicy` stays unused.
- Forced session revocation stays reachable by any operator with Step-Up until a capability exists.
  If that is not acceptable in the meantime, the interim option is to deny revocation of operator
  sessions from the support screens. That takes away a working operation, so it needs an owner
  decision.
- Once decided, the capability check becomes the single authority for these policies. The legacy
  `ApplicationPolicy` role helpers are then either replaced by it or deleted.
