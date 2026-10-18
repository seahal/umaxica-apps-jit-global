# Sign-In Failure Handling Plan

Status: backlog

Lifecycle vocabulary: failure classes here use current runtime wording. Classify them with the
canonical lifecycle terms in `docs/security/idp-flow-lifecycle.md`; the cross-flow migration is
`plans/backlog/idp-flow-state-machine-unification.md`.

## Purpose

Define how sign-in failures are handled after a credential or sign-up finalization has already
identified a registered actor. This plan is intentionally separate from sign-up failure recovery.

## Principle

Sign-in failure must not delete registered account data.

Once sign-up has durably completed, a later failure to issue or continue a session is a sign-in
problem. The user should be sent to a sign-in route or an existing challenge/session-limit route,
not back through destructive sign-up cleanup.

## Scope

Surfaces:

- app
- com
- org

Methods:

- email OTP sign-in
- telephone entry plus supported verifier
- passkey sign-in
- TOTP sign-in where supported
- secret sign-in
- Google social sign-in
- Apple social sign-in

## Failure Classes

### Credential Verification Failure

Examples:

- wrong OTP
- wrong secret
- passkey assertion failure
- TOTP mismatch
- social callback state mismatch

Expected behavior:

- do not authenticate;
- increment attempt counters where applicable;
- preserve existing account data;
- return to the relevant sign-in method or generic sign-in page.

### Actor Not Allowed

Examples:

- suspended actor
- withdrawn actor
- visibility/status disallows login

Expected behavior:

- fail closed;
- avoid user enumeration;
- do not mutate sign-up state;
- audit the failure when the actor is known.

### Session Issuance Failure

Examples:

- `log_in` returns `login_forbidden`
- DPoP validation failure
- token creation failure
- cookie write constraints

Expected behavior:

- do not delete actor or credential data;
- redirect or render the established sign-in failure path;
- preserve enough context for a safe retry only when the context is not attacker-controlled.

### MFA Required

Examples:

- primary AAL1 method succeeds but MFA is required

Expected behavior:

- do not treat this as sign-up failure;
- create pending MFA state through the existing sign-in pipeline;
- route to the configured MFA challenge.

### Session Limit

Examples:

- restricted session issued;
- hard session-limit rejection.

Expected behavior:

- follow existing session-limit behavior;
- do not delete actor or credential data;
- audit according to the session-limit policy.

## Social Sign-In Rule

Social callback handling should classify the result by database state:

- existing provider UID: sign-in;
- missing provider UID: sign-up continuation if the current sequence permits social sign-up.

The request's `intent=login` may start a generic social authentication flow, but it must not be the
security authority for whether the result is sign-in or sign-up.

If social sign-in fails after an existing identity is found, keep all account and identity records.

## Required Normalization

All sign-in methods should return a common result shape from the sign-in boundary:

- `status: :success`
- `status: :mfa_required`
- `status: :session_limit_exceeded`
- `status: :session_limit_hard_reject`
- `status: :login_forbidden`
- `status: :credential_failed`
- `status: :invalid_request`

Controllers should map those statuses to routes and responses. They should not decide cleanup of
sign-up artifacts.

## Implementation Tasks

1. Inventory all direct `log_in` and `complete_sign_in_or_start_mfa!` call sites.
2. Normalize return handling across app, com, and org.
3. Make social callback result names explicit, for example `created_account` versus
   `existing_account`.
4. Remove any sign-up cleanup from post-finalization sign-in failure handling.
5. Add tests proving sign-in failures keep existing email, telephone, passkey, secret, social
   identity, actor, and account rows.
6. Add tests for social existing-identity failure to prove no destructive cleanup occurs.

## Non-Goals

- Do not clean pending sign-up artifacts here.
- Do not retry HTTP requests internally.
- Do not rely on request params to decide ownership or actor lifecycle.
