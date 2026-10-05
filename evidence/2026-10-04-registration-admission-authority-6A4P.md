# Regular credential registration admission

Verified against HEAD `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5` with uncommitted authentication changes affecting the result.

`BaseStepUpAdmissionIssuer` now issues the already approved `credential_registration` purpose for Passkey on APP/COM/ORG and TOTP on APP. Issuance requires prior Base `step_up` evidence for the exact registration scope, audience and session, evaluated under the actor/token locks against writer time and the existing fifteen-minute freshness contract. The new permission has no assurance claim and cannot refresh that evidence. Candidate methods remain specific to the registration scope, independently of the previously authenticated method. APP may use existing Email step-up proof to obtain a TOTP registration permission.

The added public issuance test initially errored on the supported positive path before implementation (seed 59904, one test, three assertions). New negative cases cover absent evidence, another scope/session/audience, bootstrap evidence, absent method, unsupported registration methods, unrelated purpose and assurance claims. Freshness is accepted one microsecond before its deadline and rejected at and one microsecond after it, on all three surfaces. These issuance tests use synthetic prior Base evidence and do not claim credential-verification or browser coverage.

Verification used only the owned copied databases listed in `tmp/auth-boundary-isolated-20261003auth6f3.json`, with `POSTGRESQL_ISOLATED_TEST_RUN_ID=20261003auth6f3`, `POSTGRESQL_TEST_PREPARE_DATABASES=codex_integrity_20261003auth6f3_app_ticket` and `PARALLEL_WORKERS=1`. No schema rebuild or shape change occurred.

Final command: `bin/rails test test/operations/base_step_up_admission_issuer_test.rb test/operations/base_bootstrap_admission_issuer_test.rb test/models/opaque_step_up_transaction_test.rb test/operations/identity_step_up_ceremony_freshness_committer_test.rb test/integration/totp_registration_boundary_test.rb test/integration/root_login_establishment_flow_test.rb test/integration/org_root_login_establishment_test.rb`.

Result: seed 44298, 54 tests, 960 assertions, zero failures, errors or skips. RuboCop passed for the changed operation and test; scoped `git diff --check` passed. The ORG provider integration uses stubbed token/JWKS transport, not a live provider.

This connects the Base permission primitive only. User-facing routine registration entry, scoped management actions and Base-only Passkey candidate finalization remain unfinished. OTP logging remediation remains excluded and browser verification remains user-owned.
