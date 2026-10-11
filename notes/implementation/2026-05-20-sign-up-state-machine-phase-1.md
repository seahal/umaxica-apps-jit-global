# Sign Up State Machine Phase 1

Date: 2026-05-20

## Context

Phase 1 of GH issue #834 prepares the app/com sign-up ticket carrier before wiring controllers,
policies, or the state machine service.

## Decision

Use the existing per-surface cycle records as the ticket carrier:

- `ClientSignUpCycle` in `app_ticket`
- `VisitorSignUpCycle` in `com_ticket`

Do not add separate `ClientSignUpSequenceTicket` or `VisitorSignUpSequenceTicket` models. The cycle
rows already represent temporary sign flow state, have public ids, expiry, status, step, and
retention columns, and live in the correct ticket databases.

## Implemented Scope

- Added app/com ticket columns for entry method, pending contact state, social provider, completed
  checkpoint requirements, cleanup ownership, and failure/cancellation timestamps.
- Added `SignUpCycleTicket` as the shared validation/protocol concern.
- Preserved existing status ids for `STARTED`, `CONTACT_PENDING`, `CREDENTIAL_PENDING`,
  `CHECKPOINT_PENDING`, and `COMPLETED`; new intermediate states use unused ids.
- Added model coverage for app/com entry-method restrictions, com social rejection, safe return
  paths, cleanup token generation, and secret-free requirement state.

## Follow-Up

Phase 2 should build value objects and service contracts against the shared `SignUpCycleTicket`
protocol rather than new ticket classes.

## Phase 2 Update

Added shared service contracts under `SignUp`:

- `SignUp::Result`
- `SignUp::PolicyContext`
- `SignUp::RequirementContext`
- `SignUp::FinalizationContext`
- `SignUp::RequirementRegistry`
- `SignUp::StateMachine`

The state-machine service currently enforces only the public event protocol and returns
`invalid_transition` until the core transition implementation is added in Phase 4. The requirement
registry is app/com only: app supports email, telephone, Google, and Apple; com supports only email
and telephone.

## Phase 3 Update

Added Action Policy coverage under `SignUp`:

- `SignUp::TicketPolicy`
- `SignUp::ParticipantPolicy`
- `SignUp::RequirementPolicy`
- `SignUp::FinalizationPolicy`
- `SignUp::SocialCallbackPolicy`

Policy records are the Phase 2 context objects. Existing sequence actions require explicit browser
sequence binding through `actor_authentication.active_sign_sequence_id == ticket.public_id`.
Signed-in actors are rejected from starting sign-up. Pending actor authorization compares the
context pending actor with the ticket `principal_id`; it does not treat pending sign-up as a normal
signed-in session. Social callback authorization is app-social only.

## Phase 4 Update

Added the core `SignUp::StateMachine` transition implementation without controller wiring.

Implemented:

- transition validation for app/com sign-up tickets;
- expired and terminal ticket rejection before mutation;
- app-social callback progression;
- checkpoint requirement clearing;
- finalization gating on completed requirements plus an explicit typed `finalization_result`;
- sign-in handoff classification via typed `sign_in_handoff_status`;
- terminal `fail`, `expire`, and `cancel` transitions.

The state machine still does not create tickets, pending actors, contacts, credentials, social
identities, sessions, or controller responses. Those remain Phase 5+ wiring and side-effect service
work. Finalization and sign-in handoff are represented by payload result values so the state machine
can validate order without pretending to own those external side effects.

## Phase 5 Update

Added app/com participant routes and controllers:

- app `/sign/up/guardrail`
- app `/sign/up/checkpoint`
- com `/sign/up/guardrail`
- com `/sign/up/checkpoint`

The controllers use `Sign::Up::SequenceControllerSupport` for protocol-level loading, authorization,
state-machine invocation, and plain-text result mapping. They intentionally reject missing or
unbound ticket access with status responses instead of redirecting to dashboards or consuming `rt`.

This phase does not wire the existing email/telephone/social entry controllers into the new
participant routes yet. It only adds the participant endpoints and direct-access rejection boundary.

## Phase 6 Update

Migrated the app telephone sign-up entry to create and advance a sign-up cycle ticket.

Implemented:

- `SignUp::CycleLocator` for session-bound app/com sign-up cycle lookup with nonce validation;
- app telephone POST creates or resumes a `ClientSignUpCycle` with `entry_method = telephone`;
- telephone creation binds the cycle to the pending client and pending telephone contact, then
  advances to `CONTACT_PENDING`;
- telephone OTP success advances the cycle to `CONTACT_VERIFIED` and redirects to
  `/sign/up/guardrail`;
