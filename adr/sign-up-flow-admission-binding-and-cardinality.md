# Sign-up Flow Admission Binding and Cardinality (E1)

## Status

**Accepted (2026-10-21).** Decision only. The new Flow-to-Admission association, its
constraints, and retirement of the duplicate Ceremony reference are **Not Implemented**.
Runtime, schema, migrations, data, and tests are unchanged by this ADR. Acceptance does not
certify existing runtime conformity or completion of acceptance criteria.

The acceptance date is the decision date explicitly supplied by the owner. Local source review
was performed on 2026-10-20 at `febec3225cc9a0cfa53b9cbe817d20d366aba5a2` with unrelated
uncommitted work present. This record does not claim observations of future runtime behavior.

## Context and authority

[Sign In First](sign-in-first-and-sign-up-handoff.md) remains the authority for canonical
session admission and the completed registration handoff. APP and COM retain independent
Sign-up state machines for Identity, Contact, Credential, Guardrail, Checkpoint, and Finalization.
This ADR adds reference integrity and cardinality contracts without redefining Sign In First.
`COMPLETED` alone grants neither a Root Browser Session nor an RP Session. Auth owns Ceremony
and evidence; Base confirms authentication results and owns Root Session and OIDC Authorization.
A durable Identity survives a subsequent Sign-in failure without compensating deletion.

The [Base/Auth boundary](base-auth-ceremony-and-seven-rp-boundary.md),
[neutral entry decision](sign-neutral-entry-and-logout-target-authorization.md),
[lifecycle vocabulary](idp-flow-lifecycle-vocabulary.md), and
[state storage decision](idp-flow-state-machine-lifecycle.md) remain in force.
ORG public registration is outside this Flow association decision.

## Accepted decisions

### Admission scope and concurrency

Admission means Base's permission to begin an Auth Authentication or Registration Ceremony.
It is only the Base-to-Auth leg, not the whole Base-to-Auth-to-Base exchange:

| Boundary | Responsibility |
| --- | --- |
| Base to Auth | Admission issuance and browser-bound admission |
| Auth | Authentication / Registration Ceremony and evidence |
| Auth to Base | Authentication Result Handoff |
| Base | Validation, confirmation of the authentication result, Root Session / OIDC Authorization |

The existing division of issuance, Browser Binding, confirmation, Redemption, and Result receipt
is retained. `redeemed` means the admission was accepted; it proves neither successful
identity authentication nor Session issuance.

At most one Admission / Ceremony may progress concurrently for the **same parent Transaction**,
including after Redemption. Different parent Transactions remain independent. This is not a
browser-wide singleton: independent RP OIDC Authorization Transactions and multiple tabs remain
supported. Historical rows may coexist, and cancelled Ceremony history may be followed by a new
Admission for the same parent. A permanent UNIQUE over all historical parent references would
violate that contract.

Unused Admission uniqueness and admitted Ceremony uniqueness are separate conditions. Existing
locking and indexes are retained, but are not asserted to prove every case of this broader
contract; see the source-review limits below.

### One durable Flow-to-Admission authority

The sole durable association expressing which Admission owns an APP/COM Sign-up Flow is:

`SignUpFlow.auth_admission_binding_id`

| Surface | Flow | Binding | Database |
| --- | --- | --- | --- |
| APP | `ClientSignUpFlow` | `ClientAuthAdmissionBinding` | `op_base_app` |
| COM | `VisitorSignUpFlow` | `VisitorAuthAdmissionBinding` | `op_base_com` |

The target is a physical same-database FK and ultimately mandatory association (`NOT NULL`).
The owning Admission is fixed at Flow creation and MUST remain unchanged afterward. Ceremony
resolution MUST reuse the Binding's `admitted_auth_ceremony_session_id`; the resolved Ceremony,
Admission, effective intent, parent, surface, browser continuity, and applicable actor/evidence
ownership MUST agree before the Flow is used for authentication-sensitive work.

`AuthCeremonySession.local_sign_up_flow_ref` is not a second authority. It is to be retired after
migration to the Flow-to-Binding association; coexistence MUST NOT establish competing authorities.
The migration/backfill and removal procedure remains Pending. A Rails Session Flow Locator may
continue as UI lookup continuity, with no independent authentication authority. A new generic
Relation table is not adopted for this relationship.

