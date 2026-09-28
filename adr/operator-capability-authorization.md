# ADR: Operator Capability Authorization

**Status:** Accepted (2026-09-26). Supersedes the 2026-09-19 draft of this ADR, whose open
questions are answered below. The draft's findings are kept in "Context" because they explain what
was closed and why.

## Context

The org surface is the control plane for the app and com surfaces as well as the operators' own
self-service. Before this decision, facts established against commit `e423890e7`:

- `OrgStaffPolicy` delegated to role predicates `Operator` does not define, so every console
  (IAM, billing, audit, configuration, system, support) denied everyone and rendered a
  `{ status: "ok" }` stub.
- `EnforcementCasePolicy`, `{Client,Visitor,Operator}Policy#purge_sessions?`, and
  `OperatorLifecycleRequestPolicy` accepted any authenticated operator.
- The enforcement Step-Up scopes were not catalogued, so enforcement, including reading, was
  unreachable. The org `session_revoke_all` return-path pattern only matched numeric ids, while the
  routes use base32 public ids, so forced session revocation was unreachable in practice as well.
- Case creation accepted `break_glass_approved_by_operator_public_id` from the request, a release
  with an unknown reason silently became `revoked`, and every `enforcement_events` row named the
  applying operator even for approval, release, and appeal decisions.
- Organization membership endpoints returned `[]`, `{}`, a fixed 422, or a 204 that changed nothing.
- `chronicle_retention_policies` is not seeded anywhere; every Chronicle intent write fails until an
  operator creates the policy rows (see the runbook).

## Decision

### Grants are the only authority

`operator_capability_grants` (org zenith database) holds one row per grant of one fixed capability
to one operator. A capability is in force only while the grant is unrevoked, `starts_at <= now <
expires_at`, and the operator is eligible: access enabled, no withdrawal started, not withdrawn or
deactivated, inside retention, and not in a login-blocked status. `Operator#capability?` is the one
check; `ApplicationPolicy#operator_capability?` wraps it for policies. An unknown identifier raises.

- Being an `Operator` is necessary, never sufficient. No grant means deny.
- Role names, Bureau ownership, and Bureau administration, delegation, or view grants confer no
  platform capability. A NULL Bureau never means "platform".
- Every grant is platform-scoped and the realm is part of the fixed identifier, so app and com are
  granted and revoked independently. There is no wildcard. Adding a capability is a migration: the
  column carries a CHECK over the catalog.
- Validity is bounded (at most 366 days, finite timestamps), enforced by both the model and the
  `chk_operator_capability_grants_validity_window` CHECK. There is no standing grant.
- The check reads the database on every request. There is no cache, so a revocation takes effect for
  every operation that starts after it commits.

### Catalog

| Capability | Allows |
| --- | --- |
| `support.console.read` | Support landing page |
| `support.account.read.{app,com}` | List and show Clients (app) or Visitors (com) by public id |
| `support.session.revoke.{app,com}` | Revoke every current session of one Client or Visitor (also needs the read capability) |
| `enforcement.read.{app,com}` | List and show the realm's Enforcement Cases, without Step-Up |
| `enforcement.apply.{app,com}` | Open a Case (also needs read) |
| `enforcement.approve.{app,com}` | Approve a pending Case opened by someone else (also needs read) |
| `enforcement.release.{app,com}` | End an active Case (also needs read) |
| `enforcement.review_appeal.{app,com}` | Decide an appeal (also needs read) |
| `iam.capability.read` | List and show grants |
| `iam.capability.grant` | Grant a capability the granter itself holds |
| `iam.capability.revoke` | Revoke a grant |

No capability exists for the org enforcement realm, for operator sessions, for operator lifecycle,
or for membership changes. Those operations deny every operator.

### Granting

Granting is authorized separately from holding. `OperatorCapabilityGrantPolicy#create?` requires
`iam.capability.read` and `iam.capability.grant`, a target other than the granter, a catalogued
capability that is not an IAM capability, and that the granter currently holds that capability
(delegation never widens). The model and a CHECK also forbid a delegated grant naming the grantee as
granter. IAM capabilities are issued only through the audited bootstrap task, never through the
console, so the set of operators able to grant cannot be grown from inside the console.

Revoking a grant of `iam.capability.grant` or `iam.capability.revoke` takes `SELECT ... FOR UPDATE`
on every unrevoked grant of that capability, in id order, inside the revoking transaction, and only
then counts the other in-force grants held by eligible operators. Two concurrent revocations
therefore lock the same rows in the same order: the second waits, then sees the first revocation
and is refused. There is no count-then-update window. A deadlock, which the fixed order is meant to
prevent, would roll one transaction back with an error and revoke nothing. This is verified by
`test/concurrency/operator_capability_continuity_test.rb` on separate database connections; with
the lock removed the same test observes both revocations succeed. The guard does not stop expiry or
an operator becoming ineligible; bootstrap is the recovery path for that, and keeping two or more
holders is an operational recommendation, not a system guarantee.

