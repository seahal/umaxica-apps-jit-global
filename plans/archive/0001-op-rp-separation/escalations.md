# OP/RP Separation — Escalation Requests

> Archived snapshot, generation 0001 (originally `six.md`). Non-normative and not evidence; see
> [README](./README.md).

Status: **RESPONDED by Sol, 2026-10-16. Original findings are preserved below. No new architecture
choice is requested for already confirmed decisions; the successor ADR is accepted, and R5 remains
gated on implementation evidence and applicable I/S/D/E. See section 4 for dispositions.**

Date: 2026-10-16

Baseline: `feature`, HEAD `17903f7d121aa33efe29f2db9235c9aa5db4b001`. This record concerns the
implementation defined by [one.md](./implementation-plan.md). It does not modify or supersede an
ADR, grant a database operation, authorize deployment, or authorize an external write. The
intentional ignored status of the planning documents is excluded from this escalation.

## 1. R5 OP/RP separation conflicts with the accepted sign-out contract

### Facts

`one.md` defines independent RP stores, RP-local session tombstones, Back-Channel Logout, durable
logout delivery and OP outbox processing for R5. See
[one.md](./implementation-plan.md#64-https-contracts) and
[one.md](./implementation-plan.md#76-logout-and-durable-delivery).

The accepted first-party sign-out ADR requires parent and RP revocation in the shared realm Ticket
database transaction and explicitly rejects BCL, delivery queues, delivery ledgers and partial
delivery states. See
[first-party-sign-out-shared-database-without-backchannel-logout.md](../../../adr/first-party-sign-out-shared-database-without-backchannel-logout.md#decision).

These contracts cannot both be the active R5 contract. `one.md` requires the affected scope to stop
when this type of conflict exists.

### Affected scope

R5-WU03, R5-WU03A, R5-WU04 through R5-WU10, R5-WU16, R5-WU17 and R5-WU19, including local RP stores,
role isolation, logout delivery, activation and cutover.

### Decision requested

Choose one active contract:

1. Keep the accepted shared-database/no-BCL contract and revise the R5 design in `one.md`.
2. Adopt the R5 separation contract and approve a new ADR that explicitly supersedes the affected
   first-party sign-out premises.

### Consequences

Keeping the existing ADR reduces migration, deployment and delivery complexity but does not provide
the RP-database compromise boundary required by the R5 purpose. Adopting the R5 design provides that
boundary but requires new local stores, role-specific credentials, delivery recovery, cutover and
restore evidence.

### Recommendation and stop condition

If OP/RP persistence separation remains mandatory, approve option 2 through the owning ADR process.
R5 implementation and activation remain stopped until the active contract is recorded. Codex will
not modify the ADR or perform the supersession.

Decision: **PENDING**

## 2. JP/US completion scope is ambiguous

### Facts

The Success section requires concrete client, key, URI and Session DB bindings for both JP and US.
See [one.md](./implementation-plan.md#success-means).

The current execution scope provisions twelve JP cells. US has static catalog/configuration
coverage, no assumed DB/process/host/private-key environment, and runtime verification marked
`NOT_RUN`. See [one.md](./implementation-plan.md#51-fixed-catalog-and-cell-stores) and
[one.md](./implementation-plan.md#r5-wu19--approved-common-cutover-and-cell-by-cell-activation).

### Affected scope

R4-WU01 through R4-WU04, R5-WU03, R5-WU17, R5-WU19 and the final programme completion condition.

### Decision requested

Define whether the current programme completion means:

1. JP and US both have provisioned runtime cells and actual end-to-end evidence.
2. JP runtime activation is the current completion scope, while US remains static catalog and
   negative-binding coverage with runtime explicitly deferred.
3. JP and US are separate releases, each with its own activation and completion gate.

### Consequences

Option 1 requires a US environment, database/process/key/URI provisioning and independent evidence.
Option 2 allows the current JP work to close without claiming US runtime coverage, but the Success
criteria and release wording must say so. Option 3 provides the clearest lifecycle separation but
adds a future release boundary.

### Recommendation and stop condition

For the current environment, use option 2 or 3 and update the Success condition so static US
metadata is not described as a concrete US runtime binding. US evidence must never be inferred from
JP evidence.

Decision: **PENDING**

## 3. I/S/D/E approval boundaries for implementation and activation

### Facts

`one.md` records explicit I for R1-WU01 and D for R1 tests on twenty existing isolated databases,
limited to fixture writes. That D excludes database creation, deletion, reconstruction, migration
and changes to ordinary development/test databases. See
[one.md](./implementation-plan.md#11-authorized-scope-and-release-policy).

The same document states that other Work Units do not inherit I; persistence and wire shapes need S,
real data operations need exact-target D, and external stateful activity needs E. See
[one.md](./implementation-plan.md#12-canonical-documents-and-approvals).

The current text still contains stale status statements: the header says R1-WU01 is implementing,
while the handoff says R1 is awaiting I and that implementation has not begun. See
[one.md](./implementation-plan.md#handoff-and-verdict).

### Affected scope

R1-WU02 and all R2-R5 source changes, migrations, restore operations, credential cutoffs, local
store creation, deployment/role setup, external-owner probes and activation gates.

### Decision requested

Confirm the approval model:

1. Grant I, S, D and E separately per Work Unit and exact operation, preserving the current
   least-privilege boundary.
2. Grant a broader release-level approval with explicit exclusions and exact target manifests.
3. Permit source-only preparation while keeping all data, credential, deployment and external
   operations blocked.

### Consequences

Per-Work-Unit approval limits irreversible scope and makes the recovery boundary explicit. Broader
approval reduces coordination overhead but increases the chance that source preparation is mistaken
for authorization to alter security state. Source-only preparation allows progress while leaving
activation incomplete.

### Recommendation and stop condition

Use option 1. Continue R1-WU01 only within its recorded I/D scope. Do not infer approval for R1-WU02
or R2-R5. Keep migration, credential cutoff, deployment, restore and external state changes closed
until the applicable S/D/E decisions and exact targets are recorded.

Decision: **PENDING**

## Follow-up required after decisions

Update `one.md` to record each decision, affected Work Unit and superseded clause. Reconcile the R1
status wording so the document states one of `authorized`, `in progress` or `not started`. Preserve
the original escalation facts and record the decision source and date here or in the owning decision
artifact.

## 4. Sol response and disposition — 2026-10-16

This response preserves the original escalation and its historical PENDING labels. The effective
dispositions are below. The user requested this response in the current session. No ADR, database,
deployment, external registry or application behavior is changed by this response.

### 4.1 Shared-store logout ADR versus the R5 target

**Finding accepted; design choice already confirmed; required ADR execution gate remains OPEN.**

The cited ADR is Accepted and cannot be treated as already superseded. Its shared-realm atomic
parent-and-RP update and no-BCL requirements describe the active R1-R4 architecture. They conflict
with separated RP stores in the R5 target. The ADR itself identifies independently owned RP stores
as the condition for a separate BCL extension ADR. This is the case the R5 design intentionally
introduces.

The user's final-design D-08 and final handoff explicitly choose OP/RP separation, OP revocation and
OP outbox in one commit, asynchronous durable RP-local revocation, and success independent of ACK or
cookie purge. They also require planning the relevant ADR Supersession. Therefore option 2 is the
confirmed target direction; asking the user to choose again between separation and the old
shared-store architecture would reopen an already settled decision. This does **not** mean the
successor ADR has been written or Accepted, nor that present I authorizes R5 or ADR editing.

Correction integrated into `one.md` R5-WU01 and section 10, and `two.md` AT-R5-01: under its later
explicitly authorized scope, R5-WU01 prepares the successor ADR and obtains explicit acceptance
before conflicting R5 implementation proceeds. The successor names the old shared-transaction,
universal parent-read, no-BCL/no-ledger and metadata clauses it replaces, while preserving current
parent revocation authorization, commit irreversibility, GET/POST protection, exact redirects and
the no-ACK success contract. R5-WU18 is documentation closure, not permission to defer the initial
ADR gate until after implementation.

Disposition: **DESIGN_CLARIFIED / ADR_GATE_OPEN**. The affected downstream R5 scope stays stopped
until that Gate and its own approvals hold. R1-WU01 is unaffected. No ADR was edited here.

### 4.2 JP runtime completion and deferred US runtime

**Resolved from existing H-2, not a new user decision.**

The user's H-2 specifies Worldwide5 plus JP7 in the JP development environment, no mandatory US
physical stores, US static registry/configuration and wrong-region/client/audience tests, and US
runtime NOT_RUN until an independent environment exists. This corresponds to option 2 for this
programme's current runtime completion scope. It does not create a new US release or pretend that US
operational bindings have already been provisioned.

The opening success criterion and final closure wording in `one.md` now state that scope explicitly.
JP12 must pass its applicable Gates. US must retain fixed independent catalog identities, inactive
unprovisioned operational configuration and negative-binding coverage. Its actual runtime result
remains NOT_RUN with `US_ENVIRONMENT_NOT_PROVISIONED`; JP PASS is never copied to US. Future US
runtime construction/activation needs separate environment and applicable data/external approvals.

Disposition: **RESOLVED — confirmed H-2 applied**. No US DB/process/secret/Host is created.

### 4.3 Approval scope and stale implementation status

**Resolved from actual current approvals; no broader grant inferred.**

The existing I/S/D/E model remains active (option 1 describes it). This response does not require
the user to approve that already specified model again, and does not grant a source-only or
release-wide permission implicitly. Authorization must be matched to its actual scope; a grant
covering an explicit set of operations remains valid without repeated questions for that same set.

Current grants recorded in this session:

- I: the user's direct implementation-start approval for R1-WU01.
- D: the user's separate affirmative response permitting R1 fixture tests on the twenty existing
  isolated databases in `tmp/acceptance-isolated-20261016w6n2.json`, one worker, with no creation,
  deletion, reconstruction, migration or ordinary development/test database changes.
- S/E: no additional grant inferred; R1-WU01 corrects the existing context claim, with no approved
  new persistence/wire shape or external write.

`one.md` section 13 and its readiness table now agree with the header: R1-WU01 is in progress;
R1-WU02 and later units have not inherited I. Gate completion is not implied. `three.md` contains an
actual safe-test-invocation discovery, so the old statement that implementation has not begun and
the report file is empty was removed. No historical audit result is rewritten.

Disposition: **RESOLVED — scoped I/D recorded; other approvals still pending when applicable**.

### 4.4 Checks and handoff

- Source: current `feature`, HEAD `17903f7d121aa33efe29f2db9235c9aa5db4b001`; current ADR and
  affected specification clauses were read in this session. Concurrent R1 code/test work is
  preserved and belongs to its own implementation packet.
- No new Work Unit ID, dependency cycle, approval expansion or old-client fallback was introduced.
  R5-WU01 already precedes the affected R5 work; AT-R5-01 now names the missing ADR prerequisite.
- These are specification/provenance corrections. They do not establish runtime PASS, US runtime
  readiness or R5 activation readiness. Continue approved R1-WU01 only; keep future gates intact.

## 5. User dispositions — 2026-10-16

Recorded at the user's request in this session by the reviewer (Claude). Sections 1–4 are preserved.

### 5.1 Item 1 — successor sign-out ADR

The user asked for item 1 to be handled. A successor ADR draft was written:
`adr/first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores.md`, status
**Proposed**, not Accepted, with an index entry in `adr/README.md`. It applies only to first-party
RPs activated as separated cells in R5 and keeps the existing ADR in force for R1–R4. It names the
superseded Decisions 1, 2 and 4, the parent-read condition and the relevant "do not reintroduce"
items, and carries over the earlier ADR's BCL constraints (delivery after COMMIT and outside the
request, never deciding success; receiver 200 only after its revocation commit). The existing
Accepted ADR was not edited. `one.md` section 10 records the draft path.

Status: **ADR_DRAFTED / ACCEPTANCE_PENDING**. R5 implementation that conflicts with the existing ADR
stays stopped until the user accepts the successor. R1–R4 are unaffected.

Follow-up, 2026-10-16: the user accepted the successor ADR. Its status is Accepted (not
implemented); the old ADR records the partial supersession for separated R5 cells only.

Status: **RESOLVED — successor ADR Accepted by the user 2026-10-16**.

### 5.2 Item 2 — JP runtime completion scope

The user confirmed that item 2 is resolved as recorded in section 4.2 (current completion is
Worldwide5 plus JP7 in the JP development environment; US runtime NOT_RUN and deferred).

Status: **RESOLVED — user confirmed 2026-10-16**.

### 5.3 Item 3 — approval model

The user stated that the programme must be implemented through R5 and that the current per-unit,
per-operation approval model must be resolved so that implementation can continue. A proposal was
given to the user in conversation; no broader approval has been granted yet.

Status: **OPEN — awaiting the user's decision on the approval model**. Until then, the recorded
scoped grants in section 4.3 apply, and R1-WU01 remains paused by the user.

Follow-up, 2026-10-16: the user approved the proposed model and stated that development databases
hold no data worth keeping (they are routinely dropped and rebuilt). Recorded as `one.md` section
1.2A: I for all Work Units R1-WU01..R5-WU20; S for `one.md` section 6 as written; a standing D for
local development/test databases (create, drop, rebuild, migrate, seed, invalidate, rename by
rebuild) with DatabaseSafety still in force; individual user approval remains for the successor
sign-out ADR (after its acceptance, for amendments to it), R5 credential/master-key redistribution,
and anything outside local development/test databases. Jump/Edge writes stay excluded. `two.md`
restore/preservation cases are NOT_APPLICABLE with reason `NO_PRESERVED_ENVIRONMENT`.

Status: **RESOLVED — user decision 2026-10-16**. R1-WU01 may resume under section 1.2A.

## 6. R5 implementation readiness response — 2026-10-16

This section records the response to the current R5 readiness question. It does not alter the
accepted successor ADR and does not authorize credential redistribution, deployment or external
writes.

### 6.1 Effective approval state

- The OP/RP persistence-separation direction is confirmed as the R5 target.
- I applies to Work Units R1-WU01 through R5-WU20 under `one.md` section 1.2A.
- S applies to the persistence and wire shapes in `one.md` section 6 as written; a shape change
  requires a new review.
- Standing D applies to the named local development/test databases for creation, drop, rebuild,
  migration, seed, invalidation and rename-by-rebuild, with DatabaseSafety still enforced.
- Individual user approval remains required for any amendment to the accepted successor sign-out
  ADR, R5-WU03A credential or master-key redistribution/re-encryption, and any operation outside the
  local development/test databases.
- Jump/Edge writes remain excluded. Read-only contract checks do not authorize state changes.

### 6.2 R5 implementation and activation disposition

R5 source implementation and local development/test database construction may proceed within the
effective I/S/D scope. The following remain closed:

1. R5 runtime logout-contract activation before the accepted successor ADR's contract is implemented
   and validated for the target cell;
2. actual credential or master-key redistribution/re-encryption;
3. production, managed-database, deployment, CI, Jump/Edge or other external operations.

The successor ADR is
`adr/first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores.md` and remains
`Accepted` as of 2026-10-16, but it records no implementation or test result. R5 activation remains
gated on R5-WU03A effective role/secret isolation, the required preactivation evidence and the
applicable cell gates.

### 6.3 Restore and disposable-database interpretation

The current development/test scope has no preserved data environment. `two.md` restore/preservation
cases are therefore `NOT_APPLICABLE` with reason `NO_PRESERVED_ENVIRONMENT` for that scope. R5
preactivation still requires clean rebuild, security-state, role-isolation, race and protocol
verification on the approved isolated targets.

`one.md` R5-WU18A currently refers to attack and restore results. Before that Gate is executed, the
wording must distinguish a preserved-data restore rehearsal, which is out of scope for the current
disposable environments, from clean rebuild and security-state verification, which remain required.

Disposition: **R5 SOURCE IMPLEMENTATION GO WITHIN SCOPE / ACTIVATION GATED**.

Follow-up to 6.3, 2026-10-16 (reviewer, at the user's request): `one.md` R5-WU18A (targets and
procedure), R5-WU19 (recovery/stop/approvals), R5-WU20 (evidence) and the section 13.1 R5 row now
separate preserved-data restore rehearsal (NOT_APPLICABLE, `NO_PRESERVED_ENVIRONMENT`) from clean
rebuild and security-state verification, which remain required. R5-WU20 "outage and recovery" means
service recovery after an outage, not a database restore. R5-WU19 approvals now reference the
section 1.2A standing grants instead of a separate S/D.
