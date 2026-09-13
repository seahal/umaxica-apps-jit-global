# Rebuild app Sign-up / Sign-in Flows — Mighty Sprout

**Status:** active  
**Last updated:** 2026-06-24  
**Scope:** sign.app + com.app authentication restoration and test hardening

---

## Context

A batch deletion removed the OTP submission (`update`) actions from several sign-up and sign-in
controllers, breaking those auth flows. Social login was not affected because it calls
`establish_signed_in_session!` directly without going through the deleted code paths.

This plan restores the deleted actions, unifies the completion gate across all routes, and adds
compensation + regression tests per the addendum requirements.

**Behavioral baseline:** social login (Google/Apple on app surface) — it uses
`establish_signed_in_session!` in `AuthenticationBase` and `finalize_sign_up_from_checkpoint!` in
`SignUpSequenceControllerSupport` for sign-up handoffs. All restored routes must pass through the
same gate.

---

## Historical Design Summary

| Route                                                                | Intended behavior                                                             | Current state                                                                             | Missing code                                                                                                         | Doc current?                                                                  |
| -------------------------------------------------------------------- | ----------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| Sign-in: email OTP (`PATCH /sign/in/email`)                          | Verify OTP → `establish_signed_in_session!` → session/token                   | **Broken** — `update` deleted                                                             | `update`, `verify_otp_and_login`, `verify_existing_email_otp`, `handle_failed_otp_attempt`, rate limits for `update` | ✅ `docs/security/sign-in-sequence.md`                                        |
| Sign-in: passkey                                                     | Ceremony via WebAuthn → acme commits session                                  | Works (settings passkey registration affected, not sign-in)                               | None for sign-in path                                                                                                | ✅                                                                            |
| Sign-in: TOTP / secret_credential / passcode                         | MFA path via acme                                                             | Works (ceremony delegation changes affect settings only)                                  | None for sign-in path                                                                                                | ✅                                                                            |
| Sign-in: Google / Apple social                                       | OmniAuth callback → `SocialAuthLoginHandler` → `establish_signed_in_session!` | **Working baseline**                                                                      | None                                                                                                                 | ✅ `docs/security/social-callback-boundary.md`                                |
| Sign-up: email OTP verify (`PATCH /sign/up/check/email/otp`)         | `SignOtpCeremony.verify!` → state machine events → birthdate path             | **Broken** — `update` deleted from `Check::Email::OtpsController`                         | `update`, `verify_otp_ceremony!`, `complete_update_and_redirect`, `advance_sign_up_flow_after_email_otp!`            | ✅ `docs/security/sign-up-sequence.md`                                        |
| Sign-up: telephone OTP verify (`PATCH /sign/up/check/telephone/otp`) | `SignOtpCeremony.verify!` → `verify_telephone_ownership!` → guard path        | **Broken** — `update` deleted from `Check::Telephone::OtpsController`                     | `update`, `verify_otp_ceremony!`, `advance_sign_up_flow_after_telephone_otp!`                                        | ✅                                                                            |
| Sign-up: Google / Apple social                                       | `SocialAuthSignupFinalizer` → `finalize_sign_up_from_checkpoint!`             | **Working baseline**                                                                      | None                                                                                                                 | ✅                                                                            |
| Passkey settings registration                                        | `commit_settings_passkey_registration!` (direct, grant pattern removed)       | Works — grant/result pattern intentionally removed; direct commit is correct current path | None                                                                                                                 | ⚠️ `docs/security/ceremony-grant-result.md` still documents old grant pattern |
| com sign-in email OTP                                                | Parallel `update` for Visitor / VisitorEmail surface                          | **Broken** — parallel deletion                                                            | Same as app surface; `visitor_from_visitor_email` also deleted                                                       | ✅                                                                            |
| com sign-up email OTP verify                                         | Parallel deletion                                                             | **Broken**                                                                                | Same pattern as app                                                                                                  | ✅                                                                            |
| com sign-up telephone OTP verify                                     | Parallel deletion                                                             | **Broken**                                                                                | Same pattern as app                                                                                                  | ✅                                                                            |

