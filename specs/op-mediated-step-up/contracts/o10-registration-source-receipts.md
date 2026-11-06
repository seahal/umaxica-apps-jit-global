# O-10 credential registration source receipts

Status: implementation design accepted by the owner on 2026-11-05. Additive implementation is
authorized; the verification, migration preflight, audit and retention gates below remain required
before activation.

## Scope and observed behavior

This proposal covers APP / ORG passkey registration and APP TOTP enrollment finalization in
`IdentityPasskeyRegistrationFinalCommitter` and `IdentityTotpEnrollmentFinalCommitter`. Bootstrap
retains its existing purpose and remains outside the ordinary Step-Up requirement; this proposal
changes only the cross-database commit and recovery boundary.

Both writers currently acquire the principal actor lock before OP row locks. They then commit OP
candidate, ticket and Auth-ceremony consumption before the enclosing principal transaction commits
the credential. Their current retry paths recognize a credential only after OP consumption has
stored its credential reference. O-10 requires the credential source transaction to commit while the
OP authority locks remain held, with no writes to the OP authorization transaction.

`ClientPasskeyAuditOutbox` and `OperatorPasskeyAuditOutbox` already persist the registration's
`operation_ref` (the Step-Up transaction ID), actor reference and credential external ID in the same
source transaction as the passkey. The operation reference is not unique. TOTP credentials have no
corresponding operation receipt, and `IdentityTotpEnrollmentFinalCommitter` does not write the
direct `IdentityAudit` event that the older `IdentityTotpCeremonyFinalCommitter` wrote after
credential creation. The moved TOTP path therefore also needs its accounting destination resolved.

The Ruby model chain places `ClientTotpCredential` on `AppZenithRecord`
(`AppPrincipalRecord < AppZenithRecord`). Its generated schema comment still says
`Database name: app_principal`; the current `db/app_zenith_structure.sql` worktree diff removes its
table definitions, so this proposal relies on the model connection owner and migration path, not
that stale annotation or dump.

## Proposed source receipt shapes

### Passkey

Before, each realm's existing source event has the same shape:

```text
passkey_audit_outbox = {
  event_uuid: uuid, event_type: string, surface: string,
  external_id: uuid, actor_ref: string?, operation_ref: string?,
  metadata: jsonb, occurred_at: timestamp, acknowledged_at: timestamp?
}
```

After: retain that row shape and add a partial unique index on `operation_ref` for the two
registration event types (`passkey.registered.signup`, `passkey.registered.settings`) when the
reference is nonempty. Existing non-registration events keep their current reuse and nullability
rules. The APP and ORG event columns, vocabularies, callers and API shapes do not otherwise change.

The existing row is the source receipt: a match must include the operation reference, exact event
type, surface, actor reference and credential external ID. The writer also compares the registered
credential to the still-retained OP candidate before returning an existing active credential. A
receipt mismatch, more than one receipt, a missing credential, or a candidate mismatch never causes
another credential insert.

This is an additive uniqueness constraint, not a backfill. Migration preflight must report any
existing duplicate registration operation references; the migration must fail closed if any remain.

### TOTP

Before: `client_totp_credentials` has no operation reference; there is no enrollment receipt table.

After, add an APP Zenith source receipt table, with no corresponding ORG table because ORG has no
TOTP enrollment:

```text
client_totp_registration_receipts = {
  id: bigint PK,
  operation_ref: string NOT NULL UNIQUE,
  credential_id: bigint NOT NULL UNIQUE REFERENCES client_totp_credentials(id),
  candidate_digest: string NOT NULL,
  created_at: timestamp NOT NULL
}
```

`operation_ref` is the immutable OP Step-Up transaction ID. `credential_id` points to the APP Zenith
credential created by that exact transaction. `candidate_digest` is the existing 64-character
SHA-256 digest of the operation-bound candidate, constrained to 64 lowercase hexadecimal characters
by a database check, never its raw TOTP secret. The actor is derived from the credential's `user_id`
and must match the actor on the locked OP transaction. `created_at` records source receipt creation;
row existence after a fresh writer read proves the source transaction committed. There is no tuple
or new enum. All persisted state is represented by a non-null row and non-null fields; receipt rows
are immutable and retained for operation recovery.

The table is additive and starts empty; no existing credential is backfilled or rewritten. Its
foreign key prevents deleting the credential row while an operation receipt still refers to it; the
existing credential lifecycle uses explicit status transitions for removal.

## Proposed commit and recovery order

1. Open the OP authority transaction without acquiring an OP row lock. Acquire the Zenith actor lock
   first, then the device, root, grant and operation rows in the accepted order. Recheck the exact
   session, event, purpose, candidate and policy while those locks are held. The OP authority
   transaction performs locking reads but does not update the authorization facts.
2. If an exact source receipt already exists, validate its actor, purpose, operation reference and
   source credential. Do not repeat the source write. Reconcile the OP registration outcome through
   the separate receipt-backed finalization step below.
3. Otherwise, commit the credential and source receipt together while the OP authority locks are
   still held. Passkey registration writes its existing outbox row; TOTP inserts its proposed
   receipt with the credential. No network request is made in this interval.
4. End the OP authority transaction. Only afterward, use a separate OP writer transaction to consume
   the registration candidate/ticket and complete the Auth ceremony. If this finalization fails or
   its acknowledgement is lost, return an indeterminate result. A retry reads the source receipt on
   a fresh connection and may finalize the same OP transaction, but never repeats the credential
   write. Receipt-backed reconciliation is not a new authorization and must not require the expired
   Auth ceremony to become active again; the OP transaction must still match the same actor,
   session, purpose and candidate digest.
5. A lost source commit acknowledgement is resolved from a fresh source writer connection by the
   exact receipt. A matching receipt proves the already committed write; an absent or unreadable
   receipt is indeterminate and must not be treated as rollback. Audit delivery uncertainty never
   repeats the credential mutation.

This leaves an unavoidable cross-database interval between the source commit and OP finalization,
but the source receipt makes that interval idempotently recoverable. It does not claim an atomic
commit across databases. Failure to release the read-only OP authority transaction after confirmed
source commit is reported as a confirmed source outcome with a diagnostic, consistent with revision
13; receipt-backed OP finalization remains retryable.

## Verification and activation gates

- Confirm that receipt-backed OP finalization may complete the original operation after the Auth
  ceremony expires, provided the same actor, session, purpose and candidate still match. This is
  required to avoid an unrecoverable committed-credential / pending-OP state.
- Confirm the TOTP receipt should be the only source result receipt, or specify whether the moved
  TOTP write also needs a transactional audit outbox and delivery path. Preserve the existing
  `totp.enable` user-activity event if that remains part of the accepted contract. The current
  new-path committer does not emit it.
- Review whether the passkey audit outbox retention permits it to remain the durable registration
  receipt for the full recovery lifetime. Its current source rows are not deleted by normal
  delivery; verify the retention/purge call graph before activation.
- Before migration, inspect the configured APP/ORG Zenith stores for duplicate registration
  `operation_ref` values and preserve the already-dirty schema-dump work. Do not regenerate or
  replace `db/app_zenith_structure.sql` as part of this design review.
- Public tests must cover each realm's successful source-first order; source rollback; lost source
  acknowledgement; exact receipt replay; wrong actor/session/purpose/candidate receipt; concurrent
  revocation waiting on the authority locks; OP finalization rollback and lost acknowledgement;
  post-source ceremony expiry; passkey duplicate receipt refusal; and TOTP credential slot
  contention. If the reviewed TOTP receipt also becomes its audit outbox, add Chronicle retry,
  duplicate acknowledgement and retention tests before activation.