Bootstrap (`operator_capabilities:bootstrap`) is the root of trust and is stricter than the console:
`OPERATOR`, `CAPABILITIES`, `TICKET`, and `EXPIRES_AT` are all required; every capability must be
in the fixed catalog (no wildcard); expiry must be in the future and within 366 days; the operator
must be eligible; a capability the operator already holds in force is refused rather than duplicated;
all requested grants are validated before any is written and are written in one transaction; the
Chronicle intent is written first and nothing is granted if it cannot be; `DRY_RUN=true` validates
everything and writes nothing. Output contains only public ids, capability names, and times.

### Operation matrix

| Operation | Capability | Step-Up scope | Emergency session | Audit |
| --- | --- | --- | --- | --- |
| Support landing, client/visitor list and show | read | none | allowed (read) | none |
| Revoke a client's or visitor's sessions | realm read + revoke | `support_session_revoke` | refused (no Step-Up) | Chronicle `support.session.revoked` (intent first) and `AccountAccessEvent` |
| Enforcement list and show | realm read | none | allowed (read) | none |
| Open a Case | realm read + apply | `enforcement_case_apply` | refused | `enforcement_events` `applied` or `approval_requested` |
| Approve | realm read + approve, not the applier | `enforcement_case_approve` | refused | `approved` (approver), `applied` |
| Release | realm read + release | `enforcement_case_release` | refused | `ended` (releasing operator) |
| Appeal review | realm read + review_appeal, not applier or approver | `enforcement_case_review_appeal` | refused | `appeal_approved`/`appeal_rejected` (reviewer) |
| List and show grants | `iam.capability.read` | none | allowed (read) | none |
| Grant | read + grant + the delegated capability | `operator_capability` | refused | Chronicle `iam.capability.granted` (intent first) |
| Revoke grant | read + revoke | `operator_capability` | refused | Chronicle `iam.capability.revoked` (intent first) |
| Bootstrap | none (operator shell) | none | n/a | Chronicle `iam.capability.bootstrapped` (intent first) |

Each confirmation screen (`new`) authorizes the capability before it asks for Step-Up, so an
operator without the capability never starts a ceremony. Each mutating action calls `authorize!` and
then requires Step-Up in its own body. The Step-Up return-path patterns cover only the app and com
confirmation screens.

The Step-Up path is verified end to end by `test/integration/org_admin_step_up_ceremony_test.rb`:
confirmation screen, base intent, signed grant, auth passkey ceremony (only the WebAuthn
cryptographic assertion is stubbed), signed result, base completion, return to the screen, the
revocation, and its audit. The same file shows that a result for another session, a result signed
for another surface, a replayed result, an expired freshness window, a forged or re-scoped return
target, a different Step-Up scope, and an Emergency session all fail to satisfy the requirement.

**Assurance.** The administrative scopes use the surface's `verification_required_aal`, which is
`StepUpRequirement::NO_AAL`. A passkey Step-Up is recorded as `aal1`. No AAL2 or AAL3 guarantee is
made for these operations.

**CSRF.** The org surface uses Rails `protect_from_forgery using: :header_or_legacy_token` with the
staff host as the only trusted origin. For cookie-authenticated requests, `Sec-Fetch-Site:
same-origin` (or `same-site`) is accepted without a token, `cross-site` from an untrusted origin is
rejected, a request without Fetch Metadata needs a valid authenticity token, an `Origin` differing
from the request's origin is rejected, and `Referer` is not consulted. JSON bodies get no exemption.
`test/integration/org_admin_csrf_test.rb` checks this for the Support, IAM, and Enforcement
mutations.

### Audit and failure

Support revocation and IAM changes use the existing Chronicle intent/result writers through
`OrgAdministrativeAudit`. The intent row is written before the operation starts; if it cannot be
written the operation is not started and the response is 503. The intent's `event_uuid` is the
operation id the confirmation screen issued, so a resubmission returns the recorded operation
without running it again, and the same id with a different actor, action, target, or reason is a
409. A failed result write leaves the row in `intent` or `manual_recovery_required`, and the result
page reports it as unconfirmed rather than complete. Chronicle is a separate database, so intent,
operation, and result are three commits.

Enforcement keeps its own durable audit path (`write_audit_event_once!` plus
`EnforcementReconciliationJob`), written after the decision commits rather than intent-first.
`actor_operator_public_id` is a required keyword with no default: `applied` names the operator who
ran the apply (the opener on the direct path, the approver on the approval path), `approved` the
approver, `ended` the releasing operator, an appeal decision its reviewer; expiry, a principal's own
appeal or verification, and job reconciliation pass `nil` explicitly. The event actor is not the
Case's `applied_by`/`approved_by` attribution. If audit delivery fails after the Case is active,
the Case stays active with `audited_at` null and the reconciliation job writes the missing
`approved` event (naming the approver) and `revocation_reconciled`.

