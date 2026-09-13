# Authentication Method Lock

## Status

Superseded by `adr/unified-enforcement.md` (2026-07-27)

## Supersedes

This ADR is retained for traceability of the 2026-07-26 decision. Its runtime contract (mode
taxonomy, method-scoped session revocation, hidden-freeze response discipline, break-glass-only
permanent-freeze release, operator lockout prevention) is absorbed into Authentication Method Effect
in `adr/unified-enforcement.md`. Its storage design (a per-`(principal, method)` lock table as its
own SSOT) is replaced by the Enforcement Case model.

This ADR also contains three claims about repository state that a subsequent audit found do not
hold: `established_authentication_method` did not exist at the time of writing despite being
described as already carried by session tokens; no credential foreign key cascades on delete; and
the sibling trigger-usage-boundary ADR's function count was miscounted. These are corrected in
`adr/unified-enforcement.md` and, for the trigger ADR, in `adr/database-trigger-usage-boundary.md`
directly. The text below is left unedited as the historical record of what was accepted on
2026-07-26.

## Context

`adr/administrative-access-lock.md` introduced `admin_locked`, an account-wide access state. It is
all-or-nothing: an admin-locked account cannot sign in by any means, all of its sessions are
revoked, and `token_valid_after_at` invalidates every outstanding access token.

That is the correct instrument for "this account must stop," and the wrong instrument for "this
account's passkey is compromised." Today there is no way to disable one authentication method while
leaving the others working. Operators either take the whole account down or do nothing.

Three separate concerns are frequently conflated, and this ADR names them so they stay apart:

1. **Authentication Method Lock** — one principal, one authentication method. The subject of this
   ADR.
2. **Administrative Access Lock** — the whole account. Already decided in
   `adr/administrative-access-lock.md`. Not modified here.
3. **Identity Freeze** — forbidding _reuse_ of an identifier value (an email address, a telephone
   number, a Google `sub`, an Apple `sub`, an `identity_id`) by anyone. A later phase. This ADR is
   constrained to leave room for it.

The repository already carries a method-level vocabulary in `AuthenticationCredentialInventory`, but
it is AAL-shaped (`aal1_methods`, `aal2_methods`, `contact_identifiers`) and exists to answer "may
this credential be removed without stranding the user?" — not "may this method be used at all?"
`AuthMethodGuard` is the removal gate built on top of it. Neither carries operator attribution, an
expiry, or a visibility setting.

Per-credential status enums (`ClientPasskeyStatus::DISABLED`,
`ClientTotpCredentialStatus::INACTIVE`, `ClientEmailStatus::SUSPENDED`) look like candidates but are
owned by the credential lifecycle and are written by the withdrawal anonymizer. Overloading them
would make an operator action indistinguishable from a withdrawal side effect.

## Decision

Introduce **Authentication Method Lock**: state keyed on `(principal, authentication method)` that
independently controls whether the method may be used to authenticate, whether it may be added,
changed, or removed, and whether its credentials may ever be deleted.

### Lockable methods are a per-surface registry, not a global constant

The three surfaces do not offer the same methods, and pretending otherwise would create unreachable
state:

- `app` / `Client` — `email`, `telephone`, `secret`, `passkey`, `totp`, `google`, `apple`
- `com` / `Visitor` — `email`, `telephone`, `secret`, `passkey`
- `org` / `Operator` — `email`, `telephone`, `secret`, `passkey`, `entra`

`entra` is org's principal federated login and is lockable for the same reasons the others are.

The method is identified by a **stable symbol**, never by a credential table or row id. Social
credential storage is mid-migration from per-provider tables to a common external-identity table; a
lock keyed on a row would not survive that cutover.

`aal1` and `aal2` are not lockable. They describe an authentication _result_; the lock applies to
the concrete method that produced it.

### Lock modes

Three modes, crossed with expiry and visibility, express the six required behaviours.

| Mode                 | Login     | Add / change / remove | Credential deletion | Ordinary operator revocation |
| -------------------- | --------- | --------------------- | ------------------- | ---------------------------- |
| `change_locked`      | allowed   | forbidden             | allowed             | allowed                      |
| `unusable`           | forbidden | forbidden             | allowed             | allowed                      |
| `permanently_frozen` | forbidden | forbidden             | **forbidden**       | **forbidden**                |

`expires_at` present means the lock lapses on its own; `expires_at` null means it persists until
revoked. A permanent freeze must have a null `expires_at`.

`visibility` is `visible` or `hidden`, and `hidden` is only meaningful for a permanent freeze.

At most one active lock exists per `(principal, method)`. Escalating or de-escalating revokes the
current lock and records a new one, so the history is append-only in the audit trail.

### Granularity is the principal-method pair

A lock applies to a method, not to an individual credential row. This is required by the change-lock
behaviour: forbidding the _addition_ of a method the principal does not yet have is not expressible
as a flag on a row that does not exist. Per-row locking, if it is ever needed, is an additive column
on the same table.

### Session revocation is method-scoped

Setting `unusable` or `permanently_frozen` revokes only the sessions attributable to that method.
Sessions established by other methods survive, and the account's `access_state` and
`token_valid_after_at` are never touched. An Authentication Method Lock must never behave like an
Administrative Access Lock.

