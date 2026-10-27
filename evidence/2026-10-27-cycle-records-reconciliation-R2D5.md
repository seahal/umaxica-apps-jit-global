# Cycle records reconciliation (A-6, A-8)

- Commit: `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`; dirty worktree with the uncommitted cycle
  changes.
- A19: `PARALLEL_WORKERS=1 bin/rails test test/initializers/locale_bundle_integrity_test.rb
  test/initializers/locale_test.rb` — 18 runs, 187 assertions, 0 failures. A19-1 (duplicate key) and
  A19-2 (en/ja leaf keys) marked Passed; A19-3 (`ri=jp` vs `ri=us` request text) not run.
- A38: the 13 test files matching `D-135|SignUpArtifactCleanup|sign_up_passkey_termination|A38-` —
  259 runs, 2,253 assertions, 0 failures (the earlier `SignUpPasskeyTerminationHttpTest:349` failure
  did not recur). A38-1 … A38-4 marked Partial: case-to-test mapping was not recorded.
- A20-9 marked Passed with the owner decision (Employee Number = `Operator.public_id`).
- A-8: A36-*, A37-*, A41-* marked "Moved to `docs/backlog/2026-10-26-pre-deployment-checks.md`
  (D-194)"; the COM A34-2 cases were already recorded as out of cycle in the A34-2 row.
- `two.md` §6.5: WU-19 and WU-38 rows now point at their acceptance state; WU-26 marked withdrawn
  (D-196). `three.md` gained "Owner manual acceptance, 2026-10-27 (APP Google)"; `ten.md` §5 marked
  deferred.
- WU-39 (docs vs code) was not re-audited in full. Discrepancies found during this session and still
  open:
  1. `two.md` (~line 711) says the sign-up Flow uses its own TTL; `SignUpFlowTicket` caps a new Flow at
     the Admission curfew (evidence G2T8).
  2. `three.md` A12-5 expects refusal when Fetch Metadata is missing; the Visa confirmation renders the
     non-consuming form (owner decision pending, D-197).
  3. D-47 says one status for every cause; `SignInPathRefusalValue` (D-73) answers dependency
     refusals with 503 and the backend-unavailable text.
  4. `ten.md` A14-10c and §3.3 disagree on the enqueue-failure response (evidence H8M2).
  5. ORG Entra shows distinct refusal texts, contrary to D-47 (wedge-test evidence X7K2).