**Ceremony grant/result note:** `IdentityPasskeyCeremonyGrant` /
`IdentityPasskeyCeremonyResultIssuer` / `IdentityPasskeyCeremonyFinalCommitter` pattern was removed
from all ceremony delegation concerns. The `start_passkey_ceremony!` / `start_totp_ceremony!` etc.
now return `nil`. This is intentional: the acme/sign component boundary migration is in backlog
(`plans/backlog/sign-acme-boundary-remediation.md` marked inactive); the current correct path is
direct credential storage via `commit_settings_*`. `docs/security/ceremony-grant-result.md`
describes the intended future state, not current behavior.

---

## Normal Flow Matrix

### Sign-up: email path

| Step | Route                                      | Controller                                 | Key method                                                                                                                        | Next step           |
| ---- | ------------------------------------------ | ------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------- | ------------------- |
| 1    | `GET /sign/up/email/new`                   | `Sign::Up::EmailsController`               | render form                                                                                                                       | —                   |
| 2    | `POST /sign/up/email`                      | `Sign::Up::EmailsController#create`        | `initiate_email_verification!` + create `ClientSignUpFlow`                                                                        | OTP check page      |
| 3    | `GET /sign/up/check/email/otp`             | `Check::Email::OtpsController#show`        | load gate context → render OTP form                                                                                               | —                   |
| 4    | `PATCH /sign/up/check/email/otp`           | `Check::Email::OtpsController#update`      | `SignOtpCeremony.verify!` → `advance_sign_up_flow_after_email_otp!` (verify_contact → enter_checkpoint → clear_requirement(:otp)) | birthdate check     |
| 5    | `GET/PATCH /sign/up/check/email/birthdate` | `Check::Email::BirthdatesController`       | `clear_sign_up_birthdate_requirement` → state machine                                                                             | finalization        |
| 6    | Finalization                               | `Sign::Up::EmailsController` or checkpoint | `finalize_sign_up_from_checkpoint!`                                                                                               | handoff → session   |
| 7    | Handoff                                    | `finalize_sign_up_from_checkpoint!`        | `IdentityGraphProvisioner.call!` → `establish_signed_in_session!(actor, bootstrap_actor: true)`                                   | welcome / dashboard |

### Sign-up: telephone path

| Step | Route                                | Controller                                | Key method                                                                                              | Next step         |
| ---- | ------------------------------------ | ----------------------------------------- | ------------------------------------------------------------------------------------------------------- | ----------------- |
| 1–2  | `GET/POST /sign/up/telephone`        | `Sign::Up::TelephonesController`          | create `ClientSignUpFlow`, issue OTP                                                                    | OTP check         |
| 3    | `GET /sign/up/check/telephone/otp`   | `Check::Telephone::OtpsController#show`   | load gate                                                                                               | —                 |
| 4    | `PATCH /sign/up/check/telephone/otp` | `Check::Telephone::OtpsController#update` | `SignOtpCeremony.verify!` → `verify_telephone_ownership!` → `advance_sign_up_flow_after_telephone_otp!` | guard/birthdate   |
| 5–7  | Checkpoint / finalization            | Same as email path                        | `finalize_sign_up_from_checkpoint!`                                                                     | handoff → session |

### Sign-up: social (Google/Apple)

| Step | Route                    | Controller                                   | Key method                                                                | Next step                 |
| ---- | ------------------------ | -------------------------------------------- | ------------------------------------------------------------------------- | ------------------------- |
| 1    | `POST /sign/social/auth` | `Social::AuthenticationsController#continue` | `prepare_social_auth_intent!` + `issue_sign_up_flow!` + OmniAuth redirect | OmniAuth                  |
| 2    | OmniAuth callback        | `Auth::OmniauthCallbacksController`          | `handle_omniauth_callback` → `SocialAuthSignupFinalizer`                  | checkpoint / finalization |
| 3    | Finalization             | `finalize_sign_up_from_checkpoint!`          | `establish_signed_in_session!(actor, bootstrap_actor: true)`              | welcome                   |

