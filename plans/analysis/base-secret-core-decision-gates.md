# Remaining decision gates for Base, app Secret, and Core

Prepared on 2026-10-03 (UTC). This is decision support, not approval of new protocols
or a claim that every item below is currently blocking implementation.
Read with the [precedence ADR](../../adr/base-secret-core-contract-precedence.md).

## Decision record requirements

For each actual gate record the checked source/HEAD, runtime observation if any,
current accepted contract, dependent operation, smallest alternatives, recommendation,
residual risk, decision owner, and tests affected. Absence of evidence is not a value
to guess. Resolve only the dependent work; unrelated lanes remain independent.

| Gate | Evidence needed | Recommendation and decision boundary |
| --- | --- | --- |
| Issuance and presentation expiry | Current comparable flow settings, encrypted-payload retention, writer clock, replay/reveal policy | Adopt an equivalent documented contract only if ownership and threat conditions match. Otherwise set independent explicit values through an accepted decision. Do not borrow the old Emergency lifetime. |
| Step-Up freshness and scope | Current operation requirement, registration authorization, actor/session/transaction binding, proof consumption | Reuse an appropriate existing requirement. If none covers registration plus delivery, decide its scope rather than silently reuse unrelated proof. No numeric AAL substitute or signed-in bootstrap. |
| Claim/flow terminal timing | Ticket flow lock/expiry, canonical issuance commit, outstanding callback acceptance, same-operation receipt | Align terminal arbitration with the authority that can still commit login. Never expire a claim solely by elapsed time while late commit remains possible. No unclaim option. |
| Reconciliation evidence retention | Maximum supported flow/result acceptance, terminal audit delivery, legal holds and purge policy | Keep proof while any valid continuation needs it. Decide receipt retention separately from credential and audit retention. Do not erase evidence to resolve an unknown result. |
| Outbox retention | Undelivered/delivered distinction, deduplication horizon, audit policy, periodic recovery | Never delete undelivered outbox. Decide delivered-row cleanup so retry and diagnostic guarantees remain explicit. Queue retention is not audit retention. |
| Original-path return | Validated capture, session binding, forwarding, consumption, final location | If current mechanism supports only a default Dashboard, report that limit. Repair existing capture/consumption wiring if approved; a new return protocol needs a separate decision. |
| Access expiry versus invalid-cookie cleanup | Current resolver branches, RP pair cleanup, sanctioned refresh contract and browser call sequence | Preserve confirmed-invalid cleanup. Determine whether ordinary access expiry has an approved continuation route before changing cleanup or endpoint meaning. |
| Concurrent refresh and response loss | Writer locks, replay generation rules, old-token behavior, parent/RP relationships, logout race | Repair demonstrable wiring defects only. New grace window, credential-result storage or retry protocol remains BLOCKED pending explicit choice. |
| Destructive Secret DDL application | Exact old tables/columns/dependencies, real DB ownership, disposable connection, fresh/rebuild procedure, approved risk/recovery | Prepare reviewable app-only DDL. Execute only against confirmed disposable targets under the active task's authorization. Recovery rebuilds schema; it cannot recover discarded old secrets. |
| Dispatcher removal and routing cutover | Rails-owned public paths, deployed delivery configuration, rollback-compatible entrance | Keep removal reviewable and separate from externally controlled cutover. Do not add a proxy fallback or prematurely disable a live entrance. External changes remain out of scope. |

## Duration worksheet

Populate this worksheet from actual configuration and accepted decisions. Empty
cells here mean unconfirmed, not zero, Infinity, or a recommended number.

| Concern | Authority/clock to verify | Value and source | Acceptance boundary |
| --- | --- | --- | --- |
| Saved Secret usability | Credential fact owner; no newly imposed short expiry | Unconfirmed | Confirmed unused/unclaimed/unrevoked/undiscarded eligibility |
| Pending issuance/reservation | Capacity owner and DB clock | Unconfirmed | Before/equal/after expiry, jobs stopped, late confirmation |
| Encrypted delivery payload | Actual payload store and presentation transaction | Unconfirmed | Expiry/decryption loss does not activate unseen value |
| Step-Up freshness | Current requirement and proof authority | Unconfirmed | Before/equal/after; scope/session mismatch |
| Claim and sign-in continuation | Zenith acceptance plus Ticket flow authority | Unconfirmed | Terminal/commit exclusion and delayed callback |
| Credential physical reclamation | Retention owner and audit-delivery state | Unconfirmed | Early deletion denied; purge atomic with surviving outbox |
| Receipt/outbox cleanup | Each source owner and delivery/continuation horizon | Unconfirmed | No live proof or undelivered event loss |
| Chronicle retention | Existing audit policy and hold enforcement | Unconfirmed | Policy presence, hold, deduplication and allowed cleanup |

## Avoid false cross-DB atomicity

Zenith claim is authoritative even when Ticket fails. Ticket's durable commit receipt
establishes whether a normal session was committed; it does not restore credential
eligibility. Chronicle delivery confirms audit persistence; queue enqueue does not.
An implementation choosing a receipt/outbox representation must show each local
transaction's guarantees and the reconciliation path. Do not combine the databases
or introduce a generic distributed authentication framework to simplify the diagram.

## Readiness reporting

Report each resolved value/contract with its accepted source and each unresolved
item with its dependent operation. Review the three distinct axes: application
boundary, login continuation, and deployment readiness. A completed boundary lane
does not establish continuation or production routing; an unresolved refresh choice
does not prevent completing independent Base or Secret behavior.
