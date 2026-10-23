# Authentication cycle completion

Status: implementing

## Purpose and authority

The user requested implementation of every missing part of `two.md` on 2026-10-23.
This change delivers the complete authentication cycle, preserving existing unrelated work.
The detailed definitions remain in the cycle's working document `two.md`; owner decisions are
in `one.md`, acceptance cases and gates in `three.md`. Later explicit decisions supersede earlier
definitions, including D-159 (fresh databases), D-168 (cycle-scoped destructive changes), D-170
(Bootstrap excluded), and D-172 (authority-stop v2 accepted). These documents must be retained
in the generation-numbered archive when the cycle closes.

## Scope and acceptance

- AC-1: Every in-scope WU-01 through WU-44 definition, sub-unit, named artifact and acceptance
  case is implemented and verified against current code. WU-21 is merged into WU-43;
  WU-28 remains outside this cycle under D-170. Superseded definitions are explicitly identified.
- AC-2: Applicable G-1 through G-22 gates and standing checks S-1 through S-4 in `three.md` pass,
  with requirement-level test/evidence mapping. Historical evidence is reviewed rather than
  accepted as proof of current completion. Unverified cases keep this spec open.
- AC-3: APP, COM, ORG, Auth, Visa and each RP preserve their ownership, session, state and
  credential boundaries. No compatibility aliases or silent failure paths are introduced.
- AC-4: Schema changes use reviewed Rails migrations and generated dumps; development/test
  migration execution and `bin/rails db:verify_no_schema_drift` are recorded. Approved data loss
  is limited to this cycle; no production/external action is implied.
- AC-5: Current ADRs, security docs, durable checklists and affected Mermaid axes match the
  delivered behavior. Tests cover public success/refusal/ownership/concurrency/expiry boundaries.
- AC-6: The full goal remains open until all required evidence exists; passing narrow tests does
  not substitute for cycle acceptance. Remaining work is tracked in `tasks.md`.

## Delivery order

Follow `two.md` 6.6 and its later amendments: independent work and baseline reconciliation;
sign-up Binding/curfew/cleanup prerequisites; sign-up unification and expiry; Visa separation;
revocation, relays, cancel/switch, Sentry, logout, refresh and runtime isolation; authority-stop
v2 and durable notification; final cross-unit acceptance. Independent WU-24e cleanup and lock
repairs may proceed before schema work as explicitly allowed by D-143.

The baseline is captured with the existing dirty worktree before implementation. Existing
implemented portions still require acceptance reconciliation. Changes are local; deployment and
external writes require separately established authorization.
