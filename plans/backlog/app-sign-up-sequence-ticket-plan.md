# App Sign Up Sequence Ticket Plan

**Status: PROPOSAL - NOT STARTED.**

This is a proposal for cleaning up `app` sign up after the sign in sequence work. Do not implement
from this file until it is promoted to `specs/` or backed by an accepted ADR.

## Scope

In scope:

- `app` sign up only.
- Email sign up and telephone sign up.
- A dedicated `/sign/up/checkpoint` flow.
- DB-backed `ClientSignUpSequenceTicket` as the source of truth for incomplete sign up progress.

Out of scope:

- `com` sign up. The visitor/com flow has separate product semantics and should get its own design.
- `org` sign up routes. Org does not currently have a normal end-user sign up path.
- Reworking sign in checkpoint behavior.
- Moving principal creation to the very end of sign up.

## Current State

App email sign up currently creates a pending `Client` before registration is complete:

- `Sign::EmailRegistrable#create_pending_user!` creates
  `Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)`.
- The pending `ClientEmail` belongs to that pending client.
- Session keys such as `:pending_sign_up_user_id`, `:pending_sign_up_email`, and
  `:sign_up_email_flow_state` track progress.
- OTP success promotes the client to `ClientStatus::VERIFIED_WITH_SIGN_UP`, creates the account,
  logs the user in, and then uses the sign in sequence redirect.

App telephone sign up also creates a pending `Client` before registration is complete:

- `Sign::App::Up::TelephoneSignupCreator#create_pending_telephone` creates a pending client.
- The pending `ClientTelephone` belongs to that pending client.
- `session[:user_telephone_registration]` tracks the telephone registration state.
- Telephone OTP success marks the telephone as `VERIFIED_WITH_SIGN_UP`.
- Passkey registration is then required before the client is promoted, account creation happens, the
  user is logged in, and the flow enters the sign in sequence redirect.

This means the current implementation is not "create the principal at the end." It is "create a
pending principal early, then promote it after registration completes."

## Problem

The early pending-principal approach is workable, but the progress state is split across session
keys, pending client rows, contact rows, and credential-specific controllers.

That makes these cases fragile:

- Backtracking from credential registration to contact verification.
- Abandoning telephone sign up after OTP success but before passkey completion.
- Cleaning up an expired pending client/contact pair.
- Retrying the same telephone number after an interrupted sign up.
- Keeping sign up checkpoint semantics separate from `/sign/in/checkpoint`.

Telephone sign up is the highest-risk case because a half-completed registration can leave a phone
number in a state that blocks later registration attempts.

## Decision Proposal

Keep the current early pending `Client` creation strategy for the first refactor.

Do not try to move principal creation to the final step yet. That would require broader changes to
`ClientEmail`, `ClientTelephone`, `ClientPasskey`, audit creation, login, and account creation.

Instead, make `ClientSignUpSequenceTicket` the protocol object for incomplete app sign up.

The ticket should own:

- The current sign up step and state.
- The pending principal id (`principal_id`) once a pending `Client` exists.
- The current login token id (`token_id`) once the user is logged in.
- The sanitized `return_to`.
- The expiry boundary for cleanup/retry behavior.

## Proposed App Flow

### Email Sign Up

1. Start sign up and create or resume a `ClientSignUpSequenceTicket`.
2. Email submission creates the pending client and pending email.
3. Store the pending client id in `ticket.principal_id`.
4. Move ticket to `CONTACT_PENDING`.
5. Email OTP success promotes the client and moves the ticket to `CHECKPOINT_PENDING`.
6. `/sign/up/checkpoint` handles welcome/checkpoint work.
7. Checkpoint completion moves the ticket to `COMPLETED`.
8. Continue to dashboard, then `rt` if present.

### Telephone Sign Up

1. Start sign up and create or resume a `ClientSignUpSequenceTicket`.
2. Telephone submission creates the pending client and pending telephone.
3. Store the pending client id in `ticket.principal_id`.
4. Move ticket to `CONTACT_PENDING`.
5. Telephone OTP success marks the telephone as `VERIFIED_WITH_SIGN_UP` and moves the ticket to
   `CREDENTIAL_PENDING`.
6. Passkey registration succeeds.
7. Promote the client, create account, write audit, log in, and move ticket to `CHECKPOINT_PENDING`.
8. `/sign/up/checkpoint` handles welcome/checkpoint work.
9. Checkpoint completion moves the ticket to `COMPLETED`.
10. Continue to dashboard, then `rt` if present.

## Routing Proposal

