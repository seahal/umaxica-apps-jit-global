# Sign-Up Sequence

> **Authority boundary:** `acme/www` is the Session, Token, Account, Preference, Authorization, and
> downstream-token Authority. `sign/id` is ceremony-only. Existing sign-side physical tables/models
> do not imply sign-side authority. Do not use this document to reintroduce sign-side sessions,
> refresh, preference, dashboard, account lifecycle, token issuance, logout, or step-up freshness.

This document records the sign-up routing sequence for the `app` and `com` sign surfaces, and the
operator acquisition/lifecycle routing sequence for `org`. The `app` telephone and `com` telephone
flows are now driven by `ClientSignUpFlow` / `VisitorSignUpFlow` tickets and `SignUpStateMachine`;
the flow ticket is the source of truth for pending actor identity and contact tracking. Legacy
per-surface session keys for pending actor ID have been removed.

The public sign-up route vocabulary is frozen. This document tracks the accepted paths and the
authority boundary migration target; it does not authorize changing `/sign/up/*` or `/social/*`
paths.

`org` is excluded from the six app/com user-facing sign-up routes below. It has
invitation/provisioning entry points and operator lifecycle requests, not a normal end-user sign-up
flow.

Org/operator signup checkpoint cancellation is intentionally not implemented as part of the app/com
checkpoint flow. Future org work may reuse the sign-up cycle lifecycle predicates, but operator
acquisition must continue to follow the org invitation and lifecycle-request boundaries until a
separate ADR changes that policy.

## Current Route Inventory

`app` has four sign-up entry paths:

1. Email sign-up.
2. Telephone sign-up.
3. Google social sign-up.
4. Apple social sign-up.

`com` has two sign-up entry paths:

1. Email sign-up.
2. Telephone sign-up.

`org` has two operator acquisition/lifecycle paths:

1. External candidate inquiry.
2. Operator lifecycle request.

## App Sign-Up Route Matrix

| route         | controller                                                                                             | challenge/provider        | state object                                  | completion gate                     | abnormal behavior                                                                   | tests                                                                                                                                         |
| ------------- | ------------------------------------------------------------------------------------------------------ | ------------------------- | --------------------------------------------- | ----------------------------------- | ----------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| Email OTP     | `Sign::App::Sign::Up::EmailsController` -> `Sign::App::Sign::Up::Check::Email::OtpsController`         | Email OTP                 | `ClientSignUpFlow` + `ClientEmail`            | `finalize_sign_up_from_checkpoint!` | blank/wrong/locked/expired/stale OTP fails closed; retry stays on ticket-owned flow | `test/controllers/sign/app/sign/up/check/email/otps_controller_test.rb`                                                                       |
| Telephone OTP | `Sign::App::Sign::Up::TelephonesController` -> `Sign::App::Sign::Up::Check::Telephone::OtpsController` | Telephone OTP             | `ClientSignUpFlow` + `ClientTelephone`        | `finalize_sign_up_from_checkpoint!` | blank/wrong/locked/expired/stale OTP fails closed; retry stays on ticket-owned flow | `test/controllers/sign/app/sign/up/check/telephone/otps_controller_test.rb`                                                                   |
| Google social | `Sign::App::Social::AuthenticationsController` + `Sign::App::Auth::OmniauthCallbacksController`        | Google provider assertion | `ClientSignUpFlow` + social callback evidence | `finalize_sign_up_from_checkpoint!` | state/nonce/provider errors and replay fail closed                                  | `test/controllers/sign/app/social/authentications_controller_test.rb`, `test/controllers/sign/app/auth/omniauth_callbacks_controller_test.rb` |
| Apple social  | `Sign::App::Social::AuthenticationsController` + `Sign::App::Auth::OmniauthCallbacksController`        | Apple provider assertion  | `ClientSignUpFlow` + social callback evidence | `finalize_sign_up_from_checkpoint!` | state/nonce/provider errors and replay fail closed                                  | `test/controllers/sign/app/social/authentications_controller_test.rb`, `test/controllers/sign/app/auth/omniauth_callbacks_controller_test.rb` |

Current surface terminology and inventory:

| Surface | Term                                           | Actor/resource                                         | Identifier                                                            | Credential setup                                                                                            | Challenge                                                                          | Verification                                                                         | Session/token                                                                       | Chronicle/audit                        | Routes/controllers/views/tests                                                                                                                          |
| ------- | ---------------------------------------------- | ------------------------------------------------------ | --------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------- | -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `app`   | User/client registration                       | `Client`, contact identifiers, app social identities   | Email, telephone, Google provider assertion, Apple provider assertion | Birthdate checkpoint, passkey checkpoint, passcode checkpoint, and social identity binding where applicable | Sign-up checkpoint requirements; provider callback state validation for app social | Email/telephone OTP verification and checkpoint completion before durable completion | Post-finalization handoff enters the app sign-in/session sequence                   | Client sign-up chronicle/audit events  | `config/routes/sign.rb` app `sign/up` and `social`; `app/controllers/sign/app/sign/up/**`; app social callback controllers/views/tests                  |
| `com`   | Public/corporate visitor entry or inquiry flow | `Visitor`, visitor contact identifiers                 | Email, telephone                                                      | Birthdate checkpoint, passkey checkpoint, passcode checkpoint                                               | Sign-up checkpoint requirements                                                    | Email/telephone OTP verification and checkpoint completion before durable completion | Post-finalization handoff enters the com sign-in/session sequence                   | Visitor sign-up chronicle/audit events | `config/routes/sign.rb` com `sign/up`; `app/controllers/sign/com/sign/up/**`; com sign-up/no-social tests                                               |
| `org`   | Operator acquisition / staff onboarding        | `Operator`, invitation and lifecycle request resources | Invitation token or lifecycle request context                         | Passkey and secret credential setup through staff onboarding or signed-in settings where implemented        | No public social sign-up challenge                                                 | Invitation/lifecycle approval and local credential setup boundaries                  | Operator session is established only through org sign-in after local authentication | Operator chronicle/audit events        | `config/routes/sign.rb` org `sign/up/invitations` and settings lifecycle request routes; `app/controllers/sign/org/up/**`; org sign-up/onboarding tests |

