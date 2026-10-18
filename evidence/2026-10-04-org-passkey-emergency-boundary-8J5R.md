# ORG Passkey and Emergency boundary

Verified against commit `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5` with uncommitted authentication changes and unrelated parallel work.

The ORG Emergency tests now use the public Base admission and opaque result contracts, without injected Auth root credentials or legacy signed grants. They verify refusal at Base initiation, direct unaffiliated Auth requests, a context change after admission, Base finalization after a context change, and resolver refusal despite previously recorded normal freshness. A normal admitted request reaches Passkey selection.

Real WebAuthn assertions exposed ORG-specific errors in the shared implementation: OperatorPasskey has `external_id` rather than `public_id`, and has no `discard_at`. Verification and finalization now use that existing actor-scoped reference and the active status. APP/COM retain their credential expiry filters. The existing ORG `uv_verified_at` column remains in use.

New operation coverage exercises signature verification, exact credential evidence, Base finalization and result retry, challenge replay refusal, revocation before assertion and revocation before finalization. The HTTP case exercises admission GET/CSRF POST, options, real signature verification and opaque result form generation with no Auth access/refresh cookies. This does not prove an ORG root-login-to-protected-operation browser journey.

All Rails commands used owned manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, run ID `20261003auth6f3`, one worker, preparation limited to `codex_integrity_20261003auth6f3_app_ticket`.

- Before correction, the operation/Emergency pair produced 10 runs, 42 assertions, one failure and two errors (seed 31120), exposing the absent expiry column. The added HTTP case separately reproduced that error in options (seed 14235).
- Final command: `bin/rails test test/controllers/auth/org/verification/emergency_step_up_prohibition_test.rb test/operations/org_step_up_passkey_committers_test.rb test/operations/identity_step_up_passkey_verification_committer_test.rb test/operations/identity_step_up_ceremony_freshness_committer_test.rb test/controllers/auth/step_up_admission_test.rb test/controllers/concerns/verification/step_up_guard_test.rb test/models/auth_ceremony_revocation_concurrency_test.rb`.
- Result: 53 runs, 435 assertions, no failures, errors or skips (seed 32698).
- RuboCop: seven changed Ruby files, no offenses. `git diff --check` passed.

Browser verification remains user-owned. No OTP logging remediation, schema change, deployment or shared-database reconstruction was performed. The whole authentication plan remains incomplete.
