# Security Audit Implementation Notes — FINDING-01 through FINDING-04

> Date: 2026-06-13 ADR: `adr/security-audit-findings-2026-06-13.md`

---

## What was implemented

### FINDING-01 — Policy override removal + service-layer org check

The policy fix renamed `operator?` to `lifecycle_actor?` in `OperatorLifecycleRequestPolicy`. This
was required because `operator?` directly shadowed `ApplicationPolicy#operator?`. The shadow removed
all org membership checking from the policy; the type-only check (`user.is_a?(Operator)`) had no org
context.

The service-layer guard (`org_owner_authorized?` in `OrgOperatorLifecycleRequestCreate`) was chosen
over a policy-layer guard because:

- `authorize!(OperatorLifecycleRequest)` passes the class, not an instance with an org attribute.
- Injecting `organization_id` from params into a policy would require changing the policy API.
- The service already receives `actor` and `attributes` and is the right place to reject mismatched
  org ownership before any DB write.

The 4-eyes control (`approve?`, `execute?` → `different_operator?`) was deliberately left as-is.
These checks are intentional global design (a different Operator must approve and execute, across
any org boundary). The audit confirmed this is correct behavior, not a gap.

### FINDING-02 — Session revocation on credential destroy

`AuthenticationLogoutAllSessions.call` was added to `SecretCredentialsController#destroy`
immediately after `ClientSecretCredentialsDestroy.call` succeeds.

Key constraint discovered during implementation: `logout_all_sessions_for!` (the helper used in
logout flows) calls `reset_session` in an `ensure` block, which clears the flash. Using it in
`destroy` would prevent the "destroyed" flash notice from reaching the redirect. Instead, the
service class is called directly.

`session_version` on `Client` does not exist as a DB column. The increment path in
`AuthenticationLogoutAllSessions` silently no-ops. The real termination mechanism is marking
`ClientToken` records as `REVOKED` via `AuthenticationLogoutCurrentSession`. This is confirmed by
reading the `token_scope` for Client in `AuthenticationLogoutAllSessions`.

### FINDING-03 — email_verified guard in SocialAuthVerifiedProviderAssertion

`email_explicitly_unverified?` was added as a private method and called in `call`. The method
returns `false` for `nil` (claim absent) and `true` only for boolean `false` or string `"false"`.
The `claim_value` helper (already present) is reused to probe both `id_info` and `raw_info` for the
claim, because different OIDC providers place it differently.

### FINDING-04 — Not structurally fixed

No `after_action :verify_authorized` was added. The existing policy test coverage for
`ClientSecretCredentialPolicy` is the regression guard. A structural enforcement mechanism requires
an audit sweep of all existing controller actions before it can be safely enabled.

---

## Deviations from original plan

The original plan (from the prior session) said "implement only FINDING-01 and FINDING-02." The
current session expanded scope to all High findings (FINDING-01, FINDING-02, FINDING-03,
FINDING-04). FINDING-03 was implemented. FINDING-04 was documented as a structural decision
(deferred, not structurally fixed).

---

## Pre-existing test bug discovered and fixed

`test/integration/sign/app/credential_removal_constraints_test.rb` at
`test_secret_credential_removal_is_allowed_when_another_aal1_method_remains` used
`assert_difference("ClientSecretCredential.count", -1)`. This was already failing before any changes
in this session.

Root cause: `test_helper.rb` declares `fixtures :all` which loads all fixture files including
`client_secret_credentials.yml` (3 records) into `app_principal` DB even when the test class
declares an explicit fixture list. `ClientSecretCredentialsDestroy` uses `discard_now!` which is an
`update!` (soft delete), not a hard delete. `ClientSecretCredential` has no default scope excluding
soft-deleted records. Count never decreases from the destroy.

Fix: changed the assertion to `assert_predicate secret_credential.reload, :lapsed?` which correctly
verifies the soft-delete outcome (discarded_at is in the past).

---

## Cross-DB fixture interaction

Adding `:client_token_statuses` (an `app_ticket` DB table) to the fixture list does not cause
`client_secret_credentials` (an `app_principal` DB table) to be loaded. Both were already being
loaded via `fixtures :all` in `test_helper.rb`. The fixture count bug was pre-existing; the symptom
appeared during this session because the FINDING-02 regression test ran adjacent to the pre-existing
broken test, making the failure visible.

---

## What still needs follow-up

- FINDING-04: Enable `after_action :verify_authorized` after an audit sweep. Track in backlog.
- FINDING-06 (TOTP lock): `totps_controller.rb` should use `with_lock` for `last_otp_at` update.
- FINDING-07 (Argon2id): Pin parameters in an initializer and document production timing.
- FINDING-08 (WebAuthn rpId): Raise at startup if `WEBAUTHN_APP_RP_ID` env var is absent.
