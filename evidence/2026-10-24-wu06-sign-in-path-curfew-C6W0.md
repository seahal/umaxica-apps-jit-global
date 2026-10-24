# WU-06: Sign-in path curfew

Commit: `ba570a0007b1d40eabe32990a34831317fd98a93`, with this cycle's uncommitted changes in the
worktree. `curfew_at` storage itself is WU-24c.

## Implemented

- **Decision:** `AdmissionCurfewValue.for(binding).within?` compares `curfew_at` with the Binding
  model's own `database_now` (D-75), read once per decision.
- **Auth gate:** `AuthAdmissionCurfewGate#enforce_admission_curfew!` is a `before_action` in the
  APP, COM and ORG Auth ApplicationControllers.
  - It applies to every request with an admitted `authentication_handoff` ceremony.
  - At or after the curfew, the owner's browser (proven by its ceremony cookie) leaves through the
    Cancel exit: `issue_cancellation!`, ceremony cancelled, then Visa `/oidc/cancellation`, where
    the RP receives `access_denied` with the unchanged `state`.
  - With the authorization transaction gone, it answers the uniform 400.
  - A browser without the ceremony is not affected by the gate.
- **F5:** `auth_social_admission_binding!` no longer uses the 60-second acceptance expiry; it uses
  the curfew.
- **OP parents (design 3):**
  - Issuing a Sign-in path Binding extends the OIDC transaction's `expires_at` and
    `login_challenge_expires_at` to at least the curfew (`cover_sign_in_path_curfew!`).
  - `SignFlow.default_ttl` is now the 30-minute curfew duration. A Flow is created after its
    Binding, so it outlives the curfew.
  - The Auth ceremony session already lived 30 minutes from its own later creation.
- **Sign-up (D-105 / D-131 / REQ-CURFEW 7):**
  - `finalize_sign_up_from_checkpoint!` checks the curfew under the Flow lock before any
    registration write, and refuses as `:expired` at or after it.
  - After the decisive commit it checks again before the Sign In handoff. When the deadline has
    passed meanwhile, the registration is kept and the browser takes the curfew exit instead of the
    handoff.

- **Base acceptance (A06-2):** `validate_result_browser_binding!` refuses a Sign-in path result at
  or after the curfew (`expired_admission`). Only the Cancel exit (`cancellation: true`) stays open.

## Tests

- **New:** `test/services/base_result_acceptance_curfew_test.rb` (2 runs, 0 F) covers acceptance
  before the curfew, refusal after it, and the Cancel exit validating after it.

- **New:** `test/integration/admission_curfew_test.rb` (6 runs, 0 F):
  - one minute before the curfew → served (A06-1);
  - at and one second after → 303 exit, Base gives `access_denied` with the original `state`, the
    transaction is `canceled`, no token (A06-1, A06-7);
  - a social entry after the 60-second Binding expiry, within the curfew → allowed (A06-3, F5);
  - a browser without the ceremony → no exit and the transaction unchanged (A06-8);
  - the owner's browser with the transaction row removed → uniform 400 (A06-9).
- Current focused verification after the Visa host split: the curfew integration plus social entry,
  social start-gate and sign-up cancellation contracts passed **32 runs, 88 assertions, 0 failures,
  0 errors**.
- **Updated** for the longer parent and Flow lifetimes (stale in-memory parents reloaded, 15 → 30
  minutes):
  - `SignFlowTest`, `BaseAuthAdmissionCoordinatorTest`,
    `OidcAuthorizationTransactionCoordinatorTest`;
  - `AuthEmailOtpLockDeadlineTest`, `AuthAdmissionBindingPurgerTest`;
  - `SignUpFlowAdmissionOwnershipTest`, `SignUpAdmissionOwnershipTest` (snapshot reload);
  - `AppSecretReceiptCollectionJourneyTest`: it no longer waits in real time for 10-second parents;
    it ends them directly and waits only for the proof-retention bound. It passed 3 runs.
- **Not run:**
  - A06-1 at exactly 30:00.000 with a stubbed clock. The "at" case sets `curfew_at` to the read DB
    time, so the next read is later.
  - A06-4 (row still exists at 30:01): only implied by the extension.
  - A06-5 (carried codes capped by the curfew).
  - A06-6a–c (Finalization race across the deadline). The gate refuses before Finalization in
    ordinary requests, so these need lock-wait tests.

## Runs

- **Full suite (full-22):** 18444 runs, 60 F / 4 E. New names against G-1, before the fixes above:
  - fixed: the purger and ownership deadline tests (stale parents) and the receipt journey timeout;
  - recorded flakes: `SignUpPasskeyTerminationHttpTest` ×2, `RpBackchannelLogoutReceiverTest`, and
    `AuthCeremonyRevocationConcurrencyTest` APP cleanup race (same as WU-01; passed on rerun).
- No full run was repeated after these fixes.
- `rubocop` on the changed files: no offenses.
