# WU-A6 policy inventory and OIDC transaction counts

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree already had uncommitted changes: 537 tracked/staged dirty paths and 256 untracked
  files (793 total) before this evidence file was added. No application code or schema was changed
  in this check.
- `bin/rails test test/unit/security/authentication_context_operation_inventory_test.rb` passed: 3
  runs, 4,583 assertions, 0 failures, 0 errors, 0 skips. It checks generic policy-rule parity and
  fail-closed unknown context; it does not establish the per-operation HTTP matrix or real Standby
  Root issuance.
- `bin/rails test test/controllers/auth/org/in/emergency/passkeys_controller_test.rb:171` passed: 1
  run, 8 assertions. It confirms the Auth Emergency entry/options remain available while the
  ordinary ORG Sign In flag is blocked; it ends at Auth and does not establish Visa Root issuance.
- `test/integration/org_root_login_establishment_test.rb:16` was made runnable without unrelated
  global fixtures and follows Visa's GET-result/POST-continuation contract. Its Normal Root issuance
  assertions pass (one new Operator token, explicit `normal` context, root-login timestamp, consumed
  flow). The test now creates two active Passkeys to satisfy `OrgSecondPasskeyGate` for an ADVANCED
  Operator, expects the authenticated OIDC entry POST to be refused, and follows the explicit Auth
  ceremony-binding confirmation flow. The latest run still fails before the Base
  binding-confirmation form: `GET` returned 400 with the generic invalid-request body (1 run, 56
  assertions, 1 failure). The exact refusal condition is unisolated; cross-surface Step-Up
  completion remains unverified.
- `bin/rails test test/integration/base_passkey_mutation_step_up_test.rb` passed: 4 runs, 145
  assertions. Coverage includes APP/ORG Passkey rename/deletion under scoped Step-Up and ORG Standby
  refusal for Email registration, Secret bootstrap, and session revocation. It does not cover every
  AC-41 operation.
- `bin/rails test test/integration/org_admin_step_up_ceremony_test.rb` was attempted after adding
  the existing explicit-fixture isolation pattern. It did not reach test assertions: 10 runs, 0
  assertions, 10 errors. Fixture setup violates the `client_emails.user_id` foreign key because the
  referenced `clients` fixture row is absent. This result does not establish any ceremony behavior.
- A second run explicitly loaded the empty `client_emails` fixture to clear that fixture table.
  Setup then stopped at another stale cross-table fixture relation:
  `operator_device_sessions.current_refresh_token_id` referenced no `operator_tokens` row. It again
  ended with 10 runs, 0 assertions, 10 errors. No behavior assertion from this file is counted.
- `bin/rails test test/integration/org_step_up_verification_enforcer_test.rb:218` was attempted to
  check the existing Normal Step-Up public flow. Fixture setup stopped before the test body with an
  `enterprise_units.enterprise_id` foreign-key violation (1 run, 0 assertions, 1 error); no Step-Up
  behavior is inferred from this attempt.
- Ruby syntax, the focused RuboCop cops for the edited continuation code, and `git diff --check`
  passed. Full-file RuboCop still reports three pre-existing `Style/ImplicitRuntimeError` offenses
  at lines 81, 85, and 88.
- Read-only `bin/rails runner` counts, with `.env.container.devcontainer` loaded, found zero
  `OperatorOidcAuthorizationTransaction` rows in both development and test databases (pending 0,
  authenticated 0, consumed 0). An initial runner attempt without that environment stopped during
  Rails boot because the `preference_com` JWT issuer was missing; no query ran.
- Current source still has no authoritative Standby context on the ORG OIDC authorization
  transaction, and Visa ORG root issuance supplies `normal`. The exact verified Auth-flow-to-Root
  context propagation remains unimplemented. No production or Neon operation was performed, and the
  full suite was not run.
