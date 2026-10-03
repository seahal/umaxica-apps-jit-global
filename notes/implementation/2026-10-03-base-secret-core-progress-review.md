# Base, app Secret, and Core progress review

## Scope and observation boundary

Prepared on 2026-10-03 (UTC), against Rails HEAD
`bab7343c9de26b86f4ab22ae18ca0074db045394` with substantial uncommitted work.
Implementation was continuing during this review, so this is a reading-time snapshot,
not a stable build or final assessment. No source code or test file was changed.
No tests, runners, browser procedures, migrations, services, or recovery actions
were executed. Existing test reports were read, not reproduced.

The review uses the [integration analysis](../../plans/analysis/base-secret-core-integration.md)
and [acceptance catalog](../../plans/analysis/base-secret-core-acceptance.md).
Its purpose is to identify remaining evidence and coordination needs, not to add
another active implementation ledger or infer progress percentages from file counts.

## What the existing records support

| Area | Reading-time assessment | Evidence and limit |
| --- | --- | --- |
| Shared login/Step-Up boundary | Implementation in progress | The implementation note describes opaque Auth evidence, Base canonical login, scoped admission, Passkey completion, Email OTP, and cancellation. It explicitly says the ledger is incomplete. |
| Base guidance | Changes present; completion unestablished here | Dirty RootsController and associated document paths are present. Their existence does not establish each surface's complete Sign/Jump/return journey. |
| app Secret rebuild | Completion evidence not located in inspected material | File inventory still includes old credential kind/status and Emergency operation files. This does not prove they are executed or that all new work is absent; it identifies a need for the final app-only retirement inventory. |
| Core browser boundary | Decision/doc changes present; runtime outcome unestablished here | Core-related ADRs are dirty, and the TanStack boundary ADR is untracked. Edge implementation and actual browser/path ownership were not inspected. |
| Login continuation | Still requires accepted-contract evidence | Neither an existing route nor a changed ADR establishes successful continuity across access expiry. Keep the conditional refresh gate separate. |
| Overall regression | Existing record reports a failed run | Foundation evidence reports 12,651 runs, 218 failures, 45 errors, and one skip, preceding later changes. It is not a current rerun or proof those failures still exist. |
| OTP observability | Open mandatory remediation in the recorded decision | The remediation ADR records a synthetic diagnostic recovering OTP-bearing message data from notification/DEBUG paths. Production exposure is explicitly unconfirmed; no fix is claimed. |

Sources:

- [Foundation evidence](../../evidence/2026-10-03-auth-boundary-foundation-7P4K.md).
- [Authentication implementation context](2026-10-03-auth-boundary-step-up.md).
- [OTP remediation decision](../../adr/otp-observability-secret-exposure-remediation.md).

Foundation evidence also reports passing focused selections. Those are useful
attributed observations for their particular working-tree slices, not this review's
test results or substitutes for whole-lane acceptance. The note says COM/ORG complete
journeys, legacy caller retirement, and some continuation/fault coverage remain open.

## Closure needs to retain in the existing implementation workflow

1. **Reconcile current failures.** For the recorded full-suite failures, identify
   current disposition as fixed, still failing, obsolete expectation with an accepted
   replacement, or unexamined. Later focused passes cannot close unrelated failures.
   This review does not request or execute a rerun.
2. **Resolve APP Email JSON deliberately.** The note records that its success-format
   change was deferred and the existing renderer expects token data. Do not infer
   an accepted replacement from the evidence-only Auth design. Track the exact
   affected API contract separately from working HTML/Passkey paths.
3. **Keep OTP disclosure open.** The newer note/ADR escalates comprehensive handling;
   an earlier evidence paragraph still says isolated redaction approval was pending.
   Interpret the newer decision as mandatory remediation, not acceptance of a
   particular event schema or evidence that exposure was fixed. Closure needs the
   owning implementation's remediation evidence, not another planning document.
4. **Expose Secret lane progress independently.** Request the existing workstream's
   concrete issuance/reservation, management, 2/1/0, claim/receipt, outbox, and purge
   milestones. An expanded shared Step-Up patch is not evidence those milestones
   are implemented. Keep old app data retirement distinct from preserved org Emergency.
5. **Separate Core and external readiness.** Retain separate Rails/Edge identities,
   browser observations, accepted continuation contract, and external path/cache
   gates. Do not let an unrelated refresh decision stop independent Base/Secret work.

These are consolidation needs, not newly authorized implementation changes. Do not
close them solely from this note or overwrite a concurrently maintained work ledger.

## Documentation reconciliation found during reading

- The OTP ADR and implementation note link a new document under `plans/active/`,
  while `plans/README.md` prohibits a parallel active implementation backlog. Preserve
  the concurrently edited files; their owner should reconcile placement and links
  under the existing issue/plan policy without losing mandatory remediation tracking.
- The historical integrated backlog contains earlier verification snapshots. Use
  dated evidence for the exact checkout, and do not substitute an older green run
  for the recorded later failure or the current unverified working tree.
- Earlier evidence about deferred isolated OTP redaction and the newer mandatory
  remediation decision represent different stages. Mark the historical statement's
  scope when maintaining that evidence; do not rewrite historical results as a fix.

## Practical completion report

Use the existing acceptance catalog's per-area results and add only: the current
owner/workstream, concrete completed milestone, next unresolved prerequisite, and
supporting evidence. Avoid a single "still implementing" label hiding different
lane states. Shared files need coordinated ownership because this working tree
contains concurrent authentication, controller, migration, and documentation changes.

The cause of implementation duration cannot be established from these records alone.
This review identifies visible unfinished contracts and evidence gaps, not elapsed
time estimates, agent activity, or a claim that implementation is stalled.