### Sign-in: email OTP path

| Step | Route                     | Controller                          | Key method                                                                            | Next step                   |
| ---- | ------------------------- | ----------------------------------- | ------------------------------------------------------------------------------------- | --------------------------- |
| 1    | `GET /sign/in/email/new`  | `Sign::In::EmailsController#new`    | render form                                                                           | —                           |
| 2    | `POST /sign/in/email`     | `Sign::In::EmailsController#create` | `process_email_authentication` → issue OTP or dummy                                   | edit page                   |
| 3    | `GET /sign/in/email/edit` | `Sign::In::EmailsController#edit`   | `load_user_email`                                                                     | —                           |
| 4    | `PATCH /sign/in/email`    | `Sign::In::EmailsController#update` | `verify_otp_and_login` → `verify_existing_email_otp` → `establish_signed_in_session!` | redirect / MFA / restricted |

### Sign-in: social (Google/Apple)

Social sign-in still works via `SocialAuthLoginHandler` → `establish_signed_in_session!`. No changes
needed.

### Sign-in: passkey / TOTP / passcode / secret credential

These routes go through `acme/app` (not `sign/app/sign/in`) and are unaffected by the deletion. The
ceremony delegation concerns' `start_*` methods returning `nil` affects SETTINGS registration only,
not the MFA sign-in path. No restoration needed for these.

---

## Abnormal Flow Matrix

### Sign-up: email / telephone OTP (routes 4 above)

| Scenario                             | Trigger                                                       | Expected behavior                    | Compensation needed?                   |
| ------------------------------------ | ------------------------------------------------------------- | ------------------------------------ | -------------------------------------- |
| Blank code submitted                 | `params[:pass_code].blank?`                                   | 422, error on field                  | No — stateless                         |
| Wrong code                           | `SignOtpCeremony.verify!` returns `:invalid_code`             | 422, error + attempt count shown     | No — OTP attempts tracked in DB        |
| Locked (max attempts)                | `result.status == :locked`                                    | Redirect to start, session cleared   | No cleanup — ticket stays, OTP locked  |
| Expired OTP                          | `@user_email.otp_expired?` in gate load                       | Redirect to start                    | No — ticket is durable                 |
| Stale session (no ticket in session) | `load_gate_context!` returns false                            | Redirect to start                    | No                                     |
| Replay attack (code already used)    | HOTP counter prevents reuse                                   | 422 invalid code                     | No                                     |
| Dummy flow (non-existent email)      | `dummy_existing_email_flow?` = true                           | 422 invalid code (timing equalized)  | No                                     |
| State machine advance fails          | `verify_contact` returns non-`:advanced`                      | Log warning, do not redirect forward | No — ticket stays in `CONTACT_PENDING` |
| Concurrent `update` on same ticket   | Row-level lock in finalization only; OTP verify is not locked | HOTP counter prevents double-advance | No                                     |

### Sign-up: finalization (step 6–7)

| Scenario                                               | Trigger                                               | Expected behavior                                                         | Compensation                                       |
| ------------------------------------------------------ | ----------------------------------------------------- | ------------------------------------------------------------------------- | -------------------------------------------------- |
| `IdentityGraphProvisioner` fails                       | Network/DB error                                      | Transaction rolled back; ticket stays `FINALIZING`                        | Retry-safe: idempotent on same ticket              |
| `establish_signed_in_session!` fails after provisioner | Token creation fails                                  | Ticket is `FINALIZED` but no session issued                               | Operator can reset via admin; ticket carries state |
| `session_limit_hard_reject` during bootstrap           | `bootstrap_actor: true` skips this                    | Cannot happen — `bootstrap_actor: true` bypasses session limit            | N/A                                                |
| `IdentityGraphProvisioner` partial failure             | Zenith DB write fails mid-provisioner                 | Provisioner must be atomic; raises if not committed                       | Must test: provision + no-session case             |
| Concurrent finalization on same ticket                 | Row-level lock in `finalize_sign_up_from_checkpoint!` | Second caller gets stale ticket, `SignUpStateMachine` returns non-success | No duplicate tokens                                |

