# Sign Up Authentication Handoff and Social Return-To Handling (2026-05-13)

## Status

Accepted

> **Supersession (2026-06-02):** This ADR's IdP/RP-centered authority model is superseded by
> `adr/identity-authority-boundary.md`. `acme/www` is now the Session, Token, Account, Preference,
> and Authorization Authority. `sign/id` is no longer the IdP; it is a Credential Gateway and
> Credential Ceremony Zone only. Historical implementation details in this ADR must not be used to
> reintroduce sign-side sessions, refresh tokens, preference writes, dashboards, account lifecycle,
> downstream token issuance, authorization decisions, or step-up freshness.

> **Supersession (2026-07-24):** The Apple POST callback statement is superseded by
> `adr/social-omniauth-callback-transport.md`. Apple and Google callbacks now use the documented
> GET-only transport contract.

## Temporary Exception

2026-06-02: `adr/google-social-temporary-gateway-exception.md` adds a QA-only exception for the
Google social temporary gateway. It does not change this ADR's production target. Public `org`
signup is not a permanent self-service operator creation path, and `com` returns to a social-free
state before production cleanup.

## Context

The sign surfaces currently have different registration and post-authentication behavior:

- `app` supports social authentication with Google and Apple.
- `com` does not use social authentication and should remain email/telephone only, but its email and
  telephone sign-up responsibilities are growing and should follow the app sequence shape.
- `org` is not a public self-service sign-up surface. Operator creation and mutation are privileged
  lifecycle operations.
- Sign In has an established post-authentication sequence: MFA when required, session-limit
  handling, guardrail, checkpoint, dashboard, and optional `rt` continuation.
- Sign Up currently has credential-specific completion paths, especially for telephone signup.
- App Sign Up now needs an explicit route inventory before the future state machine replaces
  controller/session-local flow state.

The app social flow already stores OAuth intent and callback context in server-side session before
redirecting to the provider. It does not currently preserve `rt`, but the existing session context
means this can be added without embedding application redirect state into OAuth `state`.

Telephone Sign Up has a separate problem. OTP verification and required passkey/MFA setup must not
be treated as a completed Sign In sequence. If a telephone record is marked as verified before
required Sign Up setup is complete, an abandoned or failed setup can leave the phone number in a
state that blocks later registration attempts.

## Decision

We will keep social authentication scoped to `app` and will not introduce social login or social
signup to `com`.

The accepted `app` Sign Up routes are:

1. Email Sign Up.
2. Telephone Sign Up.
3. Google social Sign Up.
4. Apple social Sign Up.

Google and Apple are separate Sign Up routes even though they share social-auth infrastructure.
Their current callback transport is defined by `adr/social-omniauth-callback-transport.md`.

The public route vocabulary is frozen. This ADR only documents the authority boundary and handoff
behavior; it does not justify changing the accepted `/sign/up/*` or `/social/*` paths.

The accepted target `com` Sign Up routes are:

1. Email Sign Up.
2. Telephone Sign Up.

Com Sign Up should be rebuilt to mirror the app email and telephone sequence shape, without adding
social authentication. Com email moves from email OTP to `/sign/up/check`, where birthdate is
required before account finalization. Com telephone moves from telephone OTP to `/sign/up/check`,
where birthdate, passkey, and sign-in-capable passcode are required before account finalization.

The accepted `org` operator acquisition and lifecycle routes are:

1. External candidate inquiry.
2. Operator lifecycle request.

Org public entry (`GET /sign/up/new`) is a candidate/recruiting guidance page that hands off to the
com/corporate contact or recruiting intake surface. It must not create an `Operator`, issue an org
session, or behave like app/com public sign-up.

Operator creation, mutation, and withdrawal must go through an authenticated operator lifecycle
request. The request submission requires AAL2 step-up with scope `operator_lifecycle`; approval and
execution happen through the operator lifecycle controllers. Unknown Google social identities must
not create operators.

For `app` social sign in/up, `rt` may be preserved across the OAuth round trip by storing sanitized
return-to context in the server-side social auth session. OAuth `state` remains dedicated to
provider callback integrity and CSRF protection.