The app/com sign-up checkpoint owns required registration setup before durable account finalization.
Birthdate is a sign-up checkpoint requirement for app/com end-user registration.

## Shared Completion Boundary

All sign-up routes converge on the shared sign-up finalization boundary:

- `finalize_sign_up_from_checkpoint!` is the sign-up completion gate.
- `IdentityGraphProvisioner.call!` runs inside that boundary before handoff.
- `establish_signed_in_session!(..., bootstrap_actor: true)` is the shared session issuance helper
  used by the sign-up handoff path.
- Sign-up controllers must not create `ClientToken` or `ClientDeviceSession` directly, and they must
  not write auth cookies directly.
- Sign-in convergence for the next phase should reuse `establish_signed_in_session!` instead of
  introducing a route-specific session helper.

See `docs/security/sign-up-compensation.md` for retry, rollback, and cleanup behavior when sign-up
stops before durable completion.

## Ceremony Cleanup

Credential ceremony transaction tables use short-lived `expires_at` windows, not the account
retention `purged_at` lifecycle. Production recurring cleanup therefore registers the dedicated
`EmailCeremonyTransactionPurgeJob`, `PasskeyCeremonyTransactionPurgeJob`,
`SecretCredentialCeremonyTransactionPurgeJob`, `SocialCeremonyTransactionPurgeJob`,
`StepUpCeremonyTransactionPurgeJob`, `TelephoneCeremonyTransactionPurgeJob`, and
`TotpCeremonyTransactionPurgeJob` jobs from `config/recurring.yml`.

The cleanup jobs delete only rows that are expired beyond each ceremony type's retention period.
Active, non-expired ceremony transactions are not purgeable. Re-running the jobs is idempotent:
already-deleted expired rows are absent, and active rows remain outside the purge scope.

Sign-up cancellation or abandonment must mark the flow state through the sign-up lifecycle; physical
deletion is a cleanup concern. After cleanup removes expired ceremony transactions, retry starts a
fresh ceremony instead of reusing stale OTP, WebAuthn, social, TOTP, telephone, or secret-credential
state.

## App Social Sign-Up And Sign-In Boundary

Google and Apple on the `app` surface use the same provider callback, but the callback must choose
between sign-up and sign-in by whether the provider identity is already registered and complete.

- If the Google or Apple identity is unknown, the request enters the app sign-up sequence. It must
  not issue an authenticated login session. The actor may enter the normal login path only after the
  sign-up sequence has completed required checkpoint setup and finalization.
- If the Google or Apple identity is registered and the account has completed required sign-up
  setup, the request enters the normal login sequence.
- A registered Google or Apple identity must not be routed through the sign-up sequence again as a
  new registration. The sign-up path is only for unknown provider identities or incomplete
  registration setup that still needs checkpoint completion.
- An account that still lacks required sign-up data, including birthdate, is not a complete
  registered social-login account for login purposes. It must be returned to the sign-up checkpoint
  before any authenticated login session is issued.

## Common Post-Finalization Handoff

All `app` and target `com` sign-up paths share the same post-finalization routing rule:

1. Complete sign-up finalization.
2. Enter the existing sign-in boundary in the same Rails action/request.
3. The sign-in boundary creates or resumes the pending sign-in cycle.
4. Evaluate session-limit handling, sign-in guardrail state, `/sign/in/check`, and
   `/sign/in/selector` in order.
5. Commit the selector selection, then issue the active authenticated session.
6. Continue to `/welcome`.
7. If a safe `rt` return path is present, jump there after welcome sequence handling; otherwise
   continue to `/dashboard`.

The sign-up finalization and sign-in boundaries must not redirect, render, or perform an HTTP reload
between each other. Route selection belongs to the post-finalization handoff after the sign-in
boundary has either stopped at a pending sign-in participant or issued the authenticated session.

## Signed-In Actor Re-entry

A signed-in actor must not start a new sign-up or sign-in sequence without first signing out.
Attempting to enter registration or login while already signed in is an abnormal request.

The server must reject that request with a status code and a plain-text message. It must not
redirect to dashboard, continue a return path, create a new registration sequence, or sign the actor
out on their behalf.

## Guardrail, Checkpoint, Selector, Welcome, And Dashboard

`/sign/up/guard` is the sign-up stop point for cases where the current sign-up sequence must not
continue. It is distinct from `/sign/up/check`:

- Guardrail blocks continuation and returns only plain text.
- Checkpoint collects or clears required setup before finalization.

Sign-in guardrail state is also part of the common post-finalization handoff. It is evaluated before
checkpoint, selector, and session issuance. If it blocks after durable sign-up completion, that is a
sign-in failure domain; it must not delete completed account data.

Guardrail, checkpoint, selector, and welcome are sequence participants whose required content can
grow or disappear over time. The sign-up and handoff state machines decide when the current sequence
is allowed to evaluate each participant.

Each participant evaluates an ordered stack of requirement items for the current sign-up or
post-finalization sign-in sequence. The sequence advances only when the current participant's stack
is empty or every required stack item is cleared.

Expected participant behavior:

- Guardrail: if the stack is empty, advance without displaying a page. If the stack has any blocking
  item, stop the attempt with plain text. No redirect is performed.
- Checkpoint: if the stack is empty, advance without displaying a page. If the stack has any
  blocking item, keep the actor at checkpoint until all required setup is cleared.
- Selector: if there is one activation candidate, auto-commit it without rendering UI. If there are
  multiple candidates, require explicit selection. The active session is issued only after selector
  commit succeeds.