### Sign-in: email OTP (step 4)

| Scenario                                     | Trigger                                         | Expected behavior                                | Compensation                                      |
| -------------------------------------------- | ----------------------------------------------- | ------------------------------------------------ | ------------------------------------------------- |
| Dummy path (unknown email)                   | `state.existing? == false`                      | Constant-time dummy OTP compare → 422            | No                                                |
| Wrong code                                   | OTP mismatch                                    | 422 + attempt counter                            | No                                                |
| Locked email                                 | `user_email.locked?`                            | Locked message, no login                         | No                                                |
| `login_allowed?` false after OTP verify      | User banned mid-flow                            | 422 invalid code (timing safe)                   | No                                                |
| Session limit: 2 active already              | `session_limit_state_for` = `:issue_restricted` | Issue restricted token → session management path | Restricted token created (TTL 15 min)             |
| Session limit hard reject: restricted exists | `session_limit_state_for` = `:hard_reject`      | 403 hard reject rendered                         | No new token created                              |
| MFA required                                 | `mfa_required_for?(resource)` true              | `:mfa_required` → MFA entry path                 | Pending sign-in flow issued to session            |
| `establish_signed_in_session!` raises        | Token DB error                                  | 500 (unhandled)                                  | OTP was already consumed; next login starts fresh |

### Step-up abnormal paths

Step-up does NOT create a new `ClientToken`. It updates `last_step_up_at` on the existing token via
acme. Acme issues the ceremony grant; sign executes; acme commits freshness. If the existing session
is revoked between grant issue and result commit:

| Scenario                                                 | Expected behavior                                                                             |
| -------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| Session revoked between grant and result                 | Acme's result consumer must check token status before committing freshness; fail closed → 403 |
| Grant tampered / wrong audience                          | Grant validation fails → 403                                                                  |
| Grant replayed                                           | One-shot nonce; second use → 403                                                              |
| Ceremony fails (bad passkey)                             | sign returns failure; acme discards grant; no freshness update                                |
| Step-up result: `last_step_up_at` updated, not new token | Invariant: no new `ClientToken` row created                                                   |

---

## Sign-up Compensation Invariants

1. **Durable sign-up ticket**: `ClientSignUpFlow` (app) / `VisitorSignUpFlow` (com) are not deleted
   on failure. They carry state and allow retry.

2. **Cleanup touches only ticket-owned artifacts**: `SignUpArtifactCleanup` and `SignUpTermination`
   must not touch registered account data. Cleanup: pending OTP records, unverified
   emails/telephones created for this ticket, in-progress social ceremonies.

3. **Finalization is idempotent under lock**: `finalize_sign_up_from_checkpoint!` acquires a
   row-level lock before calling `IdentityGraphProvisioner`. If finalization fails after
   provisioning, re-entering finalization re-uses the existing provisioned identity (provisioner is
   idempotent on the same ticket).

4. **Session issuance is separate from provisioning**: a provisioner success + session failure
   leaves the ticket in `FINALIZED`. This is recoverable: user can sign in normally. The ticket does
   not roll back the provisioned identity.

5. **OTP failure does not invalidate the ticket**: ticket stays in `CONTACT_PENDING`. User can retry
   OTP verification or resend.

6. **`bootstrap_actor: true` prevents cooldown/session-limit on sign-up handoff**: new user arriving
   at `establish_signed_in_session!` immediately after sign-up must not be rejected by session limit
   or login cooldown. This flag must be set on all sign-up completion paths.

---

## Sign-in Compensation Invariants

1. **No usable auth state on OTP failure**: failed `update` must not set any auth cookies, must not
   create `ClientToken`, must not advance the `ClientSignInFlow`.