A signed-in actor must not start a new Sign In or Sign Up sequence without signing out first.
Re-entry into Sign In or Sign Up while already signed in is an abnormal request and must be rejected
with a status code and a plain-text message. The application must not redirect the actor to
dashboard, continue a return path, create a new registration sequence, or sign the actor out on
their behalf.

Telephone Sign Up must not use `/sign/in/check` to represent incomplete registration state. Sign Up
needs its own pending registration checkpoint, such as `/sign/up/check`, for flows where OTP
verification has succeeded but required passkey/MFA setup has not yet completed.

Sign Up and Sign In also need guardrail stops. Guardrail is distinct from checkpoint: guardrail
blocks continuation and returns a plain-text stop message, while checkpoint is an interstitial for
allowed flows that still need confirmation or setup. Direct access to guardrail without valid
sequence state must be rejected instead of redirecting through dashboard or a return path.

Guardrail, checkpoint, and dashboard are sequence participants with ordered requirement items. A
participant can have zero, one, or many items. The sequence advances only when every required item
in the current participant is cleared. New requirements should be added as participant items rather
than by inserting ad hoc routes between guardrail, checkpoint, dashboard, and return-to handling.

Telephone Sign Up verifies telephone ownership first, checks whether the pending actor already has
an active passkey, and then moves to `/sign/up/check`. Passkey registration is checkpoint-owned
setup, not a separate pre-checkpoint telephone branch. Account finalization is blocked until the
telephone checkpoint clears birthdate, passkey, and sign-in-capable passcode requirements.

All `app` Sign Up routes and target `com` Sign Up routes use the same post-finalization handoff:

1. Complete Sign Up finalization.
2. Enter the existing Sign In boundary in the same Rails action/request.
3. Evaluate Sign In guardrail before session issuance.
4. If guardrail does not block, issue the authenticated session.
5. Continue to checkpoint and dashboard.
6. If a safe `rt` return path exists, jump there after dashboard handling.

The Sign Up finalization boundary and Sign In boundary must not redirect, render, or reload through
HTTP between each other. Route selection belongs after the Sign In boundary has either stopped at
guardrail or issued the authenticated session.

Sign Up finalization failure and Sign In failure are separate failure domains. If finalization fails
before a durable actor/account exists, the Sign Up recovery policy applies. If sign-in or session
issuance fails after durable Sign Up completion, the Sign In failure policy applies and completed
account data must not be deleted.

The normal Sign Up sequence should be implemented first. Abnormal-path recovery should be added
after the normal route shape is stable, because cleanup behavior depends on the final state-machine
ownership model.

Sign Up failure recovery is a compensation process. Email and telephone sign-up may create pending
actor and contact records before registration is durable. If the current sign-up cycle fails before
durable account completion, recovery may clean up only the pending artifacts owned by that cycle so
the person can retry registration with the same email address or telephone number. Recovery must not
delete active actors, completed accounts, verified contacts, existing credentials, or artifacts from
another sign-up cycle.

Sign In failure handling is not a compensation process. Once the actor/account is durable, a failure
to issue or continue a signed-in session should ask the actor to sign in again or use the
established Sign In failure response. It must not clean up Sign Up artifacts or delete completed
account data.

Social sign-in and sign-up are classified by provider identity state, not by request params.
Existing social identities are Sign In and are never cleaned up because a later Sign In attempt
failed. A new social Sign Up may clean up only incomplete identity/account artifacts created by the
current sign-up cycle, and only before durable completion.

Future Sign In and Sign Up implementation should separate four responsibilities:

- authentication context;
- flow state;
- authorization decisions;
- audit/history recording.

`Actor.authn` should hold the normalized authentication facts for the current actor/session, such as
surface, actor id, current AAL, satisfied methods, primary method, step-up method, authentication
timestamps, token/session id, restricted-session status, and the active sign sequence id. It should
be the common source for authorization and controller decisions that need to know the actor's
current authentication state. It should not own route progression.

The sign state machine should own flow progression. It decides which sign participant is current,
whether the participant stack is empty or blocking, and which transition is allowed next. It should
cover sign-in, sign-up, guardrail, checkpoint, dashboard, and step-up sequences. Controllers should
ask the state machine for the current transition/result rather than encoding route order directly.