Add only the app route first:

```ruby
namespace :up do
  resource :checkpoint, only: %i(show update destroy)
end
```

Do not add com/org checkpoint routes in the first implementation.

Com should be redesigned separately. Org should not get user-facing sign up routes until there is a
real operator provisioning/sign up requirement.

## Implementation Shape

Add an app-focused concern first:

- `Sign::SignUpSequenceFlow`

Suggested responsibilities:

- `current_sign_up_sequence_ticket`
- `start_sign_up_sequence!(return_to:)`
- `require_sign_up_step!(step)`
- `advance_sign_up_sequence!(state, step:)`
- `complete_sign_up_sequence!`
- `discard_sign_up_sequence!`
- `cleanup_expired_sign_up_sequence!`

Keep controller responsibilities narrow:

- Controllers handle params, rendering, redirects, and HTTP status.
- The concern handles ticket lookup, validation, transitions, and cleanup entry points.
- `ClientSignUpSequenceTicket` enforces valid states and transitions.

## Migration Strategy

Implement in small steps:

1. Add `/sign/up/checkpoint` for app.
2. Add `Sign::SignUpSequenceFlow` and tests for ticket transitions.
3. Wire telephone sign up to the ticket first.
4. Keep current session keys as compatibility shims while the first controller is migrated.
5. Move cleanup from session-public-id lookup to ticket/principal based cleanup.
6. Update passkey completion to move the sign up ticket to `CHECKPOINT_PENDING`.
7. Move post-sign-up redirect from sign-in checkpoint to sign-up checkpoint.
8. Remove obsolete telephone session state after coverage is stable.
9. Migrate email sign up to the same ticket API.

Telephone should go first because it has the highest risk of locking a contact identifier after an
interrupted registration.

## Cleanup Policy

When a current sign up ticket is expired or discarded:

- If `principal_id` points to a `Client` with `ClientStatus::UNVERIFIED_WITH_SIGN_UP`, delete the
  pending client and dependent pending sign-up contact records.
- Do not delete verified or active clients.
- Do not delete contacts that no longer belong to the pending principal.
- Clear compatibility session keys.

The cleanup implementation should replace the current session-public-id cleanup in telephone sign up
once the ticket is wired.

## Test Expectations

Add or update tests for:

- App sign up checkpoint route exists and is app-only.
- Telephone sign up creates a `ClientSignUpSequenceTicket`.
- Telephone OTP success moves the ticket from `CONTACT_PENDING` to `CREDENTIAL_PENDING`.
- Passkey completion moves the ticket to `CHECKPOINT_PENDING`.
- Checkpoint completion moves the ticket to `COMPLETED`.
- Expired ticket cleanup releases a pending telephone registration.
- Retry after abandoned telephone sign up can reuse the same number.
- Sign in checkpoint behavior is unchanged.
- `rt` is preserved through sign up checkpoint and dashboard.
- Direct access to Guardrail (without a valid sequence state) is available through the dashboard or
  `rt` is not redirected to , and is rejected with status code + plain text (included from normal
  initial implementation).
- `com` sign Fix that the social authentication route (model / callback / provider settings) cannot
  be reached from up through regression testing (ADR "Com Originated from "signup remains
  social-free." The scope of this plan is `app` However, if you have a shared social infrastructure,
  track it cross-sectionally to prevent leaks).

## Cross section memo (originated from ADR / entered first even in normal system)

- **Implement Guardrail direct access denial from the beginning. ** ADR "normal system first,
  abnormal system later", but if you block invalid access to guardrail with a retrofit dashboard /
  `rt` Loopholes become entrenched as implementation habits and become difficult to remove.
  guardrail when installing `/sign/up/checkpoint` If you include a participant, at that point you
  can use "direct access without sequence state → status code + plain Also implement "text rejection
  (no redirection)".
- **Fix `com` social-free with regression testing. ** The scope of this plan is `app` However, if
  the social authentication infrastructure is placed on the app/com sharing base, it will easily
  leak to the com side. When the task of creating a shared abstraction arises, Add a regression test
  in the same change that shows that the social route is not reachable from `com` sign up (ADR
  Future Test Expectations' ``Com signup remains social-free'' guaranteed by actual tests).

## Open Questions

- Whether social sign up should create a sign up sequence ticket or continue to reuse the sign in
  post-authentication sequence.
- Whether pending email/telephone values should eventually move from contact tables to a dedicated
  pending contact table.
- Whether completed sign up should always show a visible checkpoint page, or whether an empty
  checkpoint can immediately continue to dashboard.
