# App / Org authentication boundary audit

- Date: 2026-10-27 UTC.
- Commit: `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`.
- Worktree: extensive pre-existing uncommitted application, authentication, test and ADR changes
  affected these observations. These results describe that local worktree, not HEAD alone.
- Scope: App/Org RP–Visa OP–Auth; Com RP/OP acceptance excluded. No implementation was edited.
- Detailed requested report: appended to ignored, pre-existing `nine.md`, beginning at line 1275.

## Executed verification

1. `bin/rails test test/integration/sign_entry_exit_com_org_flow_test.rb test/integration/sign_entry_exit_flow_test.rb test/policies/org_standby_access_policy_test.rb`:
   15 runs, 120 assertions, zero failures/errors/skips. Com cases confer no Com acceptance verdict.
2. `bin/rails test test/policies/standby_authentication_context_policy_test.rb test/controllers/auth/org/verification/emergency_step_up_prohibition_test.rb test/services/oidc/authorize_service_test.rb test/services/oidc/authorization_cancel_state_test.rb test/integration/visa_authorization_continuations_test.rb`:
   48 runs, 443 assertions, zero failures/errors/skips.
3. `bin/rails test test/resolvers/oidc_authorize_request_resolver_test.rb test/integration/sign_up_phase_regression_app_test.rb test/security/invariants/acceptance_wu02_base_op_session_isolation_test.rb test/services/acceptance_wu02_visa_base_issuer_test.rb`:
   18 runs, 176 assertions, zero failures/errors/skips.
4. Temporary public-boundary probes:
   `bin/rails test /tmp/nine_audit_probe_test.rb /tmp/nine_org_audit_probe_test.rb`:
   5 runs, 28 assertions, 4 failures, zero errors/skips. Expected-refusal/scope assertions failed,
   reproducing the contract violations below. Temporary files are not permanent regression coverage.
5. Added a pre-refusal page control to the temporary refusal probe, then ran
   `bin/rails test /tmp/nine_audit_probe_test.rb -n /B_stale/`:
   1 run, 6 assertions, zero failures/errors/skips. Diagnostic output established page 200 before
   refused Cancel, HTTP 400 with `auth_sid` deletion, then page 400. The probe's green assertions
   covered DB/HTTP preservation; they did not assert the desired continuity behavior.

An initial concurrent invocation of run 2 was blocked by the test-database process lock; its
successful result above came from an isolated rerun. Initial temporary script generation used
unavailable `python`; rerunning with `python3` generated the probes. Rails focused tests booted
with Ruby 4.0.9 / Bundler 4.0.23 and configured PostgreSQL 18.6 test databases.

## Observed failures

- A03: App options returned 200 with a real challenge. Saved Cancel and Switch each returned 303
  and cancelled the Ceremony. Cancel committed parent `pending` → `canceled` at Visa and generated
  RP `access_denied`. Switch retained pending parent and increased its Admission Binding count 1 → 2.
- A07: real Entra strategy verification against synthetic signed ID token/JWKS reached Passkey-wait
  state. Saved Cancel returned 303, cancelled Ceremony, retained pending second-stage session hash,
  and committed parent cancellation / RP `access_denied` at Visa. Upstream token/JWKS transport was
  substituted locally; no real provider availability or outage was tested.
- B04: evidence-present Cancel returned 400 and preserved complete Ceremony/parent attributes but
  deleted the Auth SID cookie; the pre/post page control proved continuity loss.
- E06: public Normal/Standby scope transformation differed: Standby removed `write:org`, `read:self`
  and `write:self` from identical input. Actual business-endpoint authorization denial was not tested.

No exhaustive root/RP Session, Identity, Flow or Valkey snapshot, real browser check, simultaneous
race or distributed-fault injection was performed. D11/D12 remain TBC; D14's concrete distributed
coordination remains undecided. Overall acceptance is FAIL, with remaining ledger items explicitly
UNVERIFIED where evidence is incomplete.

## Artifact preservation

The existing 183,638-byte prefix of `nine.md` had SHA-256
`a2d194290219dd6839d9ff4b0b9b900cbbd764b7589f7eb894df899bc7bc51a3` and was preserved byte-for-byte.
The appended report records all 58 A–G IDs, findings, reproduction steps, post-state observations,
missing checks and proposed minimal repair directions. No tokens, cookies, signed redirect payloads
or raw logs are retained in this evidence record.