2. **Dummy path is timing-equalized**: unknown email path calls `perform_dummy_otp_generation` in
   `create` and runs the same verify path with constant-time comparison in `update`. Response time
   must not reveal email existence.

3. **Locked account is non-recoverable via normal flow**: `user_email.locked?` → locked message. No
   bypass. Operator action required.

4. **Restricted session is not a login unit**: restricted token (`ClientToken` with status
   `RESTRICTED`) counts toward `MAX_TOTAL_SESSIONS_PER_USER = 3` but not toward
   `MAX_SESSIONS_PER_USER = 2`. It is a 15-minute window for session management, not a normal login.
   Step-up does not create a new `ClientToken` — it updates the existing one.

5. **MFA-required path holds state in session, not in a new token**: pending MFA is stored in
   `SignInFlowLocator`. No `ClientToken` is created until MFA completes.

---

## Common Completion Gate Design

All sign-in routes (email OTP, passkey, TOTP, passcode, social) **must** call
`establish_signed_in_session!` defined in `AuthenticationBase`
(app/controllers/concerns/authentication_base.rb:2308).

All sign-up routes (email, telephone, social) **must** call `finalize_sign_up_from_checkpoint!`
defined in `SignUpSequenceControllerSupport`, which internally calls
`establish_signed_in_session!(actor, bootstrap_actor: true)`.

**No route may issue `ClientToken` directly** — always go through the gate. The gate enforces:

- session limit check (skipped with `bootstrap_actor: true`)
- login cooldown (skipped with `bootstrap_actor: true`)
- login audit emission
- `ClientToken` + `ClientDeviceSession` creation
- cookie writing
- sign-in flow advance

**Login unit = `ClientToken`**: one `ClientToken` per login. RP-specific tokens (OIDC, core, base,
palm) are issued against the same `ClientToken` and do not count as separate logins.

---

## Step-up Isolation Verification

Step-up must:

- NOT call `establish_signed_in_session!`
- NOT create a new `ClientToken`
- ONLY update `last_step_up_at` on the existing active `ClientToken` (via acme)
- Fail closed if the existing session is revoked

Verification: confirm that `Sign::App::Settings::PasskeysController#verification` (the step-up entry
point after `step_up only: %i(new create options verification)`) calls `finish_passkey_ceremony!` →
`commit_settings_passkey_registration!` (for registration), and separately that step-up freshness
update is committed by acme's ceremony result consumer without creating a new token row. Check that
no `ClientToken.create` call appears in the step-up path.

---

## Social Login Regression Test Strategy

Social login is the working behavioral baseline. Regression tests must verify:

1. **Normal sign-in flow**: Google/Apple callback → `SocialAuthLoginHandler` →
   `establish_signed_in_session!` → cookie set → redirect to dashboard
2. **Normal sign-up flow**: Google/Apple callback → `SocialAuthSignupFinalizer` →
   `finalize_sign_up_from_checkpoint!` → `bootstrap_actor: true` → welcome redirect
3. **State mismatch**: tampered or missing OAuth state param → 422 / redirect to start
4. **Nonce mismatch**: OIDC nonce does not match → 422
5. **Replay**: duplicate callback request → 422 (ceremony grant consumed)
6. **Session limit at 2 active**: existing user with 2 active tokens → restricted token issued →
   session management
7. **Session limit hard reject**: existing user with 2 active + 1 restricted → 403
8. **Unlink**: `DELETE /sign/social/auth` → `SocialAuthService.unlink` → identity unlinked

Existing test: `test/controllers/sign/app/social/authentications_controller_test.rb` — verify these
cases are covered and add missing cases.

---

## Implementation Steps

### Phase 0: Verify current breakage

Run existing tests to confirm scope:

```bash
bin/rails test test/controllers/sign/app/in/emails_controller_test.rb
bin/rails test test/controllers/sign/app/up/emails_controller_test.rb
bin/rails test test/controllers/sign/app/up/telephones_controller_test.rb
```

### Phase 1: Restore sign-in email OTP (app surface)