- Welcome: if the sequence welcome stack is empty, continue to the safe `rt` return path or
  `/dashboard`. If the stack has items, display them after sign-in. Reaching welcome means the actor
  has completed selector and active session issuance and can behave as a signed-in actor.

`/welcome` is the post-finalization handoff route. It consumes the preserved `rt` only when that
return path is safe. If `rt` is missing, blank, invalid, unsafe, expired, or points back to
`/welcome`, the actor is redirected to `/dashboard`.

`/dashboard` remains an ordinary authenticated page. Ordinary direct dashboard access must not turn
a query parameter into a post-auth continuation.

Before redirecting to `/welcome`, the server clears any previous welcome gate for the surface and
issues a new session gate with `remaining = 5`, `issued_at`, and `expires_at`. Each `/welcome`
request decrements `remaining`. Once `remaining <= 0`, or once the current time is at or after
`expires_at`, the welcome gate is cleared and the actor is redirected to `/dashboard`. The expiry is
absolute and refresh does not extend it.

For example, telephone sign-up checkpoint can contain separate birthdate, passkey, and passcode
requirements. The account must not finalize until all three items are cleared. Adding a future
requirement should add a checkpoint item, not introduce a new route between checkpoint and
finalization.

Checkpoint cancellation is allowed only before durable finalization starts. Cancelled sign-up cycles
are logically discarded immediately and scheduled for later physical cleanup; controllers do not
physically delete sign-up artifacts. Because identifiers may remain reserved until the purge window
expires, cancellation UI should send the actor back to the surface root and tell them to retry
registration after a short delay.

## Reference Shape: Email Sign-Up

Email sign-up is the cleanest current route and should be treated as the reference when the sign-up
state machine is introduced.

### App Email

Expected state-machine path:

- Entry: `GET /sign/up/email/new`
  - Start or resume the app sign-up sequence.
  - The sequence is still before contact submission.
  - Backtracking rules should allow returning here only while no irreversible contact verification
    has completed.

- Email submission: `POST /sign/up/email`
  - Validate Turnstile and email params.
  - Create or resume pending email verification.
  - Move the sequence to the email OTP step.

- OTP form: `GET /sign/up/check/email/otp`
  - Show the pass-code form only while the sequence is waiting for email OTP.
  - Reject direct access when the sequence is missing, expired, or no longer at the OTP step.

- OTP submission: `PATCH /sign/up/check/email/otp`
  - Verify the submitted pass code.
  - Existing-account sign-up attempts should leave the sign-up sequence and return to sign-in.
  - New-account sign-up should move the sequence toward guardrail/checkpoint without allowing a
    return to email editing.

- Sign-up guard: `GET /sign/up/guard`
  - This is the sign-up stop point for sequence-level rejection such as policy blocks, retry
    cooldowns, or other non-continuable registration states.
  - It returns plain text and does not redirect.
  - If no guardrail content is required, the sequence advances to checkpoint.

- Sign-up check: `GET /sign/up/check/email/birthdate`
  - This is a sign-up sequence checkpoint, not the current private `/sign/in/check`.
  - For email sign-up, the checkpoint must require birthdate.
  - Birthdate collection happens inside the checkpoint.
  - The checkpoint validates the exact `YYYY-MM-DD` text form.
  - The checkpoint rejects future values.
  - The checkpoint persists the encrypted birthdate.
  - Once birthdate is accepted, the checkpoint can complete.
  - If no other checkpoint content is required after birthdate, the route can continue immediately.

- Account finalization
  - Allowed only when email OTP and checkpoint birthdate are complete.
  - `finalize_sign_up_from_checkpoint!` promotes the pending actor, provisions the durable identity
    graph, and hands off to the shared sign-in boundary.
  - `establish_signed_in_session!` is called from the shared handoff path with
    `bootstrap_actor: true` only for newly provisioned identities.
  - Both boundaries run inside the same Rails action/request.
  - Neither boundary redirects, renders, reloads through HTTP, or chooses the final route.
  - If sign-up finalization fails, treat it as sign-up failure recovery.
  - If sign-in/session issuance fails after durable sign-up completion, treat it as sign-in failure
    handling and do not delete the completed account.

- Welcome sequence: `GET /welcomes/:id`
  - Current route helper: `sign_app_welcome_path("post_auth")`.
  - This step is also bypassable by `continue_welcome_sequence_without_content!` when no welcome
    sequence content is required.
  - The common post-finalization handoff applies: after sign-in guardrail, checkpoint, selector,
    session issuance, and welcome handling, continue to the safe `rt` return path when present;
    otherwise continue to `/dashboard`.

- Post-auth handoff: `complete_update_and_redirect`
  - The controller-level completion hook should hand off into the sequence instead of deciding the
    final route by itself.

Current implementation path:

- Entry: `GET /sign/up/email/new`
  - `Sign::App::Sign::Up::EmailsController#new`
  - Builds an empty `ClientEmail`.
  - No pending client is created yet.

- Email submission: `POST /sign/up/email`
  - `Sign::App::Sign::Up::EmailsController#create`
  - Validates Turnstile.
  - Permits `user_email.raw_address`, `user_email.address`, `user_email.confirm_policy`,
    `user_email.promotional`, and `user_email.notifiable`.
  - Calls `initiate_email_verification!`.
  - Creates or resumes the pending sign-up email verification.
  - Stores registration progress in session.
  - Redirects to `GET /sign/up/check/email/otp`.

- OTP form: `GET /sign/up/check/email/otp`
  - `Sign::App::Sign::Up::Check::Email::OtpsController#show`
  - Loads `current_registration_email`.
  - Rejects the request and resets the flow if the pending email session is missing, expired, or
    mismatched.
  - Renders the pass-code form when the session is valid.

