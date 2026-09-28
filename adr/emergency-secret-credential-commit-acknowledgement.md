# Emergency Secret Credential Commit Acknowledgement

## Status

Accepted

## Date

2026-09-26

## Context

The App Emergency Secret Credential (`ClientSecretCredential`, `secret_kind = "temporary_access"`,
`usage_policy = "single_use"`) lives in `app_zenith`. The app session it creates (`ClientToken`)
lives in `app_ticket`. Phase 7 of `plans/backlog/2026-09-24-integrated-auth-avatar-warp-plan.md`
keeps `/sign/in/emergency/credential` inactive until a durable claim is bound to a trusted,
same-operation proof that the session commit succeeded. No single transaction spans both databases.

The options were compared in
`plans/backlog/2026-09-25-avatar-image-and-emergency-credential-decisions.md` §2; the owner approved
option A (an operation record co-located with the session) on 2026-09-26, including its
`app_ticket` migration and the claim columns on the credential.

## Decision

`ClientEmergencySecretCredentialSignInOperation` implements three durable steps:

1. **Claim** (`app_zenith`): lock the credential row, refuse it when already claimed, consumed,
   revoked, locked, inactive, before `not_before_at`, at or after `discard_at`, or at the failure
   cap; verify the secret; on success write a new `claim_operation_id` (unique) and `claimed_at`.
   Only a secret mismatch increments `failure_count`, and the mismatch that reaches `max_failures`
   sets `locked_at`.
2. **Session and proof** (`app_ticket`): the session-creating block and a
   `client_emergency_sign_in_operations` row (`operation_id` unique, `credential_public_id` unique,
   `client_token_id` unique foreign key) commit in one transaction. That row is the only proof that
   the session committed.
3. **Consume** (`app_zenith`): mark the credential used only after observing the proof row for the
   same operation. Repeating it is idempotent.

Recovery rules:

- A crash, rollback, outage, or unknown outcome between the steps leaves the credential claimed.
  A claimed credential never verifies again, so it fails closed.
- `reconcile!` may only finish the claiming operation, and only when its proof row exists.
  Nothing un-claims a credential; an unfinished claim expires with `discard_at` and is removed by
  the existing retention purge.
- The unique `credential_public_id` makes a second session per credential impossible even for a
  caller that presents a fabricated operation id.

The five-minute absolute expiry and the five-failure cap come from Phase 7 of the canonical plan.

## Consequences

- One small table in `app_ticket` and two nullable columns plus a unique index on
  `client_secret_credentials` in `app_zenith`, all additive.
- An interrupted sign-in consumes the credential without a usable session; the user must issue a
  new Emergency Credential. This is the intended fail-closed trade-off.
- The endpoint remains inactive until issuance (authenticated app session with Step-Up), the Auth
  sign-in controller, and the Base session wiring call this operation. Those are tracked in the
  remaining-work ledger.

## Alternatives Considered

### Move the credential to `app_ticket`

Rejected: it would move an identity-owned credential out of the principal database, conflicting
with `adr/identity-authority-boundary.md`.

### Keep the endpoint disabled with no contract

Rejected by the owner decision; it leaves the feature permanently unavailable.