**File:** `app/controllers/sign/app/sign/in/emails_controller.rb`

1. Restore rate limits for `update` action (burst + sustained, same as `create`).
2. Change `before_action :load_user_email, only: :edit` → `only: %i(edit update)`.
3. Restore `def update` action:
   - Read submitted code from `email_params(:pass_code)[:pass_code]`
   - Validate presence (render `:edit` 422 if blank)
   - Call `verify_otp_and_login(@user_email)`
   - On success: `respond_to_successful_email_login(result)`
   - On hard reject: `render_session_limit_hard_reject`
   - On failure: add error to `@user_email.errors[:pass_code]`, render `:edit` 422
4. Restore private helpers: `respond_to_successful_email_login`,
   `redirect_after_successful_email_login`, `render_successful_email_login_json`,
   `respond_to_failed_email_login`, `verify_otp_and_login`, `verify_existing_email_otp`,
   `verify_dummy_otp`, `handle_failed_otp_attempt`, `user_from_user_email`.
   - `verify_existing_email_otp`: call `verify_otp_code(user_email, user_email.pass_code)` → on
     success, call
     `establish_signed_in_session!(user, pt: peek_pt, ri: params[:ri], auth_method: "email")` → call
     `sign_in_result_from_session_result(result, actor: user)` → return appropriate hash
   - `verify_dummy_otp`: call `super(user_email.pass_code)` → return
     `{ success: false, error: ... }`
   - `handle_failed_otp_attempt`: increment attempts, emit `SignRiskEmitter`, return locked or
     remaining-attempts error hash

**Pattern reference:** `git show HEAD:app/controllers/sign/app/sign/in/emails_controller.rb`

### Phase 2: Restore sign-up email OTP verification (app surface)

**File:** `app/controllers/sign/app/sign/up/check/email/otps_controller.rb`

1. Restore `def update` action:
   - Handle dummy flow: render invalid code if `dummy_existing_email_flow?`
   - Load gate context with `load_gate_context!(gate_for_update)`
   - Load `@user_email = current_registration_email`
   - Validate blank code → 422
   - Call `verify_otp_ceremony!` (restore private method: `SignOtpCeremony.verify!` with
     `purpose: :sign_up, surface: :app, channel: :email, subject: @sign_up_ticket, destination: @user_email.address, code: ..., session_nonce: @sign_up_ticket.public_id`)
   - On locked: handle locked result
   - On failure: `render_otp_ceremony_result(result)`
   - On success:
     `@user_email.update!(user_email_status_id: ClientEmailStatus::VERIFIED_WITH_SIGN_UP)` →
     `complete_update_and_redirect`
2. Restore private helpers: `verify_otp_ceremony!`, `log_email_otp_rejection`,
   `render_blank_code_rejection`, `handle_locked_result`, `complete_update_and_redirect`.

**File:** `app/controllers/sign/app/sign/up/emails_controller.rb`

3. Restore `advance_sign_up_flow_after_email_otp!`:
   - Find current sign-up flow via `sign_up_flow_locator.current`
   - In `AppTicketRecord.connected_to(role: :writing)`:
     - `SignUpStateMachine.call(ticket: cycle, event: :verify_contact, actor_context: Actor.authn)`
     - If `verify.status == :advanced`: call `enter_checkpoint` and `clear_requirement` events
   - Log warning on non-`:advanced` result; do not redirect forward
4. Restore `sign_up_flow_locator` private method.

**Pattern reference:** `git show HEAD:app/controllers/sign/app/sign/up/emails_controller.rb`

### Phase 3: Restore sign-up telephone OTP verification (app surface)

**File:** `app/controllers/sign/app/sign/up/check/telephone/otps_controller.rb`

1. Restore `def update` action:
   - Handle dummy telephone flow
   - Load gate + `@user_telephone`
   - Validate submitted code presence
   - Call `verify_otp_ceremony!` (restore private method: `SignOtpCeremony.verify!` with
     `channel: :telephone`)
   - Handle locked result
   - On success: `verify_telephone_ownership!` → `advance_sign_up_flow_after_telephone_otp!` →
     redirect to guard path