An FK proves referenced-row existence, `NOT NULL` proves presence, a UNIQUE or partial unique
index proves its scoped cardinality, and CHECK proves only its declared row condition. These do
not alone prove correct authentication ownership or prevent changing an FK to another existing
row. Post-creation immutability and Ceremony/Admission agreement are required contracts; their
specific database/Rails enforcement, including database write permissions, remains Pending.
No trigger, callback, privilege scheme, or other implementation mechanism is selected here.

### One in-progress Flow per Admission Binding

A Binding may own at most one **in-progress** Sign-up Flow. Multiple terminal historical Flows
are permitted. Adopt a PostgreSQL partial UNIQUE index on `auth_admission_binding_id` scoped by
the existing state machine's in-progress `status_id` values.

Local `FlowSignUp`, both Flow models, and both status models were rechecked. The in-progress
sets are:

- APP: `STARTED`, `CONTACT_PENDING`, `CREDENTIAL_PENDING`, `CONTACT_VERIFIED`,
  `SOCIAL_CALLBACK_PENDING`, `GUARDRAIL_PENDING`, `CHECKPOINT_PENDING`, `FINALIZING`.
- COM: the same set excluding `SOCIAL_CALLBACK_PENDING`.

These currently map to APP IDs `10, 20, 30, 35, 36, 38, 40, 60` and COM IDs
`10, 20, 30, 35, 38, 40, 60`. These are reviewed mappings, not a new status-ID assignment.
The implementation MUST align the predicate with the owning state-machine definition.

The predicate MUST be status-based. An `expires_at > now()` dynamic time predicate is not
adopted. Expired in-progress rows must reach a terminal state through the appropriate state-machine
transition before their slot is released. Per-Flow row locks serialize transitions on an existing
Flow; they cannot lock a competing row that has not been inserted. The new partial UNIQUE is the
separate database barrier against concurrent Flow INSERTs for the same Binding.

### Restart, lifecycle, intent, and evidence

Restart ends the old Flow as `HALTED` and creates a distinct new Flow with its own identity;
it never resets the old Flow to its initial state. Preserve `FlowSignUp`, `SignUpStateMachine`,
`SignUpTermination`, and `SignUpStepGate` semantics, terminal transitions, Checkpoint Version,
and artifact Cleanup. `HALTED` is system-originated; `CANCELLED` records explicit user Cancel.
System supersession MUST NOT be recorded as a user Cancel. An old page's Flow Binding MUST NOT
update or halt its replacement Flow. This does not authorize reopening any terminal Flow.

Sign-up eligibility MUST use effective Admission Intent, including purpose and `entry_intent`
with the saved parent. A neutral OIDC parent may have `intent = authentication`; testing only
`authorization_transaction.intent == "sign_up"` is insufficient. D06 first-page Switch cancels
the old Ceremony and asks Base for a fresh Admission with the chosen `entry_intent`, retaining
the neutral parent. That existing transition is distinct from restarting a progressed Sign-up
Flow or the completed Sign-up handoff to Sign In.

OTP issuance, OTP verification, Passkey evidence, and a Social Callback are distinct facts, not
one generic authenticated state. Old Flow evidence MUST NOT be transferred improperly to a new
Flow. A callback's occurrence alone is not proof of accepted authentication. Any permitted use
must preserve method, verification, actor, operation, Ceremony, Admission, parent, browser, and
deadline bindings. Whether and how evidence survives a restart is Pending, not implicitly allowed.

### Database boundaries

The Flow-to-Binding FK is local to the corresponding OP database. It does not atomically guarantee
Zenith Principal, Contact, or other cross-database state. The
[Cross-DB Reference Policy](cross-db-reference-policy.md) remains in force; this ADR introduces
no distributed database Transaction. Durable registration is not deleted as compensation for
failed Sign In. Existing Cleanup of unfinished artifacts remains distinct from that prohibition.

## Local source review and adversarial reconciliation

The following are source observations, not executed tests or a deployed-database inspection:

- **R1 — Redemption gap:** `db/op_base_{app,com,org}_structure.sql` defines per-parent unused
  Admission UNIQUE indexes with `retired_at IS NULL AND redeemed_at IS NULL`. Redemption removes
  a row from those predicates. OIDC Ceremony uniqueness separately covers
  `authorization_transaction_ref IS NOT NULL AND cancelled_at IS NULL`; this also covers
  completed/revoked non-cancelled rows, not just currently active ones, and is not a Local-parent
  Ceremony index. `BaseAuthAdmissionCoordinator.issue_binding_and_transport!` locks the parent;
  `create_or_reuse_binding!` reuses a matching unused Binding and normally refuses reissuance if
  any matching-purpose redeemed Binding exists. The D06 exception requires all such admitted
  Ceremonies to be cancelled. Binding attach/confirm/redeem operations and the coordinator's
  parent/Binding/Ceremony locks serialize their respective transitions. These cooperating guards
  explain existing protection; the unused index alone does not enforce post-Redemption exclusion,
  and exhaustive all-purpose/all-parent concurrency coverage remains unverified.
