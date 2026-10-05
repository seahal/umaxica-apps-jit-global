# Passkey malformed-signature refusal and APP controller migration

HEAD `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`, 2026-10-04 UTC; uncommitted authentication implementation and unrelated concurrent work were present.

Replaced the six legacy APP verification Passkey controller cases with canonical opaque admission and actual FakeClient signature coverage. Removed artificial Auth login, JWT grant issuance and local dynamic test doubles from this file. Checks cover evidence without Base freshness/root credentials, fixed-dashboard cancellation, repeated non-consuming GET without deadline/attempt reset, untrusted query parameters not replacing admitted scope/target, and a separate browser refusing old grant/scope-only entry.

A malformed ECDSA signature initially caused an unhandled `OpenSSL::PKey::PKeyError: EVP_DigestVerify` after challenge consumption: 6 tests, 44 assertions, 1 error (seed 52109). The shared assertion verifier now converts that specific cryptographic exception to its explicit verification failure, preserving refusal rather than accepting or retrying the proof. The same HTTP assertion and replay both return the existing 422 failure response, the transaction remains pending, the challenge remains consumed and Base freshness remains absent. No broad exception fallback was added.

With owned isolated manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, run ID `20261003auth6f3`, preparation scoped to `codex_integrity_20261003auth6f3_app_ticket`, and one worker:

`bin/rails test test/controllers/auth/app/verification/passkeys_controller_test.rb test/services/webauthn/verifier_uv_policy_test.rb test/controllers/concerns/passkey_sign_in_flow_refusals_test.rb test/integration/org_root_login_establishment_test.rb test/operations/org_step_up_passkey_committers_test.rb`

Passed 25 tests, 196 assertions, seed 10637. This includes shared UV requirements, sign-in refusals, ORG real root/step-up journey and ORG public committers. RuboCop for the changed verifier, APP controller test and ORG integration test reports no offenses; `git diff --check` passed.

The public Base issuer supplies initial authority in the APP controller cases, so these are not independent APP login evidence. Browser/live-provider checks remain unverified; other legacy tests and full-plan registration/credential-management requirements remain outstanding. Excluded OTP logging work was untouched.