- existing-telephone sign-in handoff behavior clears the sign-up cycle locator and remains outside
  sign-up ownership.

GET `/sign/up/telephone/new` intentionally does not create a ticket because this surface treats GET
as a read-only boundary. Ticket creation starts on POST after HTTP validation passes.

## Phase 7 Update

Moved app telephone passkey registration under the sign-up checkpoint boundary.

Implemented:

- passkey registration now requires the session-bound sign-up cycle to be at checkpoint through
  `SignUp::RequirementPolicy#register_passkey?`;
- successful WebAuthn registration clears only the `passkey` requirement through
  `SignUp::StateMachine`;
- passkey registration no longer finalizes the telephone sign-up, signs the client in, clears the
  registration session, or writes signup/login chronicle events;
- the passkey success redirect now returns to `/sign/up/checkpoint`, preserving `rt`;
- participant state-machine mutations run on the ticket writing role so GET guardrail/checkpoint
  transitions do not attempt writes through replica connections.

Telephone sign-up finalization remains blocked until the remaining checkpoint requirements
(`birthdate` and `passcode`) are cleared and a later finalization phase supplies the typed
finalization result plus sign-in handoff.

## Phase 8 Update

Migrated app email sign-up into the sign-up cycle flow.

Implemented:

- email POST now creates/resumes a session-bound `ClientSignUpCycle` with `entry_method = email`;
- the cycle is bound to the pending client and pending email contact, then advanced to
  `CONTACT_PENDING`;
- email OTP success verifies the email contact, advances the cycle to `CONTACT_VERIFIED`, and
  redirects to `/sign/up/guardrail` instead of issuing an authenticated session;
- email OTP success no longer marks the client as fully verified, creates an RP account, writes
  signup/login chronicle events, creates tokens, resets the session, or redirects to dashboard;
- sign-up checkpoint can persist the pending actor birthdate and clear the `birthdate` requirement
  through `SignUp::StateMachine`;
- safe `rt` is preserved through the email edit redirect and guardrail redirect, while the decoded
  internal path is stored on the sign-up cycle as `return_to`.

App email finalization remains pending. The durable account completion and sign-in boundary handoff
must run after the birthdate requirement is clear.

## Phase 9 Update

Migrated app social sign-up into the sign-up cycle flow.

Implemented:

- social continue now creates a session-bound `ClientSignUpCycle` before provider redirect;
- safe decoded `rt` is stored server-side on the cycle, and the encoded `rt` continues through the
  existing social auth state;
- Google and Apple sign-up entries advance the ticket from `STARTED` to `SOCIAL_CALLBACK_PENDING`;
- provider callback keeps the original social auth entry value after clearing social auth intent, so
  sign-up callbacks can be separated from normal sign-in callbacks;
- new social identities bind the pending client and social identity to the cycle, advance to
  `CONTACT_VERIFIED`, and redirect to `/sign/up/guardrail`;
- social sign-up identity creation skips durable finalization side effects: no RP account, no
  signup/login chronicle events, no authenticated session issuance, and no dashboard redirect.

Existing social identities remain outside sign-up ownership and continue through the sign-in
classification path. App social finalization remains pending until the birthdate checkpoint is
cleared and the later finalization phase supplies the typed finalization result plus sign-in
handoff.

## Phase 10 Update

Migrated com email and telephone sign-up entry points into the `VisitorSignUpCycle` flow.

Implemented:

- com email POST now creates/resumes a session-bound `VisitorSignUpCycle` for new email sign-up,
  binds the pending visitor and email contact, and advances to `CONTACT_PENDING`;
- com email OTP success verifies the pending email contact, advances the cycle to
  `CONTACT_VERIFIED`, and redirects to `/sign/up/guardrail`;
- com telephone POST now creates/resumes a session-bound `VisitorSignUpCycle` for new telephone
  sign-up, binds the pending visitor and telephone contact, and advances to `CONTACT_PENDING`;
- com telephone OTP success records the OTP proof in the registration session, advances the cycle to
  `CONTACT_VERIFIED`, and redirects to `/sign/up/guardrail`;
- com email and telephone OTP success no longer creates an RP account, writes signup/login chronicle
  events, creates tokens, issues an authenticated session, redirects to dashboard, or redirects to
  root before checkpoint/finalization;
- existing com email and telephone identities remain outside sign-up ownership and redirect to the
  sign-in entry instead of creating sign-up cycle artifacts;
- regression coverage confirms com still has no social sign-up provider routes.

Com finalization remains pending. Email still requires the birthdate checkpoint; telephone keeps
birthdate, passkey, and passcode as checkpoint requirements, with durable telephone verification and
sign-in handoff deferred to a later finalization phase.