Action Policy should own authorization decisions. Policies should consume `Actor.authn` and, where
needed, sequence ownership facts to decide whether an actor may view or mutate a resource. This
applies to sensitive configuration routes, AAL2-scoped actions such as operator lifecycle requests,
social link/unlink, sign-up checkpoint setup, and any sequence-owned pending artifact.

Chronicle should record security-significant history. State transitions and sign boundary outcomes
should emit audit events such as sign-up start, contact submission, OTP verification result,
checkpoint item clearance, guardrail block, account finalization, sign-in boundary entry, session
issuance, restricted-session issuance, sign-in failure, step-up outcome, policy denial, sequence
expiry, and compensating cleanup. Chronicle events must not record OTP values, tokens, cookies,
authorization headers, or full request parameters.

Telephone registration is finalized only after all required Sign Up setup succeeds. Finalization
includes telephone status transition, actor account creation, audit writing, login session creation,
dashboard handling, and `rt` continuation.

Pending telephone registration must be resumable or cleanup-able. Expired, abandoned, or failed
pending registration state must release the phone number so the same person can retry registration
without being forced into a broken Sign In path.

## Consequences

- `app` social auth can share the Sign In post-authentication sequence while preserving `rt`.
- `app` Sign Up route ownership is explicit: email, telephone, Google social, and Apple social.
- `com` remains social-free but should align its email and telephone sign-up sequences with app.
- `com` does not gain social auth routes, models, callbacks, or provider configuration.
- `org` does not gain ordinary public sign-up. Public candidates are handled through com/corporate
  intake; privileged operator changes are handled through lifecycle requests.
- Sign Up registration state is not conflated with Sign In checkpoint state.
- Telephone Sign Up requires a dedicated pending-registration checkpoint, cleanup policy, and
  checkpoint-owned passkey setup before the current telephone/passkey path is refactored.
- `create_user_and_login` should be decomposed into Sign Up finalization plus the existing Sign In
  method, both called internally by one public Rails action.
- Sign Up failure recovery is compensating cleanup for the current pending sign-up cycle. Sign In
  failure handling is retry/stop behavior and must not delete durable account data.
- Email and telephone registration need explicit cleanup ownership because pending contact rows can
  block retry registration if abandoned.
- Social authentication cleanup must be conservative: existing provider identities are never deleted
  because Sign In failed; incomplete newly-created social artifacts can only be cleaned when owned
  by the current unfinished Sign Up cycle.
- Authentication context, flow progression, authorization, and audit/history must remain separate:
  `Actor.authn` records current authentication facts, the sign state machine advances sequence
  state, Action Policy authorizes resource access, and Chronicle records security-relevant history.
- Guardrail, checkpoint, and dashboard are sequence participants whose required content can grow or
  disappear over time.
- Existing Sign In checkpoint behavior remains unchanged except that guardrail is ordered before it.

## Future Test Expectations

- App social sign in/up preserves `rt` after Google and Apple callbacks and continues through the
  normal guardrail/checkpoint/dashboard sequence.
- Social callback failure clears stored social `rt` together with other social auth session state.
- App telephone signup interruption before passkey completion does not permanently block
  re-registration of the same number.
- Email and telephone sign-up failure before durable completion releases only the pending artifacts
  owned by the failed sign-up cycle.
- App telephone signup finalizes telephone status, account creation, audit, login, dashboard, and
  optional `rt` continuation only after required checkpoint setup succeeds.
- Sign-in failure after durable Sign Up completion keeps the completed account and routes through
  Sign In failure handling rather than Sign Up cleanup.
- Com email signup reaches account finalization only after email OTP and checkpoint birthdate are
  complete.
- Com telephone signup reaches account finalization only after telephone OTP and checkpoint
  birthdate, passkey, and passcode setup are complete.
- Com signup remains social-free.
- Org `GET /sign/up/new` does not create an operator or issue a session.
- Org operator lifecycle request creation requires an authenticated operator and AAL2 step-up.