2. Restore `verify_otp_ceremony!` private method.

**File:** `app/controllers/sign/app/sign/up/telephones_controller.rb`

3. Restore `verify_telephone_ownership!` and `advance_sign_up_flow_after_telephone_otp!`.

**Pattern reference:** `git show HEAD:app/controllers/sign/app/sign/up/telephones_controller.rb`

### Phase 4: Restore com surface parallels

Apply the same restorations to:

- `app/controllers/sign/com/sign/in/emails_controller.rb` — same pattern, `VisitorEmail` instead of
  `ClientEmail`, com-specific state/session keys
- `app/controllers/sign/com/sign/up/check/email/otps_controller.rb`
- `app/controllers/sign/com/sign/up/check/telephone/otps_controller.rb`

**Pattern reference:** `git show HEAD:app/controllers/sign/com/sign/in/emails_controller.rb` etc.

### Phase 5: Update documentation

- `docs/security/ceremony-grant-result.md`: Add a note that the ceremony grant/result pattern for
  settings passkey/TOTP/secret*credential registration is currently using the direct commit path
  (`commit_settings*\*`), not the full grant→result→finalcommitter chain. The doc describes the
  intended future state (per `adr/acme-sign-core-base-port-boundary.md`).
- No other docs need changes — the route design in `docs/security/sign-up-sequence.md` and
  `docs/security/sign-in-sequence.md` is already aligned with the restored behavior.

---

## Tests Required

### Restore / re-add (app surface)

1. **`test/controllers/sign/app/in/emails_controller_test.rb`** — add `update` action tests:
   - Success: valid OTP → session created → redirect to dashboard
   - Failure: wrong OTP → 422 + error
   - Blank OTP → 422
   - Dummy path: non-existent email → 422 (timing equalized)
   - Locked email → locked message
   - Session limit: restricted → redirect to session management
   - Session limit hard reject → 403
   - MFA required → redirect to MFA entry

2. **`test/controllers/sign/app/up/check/email/otps_controller_test.rb`** (was deleted, recreate):
   - `POST /sign/up/check/email/otp` (create/resend) — rate limited case
   - `PATCH /sign/up/check/email/otp` (update) — valid OTP → state machine advances → birthdate
     redirect
   - `PATCH` — wrong OTP → 422
   - `PATCH` — blank OTP → 422
   - `PATCH` — locked OTP → redirect to start
   - `PATCH` — dummy flow → 422

3. **`test/controllers/sign/app/up/telephones_controller_test.rb`** — add `update` tests:
   - Same set as email OTP above, using telephone params

### Compensation tests (new)

4. **`test/controllers/sign/app/sign_up_compensation_test.rb`** (new):
   - `finalize_sign_up_from_checkpoint!` when `IdentityGraphProvisioner` raises → ticket stays
     `FINALIZING`, no token created
   - `finalize_sign_up_from_checkpoint!` when `establish_signed_in_session!` raises after
     provisioner → ticket is `FINALIZED`, no cookie set, no `ClientToken` row
   - Concurrent finalization on same ticket → only one token created (row lock test)
   - `SignUpArtifactCleanup` does not touch registered `Client` or `ClientEmail` records (only
     ticket-owned pending artifacts)

5. **`test/controllers/sign/app/sign_in_compensation_test.rb`** (new):
   - Failed OTP → no `ClientToken` row created
   - Session limit hard reject path → no `ClientToken` row created, 403 returned
   - Dummy path → no auth state set in session

### Social login regression (add to existing test)

6. **`test/controllers/sign/app/social/authentications_controller_test.rb`** — verify:
   - All 8 cases from the Social Login Regression Test Strategy section above
   - Specifically: state mismatch, nonce mismatch, replay, session limit at 3/4 (restricted), hard
     reject at full limit

### Step-up isolation (new assertion in passkey test)

