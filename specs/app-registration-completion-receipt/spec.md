# APP registration completion receipt

Status: implementing

## Authority and scope

On 2026-11-02 the owner approved the existing receipt shape and local migration and assigned issue 1
to Codex. Implement `two.md` §12.4 for APP Email, Telephone, Google and Apple. Preserve unrelated
work. Callback-generation persistence belongs to Claude Code; ORG, COM, backfill and external or
production operations are excluded. The approved shape is recorded in
`plans/2026-11-01-wua2-registration-completion-receipt-shape-review.md`.

## Acceptance

- AC-1: All four methods persist exactly one immutable receipt in the source registration/audit
  transaction. Actor, Flow and verified method must match; no receipt is inferred for historical
  Clients.
- AC-2: Authorization precedes source mutation. Source actor locking precedes OP SID/parent/Flow
  locks, and the parent remains locked through the source commit outcome. Cancellation that wins
  before that commit prevents registration.
- AC-3: After source commit and OP failure, reconciliation uses the exact receipt to complete only
  FINALIZING through the existing legal edge, even after expiry. Terminal contradictions raise.
  Registration, credentials and audits survive later cancellation, expiry and cleanup.
- AC-4: Secret lifecycle and direct termination preserve completed registration credentials and
  resolve the Flow before activation. No account-status inference or new login/recovery protocol.
- AC-5: Local additive migrations and generated dumps match the approved shape. Down refuses
  nonempty completion history. Record migration and schema-drift observations; no production action.
- AC-6: Public tests cover success, wrong ownership/method, replay, source rollback and post-source
  failure/recovery, plus cancellation and cleanup boundaries. Update diagrams and current contracts.

## Execution

Create migration-owned tables/references and receipt domain operations; make the three source
writers use a shared ordered commit boundary; reconcile before destructive or expiry decisions;
exercise focused tests, generated schema verification, lint and the wider authentication boundary.
Any unverified acceptance remains explicit in evidence.
