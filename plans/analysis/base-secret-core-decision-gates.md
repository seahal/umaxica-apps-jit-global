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

## Fixed business contracts and reused authorities

The following are decided requirements, not approval gates: unused saved Secrets
have no new short expiry; claim is irreversible; success requires the canonical
Ticket receipt; Passkey registration distributes 2/1/0 at A=0..18/19/20;
ordinary remaining counts 0 and 1 trigger no intervention; old values are not
migrated. Their implementation and acceptance tests remain independently reviewable.

`StepUpRequirement::DEFAULT_TTL` is the existing 15-minute scope/session-bound
freshness contract. `SignFlow.default_ttl` is the existing 15-minute admission and
signup/sign-in flow lifetime. Secret operations reuse these authorities and do not
extend either deadline. Writer timestamps and persisted expiry facts govern their
own database transitions. Chronicle uses the existing `security` retention policy;
its absence raises an operational error instead of creating policy during a request.
The explicit `app_secret:provision_audit_policy` task requires
`CHRONICLE_SECURITY_RETENTION_DAYS` and refuses to overwrite an existing policy
with different duration/permanence. Disposable execution verifies missing-policy
creation, same-value retry and mismatch refusal. The shared operational security
duration remains unapproved; the 365-day local verification value is a proposal,
not evidence of an accepted deployed security policy.

## New operational values awaiting approval

These are proposals, not silent production defaults. `ClientSecretLifetimesValue`
requires explicit positive integer configuration; isolated tests provide explicit
values. Missing values stop the dependent operation, not unrelated HTTP work.

| Setting / concern | Proposed value | Start and resend behavior | Expiry outcome and reason |
| --- | --- | --- | --- |
| `APP_SECRET_ISSUANCE_TTL_SECONDS` | 600 seconds | Starts at writer reservation time; fixed batch retries never extend it; actual deadline is no later than signup flow expiry or scoped Step-Up expiry | Reject stale presentation/confirmation, erase payload and retire unconfirmed candidates; ten minutes permits deliberate saving within existing 15-minute authority |
| One-display encrypted payload | Same issuance deadline; no independent extension | Created by explicit authorized preparation; presentation erases it; resend cannot restore it | Missing, undecryptable or expired payload never creates replacement unseen random values; keep a single reservation/authorization horizon |
| `APP_SECRET_PURGE_DELAY_SECONDS` | 86400 seconds | Starts at source terminal transition; retries preserve terminal facts | Physical collection also waits for terminal Chronicle delivery and durable continuation reconciliation; one day gives an operational retry window without making the credential reusable |
| `APP_SECRET_OUTBOX_RETENTION_SECONDS` | 604800 seconds | Starts at confirmed source delivery acknowledgment; delivery replay does not extend it | Undelivered events never qualify; delivered records may be collected only after dependent proof/purge references no longer need them; seven days provides delivery investigation time |
| Successful receipt collection: `APP_SECRET_PROOF_RETENTION_SECONDS` | Proposed 2592000 seconds (30 days), unapproved | Starts after the latest completed-flow/authorization acceptance deadline and terminal consumed/purged Chronicle facts; retries do not extend the persisted facts | Explicit positive configuration; Source credential must be absent, matching terminal Chronicle facts must exist, and holds prevent collection. Receipt operation and lifecycle connection are implemented; remaining failure/boundary coverage is incomplete |
| Issuance and other flow/proof collection | Separate dependency review still required | Unconfirmed retired allocations now use their explicit purge deadline; confirmed/omitted batches and remaining Ticket proofs are not collected yet | Never collect unresolved claims, live callbacks or pending purge dependencies; remaining implementation and unapproved operational values remain separate |

The issuance, payload and purge settings are separate from permanent credential
eligibility and Chronicle retention. Operational approval does not authorize
shared-database destructive application. Disposable DDL execution is authorized
and recorded separately; shared application remains a separate approval item.

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
