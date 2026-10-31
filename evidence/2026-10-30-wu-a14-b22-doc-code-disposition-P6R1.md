# WU-A14 BL-22 doc/code discrepancies disposition

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree carried the uncommitted
  WU-3..WU-7, WU-A1, WU-A6, WU-A13 and earlier WU-A14 slices of this cycle plus these changes.
- Requirement: R-AU-27 of `one.md` (`two.md` section 3.11 WU-A14 row): the three named
  doc/code discrepancies ("sign-up Flow keeps its own expiry", "D-47 same status", "D-73
  dependency failure 503") must be aligned on the document or the code, one by one. The
  starting catalogue comes from `evidence/2026-10-27-cycle-records-reconciliation-R2D5.md`
  (items 1, 3, and 5 below) plus the characteristics it found.
- Disposition per discrepancy:
  1. Sign-up Flow expiry — the current code side is the truth and already self-documented:
     `SignFlow#default_ttl` carries the Binding-curfew comment and
     `SignUpFlowTicket#cap_expiry_at_admission_curfew` caps a new Flow at the Binding `curfew_at`
     (REQ-CURFEW 5). Aligned with a new public model-boundary test that creates a real sign-up
     flow through the admission factory and asserts `expires_at == binding.curfew_at`
     (`test/models/client_sign_up_flow_test.rb`, "a newly created sign-up flow is capped at its
     binding curfew"). The old-archive claim is history and was not edited.
  2. D-47 "one status for every cause" versus the D-73 class catalogue, including the ORG Entra
     distinct refusal texts — superseded contract, already recorded in the requirements: R-AU-23
     (`one.md`, 2026-10-28 owner decision OQ-8 B) amends D-47 for the reason-specific guidance and
     keeps D-52's uniform 409; RV-34 (R-AU-24) fixed the result vocabulary on
     `adr/root-login-establishment-boundary.md` and `SignInPathRefusalValue::RESPONSES`
     (definitive/ownership 400, dependency 503, internal 500 — one status per class, never per
     reason). No current `docs/` or `adr/` file carries the uniform-status claim (searched), the
     catalogue has its value tests, and the old documents stay archive history. Nothing to change
     in code or current docs; the disposition is recorded here.
  3. `three.md` A12-5 vs D-197 and `ten.md` A14-10c — those documents are not in this cycle's
     tree as current requirements (the present `three.md` is the Claude QA draft with no A12-5
     row; no `ten.md` exists), so they have no current artifact to align; both were
     owner-pending items in the recorded session and stay pending with the owner.
- Results:
  - `bin/rails test test/models/client_sign_up_flow_test.rb`: 4 runs, 25 assertions,
    0 failures, 0 errors (includes the new cap test alongside the R-AU-46 locale tests).
  - `bin/rails test test/values/sign_in_path_refusal_value_test.rb`: 4 runs, 109 assertions,
    0 failures (the class catalogue's public contract).
  - RuboCop clean on the touched test file after style correction.
- Remaining unclassified: the BL-19 defect candidates (the 406 browser-block one is already
  dispositioned in the archive as F6 "Closed, ignore"; the rest lack their per-item catalogue in
  this tree), BL-23's host-default decision, BL-22's owner-pending D-197 row.
