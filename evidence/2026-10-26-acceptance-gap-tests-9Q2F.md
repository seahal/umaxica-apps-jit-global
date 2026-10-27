# Acceptance gap tests — 2026-10-26

**Commit:** `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`

**Worktree:** Dirty throughout. The worktree included uncommitted `Gemfile`, `Gemfile.lock`,
`.gitignore`, and test changes from the active cycle. Checks below ran against that worktree and its
current bundle. No application, configuration, database, or library files were changed for this
task. `git diff --check` passed. The full test suite was not run.

## Case results

| Case | Test(s) | Result |
|---|---|---|
| A02-5 | `test/services/acceptance_wu02_visa_base_issuer_test.rb` — retired issuer for ID Token and Access JWT; retired audience assertion. `test/integration/acceptance_wu02_client_assertion_audience_test.rb` — token endpoint in APP/COM/ORG. | Passed: 2 runs/15 assertions and 1 run/6 assertions. All three token endpoints rejected the old audience with `invalid_client`. |
| A02-6 | `test/integration/acceptance_wu02_jwks_separation_test.rb` — disjoint Visa/Base key IDs and material, all realms. | Passed: 1 run/30 assertions. |
| A02-9 | `test/integration/acceptance_wu02_ceremony_purpose_host_test.rb` — purpose/host refusal before binding, ceremony, or transaction changes. | Passed: 2 runs/12 assertions. |
| A02-12 | `test/security/invariants/acceptance_wu02_base_op_session_isolation_test.rb`; `test/integration/acceptance_wu02_base_rp_state_test.rb` — static session-key guard and RP-state-only `/welcome`/`/selector`. | Passed: 1 run/4 assertions and 1 run/8 assertions. |
| A06-4 | `test/integration/admission_curfew_test.rb` — `A06-4: admission parents and the OIDC login challenge remain live through 30:01`. | **Fail:** after excluding the D-36 redemption-only Binding TTL, `ClientAuthCeremonySession.expires_at` was `2026-10-26 15:59:42.940278 UTC`, one microsecond before `binding.curfew_at` (`15:59:42.940279 UTC`). Targeted result: 1 run/4 assertions. |
| A06-6b | `test/concurrency/sign_up_passkey_termination_http_test.rb:383` — separate-transaction principal-lock wait crossing curfew. | Passed: 1 run/36 assertions. |
| A07-1c | `test/controllers/auth/app/in/emails_controller_test.rb:541` — retryable Turnstile refusal preserves Flow and OTP. | Passed: 1 run/31 assertions. |
| A07-1e | `test/integration/social_callback_refusal_matrix_test.rb` — inconsistent callback returns 5xx and emits one redacted fatal record without authority. | Passed: 1 run/1,160 assertions. |
| A07-2 | `test/integration/sign_entry_sentry_test.rb`; `test/integration/admission_curfew_test.rb` — retryable continuity kept; definitive refusal clears only the current browser's continuity. | Passed: the sentry file completed 19 runs/143 assertions; the curfew file's other seven tests passed in its 8-test run. |
| A07-3 | `test/integration/sign_entry_sentry_test.rb` — refusal event reason and secret-free fields. | Passed with the same 19-run/143-assertion sentry file. |
| A12-1 | `test/integration/base_dashboard_passkey_login_journey_test.rb` (APP/COM); `test/integration/base_org_dashboard_local_login_journey_test.rb` (ORG). | Passed: 3 tests/136 assertions total; no Continue page in the redirect sequence. |
| A12-3 | `test/integration/acceptance_wu12_relay_repeat_test.rb` — attach, Base confirmation, and redeemed-entry repeat at 9/10/11 seconds. | **Fail:** attach and confirmation boundaries passed; redeemed-entry response statuses were `[303, 303, 303]`, expected `[303, 400, 400]`. Repeat state snapshots were unchanged. File result: 4 runs/43 assertions, 1 failure. |
| A12-4 | `test/integration/acceptance_wu12_relay_repeat_test.rb` expired-attachment test; `test/controllers/auth/ceremony_admission_boundary_test.rb:1037` consumed-relay test. | Expired attachment passed in the WU12 file. Consumed-relay request could not start: fixture loading raised the FK error described below. |
| A12-6 | `test/integration/oidc_initiated_sign_in_completion_test.rb:84` — repeated final result after Root issuance. | Named assertion exists; execution stopped during fixture setup on the FK error below (0 assertions). |
| A13-4 | `test/integration/acceptance_wu13_authorize_unrelated_params_test.rb` — six APP/COM/ORG `cancellation_ref`/`switch_handoff` requests. | **Fail / decision conflict:** all six returned 400 and allocated no transaction or binding; the case expects ordinary authorization. This matches `one.md` D-38 and `test/integration/visa_authorization_start_boundary_test.rb`, which require rejecting these parameters. This is not reported as an implementation defect. |
| A27-1b | `test/controllers/base/oidc_result_browser_binding_test.rb:151` — lost response, no Root reuse, session-limit remediation. | Named assertion exists; fixture setup stopped on the FK error below (0 assertions). |
| A27-2 | `test/controllers/base/oauth_oidc_authority_test.rb:1030` — SSO code reuses the existing Root while Sign In is blocked. | Passed: 1 run/33 assertions. |
| A27-3 | `test/controllers/base/oidc_result_browser_binding_test.rb:270` (OP tabs); `test/controllers/concerns/oidc/sso_initiator_test.rb:161` (RP tabs). | Both tests are named; fixture setup stopped on the FK error below before assertions. |
| A29-4 | `test/integration/acceptance_wu29_sign_entry_sentry_blocked_test.rb` — blocked direct entries, continuation methods, provider callbacks, and retired route. | **Fail:** blocked `GET /sign/in` returned 303 to `/ceremony_bindings` (that GET returned 503); expected the direct entry to return 503. State snapshots remained unchanged. File result: 1 run/48 assertions, 1 failure. |
| A29-5 | `test/integration/acceptance_wu29_root_login_sentry_test.rb` — Root commit while Sign In is blocked. | Passed: 1 run/12 assertions; no token, cookie, or login audit, and Flow not halted. |
| A29-6 | `test/integration/social_login_admission_test.rb:271` — Sign Up while Sign In is blocked. | Passed: 1 run/34 assertions; identity persisted without a session. Fixture loading was disabled for this class and required reference rows are seeded in the test setup. |
| A29-7 | `test/integration/acceptance_wu29_sentry_toggle_test.rb` — both flag-flip directions. | Passed: 1 run/36 assertions. |
| A29-8 | `test/controllers/base/oauth_oidc_authority_test.rb:126`, `:1030`, `:1330` — Refresh, SSO, and `prompt=none`; `test/controllers/base/app/welcomes_controller_test.rb:17` and `test/integration/app_passkey_secret_session_step_up_test.rb:16` — Welcome and Step-Up. | Refresh, SSO, and `prompt=none` passed (1/6, 1/33, 1/4 assertions); Welcome and Step-Up could not start because fixture setup raised the FK error below. Sign Out test/code was not touched under the task constraint. |
| A29-9 | `test/controllers/auth/org/in/emergency/passkeys_controller_test.rb:165`; `test/controllers/auth/org/up/invitations_controller_test.rb:42`. | Named assertions exist; fixture setup stopped on the FK error below. A teardown `Flipper` nil-argument error followed because setup had not run. |
| A34-2 | `test/controllers/auth/app/in/emails_controller_test.rb:723` — APP OTP; `test/integration/social_callback_refusal_matrix_test.rb` — APP social; APP Passkey/Secret/TOTP and COM OTP/Passkey controller tests. | APP OTP passed (1 run/10 assertions), and the social callback matrix passed (1 run/1,160 assertions). The other named request tests could not start because fixture setup raised the FK error below. COM has no social sign-in route in `config/routes/auth.rb`; COM social is N/A. A valid OTP attempt updates its challenge before refusal, but the acceptance requires refusal and no authority; challenge preservation is not asserted by this case. |
| A34-5 | `test/integration/acceptance_wu34_registered_commit_failure_test.rb` — post-commit graph failure, later sign-in, cleanup recovery. | Passed: 1 run/34 assertions. |

## Fixture-blocked executions

Fixture-backed tests listed above failed before their assertions when PostgreSQL revalidated
`fk_rails_829f1830de`: `client_chronicles.event_id = 36` has no matching
`client_chronicle_events.id = 36`. This affected the attempted A12-4 consumed relay, A12-6, A27-1b,
both A27-3 tests, A29-8 Welcome/Step-Up, A29-9 Emergency/invitation, and the APP Passkey/Secret/TOTP
and COM OTP/Passkey A34-2 tests. No fixture, database, or production changes were made to bypass it.

## Verification

- `bundle exec rubocop` on the five new acceptance test files: 5 inspected, no offenses.
- `ruby -c` on all modified and new Ruby test files: all syntax checks passed.
- `git diff --check`: passed.
- No full test suite run.
