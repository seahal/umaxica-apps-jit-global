# Sign-Up Failure Recovery Plan

Status: backlog

Lifecycle vocabulary: failure classes here use current runtime wording. Classify them with the
canonical lifecycle terms in `docs/security/idp-flow-lifecycle.md`; the cross-flow migration is
`plans/backlog/idp-flow-state-machine-unification.md`.

## Purpose

Define how unfinished sign-up attempts are recovered after the normal sign-up state machine is
implemented. This plan covers failures before sign-up has become a durable registered actor. It does
not cover failures in session issuance after sign-up has completed; those belong to the sign-in
failure handling plan.

## Principle

Clean up only artifacts that are both:

- created by the current sign-up cycle; and
- still pending or incomplete.

Do not delete active, previously registered actors, verified contact identifiers, or social
identities that predate the current sign-up cycle.

## Scope

Surfaces:

- app
- com

`org` has provisioning and invitation flows rather than ordinary end-user sign-up. Treat org
operator creation as a separate lifecycle plan.

Flows:

- app email sign-up
- app telephone sign-up
- app social sign-up through Google or Apple
- com email sign-up
- com telephone sign-up

## Failure Classes

### Pre-contact Submission Failure

Examples:

- invalid email or telephone format
- Turnstile failure
- missing required params

Expected behavior:

- do not create an actor;
- render validation errors or a generic retry response;
- do not mutate cycle state beyond safe attempt tracking.

### Pending Contact Verification Failure

Examples:

- OTP mismatch
- OTP expiry
- max OTP attempts exceeded
- pending session missing while pending DB record remains

Expected behavior:

- keep the pending artifact during normal retry windows;
- expire or clean it according to the sign-up cycle TTL;
- on lockout, invalidate the cycle and clean pending artifacts created by that cycle.

### Checkpoint Failure

Examples:

- invalid birthdate text
- future birthdate
- passkey registration failure
- secret creation or confirmation failure
- checkpoint session missing

Expected behavior:

- keep the pending actor while the cycle is resumable;
- keep completed checkpoint requirements attached to the same cycle;
- reject backtracking to earlier contact verification after the contact verifier has succeeded;
- expire and clean pending artifacts when the cycle TTL is exceeded.

### Finalization Failure Before Durable Completion

Examples:

- actor status promotion fails
- account row creation fails
- required identity/contact row cannot be saved

Expected behavior:

- wrap the finalization unit in a transaction where practical;
- roll back the finalization unit;
- preserve only retry-safe pending state when the cycle can resume;
- otherwise clean artifacts created by the cycle and restart sign-up.

### Audit or Bulletin Failure

Expected behavior to decide:

- audit failures may need to fail closed for security-significant events;
- welcome bulletin failures should not block durable sign-up;
- the implementation must explicitly classify each side effect as blocking or non-blocking.

## Social Sign-Up Rule

Do not use request params such as `intent=login` or `entry=sign_up` as the security decision for
sign-up versus sign-in.

Use provider identity state:

- no existing active identity for provider UID: sign-up path;
- existing identity for provider UID: sign-in path.

`entry=sign_up` can affect user experience, checkpoint routing, or failure redirect, but not account
ownership decisions.

## Required State Model

The future state machine should record:

- cycle id;
- surface;
- entry method;
- pending actor id;
- pending contact or social identity ids;
- completed requirements;
- current step;
- expiry time;
- terminal state.

Cleanup must use the cycle id or an equivalent ownership marker, not broad queries by email,
telephone, or social UID alone.

## Implementation Tasks

1. Define sign-up cycle ownership for pending actor, contact, social identity, passkey, secret, and
   birthdate artifacts.
2. Add lifecycle states for pending, checkpoint pending, finalized, expired, cancelled, and failed.
3. Move pending cleanup to a service that accepts a cycle id and refuses to touch artifacts outside
   that cycle.
4. Classify finalization side effects as transaction-bound or post-commit.
5. Add tests for stale sessions, expired cycles, OTP lockout, checkpoint expiry, and duplicate
   retry.
6. Add social sign-up tests proving existing identity sign-in never deletes or rewrites existing
   account data.

## Non-Goals

- Do not handle sign-in session issuance failure here.
- Do not delete completed registered actors because a later sign-in attempt failed.
- Do not make `intent` or `entry` query params authoritative for account state.