This requires knowing which method established a session, which the token tables did not record.
They now carry `established_authentication_method`. Sessions predating that column have no recorded
method and are treated as unknown: the first lock applied to a principal revokes them. This is
scoped to the affected principal, never fleet-wide.

TOTP is a step-up factor rather than a primary one. Making `totp` unusable revokes sessions holding
a TOTP step-up in full, not merely their step-up state. This is deliberately stricter than "revoke
only sessions derived from the target method," and it is the accepted trade-off: a session whose
elevation rests on a compromised authenticator is itself suspect. AAL downgrade machinery is
explicitly not introduced.

### Permanent freeze survives deletion

A permanently frozen credential must not be removed by the user, by an ordinary operator action, by
withdrawal, by privacy erasure, or by retention purge. Controller guards are insufficient, and model
callbacks alone are insufficient because the retention purge uses `delete_all` and several foreign
keys cascade on delete.

Enforcement is therefore layered: controller guard, model callback, and a database trigger. The
trigger precedent is decided separately in `adr/database-trigger-usage-boundary.md`.

Where a permanent freeze conflicts with a privacy erasure or retention obligation, the freeze wins
and the credential's personal data is anonymised in place, reusing the existing withdrawal
anonymization path. The row and its identifier hash survive; the plaintext identifier does not. The
surviving hash is what a future Identity Freeze needs as its seed.

### Permanent freeze is not revocable by ordinary means

No ordinary operator action, policy grant, or user request removes a permanent freeze. A separate,
explicitly audited break-glass path exists, because a lock applied in error is a certainty over a
long enough horizon and a wholly irreversible state would push its correction outside the audit
boundary. A break-glass revocation is flagged as such in both the lock record and the audit event.

### Operator lockout prevention

No lock may be applied that would leave the target principal with zero usable primary authentication
methods; the existing credential inventory answers this. Operators may not apply a method lock to
themselves at all. An operator whose own credential is compromised escalates to another operator or
to the break-glass path; the org runbook names the route.

### Error contract

Internal fixed error codes are `authentication_method_locked.unusable`, `.change_locked`, and
`.permanently_frozen`. Application logic uses the codes. Display text is never used for business
decisions.

User-facing copy stays deliberately weak, so it cannot be mistaken for an account-level or
identity-level action:

- login blocked — "this authentication method cannot currently be used"
- change blocked — "this authentication method cannot currently be changed"

A hidden permanent freeze produces no lock-specific signal at all. Its response is identical to an
ordinary authentication failure in status, error code, body, and redirect, and it is produced by the
same code path so that response timing does not distinguish it. Nothing about a hidden freeze
reaches user-facing logs, notifications, or analytics.

## Audit Contract

Lock, revoke, expiry, and denial events are audit and security records, not application log lines.
They are persisted in the existing operator-action audit table alongside administrative access lock
events, which already requires operator attribution and a fixed reason code and therefore cannot
record an unattributed lock.

Each event carries at least: realm and surface; principal type and id; authentication method; lock
mode; visibility; `effective_at`; `expires_at`; applying operator id; reason code; optional note;
optional ticket reference; `revoked_at`; revoking operator id; whether the revocation used break
glass; occurrence time; and sanitized metadata.

Reason codes are reused from `AdministrativeAccessLockable::ADMIN_LOCK_REASON_CODES` rather than
redefined; the operational vocabulary for "why did an operator restrict this account" does not
change because the scope narrowed.

Permanent-freeze events are retained indefinitely, and the audit contract records that they are not
ordinarily revocable. The existence and reason of a hidden freeze must not appear in any
user-reachable surface.

## Consequences

- Two distinct lock mechanisms now exist. `admin_locked` remains the account-wide instrument and
  continues to block every method; Authentication Method Lock never reads or writes `access_state`
  or `token_valid_after_at`. Code that conflates them will produce an account-wide outage from a
  method-scoped action.
- Sessions now record the authentication method that established them. This also repairs the `amr`
  claim, which was previously derived from the token kind and was empty in practice.
- The repository gains database triggers for the first time, with the scope and testing obligations
  set by `adr/database-trigger-usage-boundary.md`.
- Retention purge and privacy erasure acquire a new skip condition. Erasure is no longer
  unconditional, and the legal basis for retaining a frozen credential must be documented alongside
  the existing legal-hold exception.
- The lock tables are surface-scoped and key on the principal. A future Identity Freeze keys on
  identifier values with no principal foreign key, so the two occupy disjoint tables, names, and
  responsibilities.
- Per-credential-row locking is not available. Freezing one of several passkeys requires the
  additive column noted above.

## Related

- `adr/administrative-access-lock.md`
- `adr/database-trigger-usage-boundary.md`
- `adr/authentication-assurance-level-boundaries.md`
- `adr/retainable-concern-and-retention-purge.md`
- `adr/retention-lifecycle-column-boundary.md`
- `adr/acme-session-and-token-authority.md`
- `adr/application-logging-boundary.md`
- `docs/security/observability-boundary.md`
- `docs/security/withdrawal-privacy-erasure.md`
