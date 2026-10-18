# OP/RP Separation — Acceptance Test Specification

> Archived snapshot, generation 0001 (originally `two.md`). Non-normative and not evidence; see
> [README](./README.md).

[Acceptance Test Supplements](./addenda.md#two-addenda)

Status: **baseline candidate: R1 detailed procedures design-reviewed by Sol; invariant,
release-regression, AR and preactivation registries defined. All runtime acceptance NOT_RUN. R2-R5
full unit procedures remain to be completed before execution.**

Baseline: local `feature`, HEAD `17903f7d121aa33efe29f2db9235c9aa5db4b001`, clean tracked/untracked
status at final-revision start, 2026-10-16. Current file inspection confirmed R1 omitted encoder
context, legitimate NULL-context Normal roots, current continuation/Step-Up test paths and shared
development credential/listener configuration. No Rails boot, application/DB/network/browser/restore
acceptance was run for this specification. After R1-WU01 began, scoped existing-suite runs were
recorded in `evidence/2026-10-16-r1-context-implementation-R1C1.md`; they are not Gate results, and
R1-WU01 is paused by the user pending the 2026-10-16 reviewer corrections.

## 1. Responsibility and Control

[one.md](./implementation-plan.md) defines what to implement. This document and approved Two Addenda
in [four.md](./addenda.md#two-addenda) define observable acceptance and its procedures. It does not
add unapproved implementation behavior. [three.md](./implementation-reports.md) holds actual
implementation reports; [five.md](./notes.md) is non-normative; `nine.md` is history.

R1 case authoring is complete below. The user granted I for R1-WU01 and D for R1 tests on the twenty
existing isolated databases identified by `tmp/acceptance-isolated-20261016w6n2.json`, with one
worker and fixture writes only, on 2026-10-16. Database creation, deletion, reconstruction,
migration, and ordinary development/test database changes remain excluded. Later the same day the
user approved the `one.md` section 1.2A model, which supersedes those limits: I covers all Work
Units and development/test databases are disposable under a standing D, with DatabaseSafety still
selecting the intended target. Execution results must be recorded separately below and in evidence.
R2-R5 have scoped security scenarios and gate definitions below, with remaining full unit procedures
completed before those units execute. A Gate entry is not evidence. An implementation unit cannot be
marked complete until its detailed criteria are approved/ready and all required actual acceptance is
PASS. A missing procedure remains NOT_RUN with reason `DETAIL_NOT_AUTHORED`; a contradictory
requirement is BLOCKED and reported.

## 2. Stable IDs and Status

| Entity                       | Format                                            | Rule                                                                          |
| ---------------------------- | ------------------------------------------------- | ----------------------------------------------------------------------------- |
| Work Unit                    | `R2-WU03`, `R4-WU02A`                             | Definition and dependency owner is `one.md`; never renumber an issued ID      |
| Unit Gate                    | `AT-R2-03`, `AT-R4-02A`                           | Exactly one primary Gate per Work Unit; additional cases do not change its ID |
| Release Gate                 | `AT-R2-REL`                                       | All required unit Gates plus standalone release and transition compatibility  |
| Test Case                    | `TC-R2-03-001`, `TC-R5-18A-001`, `TC-R1-REL-001`  | Assigned when authored; linked to unit Gate; retire with reason, never reuse  |
| Evidence                     | Existing `evidence/YYYY-MM-DD-topic-XXXX.md` file | Actual observed result only, full HEAD and dirty scope                        |
| Formal acceptance supplement | `ADD-TWO-0001`                                    | Registered and approved in `four.md`; links affected Gate/case/unit/report    |
| Implementation report        | `REP-YYYYMMDD-0001`                               | Registered in `three.md` during actual implementation                         |

Verification status is one of **PASS**, **FAIL**, **BLOCKED**, **NOT_RUN**, **NOT_APPLICABLE**.
NOT_APPLICABLE requires the exact release/cell/contract reason and cannot close an applicable
mandatory case. US runtime without an environment is NOT_RUN, not NOT_APPLICABLE; the client remains
part of the target architecture. `BLOCKED_EXTERNAL`, `DETAIL_NOT_AUTHORED`, `DATA_APPROVAL_MISSING`,
`ENVIRONMENT_UNAVAILABLE` and `OWNER_CONFLICT` are reasons, not new success states. Case-design
status is separate: NOT_AUTHORED / SCENARIO_DEFINED / DRAFT / REVIEWED. REVIEWED means static design
review, not user I/S/D/E approval or an execution result. Authorship, user approval, execution
result and release activation are separate facts.

PASS requires an actual observed expected result for the exact revision/environment/cell and all
required boundaries; a named test or source inspection cannot prove a runtime result. FAIL records
observed divergence. BLOCKED records a concrete prerequisite/decision. NOT_RUN records no execution.
Unexpected infrastructure failure is not a successful negative security test. A skipped test is not
PASS.

## 3. Gate Register and Traceability

The implementation packet and full requirements are in the matching `one.md` Work Unit. Summaries
here name verification scope, not a second implementation definition. R1 Gates have REVIEWED
procedures; other Gate rows show the current scenario/detail level. Every actual execution result is
NOT_RUN. Gate completion additionally requires all applicable release Invariants; prior release
evidence is not inherited.

<!-- BEGIN ACCEPTANCE UNIT REGISTER -->

| Work Unit | Gate      | Verification scope                                                                                                                                                                                                  | Case design      | Verification |
| --------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- | ------------ |
| R1-WU01   | AT-R1-01  | Context continuity, missing/unknown handling, no Step-Up promotion                                                                                                                                                  | REVIEWED         | NOT_RUN      |
| R1-WU02   | AT-R1-02  | Independent current-name/client release behavior and evidence                                                                                                                                                       | REVIEWED         | NOT_RUN      |
| R2-WU01   | AT-R2-01  | DB-enforced Waiting lease and legal lifecycle transitions                                                                                                                                                           | SCENARIO_DEFINED | NOT_RUN      |
| R2-WU02   | AT-R2-02  | N limits, occupied-slot refusal, existing-session preservation                                                                                                                                                      | SCENARIO_DEFINED | NOT_RUN      |
| R2-WU03   | AT-R2-03  | Purge/promotion/cancel/expiry, first-commit competition, crash outcome                                                                                                                                              | SCENARIO_DEFINED | NOT_RUN      |
| R2-WU04   | AT-R2-04  | ACTIVE-only every authentication path; Waiting/103 MFA denial                                                                                                                                                       | SCENARIO_DEFINED | NOT_RUN      |
| R2-WU05   | AT-R2-05  | Three-realm routed behavior, diagrams/docs match delivered state                                                                                                                                                    | SCENARIO_DEFINED | NOT_RUN      |
| R3-WU01   | AT-R3-01  | Historical move hashes, versions/classes and dump preservation                                                                                                                                                      | SCENARIO_DEFINED | NOT_RUN      |
| R3-WU02   | AT-R3-02  | Exact logical/physical/environment/reader configuration mapping                                                                                                                                                     | SCENARIO_DEFINED | NOT_RUN      |
| R3-WU03   | AT-R3-03  | Record inheritance/Autoload and correct connection ownership                                                                                                                                                        | SCENARIO_DEFINED | NOT_RUN      |
| R3-WU04   | AT-R3-04  | Grant forward rename, FK/Sequence/Family/receipt preservation                                                                                                                                                       | SCENARIO_DEFINED | NOT_RUN      |
| R3-WU05   | AT-R3-05  | Runtime/serialized consumers and retained history readability                                                                                                                                                       | SCENARIO_DEFINED | NOT_RUN      |
| R3-WU06   | AT-R3-06  | DatabaseSafety, real isolated tooling, no protected-target mutation                                                                                                                                                 | SCENARIO_DEFINED | NOT_RUN      |
| R3-WU07   | AT-R3-07  | Approved isolated clean/upgrade/restore and coherent R3 boot                                                                                                                                                        | SCENARIO_DEFINED | NOT_RUN      |
| R3-WU08   | AT-R3-08  | Actual approved dev/test cutover and security-state reconciliation                                                                                                                                                  | SCENARIO_DEFINED | NOT_RUN      |
| R4-WU01   | AT-R4-01  | Exact 11-ASCII catalog, namespaces, deployment binding and keys                                                                                                                                                     | SCENARIO_DEFINED | NOT_RUN      |
| R4-WU02   | AT-R4-02  | All in-repo callers/URIs and read-only Jump/Edge preflight                                                                                                                                                          | SCENARIO_DEFINED | NOT_RUN      |
| R4-WU02A  | AT-R4-02A | JP multi-host development binding and executable R4 environment; US static/NOT_RUN                                                                                                                                  | SCENARIO_DEFINED | NOT_RUN      |
| R4-WU03   | AT-R4-03  | Approved cutoff disables all old credentials without data loss                                                                                                                                                      | SCENARIO_DEFINED | NOT_RUN      |
| R4-WU04   | AT-R4-04  | Independent target-client flows under current shared implementation                                                                                                                                                 | SCENARIO_DEFINED | NOT_RUN      |
| R5-WU01   | AT-R5-01  | Generated owner/action inventory, canonical policy, JP runtime/US deferral scope and confirmation that the Accepted (2026-10-16) successor logout ADR still matches the design before conflicting R5 implementation | SCENARIO_DEFINED | NOT_RUN      |
| R5-WU02   | AT-R5-02  | Epoch/flow/outbox ownership, schema constraints and transitions                                                                                                                                                     | SCENARIO_DEFINED | NOT_RUN      |
| R5-WU03   | AT-R5-03  | Distinct cell schemas/Records, manifests, roles and local uniqueness                                                                                                                                                | SCENARIO_DEFINED | NOT_RUN      |
| R5-WU03A  | AT-R5-03A | Actual role/file/master-key/DB/assertion-key/worker isolation                                                                                                                                                       | SCENARIO_DEFINED | NOT_RUN      |
| R5-WU04   | AT-R5-04  | Public JWKS/type/scope verification and signer-secret isolation                                                                                                                                                     | SCENARIO_DEFINED | NOT_RUN      |
| R5-WU05   | AT-R5-05  | HTTPS outcomes, self-call receiving capacity, cookie retention                                                                                                                                                      | SCENARIO_DEFINED | NOT_RUN      |
| R5-WU06   | AT-R5-06  | Stop/issuance/redelivery ordering and non-atomic recovery                                                                                                                                                           | SCENARIO_DEFINED | NOT_RUN      |
| R5-WU07   | AT-R5-07  | JWT AND local-session, one-time callback/tombstone and expiry                                                                                                                                                       | SCENARIO_DEFINED | NOT_RUN      |
| R5-WU08   | AT-R5-08  | HTTP rotation/receipt/replay/Valkey/install and deadline behavior                                                                                                                                                   | SCENARIO_DEFINED | NOT_RUN      |
| R5-WU09   | AT-R5-09  | OP revoke/outbox atomicity and irrevocable commit success                                                                                                                                                           | SCENARIO_DEFINED | NOT_RUN      |
| R5-WU10   | AT-R5-10  | Durable delivery, local atomic receipt/tombstone, true 200 semantics                                                                                                                                                | SCENARIO_DEFINED | NOT_RUN      |
| R5-WU11   | AT-R5-11  | Current Tech capability, exact subject/client/realm and fail closed                                                                                                                                                 | SCENARIO_DEFINED | NOT_RUN      |
| R5-WU12   | AT-R5-12  | Existing IAM/Support/Enforcement canonical policy/target separation                                                                                                                                                 | SCENARIO_DEFINED | NOT_RUN      |
| R5-WU13   | AT-R5-13  | Publishing canonical policy/writer/constraint and outcome handling                                                                                                                                                  | SCENARIO_DEFINED | NOT_RUN      |
| R5-WU14   | AT-R5-14  | Existing Avatar subject/collective/ownership/lifecycle boundary                                                                                                                                                     | SCENARIO_DEFINED | NOT_RUN      |
| R5-WU15   | AT-R5-15  | Organization canonical policy and unsupported-operation denial                                                                                                                                                      | SCENARIO_DEFINED | NOT_RUN      |
| R5-WU16   | AT-R5-16  | DBSC/fallback, Base one-time completion and matching-session purge                                                                                                                                                  | SCENARIO_DEFINED | NOT_RUN      |
| R5-WU17   | AT-R5-17  | Twelve in-repo logical RP implementations, JP12 runtime; US static/NOT_RUN                                                                                                                                          | SCENARIO_DEFINED | NOT_RUN      |
| R5-WU18   | AT-R5-18  | Legacy removal, Org-only Standby names and current contract docs                                                                                                                                                    | SCENARIO_DEFINED | NOT_RUN      |
| R5-WU18A  | AT-R5-18A | Mandatory isolated adversarial and restore proof before any activation                                                                                                                                              | SCENARIO_DEFINED | NOT_RUN      |
| R5-WU19   | AT-R5-19  | Common closed cutover plus exact-cell staged activation and latest-state preservation                                                                                                                               | SCENARIO_DEFINED | NOT_RUN      |
| R5-WU20   | AT-R5-20  | Final attacks/outages/restore/actual cell and external-contract evidence                                                                                                                                            | SCENARIO_DEFINED | NOT_RUN      |

<!-- END ACCEPTANCE UNIT REGISTER -->

| Release Gate | Prerequisites / coverage to detail                                                                                             | Case design      | Verification |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------ | ---------------- | ------------ |
| AT-R1-REL    | AT-R1-01/02 cases plus applicable Invariant regression; independent current-name/client boot                                   | REVIEWED         | NOT_RUN      |
| AT-R2-REL    | AT-R2-01 through 05; three realms and unchanged R1 context/cooldown                                                            | SCENARIO_DEFINED | NOT_RUN      |
| AT-R3-REL    | AT-R3-01 through 08; renamed current-profile implementation independently bootable                                             | SCENARIO_DEFINED | NOT_RUN      |
| AT-R4-REL    | AT-R4-01/02/02A/03/04; WW5+JP7 work before R5; US runtime separately NOT_RUN                                                   | SCENARIO_DEFINED | NOT_RUN      |
| AT-R5-REL    | AT-R5-01 through 20 including 03A/18A; JP common and cell scopes; actual role/domain boundaries; US runtime separately NOT_RUN | SCENARIO_DEFINED | NOT_RUN      |

### 3.1 Trace chain

`Decision / Security Contract -> INV -> Work Unit -> Gate -> TC -> current revision/environment/cell Evidence`.
Also `AR -> INV -> Gate -> TC`. An Invariant may cover multiple units and every applicable later
release re-executes it.

Approved One Addenda that change implementation must identify affected Gates; corresponding Two
Addenda supply any additional case/acceptance change. A report in `three.md` does not silently
change this chain. New units receive fresh stable IDs and explicit dependency/acceptance entries
rather than renumbering existing ones. Historical IW/U/CID mapping belongs to `one.md`, not a second
independently managed map here.

## 4. Case Template (Not an Authored Case)

Copy this template only when detailed design begins. Angle-bracket fields are placeholders, not
actual statuses/results.

```text
Case ID: <TC-Rx-nn-nnn>
Gate / Release / Work Unit: <IDs>
Implementation contract: <one.md section / approved ADD-ONE ID>
Purpose and public observable boundary: <behavior>
Case design / approval state: <DRAFT or REVIEWED, source/date>
Scope: <realm, logical RP, concrete client/cell, actor/resource class>
Threat / security invariant: <failure this case can falsify>
Environment and safe target identity: <manifest, role, isolation>
Required approvals: <I/S/D/E as applicable; explicit references>
Preconditions: <known committed state, clocks, keys, generation>
Input partitions and boundary values: <valid, missing, empty, wrong type/scope>
Concurrency schedule / fault injection: <independent connections and barriers>
Procedure: <specific public calls / approved non-destructive probe>
Expected response and persistent outcomes: <including what remains unchanged>
Observed response and persistent outcomes: <actual observations only>
Commit / indeterminate-outcome interpretation: <explicit owner>
Recovery / cleanup: <preserve security and protected data>
Actual test/probe and command: <exact file/test or approved probe>
Execution HEAD and dirty worktree scope: <full hash and relevant changes>
Evidence reference: <factual evidence record>
Verification: <PASS / FAIL / BLOCKED / NOT_RUN>
Reason / remaining limitation: <explicit>
Related Report / Addendum: <IDs or none>
```

## 5. Detailed-Design Coverage Backlog

The following are authoring categories, not completed test cases or independent new requirements.
Expected behavior comes from the referenced implementation definition and approved supplements.

- R1: initial/Code/Refresh/reissue alternative-context continuity, missing/unknown context and
  ordinary-policy/Step-Up separation; absolute lifetime boundaries.
- R2: all three N values; N-1/N/occupied slot; same-flow retry versus new attempt; DB uniqueness on
  independent connections; purge/no-purge finalization, first-commit competition, cancel/expiry and
  crash-after-commit; existing sessions/audit/cooldown unchanged on refusal; every MFA-reset
  route/verb; 103/unknown/expired/revoked from root/API/Browser RP/Code/Refresh/UserInfo/Step-Up
  paths.
- R3: migration byte/version/class equality; clean construction from the full migration history
  (preserved-snapshot upgrade NOT_APPLICABLE, `NO_PRESERVED_ENVIRONMENT`);
  FK/constraint/Sequence/default/ledger equality; old consumer/serialized payload behavior; actual
  isolated/parallel manifest refusal; drop-and-rebuild under target names. Environment construction
  is demonstrated by real approved execution/evidence, not new setup-subject tests.
- R4: 10/11/12-character and non-ASCII/unknown region/placeholder partitions;
  issuer/audience/assertion namespace/client/URI/region confusion; in-repository Core/Warp/Palm
  target flow; complete old-credential cutoff and unchanged business/history; Jump/Edge preflight
  and authorized runtime evidence.
- R5: JWT/session conjunction, public JWKS cache/rotation, exact type/client/realm and signing-key
  isolation; callback/logout and Refresh/logout races including unknown sid; five-second receipt
  before/at/after boundary, commit-response loss, replay and Valkey failure; actor stop versus every
  issuer/redelivery and three-owner crash recovery; current Tech revoke; domain-owner current
  policies/resource/tenant/approval constraints; DBSC/fallback; OP commit/no-ACK completion, receipt
  consumption and stale cookie purge; all configured cell wiring and actual role credential denials.
- All releases: standalone boot and earlier contract compatibility; DatabaseSafety target identity
  (development/test contents are disposable per `one.md` 1.2A); source/target identity and no
  unintended external writes; meaningful expected failure rather than an infrastructure failure
  counted as denial; actual outcome recovery after a new security write.

## 6. Environment, Fault and Evidence Rules

Select environments positively from the approved exact-target manifest. Development/test database
contents are disposable under the `one.md` 1.2A standing D; DatabaseSafety must still prove each
command reaches only its intended local development/test target. Production, remote/managed and
unlisted targets are never reset. Future production configuration is not proof of a current
deployment. No actual production test fleet is assumed. Boot/tasks that prepare a DB require the
same safety/authorization checks as explicit migration.

Use public controller/protocol/operation interfaces for behavioral tests; no private reflection or
test-only accessors. Concurrency requires committed independent connections and deterministic
barriers, not arbitrary sleeps. Boundary tests cover nearest reachable values below/at/above limits
and relevant missing/empty/wrong-type states. Use shared deep protocol cases plus per-cell wiring,
not nineteen copies of every common attack.

Fault suites must specify OP/Zenith/RP/Queue/Valkey/network/JWKS/domain outage, response loss,
timing and restoration behavior. Numeric load/deadline/pool thresholds must be declared before
measurements using actual configured capacity/SLO information. Do not invent measured
latency/throughput or use localhost results to claim JP/US performance. Extra OP restriction-call
tests are not required because the retired Restricted subsystem is not part of the target design.

Evidence follows `AGENTS.md`: flat `.md` files, full commit hash, relevant dirty scope, exact
command/identity, expected and observed result, limitations and unrun scope.
Credentials/tokens/cookies, raw DB dumps, large logs or binary artifacts are excluded. A snapshot
file is not restore evidence; an HTTP 200 is not proof of persistence unless the case observes the
required commit. Report failed/blocked/not-run results truthfully.

## 7. Scope and Execution Readiness

R1 detailed procedures follow and are ready for an explicitly authorized R1 handoff. R2-R5 security
scenario coverage is not a claim that every business/environment Gate has a fully authored
procedure. Complete those detailed packets before execution and preserve stable IDs. Before formal
baseline acceptance, integrate these corrections here; after baseline acceptance, approved changes
use Two Addenda in four.md. New contradictory requirements stop the affected scope and are reported.

The default runtime set is JP development: WW5 plus JP7, twelve local stores at R5. R4 still uses
current shared authority. Static US binding/catalog negatives need no US DB. Actual US runtime
remains NOT_RUN with US_ENVIRONMENT_NOT_PROVISIONED; create an independent environment only on a
later approved need. Current production does not exist. Per-cell result keys are (HEAD, release,
Gate, case, realm, client, role, environment).

## 8. Security Invariant Registry

The contract statement is owned by one.md/the cited existing contract; this registry assigns
verification identity, scope and regression obligations. All results are NOT_RUN. Introduction is
the first release where the stated target mechanism is mandatory; existing subsets are tested
earlier where explicitly noted. Conditional non-applicability always has a per-case reason. Do not
make an introduced guarantee NOT_APPLICABLE because its implementation is missing.

| Invariant | Decision / contract source and observable guarantee                                                                                                                            | Applicable release scope                                                                                                                                                                                                 | Primary Work Units / Gates                                            | Verification cases                                                                                             |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| INV-001   | R1 context/Org alternative-auth contract: no Standby-to-Normal continuation; no Step-Up; legitimate NULL-Normal roots remain usable                                            | R1-R5, using each release's current literal/profile                                                                                                                                                                      | R1-WU01; AT-R1-01, AT-R5-18                                           | TC-R1-01-001, TC-R1-01-002, TC-R1-01-003, TC-R1-01-004, TC-R1-01-005, TC-R1-01-006, TC-R1-01-008, TC-R1-01-011 |
| INV-002   | P-8: F<=N and one actor Waiting lease; existing Full Access preserved on additional refusal                                                                                    | R2-R5                                                                                                                                                                                                                    | R2-WU01/02; AT-R2-01/02                                               | TC-R2-02-001                                                                                                   |
| INV-003   | P-8/M-2: Waiting cannot authenticate normally, enroll an RP, Step-Up or reach any MFA-reset path; Org Standby cannot perform an MFA-reset mutation because it requires Step-Up | R2-R5                                                                                                                                                                                                                    | R2-WU03/04; AT-R2-03/04                                               | TC-R2-04-001                                                                                                   |
| INV-004   | Retired token status 103, expired/revoked/unknown status never authenticates                                                                                                   | R2-R5, recheck R5 new verifier/resolver                                                                                                                                                                                  | R2-WU04, R5-WU07; AT-R2-04, AT-R5-07                                  | TC-R2-04-001, TC-R5-07-004                                                                                     |
| INV-005   | Refresh/revocation contract: revoked credential/family cannot mint or recover authority; normal rotation/replay remains                                                        | Existing current mechanism R1-R4; new HTTP/epoch mechanism R5                                                                                                                                                            | R1-WU02, R5-WU06/08/09; AT-R1-02, AT-R5-06/08/09                      | TC-R1-02-004, TC-R5-08-001, TC-R5-09-001                                                                       |
| INV-006   | Local callback/Refresh cannot recreate a logged-out sid, including unknown sid before callback                                                                                 | R5; local stores absent R1-R4                                                                                                                                                                                            | R5-WU07/10; AT-R5-07/10                                               | TC-R5-07-002, TC-R5-07-003, TC-R5-10-001                                                                       |
| INV-007   | H-4: RP has no readable/decryptable OP/sibling secret or OP/Zenith/sibling DB credential                                                                                       | R5, not an R4 shared-process requirement                                                                                                                                                                                 | R5-WU03A/04; AT-R5-03A/04                                             | TC-R5-03A-001                                                                                                  |
| INV-008   | Strict issuer/type/audience/client/realm: current profile until R4, exact target profile thereafter; wrong-region never selects a client                                       | Current client/realm/type R1-R3; target JP/US metadata R4-R5                                                                                                                                                             | R1-WU01, R4-WU01/02A, R5-WU04; AT-R1-01, AT-R4-01/02A, AT-R5-04       | TC-R1-01-010, TC-R4-02A-001, TC-R5-04-001                                                                      |
| INV-009   | Existing ActionPolicy denial and current resource/tenant/approval/ownership constraints preserved                                                                              | R1-R5; current shared then domain-owner mechanism                                                                                                                                                                        | R1-WU01, R5-WU11/12/13/14/15; AT-R1-01, AT-R5-11/12/13/14/15          | TC-R1-01-012, TC-R5-11-001, TC-R5-12-001, TC-R5-13-001, TC-R5-14-001, TC-R5-15-001                             |
| INV-010   | D-05: recovery never rolls back committed revocation/Family/Generation/replay/epoch/tombstone state                                                                            | Conditional whenever recovery is performed. Restore rehearsal is NOT_APPLICABLE (`NO_PRESERVED_ENVIRONMENT`) while all environments are disposable development/test (`one.md` 1.2A); the rule stays a design requirement | R3-WU07/08, R4-WU03, R5-WU18A/19; AT-R3-07/08, AT-R4-03, AT-R5-18A/19 | TC-R3-07-001, TC-R4-03-001, TC-R5-18A-001                                                                      |
| INV-011   | RP authentication = valid Access JWT AND live correctly bound writer-consistent local session                                                                                  | R5                                                                                                                                                                                                                       | R5-WU07; AT-R5-07                                                     | TC-R5-07-001, TC-R5-07-004                                                                                     |
| INV-012   | Code/callback State, Nonce, PKCE, browser/client/subject binding and single use                                                                                                | Current flow R1-R4; local one-time transaction additionally R5                                                                                                                                                           | R1-WU01, R5-WU07; AT-R1-01, AT-R5-07                                  | TC-R1-01-010, TC-R5-07-001                                                                                     |
| INV-013   | Original five-second Delivery Receipt; redelivery does not rotate/extend exp; replay outside contract remains rejected                                                         | Existing delivery R1-R4; HTTP query/install additionally R5                                                                                                                                                              | R1-WU02, R5-WU08; AT-R1-02, AT-R5-08                                  | TC-R1-02-004, TC-R5-08-001                                                                                     |
| INV-014   | D-08: OP revoke+outbox commit establishes logout; no ACK/purge dependence or OP resurrection                                                                                   | R5 target Flow/Outbox contract; preserve existing authority-first behavior earlier via INV-005                                                                                                                           | R5-WU09/10/16; AT-R5-09/10/16                                         | TC-R5-09-001, TC-R5-10-001, TC-R5-16-001                                                                       |
| INV-015   | H-1: purge/root/parent-finalization/Waiting release are one OP commit; no early RESOLVED gap                                                                                   | R2-R5                                                                                                                                                                                                                    | R2-WU03; AT-R2-03                                                     | TC-R2-03-001                                                                                                   |
| INV-016   | Authentication Authority does not become universal Business Writer; RP has no canonical-domain SQL                                                                             | R5                                                                                                                                                                                                                       | R5-WU01/12/13/14/15/17; AT-R5-01/12/13/14/15/17                       | TC-R5-12-001, TC-R5-13-001, TC-R5-14-001, TC-R5-15-001, TC-R5-17-001                                           |
| INV-017   | D-05/DatabaseSafety: migration history byte-preserved, exact environment/role identity before writes; development/test contents disposable (`one.md` 1.2A)                     | Existing safety R1-R5; rename/Sequence/history checks R3 onward                                                                                                                                                          | Each release; AT-R1-02, AT-R3-01/06/07/08, AT-R5-03/19                | TC-R1-02-006, TC-R3-07-001, TC-R5-17-001                                                                       |
| INV-018   | D-07: old authentication profile/keys/continuations cannot recover after cutoff, including unchanged Base IDs                                                                  | R4-R5                                                                                                                                                                                                                    | R4-WU03, R5-WU19; AT-R4-03, AT-R5-19                                  | TC-R4-03-001, TC-R5-19-001                                                                                     |
| INV-019   | HTTPS failures preserve cookies but never permit expired access; same-process self-calls have bounded reserved capacity                                                        | R5 target protocol                                                                                                                                                                                                       | R5-WU05/08; AT-R5-05/08                                               | TC-R5-05-001, TC-R5-08-001                                                                                     |
| INV-020   | P-9/M-2: no reservation, auto-submit or GET issuance; explicit bound POST rechecks and first final commit wins                                                                 | R2-R5                                                                                                                                                                                                                    | R2-WU03; AT-R2-03                                                     | TC-R2-03-001                                                                                                   |
| INV-021   | D-02: actor stop vs all issuers/redelivery ordered; Zenith/OP commits separate; delayed event cannot kill new epoch                                                            | R5 epoch guarantee; earlier existing stopped-parent behavior retained by INV-005                                                                                                                                         | R5-WU06; AT-R5-06                                                     | TC-R5-06-001                                                                                                   |
| INV-022   | H-2/H-3: JP12 runnable scope, WW remains WW; trusted region; US metadata/static validation is not US runtime PASS                                                              | R4-R5; R5 adds distinct cell DBs                                                                                                                                                                                         | R4-WU02A, R5-WU03/17; AT-R4-02A, AT-R5-03/17                          | TC-R4-02A-001, TC-R5-17-001                                                                                    |
| INV-023   | Typed event replay+local invalidation atomic; receiver 200 means commit, Queue/ACK loss retryable                                                                              | R5                                                                                                                                                                                                                       | R5-WU10; AT-R5-10                                                     | TC-R5-10-001                                                                                                   |
| INV-024   | Approval, invariant/case/evidence trace and required diagrams/docs remain truthful; no fake PASS                                                                               | R1-R5 document/release control                                                                                                                                                                                           | All closure units/Gates; AT-R1-02 and AT-R*-REL                       | TC-R1-02-006, TC-R1-REL-001, TC-REG-001                                                                        |

Existing source/test anchors (inspected, not executed):
`test/values/authentication_context_value_test.rb`,
`test/concerns/auth/org_emergency_session_continuity_test.rb`,
`test/policies/emergency_authentication_context_policy_test.rb`,
`test/controllers/auth/org/verification/emergency_step_up_prohibition_test.rb`,
`test/unit/security/org_emergency_access_invariants_test.rb`,
`test/controllers/base/oauth_token_exchange_e1_test.rb`,
`test/services/oidc_token_exchange_boundary_test.rb`,
`test/services/oidc_refresh_token_coalescing_test.rb`,
`test/unit/oidc_refresh_delivery_receipt_test.rb`, existing
session-limit/DatabaseSafety/ActionPolicy suites. A source test's presence is not proof it covers
all corresponding rows.

## 9. Adversarial Review Traceability

AR IDs stay in one.md. Here their countermeasure validation is linked to invariants/Gates/cases. All
countermeasures are DESIGN_DEFINED; programme implementation and verification remain NOT_RUN,
including current source defects. Current source observations are distinguished in one.md
section 12. Each case listed below has a procedure or scenario definition in this document.

| AR    | Invariants                | Acceptance Gates        | Cases                                                                |
| ----- | ------------------------- | ----------------------- | -------------------------------------------------------------------- |
| AR-01 | INV-001, INV-008          | AT-R1-01                | TC-R1-01-002, TC-R1-01-003, TC-R1-01-006, TC-R1-01-008, TC-R1-01-011 |
| AR-02 | INV-002, INV-015          | AT-R2-02/03             | TC-R2-02-001, TC-R2-03-001                                           |
| AR-03 | INV-003, INV-004          | AT-R2-04, AT-R5-07      | TC-R2-04-001, TC-R5-07-004                                           |
| AR-04 | INV-015, INV-020          | AT-R2-03                | TC-R2-03-001                                                         |
| AR-05 | INV-020                   | AT-R2-03                | TC-R2-03-001                                                         |
| AR-06 | INV-017                   | AT-R3-07/08             | TC-R3-07-001                                                         |
| AR-07 | INV-005, INV-010          | AT-R3-07, AT-R5-18A     | TC-R3-07-001, TC-R5-18A-001                                          |
| AR-08 | INV-008, INV-018, INV-022 | AT-R4-02A/03, AT-R5-17  | TC-R4-02A-001, TC-R4-03-001, TC-R5-17-001                            |
| AR-09 | INV-007, INV-008, INV-022 | AT-R4-02A, AT-R5-03A/04 | TC-R4-02A-001, TC-R5-03A-001, TC-R5-04-001                           |
| AR-10 | INV-006, INV-011, INV-012 | AT-R5-07/10             | TC-R5-07-001, TC-R5-07-002, TC-R5-07-003                             |
| AR-11 | INV-005, INV-021          | AT-R5-06                | TC-R5-06-001                                                         |
| AR-12 | INV-013, INV-019          | AT-R5-05/08             | TC-R5-05-001, TC-R5-08-001                                           |
| AR-13 | INV-007, INV-009, INV-016 | AT-R5-03A/12/13         | TC-R5-03A-001, TC-R5-12-001, TC-R5-13-001                            |
| AR-14 | INV-009, INV-016          | AT-R5-12/13/14/15       | TC-R5-12-001, TC-R5-13-001, TC-R5-14-001, TC-R5-15-001               |
| AR-15 | INV-006, INV-014, INV-023 | AT-R5-09/10/16          | TC-R5-09-001, TC-R5-10-001, TC-R5-16-001                             |
| AR-16 | INV-018, INV-022          | AT-R4-02A, AT-R5-17     | TC-R4-02A-001, TC-R5-17-001                                          |
| AR-17 | INV-017, INV-024          | AT-R3-07, AT-R5-17      | TC-R3-07-001, TC-R5-17-001                                           |
| AR-18 | INV-024                   | AT-R1-02, AT-R*-REL     | TC-R1-02-006, TC-REG-001                                             |
| AR-19 | INV-006                   | AT-R5-07/10             | TC-R5-07-002, TC-R5-10-001                                           |
| AR-20 | INV-007                   | AT-R5-03A, AT-R5-18A    | TC-R5-03A-001, TC-R5-18A-001                                         |

PKCE/State/Nonce/client mismatches are AR-10 subscenarios; unchanged Base IDs at cutoff are
AR-08/09; object/tenant bypasses are AR-13/14; callback/Refresh/logout schedules are AR-10/15/19;
effective master-key exposure is AR-20; restored revocations are AR-07. These require no new AR
numbers.

## 10. Release Regression and Scope Disposition

### TC-REG-001 — Current-Revision Invariant Closure

Design: REVIEWED. Execution: NOT_RUN. For every release Gate, execute each applicable invariant's
concrete cases against that release's actual HEAD, profile, roles and cells, including
previous-release suites adapted only to approved changed interfaces. Record a new
observation/evidence set; an earlier PASS is background, not a new result. Reject a release if any
applicable invariant is FAIL, BLOCKED or NOT_RUN. NOT_APPLICABLE requires the exact mechanism/scope
reason below and cannot hide an unimplemented introduced control. New cases needed by changed
implementations are authored before closure.

| Release Gate | Mandatory invariant set                                                                                                                        | Applicability notes / exact exclusions                                                                                                                                                                                                                           |
| ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| AT-R1-REL    | INV-001, INV-005, INV-008, INV-009, INV-012, INV-013, INV-017, INV-024                                                                         | INV-008/012/013 use current clients/shared flow/receipt. R2 Waiting/103 changes and R5 local roles/outbox/epochs are NOT_APPLICABLE because not introduced. INV-010 is conditional: no restore in the R1 plan; if any restore is performed it becomes mandatory. |
| AT-R2-REL    | R1 set plus INV-002/003/004/015/020                                                                                                            | Re-run context and current flow/Refresh after new session writers. INV-010 mandatory for any actual restoration; R3 mechanical-name and R5 local mechanisms not yet present.                                                                                     |
| AT-R3-REL    | R2 set plus INV-017 full rename-by-rebuild/history/Sequence/role checks; INV-010 restore rehearsal NOT_APPLICABLE (`NO_PRESERVED_ENVIRONMENT`) | Re-run R1/R2 on new Records and physical names with current pre-R4 client IDs. No new R5 store/secret-role requirement.                                                                                                                                          |
| AT-R4-REL    | R3 set plus INV-018/022; INV-008 includes exact target profiles, JP/US negatives                                                               | WW5+JP7 actual environment; US metadata/static cases run, US runtime remains NOT_RUN. Do not count an unconfigured US runtime as a required JP environment PASS.                                                                                                 |
| AT-R5-REL    | INV-001 through INV-024, all introduced mechanisms and R1-R4 regression                                                                        | Re-run 103/MFA denial through the new local verifier, context through HTTPS, receipt through HTTP, and actual role isolation after the current activation. US actual runtime stays NOT_RUN outside the declared JP release scope.                                |

These sets are cumulative requirements, not cumulative evidence. Per-case applicability rows
distinguish the existing mechanism from its future replacement. No previous success is used to waive
checking a new verifier or migration. Domain changes maintain their existing ActionPolicy tests even
if the current implementation uses different authentication internals.

Every release closes its own current docs/diagram/inventory/checklist reconciliation, including R3
and R4. Historical records stay historical. `three.md` is actual implementation reporting; current
static audit stays in `five.md`. A new approved requirement has exact `four.md` traceability after
baseline acceptance.

## 11. R1 Detailed Acceptance Procedures

### 11.1 Scope, real entry points and safe setup

These definitions are REVIEWED by Sol for implementation handoff, execution **NOT_RUN**. They are
executable specifications for future tests/probes, not test code added in this cycle. R1 changes no
Client ID, schema, status-103 lifecycle, environment architecture or Org naming. Current alternative
context is the wire literal `emergency`, semantically Standby.

Before execution, record I and the exact safe test-target authorization, effective
DatabaseSafety/catalog manifest, full HEAD/dirty scope and existing keys/providers available. Run
only in the authorized isolated/safe existing test scope; never reset an existing data-bearing
dev/test DB to prepare fixtures. Existing test setup performs writes, so permission to inspect files
is not permission to run it. Missing prerequisites mean BLOCKED with reason, not skipped/PASS. Do
not print credentials, tokens, cookie values, claims containing personal identifiers or private
keys.

Create independent fixture-owned active actors and usable browser roots through existing public
establishment helpers/interfaces. Define N0 = Org root whose durable context is SQL NULL (existing
legitimate Normal), N1 = explicit `normal`, S = explicit `emergency`; app/com have no context column
and are Normal by contract. Keep ordinary status/lifetime/browser/actor validity identical between
cohorts. Use frozen test time T, finite root/Grant absolute expiry, current registry client (primary
`tech-org` plus current `base-org-ww` where appropriate), exact issuer/redirect, PKCE S256,
Nonce/State and real test assertion credentials. R4 names such as `tech-org-ww` must not be required
for R1.

Use public boundaries:

- `OidcAuthorizeCoordinator.call` with current valid request/root, then realm
  `Base::{App,Com,Org}::Oauth::TokensController#create` (`base_<realm>_oauth_token_url`) or public
  `OidcTokenExchangeCoordinator.call` for the same actual transaction. Real Code redemption/Refresh
  must exercise production encoding, not a stubbed encoder/result.
- Browser OIDC callback/protected controller and existing policy/Step-Up public operations for token
  acceptance. Verify signature/type/issuer/audience with the current verifier, then assert the
  literal claim independently. Merely `JWT.decode(..., false)` is insufficient acceptance.
- Public Base OAuth authorization resume: GET `AuthorizationsController#show` renders the
  receiver-local confirmation form; the CSRF-protected POST to `create` performs the bound
  finalization/reissue. Use the valid already-finalized transaction for that reissue branch.
  Reproduce its real completed-root/lost-browser-response state through public flow steps; do not
  invoke `finalize_authorization_transaction!` or `encode_*` through reflection. GET alone issues no
  replacement root credential.
- Existing `AuthenticationContextValue.for`, policy `apply`, real Base Step-Up admission/HTTP flow,
  and current parent/family queries for their public contracts. No new `send`, private wrapper,
  visibility widening or fake authorization to manufacture a passing test. Existing old helper
  deviations are not permission to add another one.

Observe before/after root identity/count/context/expiry/cooldown, Grant Family/Generation/digest
identity (safe fingerprints only), replay/receipt state, browser authentication outcome, policy
denial and relevant audit count. The required preserved quantity is stable browser/root authority;
legitimate token generation rotation follows its current contract. No new LOGGED_IN/root is allowed
from Code exchange/Refresh/reissue. ID Token `authn_ctx` is not invented: retain its current
audience/nonce/issuer/sid/`acr/amr` contract while asserting Access context.

Existing tests to adapt or retain:

| Current file (exists)                                                                                                        | Evidence it provides / limitation                                                                                                                              |
| ---------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `test/concerns/auth/org_emergency_session_continuity_test.rb`                                                                | Local initial/Refresh continuity and legitimate Normal NULL root; does not cover the two OIDC encode omissions                                                 |
| `test/values/authentication_context_value_test.rb`                                                                           | Closed enum, unknown value denial, ordinary rules/Step-Up/scopes; legacy general missing-claim fallback tests are not a license to accept missing OIDC context |
| `test/policies/emergency_authentication_context_policy_test.rb`                                                              | Ordinary policy permission/denial context behavior; add strict OIDC/root consistency at the actual authentication boundary                                     |
| `test/controllers/auth/org/verification/emergency_step_up_prohibition_test.rb`                                               | Real admission/finish/reuse context gates; retain Normal positive controls                                                                                     |
| `test/controllers/base/oauth_token_exchange_e1_test.rb`                                                                      | Public code/PKCE/client consumption entry and lost-response replay; use current realm-specific fixture/assertion path for context cases                        |
| `test/services/oidc_token_exchange_boundary_test.rb`                                                                         | Structural no-root-mint/no-root-rotation in exchange; supplement with actual row/audit observations                                                            |
| `test/services/oidc_refresh_token_issuer_surface_test.rb`, `oidc_refresh_token_coalescing_test.rb`                           | Realm Refresh, inactive parent, generation/replay/five-second delivery behavior                                                                                |
| `test/integration/org_root_login_establishment_test.rb`, `org_oidc_auth_handoff_root_completion_test.rb`                     | Current real Base root establishment/continuation; adapt public resume setup for reissue                                                                       |
| `test/controllers/concerns/authorization/token_claims_test.rb`, `test/unit/security/org_emergency_access_invariants_test.rb` | Signed claim shape and scoped ceremony routing; do not rename Org vocabulary in R1                                                                             |

New coverage may live in proposed `test/services/oidc_authentication_context_exchange_test.rb`,
`test/integration/oidc_authentication_context_contract_test.rb` and an existing suitable public
resume test. Reuse the appropriate existing file if it keeps one clear contract owner. Missing
current fixture keys or public reissue setup is BLOCKED for that case and an implementation report
if material, not a reason to test a private method.

### TC-R1-01-001 — Initial Context and Stored-Root Representation

Gate: AT-R1-01. Invariants: INV-001. Design REVIEWED; execution NOT_RUN.

Input: N0, N1, S plus app/com Normal; authenticated evidence and cooldown permitting one new login
each. Execute current public Base root establishment/Org alternative ceremony using scoped existing
helpers, then consume its Access at a protected entry.

Expected: N0 stays NULL in DB yet has explicit Access `authn_ctx=normal`; N1 is normal; S
stores/emits `emergency`; app/com emit Normal without a new column. Normal follows current Step-Up
eligibility; S never gains Step-Up. Root status/absolute lifetime and success audit reflect exactly
one legitimate committed login. No migration/backfill is required. Failure: any NULL-Normal refusal,
token omission or mismatched context fails Gate. Evidence: current test ID/result and safe
root/context/count/deadline observations.

### TC-R1-01-002 — Authorization Code Preserves Standby

Gate: AT-R1-01. Invariants: INV-001/008/012. Design REVIEWED; execution NOT_RUN.

Input: S root, current org client, original auth event, valid authenticated bound Code with S256 and
Nonce. Redeem once through org token endpoint with fresh valid Client Assertion and exact
redirect/verifier.

Expected: successful standard token response; signed Access context is exactly `emergency`, never
implicit `normal`; subject/audience/client/realm/sid/auth_time match the root/grant contract. ID
Token keeps current bindings. Root identity/count/context/absolute expiry/cooldown unchanged; only
normal OP Grant/Code state changes. Redeeming again is refused under existing Code single-use rules.
Any default Normal output or new root fails. Evidence: verified nonsecret claim assertions, Code
disposition, root and Grant fingerprints/audit counts, no raw token.

### TC-R1-01-003 — Repeated Refresh Preserves Standby

Gate: AT-R1-01. Invariants: INV-001/005/013. Design REVIEWED; execution NOT_RUN.

Input: S Code result and its current bound Refresh credential. Perform at least three valid
sequential Refresh calls with current client assertions, retaining each returned successor. Use a
fresh assertion each call.

Expected: every Access contains `emergency`; no Step-Up from a returned token; each current valid
rotation follows current one-successor/Generation semantics, absolute lifetime never extends, root
context/count/cooldown unchanged. No failure is masked as empty success. Outside-window predecessor
replay keeps the current replay/family-revocation behavior (separate cases in TC-R1-02-004). Capture
each generation/context/absolute deadline as safe assertions. Any Normal output or altered replay
rule fails.

### TC-R1-01-004 — Public Resume/Reissue Preserves Existing Root

Gate: AT-R1-01. Invariants: INV-001/005. Design REVIEWED; execution NOT_RUN.

Input: completed valid Base org authorization parent bound to S and its browser, with the browser
response deliberately not installed; use current public flow setup to reach `base_finalized_at` and
`browser_session_ref`. GET `AuthorizationsController#show` with the proper
result-generation/binding, then submit its real CSRF-protected POST to `create`. Only that POST may
execute the reissue branch; assert GET leaves credential state unchanged.

Expected: actual existing reissue branch returns corrected credentials for that root, Access is
`emergency`, no new root/device or fresh root-login cooldown anchor, current legitimate credential
rotation only, no lifetime extension. Duplicate/stale/different-browser continuation cannot mint
another root. Repeat with N0 and N1 controls. Failure to reach the actual branch with public setup
is BLOCKED, not PASS from a source match or private encoder call. Evidence records the exact
route/test and bound root identity/generation before/after.

### TC-R1-01-005 — Normal and Cross-Realm Positive Regression

Gate: AT-R1-01. Invariants: INV-001/008. Design REVIEWED; execution NOT_RUN.

Input: N0 and N1 through initial/Code/Refresh/reissue; app/com Normal through their existing
Code/Refresh. Execute same public paths as preceding cases with correct current clients.

Expected: every valid path emits `normal`, authenticates under current policy and retains normal
Step-Up eligibility when its independent evidence requirements are met. No required `standby`
literal, new schema, new client registration or role split. Preserve `acr/amr/auth_time` and finite
absolute deadlines. Any invalidation of canonical NULL Normal roots or treating absent app/com
column as malformed fails. Evidence separates each reachable realm/path; an unsupported path is not
silently presumed tested.

### TC-R1-01-006 — Missing and Malformed Access Context Refuses

Gate: AT-R1-01. Invariants: INV-001/008. Design REVIEWED; execution NOT_RUN.

Input: otherwise valid current OIDC Access signed with the authorized test issuer, independent
cohorts of removed claim, null, empty string, unknown string, integer, boolean, list and object.
Correct signature/client/sid/expiry remain so context is the refusal cause. Present at actual RP
callback/protected and applicable Step-Up boundaries; use valid-context positive controls on each
entry.

Expected: no authenticated principal/business action/Step-Up authority from malformed token; no
Normal inference from the general lenient helper. No root/grant/refresh mutation merely to repair
context. HTTP contract is authentication refusal (existing 401/unauthenticated redirect as
appropriate), not authenticated 200 or dependency 5xx counted as denial. Record exact response class
and missing-principal/no-effect assertions. Tests must falsify an accidental fallback, not just
assert enum behavior.

### TC-R1-01-007 — Unknown Stored Context and Enum Boundaries

Gate: AT-R1-01. Invariants: INV-001/017. Design REVIEWED; execution NOT_RUN.

Input: strict public enum lookup with `normal`, `emergency`, unknown/empty; current allowed Operator
storage includes NULL, `normal`, `emergency`. Existing DB CHECK rejects other values.

Expected: strict unknown/empty lookup raises the named configuration/domain failure, never Normal; a
fixture-only attempted illegal persistent value is rejected by the existing DB constraint without
disabling it. NULL is tested as legitimate Normal through TC-R1-01-005, not passed to strict enum as
an unknown string. Do not bypass CHECKs/create unreachable bad rows just to reach an issuer. If an
approved legacy snapshot actually violates the constraint, block/report that source discrepancy
before issuing. Evidence distinguishes enum/schema observations from the real Code/Refresh positive
tests.

### TC-R1-01-008 — Explicit Wrong Normal Claim Cannot Override Standby Root

Gate: AT-R1-01. Invariants: INV-001/008. Design REVIEWED; execution NOT_RUN.

Input: S root with otherwise valid correctly signed bound Access claiming `normal`, modeling the
observed current builder default from the omitted argument. Also test `emergency` token mismatched
to a legitimate Normal root, preserving all other valid bindings.

Expected: actual shared-chain OIDC acceptance checks canonical context equality and refuses the
inconsistent credential. The server neither rewrites root to match token nor grants Normal Step-Up.
Fresh independently authorized issuance/Refresh from S produces `emergency`. Matching known-context
positive controls remain accepted. Evidence identifies this cohort separately from a literally
missing claim; the existing source defect need not produce a missing claim to be caught.

### TC-R1-01-009 — Absolute Expiry and Existing Leeway

Gate: AT-R1-01. Invariants: INV-001/005/008. Design REVIEWED; execution NOT_RUN.

Input: T-frozen root with known finite absolute expiry and Access exp. Test nearest reachable
instants just before/at/after root absolute expiry, plus Access-only leeway with a still-live root
at exp+29, exp+30 and exp+31 seconds (one-second resolution; use finer nearest resolution if the
actual profile requires it).

Expected: root expiry cannot be extended by reissue/Refresh; at/after root absolute expiry no
current authority issues/accepts via the shared chain. Access validation preserves actual fixed
30-second profile tolerance at its exact boundary (accept only when its comparison permits exp+29;
refuse at/after exp+30), never a fresh TTL from receipt/reissue. Minted exp <= original root cap and
current 300-second Access policy. Every still-valid S output remains S. Failure: expiry extension,
changed leeway, or a test clock inconsistent with the issuer invalidates the test/Gate, not a
fabricated pass. Evidence includes frozen times/expected comparisons without credential values.

### TC-R1-01-010 — Public Binding and Type Negative Regression

Gate: AT-R1-01. Invariants: INV-008/012. Design REVIEWED; execution NOT_RUN.

Input: valid controls then one-dimension wrong issuer, audience, client, resource realm, token type
(ID token as Access), State, Nonce, PKCE verifier, redirect or browser continuation binding, using
current R1 registry/hosts. Signed claim negatives retain a valid test signature so wrong scope is
actually tested; signature tamper is a separate invalid-signature partition.

Expected: public boundary refuses, creates no authenticated RP/root replacement or cross-client
effect, and maintains Code single-use rules and correct existing owner state. A malformed HTTP
request or unknown host alone does not prove a client/realm verifier check. Include right-scope
controls to avoid vacuous negatives. Evidence names each entry/partition and preserved owner's
state. JP/US target-ID negatives are deferred to R4, not falsely claimed here.

### TC-R1-01-011 — Step-Up Initiation, Completion and Freshness Reuse Denied

Gate: AT-R1-01. Invariants: INV-001/009. Design REVIEWED; execution NOT_RUN.

Input: S tokens from Code, Refresh and reissue; existing valid passkey/ordinary Step-Up evidence for
the same root where current APIs allow the negative setup. Exercise actual Base admission, Auth
ceremony/result and final protected operation. Include a Normal positive control that satisfies all
independent Step-Up requirements.

Expected: S cannot start, complete or reuse ordinary Step-Up, including preexisting freshness; no
admission/evidence scope or privileged mutation is created. Context is a capability gate, not a
freshness timestamp bypass. Preserve existing CSRF/Origin/admission controls. Missing/malformed
context also cannot enter Step-Up via TC-R1-01-006. Evidence names actual existing public tests and
no-new-authority assertions, not private policy calls alone.

### TC-R1-01-012 — Ordinary Policy Is Preserved, Not Automatically Granted

Gate: AT-R1-01. Invariants: INV-001/009. Design REVIEWED; execution NOT_RUN.

Input: active S and Normal actors under an existing ordinary non-Step-Up operation (use current
PublishingEntryPolicy or another actually reachable ordinary rule); a canonical
policy-denied/inactive/wrong-resource actor control; public Policy `apply` tests supplement routed
cases.

Expected: S follows the same applicable ordinary rule, is not blanket-read-only and never widens a
policy denial. Existing scope constraints remain; the test does not add grants to force a policy
allow. A Step-Up-protected action remains denied for S. Evidence records rule/resource/subject scope
and actual public allow/deny observation. No new publishing/membership business policy is specified
by this case.

### TC-R1-02-001 — Safe Correction from Independent Refresh Authority

Gate: AT-R1-02. Invariants: INV-001/005. Design REVIEWED; execution NOT_RUN.

Input: missing or inconsistent Access cohort, independently valid exact-client current Refresh
credential and still-valid canonical root. Execute only the existing authorized Refresh/reissue
path; missing Access itself cannot authorize arbitrary root lookup.

Expected: current validation/rotation succeeds once and derives corrected context from the root,
preserving S and N0 representations. The malformed old Access never authenticates, even if recovery
succeeds. No new root, bypass, raw Refresh reconstruction or blanket sign-out. An
unrelated/cross-browser/cross-client Refresh fails. Evidence distinguishes refusal of old Access
from successful independent continuation.

### TC-R1-02-002 — Existing Root Requires a New Code Flow When No Continuation Exists

Gate: AT-R1-02. Invariants: INV-001/008/012. Design REVIEWED; execution NOT_RUN.

Input: live valid OP root, rejected old RP Access, no usable independently authorized RP
Refresh/reissue continuation. Enter standard authorization with valid
State/Nonce/PKCE/client/browser binding.

Expected: fresh Code Flow restores correct RP credentials, potentially without repeating credential
ceremony if current OP session/policy permits. The root alone is never accepted as RP Access, and
new Code output keeps S. No invented silent refresh endpoint or use of missing context as Normal.
Evidence records the actual public redirect/Code/acceptance sequence without raw tokens.

### TC-R1-02-003 — Recovery Refuses Ended Authority; Matching Sessions Continue

Gate: AT-R1-02. Invariants: INV-001/005. Design REVIEWED; execution NOT_RUN.

Input: matching known-context live token control; missing/mismatched token with expired/revoked root
or ended grant; independent unaffected valid actor. Execute protected request and attempted current
recovery.

Expected: matching live credentials continue; ended authority issues nothing and requires existing
new sign-in policy. Unaffected sessions remain unchanged. Do not claim all users must sign in again
or all old credentials recover without a ceremony. Evidence separates all cohorts and records no
blanket status updates/cutoff/data changes.

### TC-R1-02-004 — Refresh/Receipt/Replay and Earlier Authority Regression

Gate: AT-R1-02. Invariants: INV-005/013. Design REVIEWED; execution NOT_RUN.

Input/path: current public realm Refresh parent-revocation tests and
`OidcRefreshTokenCoalescingTest` actual stored receipts. Repeat exact predecessor inside original
five seconds (including existing 4.999-second test), at 5.000 and after 5.001, two-generations-old
replay, expired/revoked parent, Valkey/receipt failure as existing current contract supports. This
is the current receipt mechanism, not the R5 HTTP query endpoint.

Expected: exact inside-window redelivery retains original response/exp and rotates once; at/after
fixed expiry replay behavior remains; ended parent blocks redelivery; no root issuance/refresh
rewind. Assert safe Family/Generation/expiry/dedup/audit state as in current suite. Any change to
make Context tests pass by weakening replay/receipt/refusal fails release. Missing real Valkey/safe
target means BLOCKED, not a fake unit result.

### TC-R1-02-005 — Independent R1 Boot and Current-Profile Round-Trip

Gate: AT-R1-02. Invariants: INV-001/008/017. Design REVIEWED; execution NOT_RUN.

Input: coherent R1-only checkout over existing Ticket schema, current registry IDs, current shared
listener/credentials and exact authorized test environment. Run actual app boot and current
Code/Refresh/reissue/protected normal/alternative flows.

Expected: no R2 Waiting schema, R3 name, R4 client or R5 process/DB is required to boot or accept
correct R1 tokens. No migration/reset/client registration/cutoff or unrelated code modification is
performed as a repair. Preserve current session limit/cooldown and existing ceremony contract. A
missing environment prerequisite is BLOCKED, not evidence of an R1 code dependency. Record actual
effective nonsecret config identity and command in evidence; add no environment-construction
Minitest/Vitest.

### TC-R1-02-006 — Coverage, Source Safety and Truthful Handoff

Gate: AT-R1-02. Invariants: INV-017/024. Design REVIEWED; execution NOT_RUN.

Input: actual R1 diff, all encode/reissue call sites, required test results and safe environment
manifest. Inspect/read-only diff and source consumers; run affected invariant guards and
`git diff --check` after code authorization.

Expected: both OIDC omissions and every actual reissuer covered, and the third omitted encoder
`CoreBrowserCredentialContract.encode_access_token` explicitly classified (application caller fixed
to pass root context, or recorded as test-only), old general fallback cannot leak through the strict
OIDC boundary, Normal NULL contract retained, no private-method test wrappers/visibility changes, no
test skip/guard broadening, no rename/schema/cutoff creep and no unrelated dirty-work overwrite.
Current docs/checklists accurately describe delivered behavior. Every Gate/case result has full
HEAD/dirty scope; prior notes are not PASS. Every applicable case not run blocks release. Any
S-worthy actual shape expansion is separately approved before its implementation.

### TC-R1-REL-001 — R1 Release Decision and Sol-to-Luna Handoff Closure

Gate: AT-R1-REL. Invariants: R1 set in section 10. Design REVIEWED; execution NOT_RUN.

Procedure: collect all AT-R1-01/02 cases and actual evidence, execute TC-REG-001 for applicable
current mechanisms, confirm no unresolved Critical/High R1 result and no required case
FAIL/BLOCKED/NOT_RUN. Document explicit NOT_APPLICABLE reasons (e.g. no R5 local-role mechanism; no
restore performed in R1), not global exclusions. Verify I and any specific execution/shape
approvals, exact diff and current-source compatibility. Root context impact cohorts must be stated
using actual observations, without extrapolating a population-wide re-login claim.

Expected: R1 PASS only after all applicable evidence; otherwise record the exact
failed/blocked/unrun unit and keep AT-R1-REL unpassed. R2 implementation sequencing follows only
after R1 release closure. A design-reviewed case or this specification alone cannot set PASS or
authorize execution. Evidence is a factual release record referencing individual test
IDs/commands/HEAD/environment, not a token dump.

### 11.2 Future Execution Commands and Evidence Packet

After I and exact safe-target authorization, the implementation packet uses the repository's real
`bin/rails test <file>` commands for the new/extended public cases, then the relevant existing
Context/policy/Step-Up/Code/Refresh/receipt suites above. It runs the narrow failing reproduction
first and broadens once to the affected security boundary, not the entire unrelated suite
repeatedly. Actual boot/configuration construction is run and recorded as evidence, never disguised
as a unit test. No such command was run during this revision.

Each case result includes Test Case/Gate/INV IDs, full commit hash and dirty scope, authorized
target/role/client/clock cohort, exact test/probe command, expected versus observed public and
persistent effects, outcome (PASS/FAIL/BLOCKED/NOT_RUN/justified NOT_APPLICABLE), evidence file and
remaining limitation. Assertions retain only safe identifiers/counts/timestamps/fingerprints. Report
material failures to the user and three.md during actual implementation. A preexisting suite failure
is reported with current evidence, never relabeled as PASS or hidden by weakening it.

## 12. Scoped R2-R5 Security Scenarios

These entries are SCENARIO_DEFINED and execution NOT_RUN. They give every AR a falsifiable
public/persistent outcome and pin preactivation coverage. Full per-unit fixtures, numeric
environment thresholds and executable test/probe commands are finalized before the corresponding
later Gate is executed. They do not imply that all R2-R5 acceptance-detail authoring is complete.
All use the safe-target/approval/evidence rules above.

### TC-R2-02-001 — Limit and Actor Slot Boundary

Gates AT-R2-01/02; INV-002. For each realm N=2/1/1 exercise F=N-1, F=N with free slot, F=N with
occupied slot, and simultaneous independent-connection sign-ins. Expected one actor lease, no more
than N Full Access roots, Waiting has no root/Grant/success audit, same-flow retry is idempotent and
another actor's lease is irrelevant. Existing sessions/cooldown remain unchanged on refusal. Test
expiry exactly around its capped deadline and legal lease release; raw DB uniqueness must enforce
the invariant. A model-only or mocked count result is insufficient.

### TC-R2-03-001 — Explicit Continue, Promotion Competition and Atomicity

Gate AT-R2-03; INV-002/015/020. With an existing waiter, free a slot by selected purge and
separately by normal sign-out/expiry. GET show is read-only and renders an explicit Continue control
without auto-submit. Also hit every generic OAuth/social resume after capacity frees: it must stay
Waiting/read-only, not auto-promote through a different root issuer. The planned explicit POST at
the current limitation path reaches the existing update Action with valid
CSRF/Origin/browser/flow/evidence and completes only if fresh actor-locked capacity permits.
Existing PATCH/PUT must enforce the identical gate; all other unregistered verbs refuse. Current
source resource routes do not themselves prove the new POST exists. Race new login against Continue
in both commit orders: winner takes capacity; losing waiter remains sole Waiting owner with
unchanged deadline. Inject failures between purge/root/parent/lease operations; no early RESOLVED or
independently committed purge/new login gap. Separately, while a Waiting lease is open and capacity
is free, start a different fresh sign-in flow for the same actor from another browser through each
completion path (password/passkey, OAuth resume, social completion): it must issue Full Access per
admission step 2 and leave the Waiting owner and its deadline unchanged; only the Waiting flow's own
resume stays read-only. A Waiting-lease check that blocks this different flow is FAIL (P-9).
Cancel/expiry frees only its own lease and does not affect existing Full roots. Invalid binding/CSRF
or replay against a newer login is denied without collateral revocation.

### TC-R2-04-001 — Retired 103 and Waiting/MFA Rejection

Gate AT-R2-04; INV-003/004. Use valid positive controls then historical 103, revoked, expired and
unknown-status roots on every inventoried root/API/Browser RP/Code/Refresh/UserInfo/Step-Up path.
Separately present Waiting/pending browser credentials at each ordinary/MFA-reset route and verb.
Expect no general principal/Access/Refresh/Grant or privileged effect; only full-access credentials
under existing policy reach the current reset-unavailable page. An Org Standby (`emergency`) root
gains no MFA-reset mutation: any reset action requires Step-Up, which Standby cannot obtain
(positive Normal Step-Up control included). New status-103 writer/allowlist or missing callback
classification is FAIL, not a reason to shrink route coverage.

### TC-R3-07-001 — Name/History/Restore Security Preservation

Gates AT-R3-01/03/04/05/06/07/08; INV-010/017. On a rebuilt isolated target compare historical
versions/classes/file hashes and FK/constraint/Sequence/default equality after clean construction,
then boot/replay current R1/R2 flows. Show unsafe or unlisted target identity refused before writes.
At WU08 drop and rebuild the development/test OP databases under target names and verify no old-name
connection or alias remains. Restore and preserved-snapshot cases are NOT_APPLICABLE
(`NO_PRESERVED_ENVIRONMENT`, `one.md` 1.2A). No historical migration rewrite or old Runtime alias.

### TC-R4-02A-001 — JP Shared-Process Trusted Environment

Gates AT-R4-01/02/02A/04; INV-008/022. Validate actual fixed JP host/family/realm binding in the
current shared Rails process, WW5 stays `*-ww`, Regional7 is JP, required startup region and current
registry keys/URIs/assertions match. Forge `ri=us`, unknown Host, wrong audience/client/region
credential and missing required binding: no US client/DB/key selection or arbitrary ID assembly.
Separately statically validate explicit hypothetical US metadata/config; missing runtime/private
data is reported and US runtime marked NOT_RUN. Do not create US stores or require R5 secret roles
to pass R4. Unknown required Jump/Edge route remains BLOCKED; mock-only reachability is not PASS.

### TC-R4-03-001 — Cutoff Includes Unchanged Base Client IDs

Gates AT-R4-03/04; INV-005/010/018. In an isolated test target, mint old-profile
Root/Access/Code/Refresh/receipt and assertion credentials for old named clients AND current
`base-app-ww`, `base-com-ww`, `base-org-ww` before switching to the target profile. After the switch
each old continuation is unusable although those Base ID strings are unchanged; fresh standard
target Code flow succeeds. No row/client relabel or old-key alias can restore acceptance.
Development/test databases are rebuilt for the real cutover (`one.md` 1.2A), so no business/history
preservation check applies there.

### TC-R5-03A-001 — Actual Role Capability Denial

Gates AT-R5-03A/04; INV-007/017. Boot the actual RP role and actual worker identity with the
declared mounts/secret bundle/effective config. Attempt reading global master-key/key paths,
decrypting an OP signing fixture using only available RP capability, resolving another cell
assertion secret, accessing host-control sockets or broad inherited environment, and actual
unauthorized OP/Zenith/sibling DB login using every available role credential. Observe explicit
failure without exposing secret values; permitted own DB and public JWKS/HTTPS positive controls
succeed. Code grep, mocked provider denial or file mode under the same powerful UID is insufficient.
OP/domain/worker roles have positive and negative least-privilege controls too. Missing role
launch/targets is BLOCKED. This runs before functional JWT/Local Session/activation completion, with
functional proof repeated later.

### TC-R5-04-001 — New Public Verifier Profile and Key Rotation

Gate AT-R5-04; INV-007/008/011. Exercise current target Access signature, issuer, audience, client,
realm, contract-epoch/profile and known context, with ID/Logout token confusion and a signed wrong
epoch/old missing-profile credential. Reject one-field mismatches, token-selected URLs,
unknown/untrusted keys and expired JWT. Approved known cached public key behavior during JWKS
failure and rotation is tested separately. RP can verify without OP private key; compromise/forgery
of only local rows cannot make a pre-cutoff JWT current. Missing isolated key rotation evidence
blocks activation.

### TC-R5-06-001 — Stop Against Every Issuer and Redelivery

Gate AT-R5-06; INV-001/005/021. Independent connections/barriers serialize stop against
initial/Code/Refresh/reissue/fresh Grant replacement/receipt redelivery in both orders.
Stop-committed-first forbids later authority; already committed issuance has fixed original expiry.
Crash after Zenith state/epoch/outbox commit but before OP revocation, and after OP commit before
acknowledgement; durable retry converges without pretending atomicity. Delayed old event after a
restored newer epoch cannot kill new authority. Measure the actual lock order/wait bounds; any
missed writer or inverse-order deadlock masks no success. Residual-access bound is derived from all
issuers and clocks, not TTL alone.

### TC-R5-07-001 — Callback and JWT/Local Session Conjunction

Gate AT-R5-07; INV-008/011/012. Exercise valid Code callback, consume State once, require matching
Nonce/PKCE/client/issuer/subject/sid/browser and strict contract epoch. Independently corrupt each
while preserving other controls, then test JWT-only/local-only, missing/mismatched identity binding
and exp/leeway boundaries. No email linking or Global integer principal fallback. Local writer state
must be read; stale replica cannot permit. A failed callback local commit installs no cookie or
reusable state/code.

### TC-R5-07-002 — Logout Before/During Callback, Including Unknown Sid

Gates AT-R5-07/10; INV-006/023. Deliver a valid logout for an unknown sid first: receiver commits a
nullable-identity tombstone without a synthetic principal; subsequent callback refuses. Reverse
order and pause between anchor upsert/lock and session commit: every legal winner leaves terminal
invalidation, never a revived session. Duplicate callback and duplicate signed logout are idempotent
only for their recorded binding. Observe actual two-connection row/unique constraints, not stubbed
callbacks or response status alone.

### TC-R5-07-003 — Callback/Refresh/Logout Installation Race

Gates AT-R5-07/08/10; INV-005/006/011. With active exact sid, pause Refresh after OP commit, race
duplicate callback/session enrollment and logout, then deliver the delayed response in each
ordering. Only a permitted local generation CAS may install; tombstone wins over delayed install and
callback cannot replace its identity or recreate revoked sid. Fresh Code enrollment uses a fresh OP
sid under the existing one-active-grant/device/client rule; late purge/notification for the
predecessor does not revoke the new unrelated sid. Root/global authority is never read from RP DB.

### TC-R5-07-004 — Recheck R2 103 Denial After Separation

Gate AT-R5-07; INV-003/004/011. Re-run R2's public status/Waiting tests against new OP issuance and
RP entry paths. Historical status-103 roots cannot obtain new-profile Code/Refresh/Access; old 103
Access remains unusable even when unexpired and even if an attacker inserts apparently live local
binding/session rows, because the new required contract-epoch/profile is absent/wrong. No local row
can supply the missing signed claim. Issuer transition guards forbid newly writing 103 or signing
modern credentials from it. This does not invent a valid runtime transition to Restricted requiring
per-request OP introspection; no such writer/feature exists. A test that only fails due to a missing
cookie without exercising this credential partition is insufficient.

### TC-R5-08-001 — HTTP Receipt, Replay and Dependency Semantics

Gate AT-R5-08; INV-005/013/019. Rotate once, lose the response after commit, query original exact
attempt/predecessor with a new endpoint-bound assertion inside 4.999 seconds, at 5.000 and after
5.001. Only original-window redelivery succeeds and never changes signed exp or generation. Wrong
attempt/client/realm and revoked/stopped root refuse. Two tabs, lease loss/Valkey outage, corrupt
receipt and two-generations-old token retain current replay behavior; no late old-token rotate
retry. Re-lock local row after network and reject revoked/stale install. Dependency failures
preserve cookies but cannot extend Access validity. Demonstrate actual admitted total
timeout/recovery budget under independent OP receiving capacity; no TTL relaxation.

### TC-R5-09-001 — OP Commit, Lost Response and Refresh Finality

Gate AT-R5-09; INV-005/014. All RPs down: valid bound OP request commits root/Grant/Code/receipt
invalidation plus Flow/Participant/outbox and establishes success. Inject commit ambiguity then
writer reread; never report success without proven commit or revive after it. Refresh/receipt
concurrent with logout in both lock orders cannot obtain authority after committed revocation.
Duplicate bound POST cannot target a newer login. OP success is independent of RP ACK/purge; no
single DB transaction is claimed across RP delivery.

### TC-R5-10-001 — Durable Delivery/Queue/Replay/ACK

Gate AT-R5-10; INV-006/014/023. Stop Queue, commit OP revocation/outbox, restart dispatcher/sweep
and verify delivery. Crash sender before/after network and lose ACK; duplicate standard Logout
Token/event replay resolves idempotently. Wrong issuer/audience/type/nonce/binding refuses. Force
receiver persistence failure: HTTP must be retryable non-200, no receipt-only commit; a valid
unknown sid must atomically tombstone/invalidate with receipt before 200. No secret payload in
queue/logs and no outbound HTTP under a row transaction. Observe event attempts and actual rows.

### TC-R5-05-001 — Self-Call Admission and Failure Isolation

Gate AT-R5-05; INV-019. Run real same-FQDN Base Self-RP HTTPS and shared-load RP waits against
separately reserved OP receivers, with declared offered load/concurrency/deadline/pool limits before
measurement. Inject TLS/DNS/timeout/429/5xx/invalid-success errors and confirm typed outcomes/cookie
retention, no direct-service or cached permission fallback. Measure actual thread/connection waits
and recovery; increasing read timeout alone is not a pass. JP evidence describes the actual path; no
US RTT/throughput is fabricated.

### TC-R5-11-001 — Current Tech Capability

Gate AT-R5-11; INV-008/009. Commit `tech.access` revoke then begin a new exact-client decision; it
denies from current org Zenith writer. Reverse ordering to capture the explicit in-flight limit.
Wrong Operator/client/realm/audience/scope, invalid actor or dependency failure denies; no positive
cross-request cache. Real ActionPolicy/capability facts are used, not RP allow booleans. Preserve
existing stronger final-mutation checks if any were found.

### TC-R5-12-001 — IAM/Support/Enforcement Canonical Decisions

Gate AT-R5-12; INV-009/016. Use actual existing policy/operation packets (12-I/S/E), including
denied bootstrap/self-delegation, target app/com capability confusion, unsupported org discipline
and apply/approve separation. Try another tenant/object, forged Operator ID/allow flag, stale
permission and incorrect target resource. Receiver resolves real actor and current canonical policy
before existing writer; target-specific OP revocation is an effect, not cross-TLD user
authentication. Query-only calls cannot mutate. No future permission model is inferred.

### TC-R5-13-001 — Publishing Policy and Writer

Gate AT-R5-13; INV-009/016. Execute current fixed-cell
entry/read/revise/publish/end/archive/unarchive operations with valid org subject and scope;
preserve optimistic version, immutable revisions/publications/window constraints/audit identity.
Wrong content cell/other object/inactive Operator, forged RP allow/ID and client assertion endpoint
audience refuse. Force response loss on a supported idempotent mutation: exact result query/dedup,
never blind duplicate Create/Publish. Publishing DB is the only content writer; OP token controllers
and RP local DB are not writers. Cross-DB permission/write atomicity is not assumed.

### TC-R5-14-001 — Avatar Current Scope and Ownership

Gate AT-R5-14; INV-009/016. Exercise actual current Avatar query/writer with canonical
subject/collective/ownership/lifecycle facts. Wrong surface/tenant/collective/object/actor and stale
owner refuse at the domain authority even when RP claims allow. Preserve existing current ownership
transfer/lock guarantees; no new D-10 model. Actual RP role denied canonical DB access and owner
policy applied. Existing committed Avatar work remains the source baseline.

### TC-R5-15-001 — Organization Current Permissions

Gate AT-R5-15; INV-009/016. Preserve current canonical identity joins and supported app/com
membership operations; wrong subject/collective/object or inactive membership cannot grant access.
Current denied org mutation remains denied, regardless of RP principal/allow flag. Existing real
owner writes/audits remain; no new business role added. An owner/guarantee UNKNOWN blocks that
existing operation and is reported, not converted to delayed permission.

### TC-R5-16-001 — DBSC, Base Completion and Matching Purge

Gate AT-R5-16; INV-014. Validate current DBSC supported-browser proof and non-support fallback
without OP DB access from RP. Base GET bye is read-only, explicit POST receipt consumption one-time;
RP/cookie ACK missing does not undo OP success. A delayed old-flow purge must not delete a new
matching-host but different sid login. Browser deletion-response-sent and persisted session
invalidation are distinct outcomes. Current Sign-out route removal remains Pending.

### TC-R5-17-001 — JP12 Role Wiring and Generated Boundary Coverage

Gates AT-R5-01/03/17; INV-007/016/017/022. For each WW5+JP7 cell use its actual role, own DB,
assertion namespace, callbacks, Refresh/logout and current domain adapters; wrong
sibling/region/realm is rejected. Derive effective routes/callbacks/models and pin unclassified
action/table/consumer failure; historical references have explicit purpose. Existing Global
Core/Warp/Palm source is tested here, not an imaginary external implementation. Jump/Edge contract
probes are read-only or separately E-approved; unavailable required contract blocks cell activation.
US actual result is NOT_RUN until independently provisioned. No OP/Zenith/sibling/Publishing/Avatar
SQL credential belongs to RP.

### TC-R5-18A-001 — Mandatory Isolated Precutover Attack/Restore Aggregate

Gate AT-R5-18A; all applicable R5 invariants. Use rebuilt isolated exact JP role environments.
Execute the matrix in section 13 below against the reviewed build; restoration cases are
NOT_APPLICABLE (`NO_PRESERVED_ENVIRONMENT`, `one.md` 1.2A). Do not waive failed/unrun cases because
corresponding source looks correct or final WU20 is planned. Any required absent
environment/procedure/approval is BLOCKED or NOT_RUN and therefore Activation NO-GO. The aggregate
result references actual individual case evidence and is not a substitute for it.

### TC-R5-19-001 — Common Cutover Then Exact-Cell Admission

Gate AT-R5-19; INV-005/010/014/018/022. After preactivation PASS and explicit D, perform the
prepared stopped-writer common batch with each DB commit checkpointed. Partial failure keeps all
affected access closed for forward repair. No old method serves disabled cells. Then enable a single
exact epoch/client (Base app pilot), verify its public flow/isolation/logout, and continue ready
cells independently. A failing Cell is disabled with audited outcome; sibling PASS cannot cover it.
Old Base/other pre-R5 tokens/families/Code/receipt cannot recover despite forged local rows. US
metadata remains inactive. Re-run corresponding evidence after activation in AT-R5-20; no OP
revocation rollback.

## 13. Preactivation Proof and Postactivation Recheck

R5-WU18A precedes R5-WU19 in the authoritative DAG. The following mandatory coverage must have
actual PASS for the approved JP build/scope before common cutover/any cell admission. All are
currently NOT_RUN; R5 Activation is currently NO-GO. Permission to run tests is not D/E for
restoring/cutting off existing state or probing an external owner's authentication.

In-process two-connection ordering, cached-reading-caller and JWKS-rotation-outage sub-cases have
PASS evidence in `evidence/2026-10-18-r5-wu18a-two-connection-and-jwks-rotation-W18B.md`; they do
not change the NOT_RUN Gate states.

| Mandatory attack/fault coverage                                                               | Cases whose actual evidence is required                                   |
| --------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| JWT type/issuer/audience/client/profile binding                                               | TC-R5-04-001, TC-R5-07-001                                                |
| Callback State/Nonce/PKCE and browser binding                                                 | TC-R5-07-001                                                              |
| Callback/logout including unknown sid                                                         | TC-R5-07-002, TC-R5-10-001                                                |
| Callback/Refresh/late install                                                                 | TC-R5-07-003                                                              |
| Rotation/replay/fixed five-second receipt                                                     | TC-R5-08-001                                                              |
| Identity stop vs all issuance and redelivery                                                  | TC-R5-06-001                                                              |
| Actual OP/RP/sibling secret and master-key isolation                                          | TC-R5-03A-001                                                             |
| Actual cross-RP/OP/Zenith DB connection denial                                                | TC-R5-03A-001, TC-R5-17-001                                               |
| Old credential rejection including unchanged Base IDs                                         | TC-R4-03-001 adapted to R5, TC-R5-07-004, TC-R5-19-001 isolated rehearsal |
| Queue/outbox/crash/retry and true receiver ACK                                                | TC-R5-09-001, TC-R5-10-001                                                |
| Migration keeps invalidation truth (restore NOT_APPLICABLE while environments are disposable) | TC-R3-07-001 adapted to R5, TC-R5-18A-001                                 |
| R2 protections through new verifier; context and policies                                     | TC-R5-07-004, R1 and domain regression per TC-REG-001                     |

TC-R5-19-001 first runs as an isolated rehearsal with its own separate authorization, not as the
real cutover to obtain permission for itself. Its later actual-target execution produces a new
evidence set. Role scaffolding tests occur at WU03A, attack integration at WU18A, actual activation
at WU19, and final environment verification at WU20. No parent-unit completion depends backward on a
future live deployment.

AT-R5-20 repeats applicable Invariants/cases on the actual activated environment with exact
cell/role/HEAD result rows and TC-REG-001. Common-case evidence may be shared only for the same
tested common build; each cell's wiring/credentials/DB isolation/runtime outcome remains
independently observed. Complete JP release means all twelve intended cells passed, or a separately
explicitly approved narrower release scope; US NOT_RUN is retained and cannot be passed using JP
evidence. No postactivation failure permits rollback to an old authenticator or stale security
snapshot.