- OTP submission: `PATCH /sign/up/check/email/otp`
  - `Sign::App::Sign::Up::Check::Email::OtpsController#update`
  - Requires `user_email.pass_code`.
  - Calls `process_verification_code`.
  - Existing-account sign-up attempts are redirected back to sign-in instead of creating a new
    account.
  - New-account sign-up verifies the OTP ceremony, marks email verified, advances the sign-up flow
    to checkpoint, and then redirects to birthdate.

- Birthdate checkpoint: `GET /sign/up/check/email/birthdate`
  - `Sign::App::Sign::Up::Check::Email::BirthdatesController#show`
  - The checkpoint owns the remaining birthdate requirement before finalization.

- Account finalization: `finalize_sign_up_from_checkpoint!`
  - Promotes the pending `Client`.
  - Creates `rp_account` when missing.
  - Writes the sign-up audit entry.
  - Saves the verified email.
  - Provisions the identity graph.
  - Hands the actor off to the shared sign-in boundary with `bootstrap_actor: true`.

- Post-auth handoff: shared sign-in boundary
  - The shared handoff helper establishes the authenticated session only after guardrail,
    checkpoint, and selector evaluation complete.
  - The sign-up controller does not choose the final route directly.
  - The shared helper is the only place sign-up should issue auth cookies or login tokens.

Current gate status:

- The app email OTP flow now advances into the birthdate checkpoint before durable finalization.
- The sign-up completion boundary remains shared with the sign-in handoff and must not directly
  issue tokens or cookies.
- Any future refactor should keep the OTP controller focused on OTP ceremony and checkpoint
  progression only.

### Com Email

Target state-machine path:

- Entry: `GET /sign/up/email/new`
  - Start or resume the com sign-up sequence.
  - The sequence is still before contact submission.
  - Backtracking rules should allow returning here only while no irreversible contact verification
    has completed.

- Email submission: `POST /sign/up/email`
  - Validate Turnstile and email params.
  - Create or resume pending email verification.
  - Move the sequence to the email OTP step.

- OTP form: `GET /sign/up/email/edit`
  - Show the pass-code form only while the sequence is waiting for email OTP.
  - Reject direct access when the sequence is missing, expired, or no longer at the OTP step.

- OTP submission: `PATCH /sign/up/email`
  - Verify the submitted pass code.
  - Existing-account sign-up attempts should leave the sign-up sequence and return to sign-in.
  - New-account sign-up should move the sequence toward guardrail/checkpoint without allowing a
    return to email editing.

- Sign-up guard: `GET /sign/up/guard`
  - This is the sign-up stop point for sequence-level rejection such as policy blocks, retry
    cooldowns, or other non-continuable registration states.
  - It returns plain text and does not redirect.
  - If no guardrail content is required, the sequence advances to checkpoint.

- Sign-up check: `GET /sign/up/check`
  - This is a sign-up sequence checkpoint, not the current private `/sign/in/check`.
  - For com email sign-up, the checkpoint must require birthdate.
  - Birthdate collection happens inside the checkpoint.
  - The checkpoint validates the exact `YYYY-MM-DD` text form.
  - The checkpoint rejects future values.
  - The checkpoint persists the encrypted birthdate.
  - Once birthdate is accepted, the checkpoint can complete.
  - If no other checkpoint content is required after birthdate, the route can continue immediately.

- Account finalization
  - Allowed only when email OTP and checkpoint birthdate are complete.
  - Use the same two-boundary shape as app email: sign-up finalization first, then the existing
    sign-in boundary inside the same Rails action/request.
  - Do not redirect, render, or perform an HTTP reload between sign-up finalization and sign-in.
  - Promote or finalize the pending `Visitor`.
  - Create `rp_account` when missing.
  - Write the sign-up audit entry.
  - Save the verified email state.
  - Enter the sign-in boundary with `auth_method: "email"`; session issuance happens only after
    sign-in guardrail, checkpoint, and selector pass.
  - Sign-up finalization failure belongs to sign-up failure recovery.
  - Sign-in/session issuance failure after durable sign-up completion belongs to sign-in failure
    handling and must not delete completed account data.

- Welcome sequence: `GET /welcomes/:id`
  - Current route helper: `sign_com_welcome_path("post_auth")`.
  - The common post-finalization handoff applies: after sign-in guardrail, checkpoint, selector,
    session issuance, and welcome handling, continue to the safe `rt` return path when present;
    otherwise continue to `/dashboard`.

Current path:

1. `GET /sign/up/email/new` renders the email sign-up form.
2. `POST /sign/up/email` validates Turnstile, validates email params, creates or resumes pending
   visitor email verification, stores pending registration state in session, and redirects to edit.
3. `GET /sign/up/email/edit` renders the OTP form when the pending email session is valid.
4. `PATCH /sign/up/email` validates the OTP.
5. OTP success marks the `VisitorEmail` as `VERIFIED_WITH_SIGN_UP`.
6. The visitor account row is created if needed.
7. A sign-up audit entry is written.
8. The visitor is logged in.
9. A welcome bulletin is requested through the shared helper.
10. The flow calls the sign-in post-authentication sequence.
11. Target behavior is that guardrail, checkpoint, and selector are evaluated before session
    issuance.
12. In the current implementation, the actor reaches `/sign/in/check` if checkpoint content exists.
13. Otherwise, or after checkpoint and selector completion, the actor receives the active session,
    continues to dashboard, and then the safe `rt` return path when present.

## App Telephone

App telephone sign-up verifies telephone ownership first, then moves into the sign-up checkpoint.
The checkpoint owns required setup such as passkey registration; the telephone OTP route should not
branch into a separate passkey-registration route before the checkpoint.

Expected state-machine path:

- Entry: `GET /sign/up/telephone/new`
  - Start or resume the app sign-up sequence.
  - The sequence is still before telephone submission.

- Telephone submission: `POST /sign/up/telephone`
  - Validate Turnstile and telephone params.
  - Create or resume pending telephone verification.
  - Create the pending `Client` when needed.
  - Move the sequence to the SMS OTP step.

