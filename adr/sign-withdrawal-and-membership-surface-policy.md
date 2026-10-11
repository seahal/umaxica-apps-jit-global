# ADR: Sign Withdrawal And Org Membership Surface Policy

**Status:** Accepted (2026-05-14)

> **Supersession (2026-06-02):** This ADR's IdP/RP-centered authority model is superseded by
> `adr/identity-authority-boundary.md`. `acme/www` is now the Session, Token, Account, Preference,
> and Authorization Authority. `sign/id` is no longer the IdP; it is a Credential Gateway and
> Credential Ceremony Zone only. Historical implementation details in this ADR must not be used to
> reintroduce sign-side sessions, refresh tokens, preference writes, dashboards, account lifecycle,
> downstream token issuance, authorization decisions, or step-up freshness.

## Context

The sign configuration surfaces expose different actor types and ownership boundaries:

- `app`: end-user `Client`
- `com`: public/corporate `Visitor`
- `org`: staff/operator `Operator`

The current withdrawal implementation was started before the Rails engine and wrapper-app
experiments were abandoned. The app and com withdrawal controllers now contain near-identical
business behavior, while org has no intended self-service withdrawal or join flow.

This decision records the stable product and architecture direction so future cleanup does not infer
behavior from transitional controller duplication.

## Decision

### Org membership

Org operator join and withdrawal are not self-service product flows.

Until a dedicated org membership workflow is designed and accepted, org membership changes are
handled operationally:

- An operator requests join, withdrawal, or membership adjustment by direct message.
- Direct message is not implemented yet; until it exists, the sign org surface records the request
  as an operator lifecycle request.
- Another operator coordinates, approves, and performs the change through the appropriate
  operational channel.
- Operator withdrawal uses the same persisted state columns as app and com actors:
  `withdrawal_started_at`, `deactivated_at`, `discarded_at`, and `purged_at`.
- Operator lifecycle requests are org-specific and must not share the app/com self-service
  withdrawal service.
- The sign org surface must not expose a self-service destructive withdrawal flow for operators.
- Existing org withdrawal routes or controllers, if present, are informational entry points or links
  into the operator-to-operator lifecycle request workflow. They must not be expanded into
  self-service account deactivation without a new ADR.

### App and com withdrawal

App and com account withdrawal should follow one shared business model.

- `app` and `com` may keep separate controllers, routes, policies, path helpers, translations, and
  audit event names because they are separate surfaces.
- The underlying withdrawal state machine, recovery window, validations, timestamp updates, and
  recovery behavior should be implemented once or through a shared local abstraction.
- Completing app or com withdrawal is staged. `withdrawal_started_at` represents `closing`;
  `deactivated_at` and `discarded_at` represent `suspended`; `terminated_at` represents irreversible
  termination.
- Withdrawal handling revokes other sessions while preserving the current MFA-verified session as
  the withdrawal-continuation session, because no separate withdrawal ticket exists yet.

  > **Superseded (2026-09-13):** A withdrawal ceremony now exists. Suspension and termination revoke
  > every session of the actor, including the requesting session, clear the auth cookies, and
  > continue status, recovery, and early termination through the withdrawal ceremony
  > (`WithdrawalLifecycle`, `BaseSettingsWithdrawalFlow`).

- The ID surface may keep enough authenticated behavior to show withdrawal status, recovery, and
  actor-initiated early termination, but RP/OIDC actions must reject the actor while closing,
  suspended, or terminated.
- `discarded_at` marks the point where normal access stops. `purged_at` marks the end of the
  recovery window and is the deadline used by retention jobs for anonymization. App/com account rows
  are not physically deleted by self-service withdrawal retention.
- Direct messages, audit records, activity history, and legal-hold-sensitive records are not purged
  by the app/com account withdrawal transaction. Those records follow their own retention,
  disclosure, and legal hold policies.
- Recovery is available only after one hour and before the 31-day deadline. Early irreversible
  termination is available to the actor after seven days.
- Current app/com controller duplication is transitional. Future work should extract the common
  behavior into a service, form, concern, or other existing local pattern while keeping surface I/O
  separate.
- Org may share the same withdrawal state machine, but not the same self-service surface flow unless
  a future accepted decision introduces self-service org withdrawal.

## Consequences

- Do not use the current org route shape as evidence that org self-service withdrawal is planned.
- Tests for app and com withdrawal should cover equivalent behavior on both surfaces.
- Refactors should remove app/com business-logic drift rather than creating separate policy
  branches.
- Operational direct-message membership handling for org remains the documented behavior until a
  dedicated workflow supersedes it.
