# WU-24 / WU-30 follow-up: suite repair and Security Mode Step-Up windows

Commit: `ba570a0007b1d40eabe32990a34831317fd98a93`, with uncommitted changes from this session and
from a concurrent WU-24h session in the worktree. Both affect the results below.

## Production changes

- `StepUpResolver`: the Step-Up window is the shorter of the requirement TTL and the Security Mode
  maximum (NORMAL 15 min, ADVANCED 5 min, consolidation ADR 2.3). ADVANCED accepts only Passkey
  evidence. An actor whose mode is not valid has no window.
- `StepUpConfiguredMethodsQuery`: ADVANCED offers only `passkey`; an invalid mode offers nothing.
- APP TOTP second factor removed:
  - Deleted: the route `/sign/in/challenge/totp`, `Auth::App::Sign::In::Challenge::TotpsController`,
    `src/pages/auth/app/sign/in/challenge/totps/new.tsx` and `TotpChallengeForm.tsx`.
  - Updated: the UI view inventory row.
- `SignUpCycleLocator#current`: when the session hint names the Binding's own ended attempt (same
  public id and nonce), it returns nil instead of raising an ownership mismatch. A hint naming any
  other Flow, or carrying the wrong nonce, is still a mismatch.
- Locale: `activerecord.attributes.{operator,visitor}.security_mode` and
  `{client,visitor}_sign_up_flow.auth_admission_binding` in jp/us × ja/en.

## Test changes (assertions changed)

- **ORG two-Passkey gate (D-132):**
  - Test operators get two Passkeys; `OperatorPasskeyTestSupport` reloads the operator.
  - A missing Step-Up for an operator with Passkeys is 401 or a redirect to `/verification`, not
    `/verification/setup`.
  - Removal tests keep two Passkeys after a removal (third Passkey added).
  - Bootstrap uses an operator created without Passkeys.
- **Direct `log_in` boundary tests:** pass `require_totp_check: false`, as production callers do.
- **E1 / D-72 / D-73:**
  - Flows carry an Admission Binding.
  - A request without a sign-up admission expects the uniform 400.
  - Tests for the removed sequence-id and locator fallbacks now assert refusal.
  - Sign-up HTTP tests Switch first: `SignUpSwitchTestSupport` routes Base hops through a separate
    Base session when one is given.
  - `session_sign_up_flow` reads the Flow from the session hint.
  - A revisit after an age-restriction halt expects 400, because the attempt ended its admission.
- **Security Mode downgrade:** revokes the current session too (ADR 2.5).
- **Step-Up freshness boundaries for ORG:** use the 5 minute ADVANCED maximum.
- **New:** `test/resolvers/step_up_resolver_security_mode_test.rb`:
  - 15 min − 1 s / 15 min for NORMAL; 5 min − 1 s / 5 min for ADVANCED.
  - A requirement TTL shorter than the mode maximum still applies.
  - ADVANCED refuses TOTP evidence.
  - Method sets per mode.

## Deleted tests

- `test/controllers/auth/com/sign/up/check/email/otps_controller_branch_coverage_test.rb`: it
  stubbed controller internals and called actions through `send`.
- `test/controllers/auth/app/in/mfa/totps_controller_test.rb`, the TOTP back-link case in
  `challenges_controller_test.rb`, and two TOTP burst-limit cases: their subject was removed.
- The MFA per-account rate-limit invariant now asserts that every sign-in second factor controller
  is a Passkey controller.

## Runs

- Full suite full-19: 18490 runs, 71 F / 2 E.
- Full suite full-20: 18491 runs, 63 F / 3 E.
  - Against the G-1 names, 7 were new. All 7 were then handled, as follows.
  - 4 were Step-Up freshness tests. After the window fix each passes when its file is run.
  - The 2 `SignUpPasskeyTerminationHttpTest` deadline cases (from the concurrent session) pass
    alone (5 runs, 0 F). They are timing-dependent and recorded as flaky, not fixed.
  - `RpBackchannelLogoutReceiverTest` signed Logout Token: the same flake WU-01 recorded.
- No full run was repeated after the last four fixes.
- `rubocop` on the 45 changed Ruby files: no offenses.