- SMS OTP form: `GET /sign/up/telephone/edit`
  - Show the pass-code form only while the sequence is waiting for SMS OTP.
  - Reject direct access when the sequence is missing, expired, or no longer at the SMS OTP step.

- SMS OTP submission: `PATCH /sign/up/telephone`
  - Verify the submitted pass code.
  - Mark the telephone as `VERIFIED_WITH_SIGN_UP`.
  - Check whether the pending client already has an active passkey.
  - Move the sequence toward guardrail/checkpoint without allowing a return to telephone editing.

- Sign-up guard: `GET /sign/up/guard`
  - This is the sign-up stop point for sequence-level rejection such as policy blocks, retry
    cooldowns, or other non-continuable registration states.
  - It returns plain text and does not redirect.
  - If no guardrail content is required, the sequence advances to checkpoint.

- Sign-up check: `GET /sign/up/check`
  - This checkpoint owns all required post-contact setup before account finalization.
  - For SMS sign-up, the checkpoint must require all of:
    - accepted birthdate;
    - at least one active passkey for the pending client;
    - at least one active sign-in-capable passcode for the pending client.
  - If any requirement is missing, the checkpoint remains incomplete and the actor cannot continue
    to account finalization.
  - The checkpoint can render both setup tasks on one page or route to dedicated setup substeps, but
    the sequence state should remain `CHECKPOINT_PENDING` until both are complete.

- Birthdate setup requirement
  - Birthdate collection happens inside `/sign/up/check`.
  - The checkpoint validates the exact `YYYY-MM-DD` text form.
  - The checkpoint rejects future values.
  - The checkpoint persists the encrypted birthdate and marks the birthdate requirement as cleared.

- Passkey setup requirement
  - Passkey registration happens from the checkpoint when the pending client has no active passkey.
  - The existing `/sign/up/telephone/passkey_registration` implementation is the current mechanism,
    but the state-machine route should model it as checkpoint-owned setup.
  - Future route shape can be generalized to `/sign/up/passkey` if the same checkpoint is shared by
    email, telephone, and social sign-up.
  - Completion creates a `ClientPasskey` for the pending client and marks the passkey requirement as
    cleared.

- Passcode setup requirement
  - Use the existing model/service layer: `ClientSecret` and `ClientSecrets::Create`.
  - Do not reuse the configuration controller directly; it is written for an already-authenticated
    actor and step-up flow.
  - Generate the raw passcode server-side, show it once, persist only the digest, and mark the
    passcode requirement as cleared after the user confirms storage.
  - The passcode should be sign-in capable, active, and attached to the pending client before
    account finalization.

- Account finalization
  - Allowed only when telephone OTP, birthdate, passkey setup, and passcode setup are all complete.
  - Use the same two-boundary shape as email: sign-up finalization first, then the existing sign-in
    boundary inside the same Rails action/request.
  - Do not redirect, render, or perform an HTTP reload between sign-up finalization and sign-in.
  - Promote the pending `Client`.
  - Create `rp_account` when missing.
  - Write the sign-up audit entry.
  - Enter the sign-in boundary with `auth_method: "telephone"`; session issuance happens only after
    sign-in guardrail, checkpoint, and selector pass.
  - Sign-up finalization failure belongs to sign-up failure recovery.
  - Sign-in/session issuance failure after durable sign-up completion belongs to sign-in failure
    handling and must not delete completed account data.

- Welcome sequence: `GET /welcomes/:id`
  - Current route helper: `sign_app_welcome_path("post_auth")`.
  - This step is bypassable by `continue_welcome_sequence_without_content!` when no welcome sequence
    content is required.
  - The common post-finalization handoff applies: after sign-in guardrail, checkpoint, selector,
    session issuance, and welcome handling, continue to the safe `rt` return path when present;
    otherwise continue to `/dashboard`.

Current path (state-machine implementation):

1. `GET /sign/up/telephone/new` renders the telephone form.
2. `POST /sign/up/telephone` validates Turnstile and telephone params, creates a pending `Client`
   and pending `ClientTelephone`, issues a `ClientSignUpFlow` ticket with
   `entry_method: "telephone"` and `principal_id` pointing to the pending client, stores the flow
   locator in session, and redirects to edit.
3. `GET /sign/up/check/telephone/otp` renders the OTP form when the registration session is valid.
4. `PATCH /sign/up/check/telephone/otp` validates the OTP and marks the telephone as
   `VERIFIED_WITH_SIGN_UP`.
5. The state machine advances the ticket through `verify_contact` → `enter_checkpoint` →
   `clear_requirement(:otp)` and redirects to `GET /sign/up/guard/telephone`.
6. `GET /sign/up/guard/telephone` evaluates guardrail content; if none is required the flow
   redirects to `GET /sign/up/check/telephone/passkey`.
7. `GET /sign/up/check/telephone/passkey` renders the passkey registration UI. `POST` begins the
   WebAuthn ceremony; `PATCH` finalizes it and marks the `passkey` requirement as cleared.
8. The flow redirects to `GET /sign/up/check/telephone/passcode`, which marks the `passcode`
   requirement as cleared after the user confirms storage.
9. The flow redirects to `GET /sign/up/check/telephone/birthdate`, which collects and validates the
   birthdate and marks the `birthdate` requirement as cleared.
10. When all requirements are cleared the state machine runs `finalize`: the pending client is
    promoted to `VERIFIED_WITH_SIGN_UP`, the sign-up audit entry is written, and the sign-in
    boundary issues the authenticated session.
11. Sign-in failure after durable finalization is treated as a sign-in domain failure; it does not
    delete the completed account.

## App Social

App social sign-up uses the same social entry and callback as social sign-in. A missing provider
identity creates a new client account.

### App Google

Expected state-machine path:

- Entry: `GET /sign/up/new` or `GET /sign/up`
  - User chooses Google from the app sign-up surface.
  - The sequence starts before leaving the application for the provider.