7. **`test/controllers/sign/app/settings/passkeys_controller_test.rb`** — add:
   - Step-up `verification` success: assert `ClientToken.count` did not change, assert no new
     session cookie issued, assert `last_step_up_at` updated on existing token

---

## Verification

```bash
# Targeted first
bin/rails test test/controllers/sign/app/in/emails_controller_test.rb
bin/rails test test/controllers/sign/app/up/check/email/otps_controller_test.rb
bin/rails test test/controllers/sign/app/up/telephones_controller_test.rb
bin/rails test test/controllers/sign/app/social/authentications_controller_test.rb
bin/rails test test/controllers/sign/app/settings/passkeys_controller_test.rb

# Broader — shared concerns affect multiple surfaces
bin/rails test test/controllers/sign/

# Compensation tests (new files)
bin/rails test test/controllers/sign/app/sign_up_compensation_test.rb
bin/rails test test/controllers/sign/app/sign_in_compensation_test.rb
```

After each phase, run the targeted test before moving to the next phase.

---

## Files to Create or Modify

### Restore (modify):

- `app/controllers/sign/app/sign/in/emails_controller.rb`
- `app/controllers/sign/app/sign/up/check/email/otps_controller.rb`
- `app/controllers/sign/app/sign/up/emails_controller.rb`
- `app/controllers/sign/app/sign/up/check/telephone/otps_controller.rb`
- `app/controllers/sign/app/sign/up/telephones_controller.rb`
- `app/controllers/sign/com/sign/in/emails_controller.rb`
- `app/controllers/sign/com/sign/up/check/email/otps_controller.rb`
- `app/controllers/sign/com/sign/up/check/telephone/otps_controller.rb`

### Restore + extend (tests):

- `test/controllers/sign/app/in/emails_controller_test.rb` (extend)
- `test/controllers/sign/app/up/telephones_controller_test.rb` (extend)
- `test/controllers/sign/app/social/authentications_controller_test.rb` (extend)
- `test/controllers/sign/app/settings/passkeys_controller_test.rb` (extend)

### Create (new tests):

- `test/controllers/sign/app/up/check/email/otps_controller_test.rb`
- `test/controllers/sign/app/sign_up_compensation_test.rb`
- `test/controllers/sign/app/sign_in_compensation_test.rb`

### Update (docs):

- `docs/security/ceremony-grant-result.md` — add note about current direct-commit path

---

## Key Utilities to Reuse

| Utility                                        | Location                                                          | Used for                              |
| ---------------------------------------------- | ----------------------------------------------------------------- | ------------------------------------- |
| `establish_signed_in_session!`                 | `app/controllers/concerns/authentication_base.rb:2308`            | All sign-in completion                |
| `finalize_sign_up_from_checkpoint!`            | `app/controllers/concerns/sign_up_sequence_controller_support.rb` | All sign-up completion                |
| `SignOtpCeremony.verify!`                      | `app/services/sign_otp_ceremony.rb`                               | Sign-up OTP verification              |
| `verify_otp_code`                              | `AuthenticationBase` concern (existing)                           | Sign-in OTP verification              |
| `sign_in_result_from_session_result`           | `AuthenticationBase` concern                                      | Parse session result for redirect     |
| `load_gate_context!`                           | `SignUpExplicitStepControllerSupport`                             | Gate load for OTP check controllers   |
| `advance_sign_up_flow_after_email_otp!`        | `sign/app/sign/up/emails_controller.rb` (restore here)            | Email OTP → state machine             |
| `advance_sign_up_flow_after_telephone_otp!`    | `sign/app/sign/up/telephones_controller.rb` (restore here)        | Telephone OTP → state machine         |
| `SignUpStateMachine.call`                      | `app/services/sign_up_state_machine.rb`                           | State machine events                  |
| `Actor.authn`                                  | global                                                            | Actor context for state machine calls |
| `AppTicketRecord.connected_to(role: :writing)` | DB concern                                                        | Write-DB routing for state machine    |
