# Administrative Access Lock

## Status

Accepted (2026-06-03)

## Context

The account withdrawal and retention model already uses lifecycle timestamps such as
`withdrawal_started_at`, `deactivated_at`, `discard_at`, `purge_eligible_at`, and `terminated_at`. Those
timestamps describe withdrawal, suspension, retention, and termination behavior.

Operational forced access removal is a different security action. It is not ordinary inactivity, not
self-service withdrawal, and not retention. It immediately removes an actor's ability to use
existing sessions and tokens because an operator or operational process decided access must stop.

`acme/www` is the Session, Token, Account, Preference, and Authorization Authority. Therefore
administrative access lock state and enforcement belong to the acme-owned account/session/token
boundary, even if compatibility code still lives under sign-named modules.

## Decision

Introduce an explicit Administrative Access Lock state named `admin_locked`.

Administrative access state is separate from withdrawal and termination lifecycle state:

- lifecycle state describes account existence and withdrawal/termination progression;
- access state describes whether an otherwise existing account may use authentication-backed access.

The initial access states are:

- `enabled`
- `admin_locked`

Do not add `dormant` in this decision. Inactivity dormancy is a separate product workflow with
different reactivation, notification, and operator-responsibility semantics.

`admin_locked` applies to all three actor classes:

- `Client`
- `Visitor`
- `Operator`

The first implementation slice is service-only. It must not add UI, routes, or controllers.

## Runtime Contract

When an account is admin-locked:

- all active sessions for that account are revoked;
- refresh token families for those sessions are revoked through the existing session-revoke
  boundary;
- existing access tokens issued before the lock are rejected by comparing JWT `iat` with
  `token_valid_after_at`;
- new sign-in is rejected after credential verification and before session/token creation;
- refresh-token exchange is rejected and must not issue a new access token;
- step-up, recovery, credential mutation, API token issuance, WebSocket token issuance, and
  downstream/presigned-token issuance are unavailable through the normal authenticated gates.

`token_valid_after_at` means "the last time all previously issued access tokens became invalid." It
advances on lock and on unlock. Unlocking must not revive any old session, refresh token, access
token, step-up freshness, or downstream token eligibility.

## Audit Contract

Administrative access lock is an audit/security event, not merely an application log line.

Persist lock/unlock events in a durable audit table, with at least:

- target account type and id;
- event type;
- previous and next access state;
- operator id;
- reason code;
- optional operator note;
- optional ticket id;
- occurrence time;
- sanitized metadata.

Reason notes are free text for operator context only. Application logic must use fixed reason codes,
not note text.

Initial reason codes:

- `abuse`
- `security_incident`
- `chargeback`
- `terms_violation`
- `support_request`
- `legal_hold`
- `operator_error_recovery`
- `other`

## Consequences

- Do not overload `dormant`, `deactivated_at`, withdrawal state, or retention state for forced
  operator access removal.
- Access enforcement must be state-backed. Revoking refresh tokens alone is insufficient when access
  JWTs are stateless.
- Requests that validate access tokens must consult account state and `token_valid_after_at` on the
  revocation-sensitive path.
- Operator locking needs a last-enabled-operator safety check so the org surface cannot lock itself
  out accidentally.
- Any future UI for this feature should be an org/operator control-plane workflow, but this ADR does
  not approve a UI or route.

## Related

- `adr/identity-authority-boundary.md`
- `adr/acme-session-and-token-authority.md`
- `adr/sign-withdrawal-and-membership-surface-policy.md`
- `adr/application-logging-boundary.md`
- `docs/security/observability-boundary.md`