- Social start: `GET /social/google/sign/up`
  - Store sign-up intent, provider, region, sanitized `rt`, and callback state in the server-side
    session.
  - Redirect to `/social/google/callback`.
  - Do not encode application routing decisions into OAuth `state`; keep OAuth `state` dedicated to
    callback integrity.

- Provider redirect: Google
  - Google handles authentication and consent.
  - The application is outside the local sequence until the callback returns.

- Social callback: `GET /social/google/callback`
  - Verify the social callback request.
  - Validate the stored social auth state.
  - Normalize the provider to Google.
  - If the Google identity already belongs to an account, leave sign-up and continue as sign-in.
  - If the identity is new, create the pending `Client` and link the Google identity.
  - Move the sign-up sequence toward guardrail/checkpoint.

- Sign-up guard: `GET /sign/up/guard`
  - This is the sign-up stop point for sequence-level rejection such as policy blocks, retry
    cooldowns, or other non-continuable registration states.
  - It returns plain text and does not redirect.
  - If no guardrail content is required, the sequence advances to checkpoint.

- Sign-up check: `GET /sign/up/check`
  - For Google sign-up, the checkpoint must require birthdate.
  - Birthdate collection happens inside `/sign/up/check`.
  - The checkpoint validates the exact `YYYY-MM-DD` text form.
  - The checkpoint rejects future values.
  - The checkpoint persists the encrypted birthdate and marks the birthdate requirement as cleared.
  - Google social login counts as an AAL1 sign-in method, but not as an AAL2 step-up method.
  - Passkey or passcode setup can be added here later by policy, but the current required Google
    sign-up checkpoint requirement is birthdate.

- Account finalization
  - Allowed only when Google callback identity handling and checkpoint birthdate are complete.
  - Use the same two-boundary shape as email: social sign-up finalization first, then the existing
    social sign-in boundary inside the same Rails action/request.
  - Do not redirect, render, or perform an HTTP reload between sign-up finalization and sign-in.
  - Ensure the linked Google identity is active.
  - Write the social sign-up audit entry.
  - Enter the sign-in boundary with `auth_method: "social"` and provider context; session issuance
    happens only after sign-in guardrail, checkpoint, and selector pass.
  - Sign-up finalization failure belongs to sign-up failure recovery.
  - Sign-in/session issuance failure after durable sign-up completion belongs to sign-in failure
    handling and must not delete completed account data.

- Welcome sequence: `GET /welcomes/:id`
  - Current route helper: `sign_app_welcome_path("post_auth")`.
  - This step is bypassable by `continue_welcome_sequence_without_content!` when no welcome sequence
    content is required.
  - The common post-finalization handoff applies: after sign-in guardrail, checkpoint, selector,
    session issuance, and welcome handling, continue to the safe `rt` return path when present;
    otherwise continue to `/dashboard`.

### App Apple

Expected state-machine path:

- Entry: `GET /sign/up/new` or `GET /sign/up`
  - User chooses Apple from the app sign-up surface.
  - The sequence starts before leaving the application for the provider.
  - Apple sign-up is app-only; `com` and `org` must not offer it.

- Social start: `GET /social/apple/sign/up`
  - Store sign-up intent, provider, region, sanitized `rt`, and callback state in the server-side
    session.
  - Redirect to `/social/apple/callback`.
  - Do not encode application routing decisions into OAuth `state`; keep OAuth `state` dedicated to
    callback integrity.

- Provider redirect: Apple
  - Apple handles authentication and consent.
  - The application is outside the local sequence until the callback returns.

- Social callback: `GET /social/apple/callback`
  - Verify the social callback request.
  - Validate the stored social auth state.
  - Normalize the provider to Apple.
  - If the Apple identity already belongs to an account, leave sign-up and continue as sign-in.
  - If the identity is new, create the pending `Client` and link the Apple identity.
  - Move the sign-up sequence toward guardrail/checkpoint.

- Sign-up guard: `GET /sign/up/guard`
  - This is the sign-up stop point for sequence-level rejection such as policy blocks, retry
    cooldowns, or other non-continuable registration states.
  - It returns plain text and does not redirect.
  - If no guardrail content is required, the sequence advances to checkpoint.

- Sign-up check: `GET /sign/up/check`
  - For Apple sign-up, the checkpoint must require birthdate.
  - Birthdate collection happens inside `/sign/up/check`.
  - The checkpoint validates the exact `YYYY-MM-DD` text form.
  - The checkpoint rejects future values.
  - The checkpoint persists the encrypted birthdate and marks the birthdate requirement as cleared.
  - Apple social login counts as an AAL1 sign-in method, but not as an AAL2 step-up method.
  - Passkey or passcode setup can be added here later by policy, but the current required Apple
    sign-up checkpoint requirement is birthdate.

- Account finalization
  - Allowed only when Apple callback identity handling and checkpoint birthdate are complete.
  - Use the same two-boundary shape as email: social sign-up finalization first, then the existing
    social sign-in boundary inside the same Rails action/request.
  - Do not redirect, render, or perform an HTTP reload between sign-up finalization and sign-in.
  - Ensure the linked Apple identity is active.
  - Write the social sign-up audit entry.
  - Enter the sign-in boundary with `auth_method: "social"` and provider context; session issuance
    happens only after sign-in guardrail, checkpoint, and selector pass.
  - Sign-up finalization failure belongs to sign-up failure recovery.
  - Sign-in/session issuance failure after durable sign-up completion belongs to sign-in failure
    handling and must not delete completed account data.

- Welcome sequence: `GET /welcomes/:id`
  - Current route helper: `sign_app_welcome_path("post_auth")`.
  - This step is bypassable by `continue_welcome_sequence_without_content!` when no welcome sequence
    content is required.
  - The common post-finalization handoff applies: after sign-in guardrail, checkpoint, selector,
    session issuance, and welcome handling, continue to the safe `rt` return path when present;
    otherwise continue to `/dashboard`.

