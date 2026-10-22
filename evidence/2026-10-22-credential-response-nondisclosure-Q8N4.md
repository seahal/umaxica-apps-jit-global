# Credential response nondisclosure verification

Date: 2026-10-22. Git HEAD: `febec3225cc9a0cfa53b9cbe817d20d366aba5a2`.
The worktree contained substantial pre-existing uncommitted work and the uncommitted remediation;
both affected this result. This is local verification, not a deployment result.

## Executed checks

The final command completed with **159 runs, 1126 assertions, 0 failures, 0 errors, 0 skips**
(seed 38042):

```bash
PARALLEL_WORKERS=1 bin/rails test \
  test/controllers/auth/org/up/invitations_controller_test.rb \
  test/controllers/auth/app/in/secrets_controller_test.rb \
  test/controllers/auth/org/in/emergency/passkeys_controller_test.rb \
  test/integration/withdrawal_ceremony_reentry_test.rb \
  test/integration/identity_recovery_entrypoint_render_test.rb \
  test/controllers/auth/app/in/passkeys_controller_test.rb \
  test/controllers/auth/com/in/passkeys_controller_test.rb \
  test/controllers/auth/org/in/passkeys_controller_test.rb \
  test/integration/preference_dbsc_advertisement_test.rb \
  test/controllers/auth/credential_timing_protection_contract_test.rb \
  test/controllers/concerns/preference/dbsc_registration_endpoint_test.rb \
  test/unit/webauthn/verifiers_test.rb \
  test/controllers/concerns/passkey_sign_in_flow_refusals_test.rb \
  test/unit/security/webauthn_invariants_test.rb \
  test/unit/security/org_emergency_access_invariants_test.rb \
  test/unit/security/standard_csrf_invariant_test.rb \
  test/security/invariants/csrf_verification_strategy_invariant_test.rb
```

## Acceptance observations

The scoped `bundle exec rubocop ... --format simple` invocation inspected the 14 modified
application Ruby files and 11 modified/new Ruby test files: **25 files, no offenses**.
`git diff --check` also completed without output. No JavaScript changed.

| Criterion | Public checks and observed result |
| --- | --- |
| AC-1 | Secret requests across distinct request IPs returned 422 for attempts 1–5 and 429 for 6–7 for both known and unknown identifiers, including normalized casing/whitespace. Six failed CAPTCHA requests did not consume the chosen identifier's budget. The independent account budget remains and emits a generic, response-budgeted 422. |
| AC-2 | Repeated Emergency options for eligible, unknown and ineligible selections returned empty descriptor lists; actor bindings were all 20 bytes and retained the expected Operator/sentinel value. Existing ownership/purpose refusals and Auth-to-Base standby-session issuance passed. Registration tests require discoverable credentials separately on all three surfaces. |
| AC-3 | Valid, expired, consumed, unknown, empty and missing invitation codes received the same migration refusal with 422, no redirect and no provisioning/consumption. Code inspection confirms refusal before lookup and retention of the inherited common rate limit. |
| AC-4 | App/com recovery and withdrawal compared real/dummy JSON byte counts and actual unescaped encrypted-session cookie lengths. Both matched and remained under 4096 bytes. Existing real OTP success, dummy/wrong-code refusal and effective-binding tests passed. |
| AC-5 | Real-cryptography App assertions with a missing credential and an invalid signature had identical status, body and selected response headers, without sign-count/session changes. App/com/org verification, sign-count refusal, challenge cleanup and timing contract tests passed. |
| AC-6 | Core app/com/org theme mutations advertised the canonical host-local Preference DBSC path. The corresponding Auth/Base mutations succeeded without unsupported registration headers. DBSC registration endpoint tests passed. |

## Initial failures and resolution

- Initial HTTP runs stopped in the existing DBSC serializer: the Preference advertisement passed
  a nil obsolete route. Unsupported hosts now explicitly do not advertise; Core names its real
  Preference endpoint. Validation of existing bound credentials remains unchanged.
- An initial Base completion returned 400. The same failure reproduced with the original
  `PasskeySignInFlow` and `SignOrgStandbyPasskeyCeremony` restored temporarily, retaining the DBSC
  prerequisite fix. Exception-location diagnostics identified the absent `OpOrgProtocolEpoch`
  singleton. Adding that domain prerequisite inside the success test produced a passing real
  Base session-issuance result. No global test setup or production authorization rule changed.
- Initial test cookie comparisons used an unsupported CookieJar method; the final tests use
  its public index accessor. The final command above supersedes those failed runs.

## Limits

The full repository suite, production deployment, live email/CAPTCHA providers, fleet readiness of
discoverable Org credentials and production latency distributions were not tested. Response floors
cover the reviewed operations but are not proof of constant-time behavior under arbitrary I/O
delays. No credential deletion, schema migration or production bulk operation was performed.
Existing non-discoverable Org keys remain usable through normal Entra-bound sign-in and need
re-registration before Emergency Access can use them. Invitation-specific rate limits remain
deferred by explicit user decision.