- **R2 — effective intent:** `validate_entry_parent_intent!` accepts neutral `authentication`
  and constrains a populated `entry_intent` to the requested entry. The new contract preserves
  this instead of importing the research proposal's parent-only `sign_up` test.
- **R3 — evidence:** `AuthOidcResultHandoff` requires recorded authentication evidence and its
  method/event timestamp; the coordinator separately checks provider evidence for Social results.
  Neither Admission Redemption nor OTP delivery is a substitute. Restart evidence policy remains
  Pending; no existing evidence path is certified universally correct by this review.
- **R4 — integrity:** the reviewed APP/COM schemas do not contain the new Flow
  `auth_admission_binding_id`. Ceremony-side `local_sign_up_flow_ref` and exclusivity CHECKs
  remain. Target association, mandatory FK, cardinality, and immutability are future work;
  existence of those older constraints does not implement this decision.
- **R5 — lifecycle:** `SignUpFlowEntry` supersedes via system halt before new artifacts;
  `SignUpTermination` owns terminal retention/Cleanup; `SignUpStepGate` distinguishes wrong Flow
  bindings from same-Flow phase/generation violations. Existing tests in
  `test/services/sign_up/state_machine_test.rb`, `test/services/sign_up_step_gate_test.rb`, and
  `test/services/auth_admission_binding_concurrency_test.rb` describe related boundaries; they
  were inspected, not run. Historical `FAILED`, `FINALIZED`, and `SIGN_IN_HANDOFF_PENDING` remain
  terminal compatibility vocabulary in the current models, not newly adopted active states.
- **R6 — Cross-DB:** local OP membership does not extend the physical FK guarantee to Zenith.
  Sign In First's durable Identity protection is retained without distributed atomicity claims.
- **R7 — earlier proposal:**
  `research/sign-up-admission-child-binding-shape-proposal.md` remains Proposed and non-normative.
  Its Ceremony-side child attachment and strict parent `sign_up` condition are not adopted.
  This accepted Flow-to-Binding authority governs that conflict; the research file is unchanged.

## Pending decisions

| Item | Still undecided |
| --- | --- |
| Restart after OTP issuance | Whether the same Admission may be reused |
| Restart after authentication evidence | Conditions for a new Admission and treatment of old evidence |
| OIDC / Local restart | Exact route back through Base |
| Admission / Ceremony expiry | Exact continuation and restart eligibility |
| FK immutability | Concrete database and Rails enforcement mechanisms |
| Legacy backfill | Migration of existing Flows without sufficient proof |
| `ON DELETE` | `RESTRICT`, `CASCADE`, or another policy |
| Purger | Binding and Flow deletion order |
| Retention | Physical deletion deadlines and dependencies |
| D14 | Distributed Cancel / Switch / Supersession / Late Result coordination |

“Always acquire a new Admission after OTP issuance” is not Accepted. `ON DELETE RESTRICT` is a
candidate only, not Accepted. Existing retention constants or old FK deletion actions do not settle
these new relationship decisions. The accepted target of eventual mandatory binding does not
select an unsafe backfill or authorize destructive data repair.

## Relationships and tradeoffs

This is the E1 authority for APP/COM Flow ownership and cardinality, supplementing Sign In First.
The [declarative constraint decision](declarative-database-constraints-for-integrity-and-cardinality.md)
provides the database principle; it does not supply cross-row ownership or OLD/NEW immutability.
Historical lifecycle inventories remain revision-scoped; this ADR does not rewrite them or change
their storage contract. The [Base/Auth amendment](base-auth-ceremony-and-seven-rp-boundary.md#oidc-result-url-and-e1-amendment-2026-10-21)
separately records the accepted OIDC Result URL change.

One association avoids competing authorities and a status-scoped index permits history while
protecting concurrent creation. The cost is a later integrity migration, explicit stale-page and
evidence validation, and unresolved lifecycle/deletion coordination. No application test,
Migration, or acceptance gate was executed in this ADR-only consolidation.
