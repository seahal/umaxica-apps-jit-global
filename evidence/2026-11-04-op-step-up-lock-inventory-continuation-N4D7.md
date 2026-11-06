# OP-mediated Step-Up lock inventory continuation

Date: 2026-11-04

## Scope

Continued the O-10 lock-order source review against `b30345216886c98af1f04cbd434f067f12decf01`. The
worktree was extensively modified before and during this continuation. No application source, tests,
or database state were changed. The only artifact edit was the working lock inventory.

## Observations

Re-ran the bounded lexical intersection over Ruby files in `app/`, using lock expressions
`with_lock`, `.lock`, `lock!`, and `with_cycle_lock`, intersected with OP/Auth model markers. It
returned 88 files. The updated `specs/op-mediated-step-up/contracts/lock-order-inventory.md` now
names all 88 paths by full path and gives bounded direct-path dispositions for the 42 previously
unnamed files.

Source inspection found no new simultaneous OP-row-before-principal-row edge in those 42 bounded
direct paths. Several source-commit issues remain separate from lock inversion: passkey and TOTP
registration consume OP authority before the Zenith credential transaction commits; APP contact
finalizers consume OP evidence before the source binding completes; ORG contact finalizers keep OP
open through the source write but lack a demonstrated durable cross-store recovery receipt.

A follow-up call-site scan found a separate O-10 conformance gap outside the lexical candidate
expression. `StepUpEvidenceVerifier` locks OP device/root/grant rows but does not lock the actor.
The enforcement case apply/end operations, `EnforcementAppeal#resolve!`, and the support
case-creation controller begin a Case/Appeal source transaction before calling the verifier, without
an explicit Operator row lock at those call sites. No inverse OP-to-Operator edge was established,
but the accepted actor-first requirement is not demonstrated; the complete graph remains open.

The current `five.md` SHA-256 remains
`ab191cb1d6d1099dbf38d6c4c85faa68b5850733ba3483e9e2425860d211ab45`. Its C9-listed closed slices are
already implemented and verified. C0 still limits work to those individually closed slices;
unresolved C5 decisions, the accepted invalid-browser-credential recovery conflict, and the
pre-existing dirty schema dump prevent further safe feature implementation in this continuation.

## Verification disposition

No tests were run and no database was accessed. The source findings above are static inspection
only; they do not establish runtime lock behavior or complete interprocedural coverage. O-9 remains
disconnected pending review of `specs/op-mediated-step-up/contracts/o9-visa-roundtrip-design.md`.
Q-1, contact-registration, and O-10 receipt shapes remain review-gated.

HEAD: `b30345216886c98af1f04cbd434f067f12decf01`; worktree extensively uncommitted.