Current path:

1. `GET /social/:provider/sign/in` and `GET /social/:provider/sign/up` store social intent,
   provider, entry, region, and sanitized `rt` in session.
2. The controller redirects to `/social/:provider/callback`.
3. The provider redirects back to `/social/:provider/callback`.
4. The callback verifies the social callback request and validates social auth session state.
5. A missing social identity creates a new `Client` with `UNVERIFIED_WITH_SIGN_UP` status defaults.
6. The social identity is created and linked.
7. A social sign-up audit entry is written.
8. The client is signed in through the normal social login path.
9. New and existing accounts both call the sign-in post-authentication sequence.
10. Target behavior is that guardrail, checkpoint, and selector are evaluated before session
    issuance, then the actor reaches welcome/`rt` or dashboard according to the sign-in sequence.

## Com Telephone

Com telephone sign-up should be rebuilt to match the app telephone sequence shape. It verifies
telephone ownership first, then moves into the sign-up checkpoint. The checkpoint owns required
setup such as passkey and passcode registration; the telephone OTP route should not finalize the
account directly.

Target state-machine path:

- Entry: `GET /sign/up/telephone/new`
  - Start or resume the com sign-up sequence.
  - The sequence is still before telephone submission.

- Telephone submission: `POST /sign/up/telephone`
  - Validate Turnstile and telephone params.
  - Create or resume pending telephone verification.
  - Create the pending `Visitor` when needed.
  - Move the sequence to the SMS OTP step.

- SMS OTP form: `GET /sign/up/telephone/edit`
  - Show the pass-code form only while the sequence is waiting for SMS OTP.
  - Reject direct access when the sequence is missing, expired, or no longer at the SMS OTP step.

- SMS OTP submission: `PATCH /sign/up/telephone`
  - Verify the submitted pass code.
  - Mark the telephone as `VERIFIED_WITH_SIGN_UP`.
  - Check whether the pending visitor already has an active passkey.
  - Move the sequence toward guardrail/checkpoint without allowing a return to telephone editing.

- Sign-up guard: `GET /sign/up/guard`
  - This is the sign-up stop point for sequence-level rejection such as policy blocks, retry
    cooldowns, or other non-continuable registration states.
  - It returns plain text and does not redirect.
  - If no guardrail content is required, the sequence advances to checkpoint.

- Sign-up check: `GET /sign/up/check`
  - This checkpoint owns all required post-contact setup before account finalization.
  - For com telephone sign-up, the checkpoint must require all of:
    - accepted birthdate;
    - at least one active passkey for the pending visitor;
    - at least one active sign-in-capable passcode for the pending visitor.
  - If any requirement is missing, the checkpoint remains incomplete and the actor cannot continue
    to account finalization.
  - Passkey and passcode setup are checkpoint-owned setup steps for the pending visitor.

- Birthdate setup requirement
  - Birthdate collection happens inside `/sign/up/check`.
  - The checkpoint validates the exact `YYYY-MM-DD` text form.
  - The checkpoint rejects future values.
  - The checkpoint persists the encrypted birthdate and marks the birthdate requirement as cleared.

- Passkey setup requirement
  - Passkey registration happens from the checkpoint when the pending visitor has no active passkey.
  - Do not reuse the configuration controller directly; it is written for an already-authenticated
    actor and step-up flow.
  - Completion creates a `VisitorPasskey` for the pending visitor and marks the passkey requirement
    as cleared.

- Passcode setup requirement
  - Use the existing model/service layer shape for `VisitorSecret`.
  - Do not reuse the configuration controller directly; it is written for an already-authenticated
    actor and step-up flow.
  - Generate the raw passcode server-side, show it once, persist only the digest, and mark the
    passcode requirement as cleared after the user confirms storage.
  - The passcode should be sign-in capable, active, and attached to the pending visitor before
    account finalization.

- Account finalization
  - Allowed only when telephone OTP, birthdate, passkey setup, and passcode setup are all complete.
  - Use the same two-boundary shape as app telephone: sign-up finalization first, then the existing
    sign-in boundary inside the same Rails action/request.
  - Do not redirect, render, or perform an HTTP reload between sign-up finalization and sign-in.
  - Promote or finalize the pending `Visitor`.
  - Create `rp_account` when missing.
  - Write the sign-up audit entry.
  - Enter the sign-in boundary with `auth_method: "telephone"`; session issuance happens only after
    sign-in guardrail, checkpoint, and selector pass.
  - Sign-up finalization failure belongs to sign-up failure recovery.
  - Sign-in/session issuance failure after durable sign-up completion belongs to sign-in failure
    handling and must not delete completed account data.

- Welcome sequence: `GET /welcomes/:id`
  - Current route helper: `sign_com_welcome_path("post_auth")`.
  - The common post-finalization handoff applies: after sign-in guardrail, checkpoint, selector,
    session issuance, and welcome handling, continue to the safe `rt` return path when present;
    otherwise continue to `/dashboard`.

Current path:

1. `GET /sign/up/telephone/new` renders the telephone form.
2. `POST /sign/up/telephone` validates Turnstile and telephone params, creates a pending `Visitor`
   and pending `VisitorTelephone`, issues a `VisitorSignUpFlow` ticket with
   `entry_method: "telephone"` and `principal_id` pointing to the pending visitor, stores the flow
   locator in session, and redirects to edit.
3. `GET /sign/up/telephone/edit` renders the OTP form when the registration session is valid.
4. `PATCH /sign/up/telephone` validates the OTP and marks the telephone as `VERIFIED_WITH_SIGN_UP`.
5. The state machine advances the ticket through `verify_contact` → `enter_checkpoint` →
   `clear_requirement(:otp)` and redirects to `GET /sign/up/guard/telephone`.
6. `GET /sign/up/guard/telephone` evaluates guardrail content; if none is required the flow
   redirects to `GET /sign/up/check/telephone/passkey`.
