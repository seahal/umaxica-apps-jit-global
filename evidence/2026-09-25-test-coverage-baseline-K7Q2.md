# Test coverage: Vitest raised, Minitest baseline measured

Commit: `e423890e7357e1fa7975eac45aeacdb416b3bce9`. The worktree had uncommitted changes to the
Vitest specs listed below. Those changes produced the "after" Vitest figures.

## Vitest (`bun run test:coverage`)

| Metric     | Before                  | After                   | Threshold |
| ---------- | ----------------------- | ----------------------- | --------- |
| Statements | 99.43%                  | 100%                    | 99%       |
| Branches   | 98.46% (run failed)     | 99.63%                  | 99%       |
| Functions  | 99.15%                  | 100%                    | 99%       |
| Lines      | 99.42%                  | 100%                    | 99%       |

The run went from 1023 to 1043 tests and passed after the change. Specs added or extended:

- `spec/pages/base/avatar_mfa_recovery_pages.test.tsx` (new)
- `spec/features/base_shared/surface_pages.test.tsx`
- `spec/features/self_service/self_service_pages.test.tsx`
- `spec/features/auth/signin/signin_interaction.test.tsx`

Five branches remain uncovered. Four are in `src/features/auth/signin/TotpChallengeForm.tsx` at
lines 70-71 and 116. They are defensive fallbacks that the form's initial state never reaches.
The fifth is `PasskeySignInPanel.tsx:92`.

## Minitest (`COVERAGE=true bin/rails test`)

11698 runs, 0 failures, 0 errors, 2 skips. SimpleCov exited with status 2 because all three
coverage metrics were below their `.simplecov` minimums:

- Line: 95.70% (59078 / 61729), minimum 98%
- Branch: 73.39% (7615 / 10376), minimum 90%
- Method: 91.59% (10065 / 10988), minimum 95%

These files have the most uncovered lines: `authentication_base.rb` (183),
`preference_adoption.rb` (110), `social_auth.rb` (75), `preference_base.rb` (73), and
`sign_up_sequence_controller_support.rb` (63). `IdentifierDetection#find_user_by_identifier` has no
callers. `app/controllers/concerns/identifier_detection.rb` is included only by
`Auth::App::Sign::In::PasskeysController`, and none of its methods are called.

## Minitest after the second pass (same commit, uncommitted changes)

After `identifier_detection.rb` was removed and Minitest cases were added, the suite ran 11712 tests
with 0 failures. SimpleCov still exited with status 2:

- Line: 95.87% (59154 / 61698), minimum 98%
- Branch: 73.75% (7639 / 10357); the `.simplecov` minimum had been raised to 93% by then
- Method: 91.69% (10070 / 10982); the `.simplecov` minimum had been raised to 97% by then

Cases added in this pass:

- Enforcement reconciliation for ended cases, approved and rejected appeals, and a failed end
  reconciliation.
- `BaseAuthAdmissionCoordinator.consume_local_entry!`, including one-shot use and denial for the
  wrong surface, the wrong intent, and an unknown code.
- An integration test showing that a rotated browser preference is copied onto the signed-in client
  preference.
- Com step-up email OTP verification without stubbing: a correct code, a wrong code, and malformed
  codes. `as_*_headers` replaces the Cookie header and drops the Rails session. These tests put the
  access cookie into the integration cookie jar instead.

Code that no request can reach, found during this pass:

- `transparent_refresh_allowed?` always returns false, so the transparent refresh path in
  `AuthenticationBase` never runs.
- `RootSignInRedirect`, `RegionalRootRedirect`, and `SessionLimitPendingGuard` are referenced only
  by tests.
- `Auth::Org::Sign::In::ChallengesController` and `Challenge::PasskeysController`. Operator sign-in
  is passkey, which skips MFA, or Entra, which sets no pending MFA.
- `PreferenceCore#safe_return_to_path` and `PreferenceTransport#refresh_preference_token_from_db_for_edit_entry!`
  have no callers.
- `SignUpSequenceControllerSupport#render_sign_up_age_restricted` and `render_sign_up_checkpoint`
  are overridden by every controller that includes the concern.

## Minitest after the third pass (2026-09-26, same commit, uncommitted changes)

After more deletions and new tests, the suite ran 11734 tests with 0 failures and 2 skips.
SimpleCov still exited with status 2:

- Line: 96.10% (59144 / 61544), minimum 98%
- Branch: 74.34% (7672 / 10320), minimum 93%
- Method: 91.94% (10068 / 10950), minimum 97%

Deleted in this pass:

- The unrouted `auth/*/sign/in/session/cancellations` controllers and
  `SignSessionLimitCancellationEndpoint`. Cancellation is handled by `sessions#destroy`.
- `UserWithdrawalFinalizeJob`. It referenced a `User` model that does not exist, and nothing
  scheduled it.
- Uncalled private methods in `PreferenceTransport`, `CoreBrowserApiBoundary`, `AuthCeremonyContext`,
  `PreferenceCore`, and `CommonRedirect`.

Tests added in this pass cover the following, without stubbing the main check:

- The session-limit sign-in flow on app and com: revoke and promote, an empty selection, and cancel.
- Preference refresh-token replay and an unknown refresh token.
- A social identity conflict during the callback.
- An avatar transfer denied by policy, including its client audit record, an expired transfer, and an
  unknown target.
- Valkey store outages and corrupt payloads.
- GUID probes, legacy SMS payload handling, and sign-up expiry job failures.

The com session-limit redirect drops `ri`; the app surface keeps it.
