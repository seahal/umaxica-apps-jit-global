# Authentication work-unit handoff residuals

## Status

Open handoff ledger. This records the disposition of the work units and acceptance IDs in the
ignored `two.md`; it does not authorize implementation beyond current accepted specs, ADRs and owner
decisions. The source design is preserved as a non-normative snapshot at
`plans/archive/0003-authentication-handoff-work-logs/two-design-work-log.md`.

## Work units

| Work unit | Handoff status | Evidence and next step |
|---|---|---|
| WU-0 | Done and verified | Baseline failure inventory is `plans/2026-10-28-baseline-failing-tests.md`; refresh comparisons are in the current H-2 evidence. |
| WU-0R | Open | Fresh-VM fixture/reference-data construction has not been verified. On the receiving VM, run the documented `bin/setup` and `db:seed` path, then record the source and foreign-key-safe setup for the affected test references. |
| WU-P0 | Done as an owner-approved design decision; implementation unverified | Owner decisions and the ADR/shape review are recorded in `zero.md` and the archived two.md. Do not run destructive migrations or implement the old Preference shape; continue under `plans/backlog/2026-11-07-experience-consent-affinity-redesign.md`. |
| WU-1 | Open | The issuer normalization is implemented and its focused tests/caller trace are recorded; AC-4 is complete. The strict b6 route comparison still has AC-3/WU-1 rows without a documented disposition, so this unit remains open with the detailed route evidence. |
| WU-2 | Retired by D-51 | No temporary old-API repair is required. The new behavior is tracked by AC-20b and the Experience/Consent/Affinity backlog. |
| WU-3 | Open | The ten org Support COM enforcement routes are removed, and the current route contract passes. The task-start route delta is exactly EQ-1. Strict b6-to-result comparison is itemized but remains open for 10 undocumented host rows and a four-row Core Preference DBSC documentation conflict. |
| WU-4 | Open | Current eager load passes; inherited anonymous COM Preference, content, Publishing, health and shared-job checks are recorded. CI still contains retired COM auth/database names in a read-only file, and accepted enforcement/identifier guidance conflicts with current runtime. |
| WU-5 | Open; destructive execution not authorized here | COM database and table removal still requires the recorded B-5 approval and a reviewed recovery plan. No destructive DB operation was performed for this handoff. |
| WU-6 | Open | Current full `bin/rails test` attempt stopped before test execution because PostgreSQL host `primary` did not resolve; the earlier 308-failure/86-error snapshot and 316 baseline-absent IDs remain historical evidence. Current test failure/skip comparison and DB catalog recheck are unavailable. CI COM/visitor auth variables remain in a read-only file, and 48 baseline-relative deleted test files still need per-file history attribution. |
| WU-7 | Superseded by the three-unit redesign | Use `plans/backlog/2026-11-07-experience-consent-affinity-redesign.md`; do not implement the old COM Preference shape from two.md. |
| WU-8 | Retired | The former key-separation-only unit was withdrawn; no separate work remains. |
| WU-A1 | Open | Reconcile current sign-in classification and stop checks with the active authentication specs; H-2 evidence remains failing. |
| WU-A2 | Open | Sign-up transitions, D-52 refusal and cancellation require a per-acceptance review against the current flow contract and test failures. |
| WU-A3 | Open | D-53 replacement and switch binding need a current public-flow review; the selector remains outside the sign-in state machine per `plans/backlog/2026-11-06-selector-state-machine-connection.md`. |
| WU-A4 | Open | Cross-database authorization and consume order need a complete writer/receipt inventory and failure-order verification. |
| WU-A5 | Open | Passkey slot, ORG external ID, audit, delivery and display acceptance remains incomplete; continue from the owning credential specs. |
| WU-A6 | Open | ORG Normal/Standby operation scope needs a current authorization and refusal-path review; unresolved failures are in H-2 evidence. |
| WU-A7 | Open | Withdrawal state and temporary fail-closed behavior are not fully verified; carry remaining recovery/erasure work through `plans/backlog/2026-11-06-withdrawal-and-recovery-entry-gaps.md`. |
| WU-A8 | Open | Base identity resolution and RP authorization remain unresolved; use the existing Base RP backlog and do not infer a cross-cell resolver contract. |
| WU-A9 | Open | Result/HTTP and social restart behavior is not fully verified. O-9 connection remains explicitly open in `specs/op-mediated-step-up/`. |
| WU-A10 | Open | Credential-version writers and root revalidation require a complete, lock-ordered writer inventory and tests. |
| WU-A11 | Open | Non-Base RP Jump behavior remains deferred; resume from `plans/backlog/2026-10-16-jump-rp-routes-and-continuation-redesign.md` after WU-A8. |
| WU-A12 | Open | Continuation simplification and rollout to other RPs remain deferred with WU-A11 and the accepted browser-flow cookie work. |
| WU-A13 | Open | Age-checking release conditions and supported registration ages require owning-function inventory and release evidence. |
| WU-A14 | Open | Remaining boundary, translation and attribute defects need per-file triage after the core units are reconciled. |
| WU-9 | Open; not connected | Visa does not yet connect the approved O-9 flow. Complete `specs/op-mediated-step-up` units 6b/7 and resolve its recorded prerequisite before wiring O-9. |
| WU-X1 | Open | Route, settings and translation cleanup remains after the applicable work units; identify each surviving route from current ownership before removing it. |
| WU-X2 | Open | The BL-14/BL-20 and not-run acceptance inventory is incomplete; classify each public boundary and retain unverified rows. |
| WU-E | Open; deferred | Edge/Jump/Away/xt acceptance was not run on this machine. Fix the Rails prerequisites, freeze the external reference and use the receiving environment's tunnel/browser evidence. |

## Acceptance IDs

The 51-row AC status matrix is in `plans/2026-11-07-handoff-status.md` §H-4. AC-20 is retired by D-51;
AC-20b is its replacement. All other ACs stay open unless that matrix records a verified bounded
slice. A passing focused test proves only its named boundary, not the whole AC or Work Unit. The
latest full-suite result and per-file classification are recorded in the linked H-2 evidence.

## Resume rule

Before resuming an open unit, map its ACs to the current accepted spec/ADR and current owner decision,
confirm the relevant source behavior, and run the narrowest public-boundary test. Preserve unresolved
items as open; do not treat this handoff ledger or the archived Japanese working document as a new
implementation authorization.