7. `GET /sign/up/check/telephone/passkey` renders the passkey registration UI. `POST` begins the
   WebAuthn ceremony; `PATCH` finalizes it and marks the `passkey` requirement as cleared.
8. The flow redirects to `GET /sign/up/check/telephone/passcode`, which marks the `passcode`
   requirement as cleared after the user confirms storage.
9. The flow redirects to `GET /sign/up/check/telephone/birthdate`, which collects and validates the
   birthdate and marks the `birthdate` requirement as cleared.
10. When all requirements are cleared the state machine runs `finalize`: the visitor status is
    confirmed active, the sign-up audit entry is written, and the sign-in boundary issues the
    authenticated session through the shared post-finalization handoff.
11. Sign-in failure after durable finalization is treated as a sign-in domain failure; it does not
    delete the completed account.

## Org Operator Acquisition And Lifecycle

Org is not an app/com-style public sign-up surface. A public org request must not create an
`Operator` directly. Operator creation, mutation, and withdrawal are controlled lifecycle events.

### Withdrawn Google Gateway Exception

The 2026-06-02 temporary Google gateway exception for `org` and `com` is withdrawn. Org signup must
not create an operator through an external social provider, and com signup must not create a visitor
through an external social provider.

- Org remains an invitation and operator-lifecycle surface, not a public social self-registration
  surface.
- Com remains an email/telephone local registration surface, not a social registration surface.
- The app Google and Apple social signup sequence remains unchanged.
- Any future org/com social provider work requires a new accepted ADR.

### External Candidate Inquiry

Target path:

- Public entry: `GET /sign/up/new`
  - Render an org sign-up unavailable or recruiting guidance page.
  - Do not create an `Operator`.
  - Do not create an authenticated org session.
  - Link the external candidate to the com/corporate contact or recruiting intake surface.

- Optional guardrail: `GET /sign/up/guard`
  - This is only for an org acquisition sequence that must stop with a plain-text message.
  - It must not become public self-service operator registration.
  - Direct access without valid sequence state must be rejected.

- Com/corporate intake
  - The candidate submits an inquiry, contact request, or future direct-message intake on the com
    side.
  - The intake record is reviewed operationally.
  - If the candidate should become an operator, an existing operator starts an operator lifecycle
    request.

Current path:

1. `GET /sign/up/new` is handled by `Sign::Org::UpsController#new`.
2. The view renders recruiting guidance.
3. The recruiting link currently points to the corporate/com root.
4. No `Operator` is created.
5. No org authentication session is issued.

### Operator Lifecycle Request

Target path:

- Existing operator sign-in
  - The actor must already be an org operator.
  - The actor completes the normal org sign-in sequence.

- Lifecycle request form: `GET /settings/operator_lifecycle_requests/new`
  - Used for operator create, update, withdrawal, or related lifecycle actions.
  - The request records the intended action, target operator or target email, organization, role,
    and reason.

- Lifecycle request submission: `POST /settings/operator_lifecycle_requests`
  - Require AAL2 step-up with scope `operator_lifecycle`.
  - Create an `OperatorLifecycleRequest`.
  - Do not execute privileged lifecycle changes directly from an unauthenticated public route.

- Optional lifecycle guardrail
  - Lifecycle-specific stops can use the same guardrail semantics: plain text, no redirect, and no
    lifecycle mutation when the sequence state is invalid.

- Approval / rejection / execution
  - Approved requests move through the configured approval and execution controllers.
  - Execution creates, updates, or withdraws the target operator.
  - The target operator later uses normal org sign-in and credential setup paths.

Current path:

1. An authenticated operator opens `GET /settings/operator_lifecycle_requests/new`.
2. `POST /settings/operator_lifecycle_requests` requires step-up scope `operator_lifecycle`.
3. The request is persisted as an `OperatorLifecycleRequest`.
4. Approval, rejection, and execution are handled under
   `/settings/operator_lifecycle_requests/:id/...`.

### Org Invitation Routes

Current route shape includes `/sign/up/invitations` for controlled invitation acceptance. Legacy
`/sign/up/invitations/emails` routes were removed because they were an incomplete public
operator-registration path.

Target decision:

- Keep invitation acceptance only when it is tied to a pre-approved operator lifecycle request.
- Do not expose email or social public self-registration routes for org operators.

## Implemented State-Machine Notes

- App/com sign-up progression is carried by `ClientSignUpFlow` and `VisitorSignUpFlow` tickets, not
  by credential-specific session state as the source of truth.
- `SignUpStateMachine` owns one-way progression through contact/social verification, the required
  guardrail for email/telephone flows, checkpoint, finalization, sign-in handoff, and completion.
  `CONTACT_VERIFIED` cannot enter `CHECKPOINT_PENDING` directly; the state machine and policies
  require `GUARDRAIL_PENDING` first. App social callback completion remains its separately verified
  path to the checkpoint and does not add a second, unapproved guardrail contract.
- The checkpoint records compact cleared requirements. Email/telephone OTP and social confirmation
  are recorded as prior cleared gates; checkpoint-visible setup still owns birthdate, passkey, and
  passcode requirements before durable finalization.
- App/com email and telephone sign-up finalize only from the checkpoint after required items are
  clear. Telephone OTP success never finalizes registration or issues a session by itself.
- App social sign-up treats unknown provider identities as pending evidence until explicit
  confirmation and birthdate checkpoint completion. Existing provider identities follow sign-in, not
  sign-up.
- Cancellation, expiry, and pre-finalization failure use `SignUpTermination` and
  `SignUpArtifactCleanup` so cleanup touches only pending artifacts owned by the current flow
  ticket.
- Org public sign-up should remain a candidate inquiry handoff, not an operator-creation route.
- Org operator creation, mutation, and withdrawal should remain lifecycle requests from an existing
  authenticated operator with AAL2 step-up.