### Access lock and Enforcement

The Case remains the decision record and `AdministrativeAccessLock` the only runtime gate. There is no
separate access-lock endpoint. Ending a Case unlocks only when no other in-force Case blocks the
principal, and unlocking never revives sessions, tokens, or Step-Up freshness. A request for
break-glass on create is refused. A permanent ban or a `break_glass_only` Case is refused by the
release endpoint: the break-glass second-approver flow is not provided, and releasing under a weaker
control than the one that applied the Case is not allowed. An operator may release only with reason
`revoked` or `corrected`; any other value is a 422. Concurrent approvals are serialized by claiming
the approver under the Case row lock. After any failure, the claim is withdrawn only if, re-read
under the row lock, the Case is still `pending_approval` with this approver. That condition proves
nothing observable happened, because `EnforcementCaseApplyOperation` commits the state change and
the effect rows in one transaction and performs the account lock, session revocation, and audit
only after that commit. A Case that became `active` or `failed` keeps its approver, and an applied
lock is never undone to make the Case look pending. `test/controllers/base/org/support/
enforcement_approval_failures_test.rb` covers each failure point.

### Concerns

| Concern | Kind | Responsibility | Contract with the includer |
| --- | --- | --- | --- |
| `OrgAdministrativeAudit` | controller | Chronicle intent, idempotent replay, result, invalidation | provides `current_operator`, `request` |
| `OrgAdministrationPage` | controller | acting-operator/realm context, bounded query and page, operation id | provides `current_operator` |
| `OrgSupportSessionRevocationPage` | controller | revocation input validation and page shaping | also includes the two above |
| `OrgEnforcementCasePage` | controller | Case JSON, fields, explicit per-realm paths | also includes `EnforcementCaseRealmResolvable`, `OrgAdministrationPage` |

None of them adds `included do`, callbacks, authorization, or Step-Up. Each concrete controller names
its target class, lookup, policy and rule, Step-Up scope, and the operation it calls.

### Routes

All on the org host only: `/support`, `/support/{clients,visitors}` (index, show), nested
`revocations` (new, create, show), `/support/{app,com,org}/enforcement_cases` with nested `approval`,
`release`, and `appeal_review` (new, create), `/iam`, `/iam/grants` (index, show, new, create) with
nested `revocation` (new, create). Org membership routes are index and show only. The previous
`sessions/purge`, `sessions/emergency_revocation`, and unrouted operator session controllers are
removed.

## Not provided, and why

- **Org enforcement realm, operator session revocation, operator lifecycle** (join, withdraw,
  suspend, terminate, restore): no rule decides which operator may act on which other operator, what
  four-eyes and last-administrator rules apply, or whether a third executor is required.
  `OperatorLifecycleRequestPolicy` denies every rule.
- **Membership changes**: org memberships are read-only (index and show of real data, members of
  the Bureau only); create, update, and destroy are not routed, and the policy's change rules deny
  every org record. Two ownership notions exist (`BureauOwnership` /
  `BureauAdministrationGrant` and the membership-level `OWNER` kind the selector bootstrap assigns)
  and neither is decided as the authority. Members may read their Bureau's roster.
- **Break-glass release**: needs a second approver recorded from their own session.
- **Audit, billing, configuration, system consoles**: no authoritative data source is owned here.
  `OrgConsolePolicy` denies them to every operator.
- **AAL requirement**: the admin Step-Up scopes use the surface's current `verification_required_aal`
  (no AAL floor). A higher assurance requirement is not claimed.

## Production blockers and prerequisites

Current status is kept in `docs/operations/org-control-plane-production-readiness.md`. In short:

- **OQ-AUD-004** is decided: compliance retention is 365 days (2026-09-26), inserted by a chronicle
  data migration. It applies to the Chronicle intents of Support revocation, IAM, and bootstrap;
  Enforcement events use no retention policy.
- **OQ-AUD-001** is decided but not implemented (`adr/chronicle-tamper-resistance.md`): database role
  privileges on the chronicle tables. It remains a blocker for every administrative operation,
  Enforcement included, until the runtime and migration roles are separated and verified.
- Bootstrap must name the first operators; two or more IAM holders are an operational
  recommendation, not a system guarantee.

## Consequences

- Nothing administrative is available after deployment until bootstrap has run.
- The legacy `ApplicationPolicy` role helpers remain for non-org callers; they are not used by any
  org administrative policy.
- `docs/operations/operator-capability-runbook.md` holds the bootstrap, revocation, and audit
  recovery procedures.
