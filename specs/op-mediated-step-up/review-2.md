# Review 2: OP-mediated step-up, revision 2

Date: 2026-11-03

Disposition: substantial improvement; four targeted corrections remain. Proceed with the
document-only contract/inventory work of unit 0. This review does not accept the spec, amend an ADR
or authorize implementation. No new product-policy decision is requested by these findings.

Reviewed the revision-2 request at the end of `zero.md`, current `spec.md`, `plan.md` and revised
consolidated requirements items 21-22. Rechecked selected current implementation boundaries and the
rules concerning lifecycle transitions, Browser RP authentication and stable acceptance IDs. The
prior review remains historical; this document records its disposition and the delta.

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`, with extensive existing uncommitted changes.
Reviewed SHA-256 hashes:

- spec: `ec98f054565f549de91479995a13454ecc6ceb8acf0afa298dc634c23e33ad1c`.
- plan: `20f895cd78f5f16dfd654ee60b1b315b296b11df81f04bd5f0e25130aee5c9f1`.
- consolidated requirements: `d265ce8576f21b1b81431765b01bce785f57e602120ccaddb9fe092484aa6f90`.

## Findings

### RV-71 — High — The global refusal definition erases distinct protocol/security outcomes

Evidence: `spec.md:43`, AC-9 at 72-74, AC-10 at 77-79 and AC-13 at 87-92. Line 43 makes an otherwise
unspecified refusal an `insufficient_user_authentication` challenge. AC-13 uses that unqualified
term for foreign browser, subject/issuer mismatch, PKCE mismatch, expired flow, logout and stale
completion. AC-20/21 do likewise for invalid proof and terminal state refusal. Those conditions do
not all mean that a valid RP session merely needs step-up.

Trigger/impact: after logout or invalid callback correlation, the default directs the client towards
step-up even though its original session or transaction is invalid. This conflicts with AC-9's
distinct missing-login recovery and may create restart loops or tempt an implementation to recover
an invalid transaction as a new ceremony. At an OP authorization/token boundary, errors also have
their own OIDC/OAuth response contract, rather than the resource-server challenge.

Proposed disposition: scope the default challenge to a protected-resource request whose ordinary
authentication and authorization prerequisites are valid but whose step-up evidence is absent or
insufficient. In unit 0 define a boundary-specific outcome table: resource challenge, missing login,
authorization denial, invalid provenance/CSRF, invalid callback/code/binding, terminal ceremony
conflict, and dependency failure. Preserve existing safe error handling where applicable. Do not
turn CSRF, issuer, PKCE or proof-binding errors into instructions to resume that transaction.
Current missing-login handling already has distinct branches at
`app/controllers/concerns/browser_rp_authentication.rb:414-433`; preserve that distinction.

This is consistent with [RFC 9470 section 3](https://www.rfc-editor.org/rfc/rfc9470.html#section-3)
and [OIDC Core section 3.1.2.6](https://openid.net/specs/openid-connect-core-1_0.html#AuthError):
the resource authentication challenge and authorization response errors are separate boundaries.

### RV-72 — Medium — Audit of refusal conflicts with the terminal-state acceptance wording

Evidence: AC-15 at `spec.md:99-102` requires durable refusal facts and duplicate handling; AC-21 at
114-117 rejects stale/duplicate/conflicting requests without an extra audit outcome. `plan.md:22`
also says each refusal writes a fact, and unit 2 at 51-55 tests each outcome.

Trigger/impact: a duplicate completion is refused. Recording the refusal appears to violate AC-21,
while recording nothing appears to violate AC-15 and the plan. Implementers cannot derive one
assertion set from the current wording, and suppressing all rejection evidence would weaken the
intended Accounting boundary.

Proposed disposition: distinguish one authoritative issuance/installation/terminal-transition fact
from a separately defined rejected-attempt observation. A replay must not create another success or
another terminal transition. Specify whether refusal attempts are individually recorded or
deduplicated, their safe correlation and their persistence-failure policy. For unknown delivery,
record the component's observed uncertainty, not an invented delivery or installation fact. These
are unit-0 contract details; no anomaly-detection feature is required.

### RV-73 — Medium — AC-20 has been reassigned to a different requirement

Evidence: revision 1's AC-20 was current documents/ADRs/diagrams, as preserved in `review-1.md`'s AC
assessment. Revision 2 uses AC-20 for DBSC (`spec.md:111-113`) and moves the former requirement to
AC-22 at 118-120. `specs/README.md:35-40` requires stable local IDs.

Trigger/impact: an existing review or future evidence citation to AC-20 changes meaning without
changing the cited identifier. That loses traceability even though the content of both criteria is
useful.

Proposed disposition: preserve AC-20 for documentation, keep AC-21 for terminal-state behavior, and
allocate AC-22 to new DBSC acceptance. Update revision-2 plan references and disposition notes
accordingly, without rewriting the historical review. The assessment below uses the current
revision-2 numbering only and makes no claim that this reassignment was already fixed.

### RV-74 — Medium — AC-6 must order responses by causality, not by operation type

Evidence: `spec.md:59-62` says a late ordinary response never overwrites a step-up installation "and
the reverse"; `plan.md:19-21,66-70` delegates ordering to the installer. Current installation
compares a reserved generation with the live generation at
`app/operations/rp_refresh_committer.rb:90-103`.

Trigger/impact: a legitimate refresh issued after completed step-up must be installable and retain
that event. Likewise, a step-up initiated after a completed refresh must be installable. A symmetric
prohibition based on whether one response is ordinary and the other step-up would reject these valid
orderings. Arrival time alone cannot decide which response is superseded.

Proposed disposition: state that a response whose initiating installation generation/transaction has
been superseded cannot replace the current credentials, regardless of operation type. Distinguish
overlapping attempts from an operation initiated after its predecessor completed. Test both arrival
orders of overlapping work, plus sequential refresh-after-step-up and step-up-after-refresh. Account
for the rotated refresh credential before deciding to install a late response; generation
bookkeeping alone does not undo an OP rotation. This refines AC-6, not the agreed fixed-deadline or
refresh-rotation policy.

## Disposition of review 1

"Addressed in requirements" is not verification of implementation. Unit-0 obligations are legitimate
next design work, not an instruction to build the feature to prove acceptance.

| Prior finding | Revision-2 disposition                                                                                                                                                                                                                      |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| SU-R1         | Addressed in requirements: both Base surfaces are now included; retained shared consumers are explicit in spec:17-24 and consolidated items 21-22. Inventory must still define the actual removals.                                         |
| SU-R2         | Addressed in requirements: AC-12/14 now distinguish pre-commit and committed outcomes and unavailable old refresh credentials. Preserve the reported owner tradeoff; do not reopen it. Apply RV-71 to the refusal taxonomy.                 |
| SU-R3         | Addressed in requirements: AC-13 defines the exact initiating Identity/session/grant and no new login. Concrete carrier and separate-owner commits belong in unit 0.                                                                        |
| SU-R4         | Addressed in intent: snapshot consistency is explicit in AC-6. RV-74 clarifies response ordering; locked event and installation mechanisms remain unit-0 work.                                                                              |
| SU-R5         | Addressed in requirements: DBSC is now explicit acceptance and units 3/4 verify it. No proposed-flow or real-browser DBSC behavior has been verified.                                                                                       |
| SU-R6         | Addressed in intent: essential event time, parser/error classification and delayed Discovery are included. Complete the exact request and combined-form behavior in unit 0; RV-71 keeps errors boundary-specific.                           |
| SU-R7         | Addressed in requirements: independent authorization, allowed methods, exclusive deadline, zero extra skew and explicit E2 amendment are stated. The class remains a candidate until the contract fixes it.                                 |
| SU-R8         | Addressed in requirements: unchanged bootstrap anchor, start provenance and terminal/replay/attempt controls are explicit. Finish the cancel/complete winner and attempt accounting in unit 0.                                              |
| SU-R9         | Addressed in intent: audit moves before activation and includes failure categories. RV-72 resolves the remaining duplicate/refusal ambiguity.                                                                                               |
| SU-R10        | Addressed in plan: contract first, one non-activatable change, narrow baseline rather than unrelated cleanup gate, build/locales and retained-flow tests included. Treat units as development slices, not individually deployable releases. |
| SU-R11        | Addressed in plan: shapes, object placement, identifier classification and lifecycle ownership precede additive migrations. No concrete new schema or carrier is approved by this review.                                                   |

## AC-1 through AC-22 delta assessment

| Current AC | Assessment                                                                                                                                        |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1          | Independent checks are now explicit; test reuse with at least two authorized operations.                                                          |
| 2          | Sign-in and bootstrap are correctly separated; retain the original-login-anchor regression.                                                       |
| 3          | Scope and authorization independence are clear; classify foreign-session refusal under RV-71.                                                     |
| 4          | Exact comparison is clear; finalize the candidate class in unit 0 and test non-normalization.                                                     |
| 5          | Formula and zero extra window skew are decidable; distinguish a broken clock/dependency from insufficient proof.                                  |
| 6          | Snapshot requirement is clear; refine causal response ordering under RV-74.                                                                       |
| 7          | Rotation/old-refresh refusal are explicit; earlier access acceptance is still conditional on live session, binding, authorization and AC-19.      |
| 8          | Public request/output and Discovery intent are clear; replace "defines the behavior" with the completed unit-0 tables before implementation.      |
| 9          | Resource challenge is clear; narrow the global refusal definition under RV-71.                                                                    |
| 10         | Browser types, provenance, no GET writes and return-target validation are specified; concrete routes/UI/error behavior remain unit-0 work.        |
| 11         | Shared public evidence decision is clear; shared implementation is a structural review requirement.                                               |
| 12         | Commit partitions fix the earlier contradiction; "unchanged" refers to effects of the failed attempt, not prevention of concurrent expiry/logout. |
| 13         | Good explicit session capability and negative cases; assign their response categories under RV-71.                                                |
| 14         | Credential-loss consequence is now explicit; a later refresh requires an actually available current credential and never replays a lost exchange. |
| 15         | Broader durable outcomes are now covered; resolve duplicate/refusal semantics under RV-72.                                                        |
| 16         | Server-side current-policy checks at both acceptance boundaries are explicit.                                                                     |
| 17         | Scope is fixed to both Base ordinary step-up paths while retaining other purposes.                                                                |
| 18         | Any allowed method plus independent no-lockout is unambiguous; follow the recorded policy amendment.                                              |
| 19         | Existing revocation remains effective; no extra window-closing feature is required by this review.                                                |
| 20         | DBSC requirement is substantive and useful; preserve its requirement but correct its ID under RV-73.                                              |
| 21         | State-machine safety is explicit; specify audit distinction and winning transition in unit 0.                                                     |
| 22         | Documentation deliverable is appropriate; restore the original requirement ID under RV-73.                                                        |

## Direct answers on the plan and Visa ORG

Yes, Visa ORG needs the same enabled-realm request parsing, essential-class enforcement, evidence
acceptance, issuance and error semantics in unit 3. Base ORG is now an ordinary step-up consumer; it
cannot use APP's issuer, client registration or grant store as a substitute. Rechecked
`app/controllers/visa/org/authorization_base_controller.rb:234-242`: its parameter allowlist still
lacks `claims` and `acr_values`, as does APP at
`app/controllers/visa/app/authorization_base_controller.rb:269-277`. Unit 3 already names both; this
should be a required parity check, not an optional follow-up. Realm trust boundaries remain.

The revised 0-7 dependency order is reasonable for one integrated, non-deployable-in-slices change.
Unit 0 must finish the protocol and shapes before unit 1. Unit 2 provides audit ownership before
units 3/4 activate writers; units 3/4 share the accepted contract; unit 5 integrates clients; unit 6
migrates consumers; unit 7 checks the complete result and metadata. Metadata alone is not an
activation gate: do not deploy unit-6 wiring/removal separately from the complete chain. No
compatibility runtime or new feature flag is requested here. Update diagrams with their owning
implementation changes in that final coherent change.

Do not confuse persistence prerequisites with a demonstrated migration path: adding NOT NULL context
to existing rows without a backfill may require a new purpose-owned table or another explicit
additive shape. Unit 0 must select it; this review authorizes no backfill or destructive operation.
Existing-session guards were rechecked at `app/services/oidc_token_exchange_coordinator.rb:859-865`
and `app/operations/rp_callback_committer.rb:51-72`; they remain and require a distinct completion.

The reported 652-test residue reproduction is acknowledged as Claude's observation. It was not rerun
or independently verified here; removing it as an acceptance gate is appropriate. The earlier review
did not claim the residue could not be reproduced, only that its cause had not been reproduced in
that review session.

## Next step and verification limits

Correct RV-71 through RV-74 and prepare the unit-0 contract/inventory/ADR drafts. No further product
clarification is needed to perform that document work. Formal acceptance remains the owner's role;
missing technical shapes are not a reason to ask the owner to design them.

No application, test, spec, plan, consolidated-requirements or prior-review files were changed.
Tests, migrations, database cleanup, providers and live browser/DBSC flows were not run. This is a
static follow-up review, with new findings recorded here and a short response appended to `zero.md`.
