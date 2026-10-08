# Identifier HMAC Emergency Rotation

## Status

Accepted on 2026-05-18.

Amended on 2026-10-07 by [realm-separated identifiers](realm-separated-identifiers-and-dead-history.md):
rotation requires an explicit realm and channel and visits only that one identifier model.
The six dedicated HMAC KEY names replace the two global SALT names. The maintenance freeze is
scoped to the selected realm/channel; no cross-realm write or global rotation is implied.

Amended on 2026-10-08 under the owner's explicit limited-DDL and maintenance authorization:
recalculation uses a separate explicit PostgreSQL maintenance connection and channel-scoped
SECURITY DEFINER functions, not ordinary model updates. The normal binding writer remains
immutable. Each function can mutate only its digest column, checks the previous digest while
holding the Source lock, and inserts an atomic internal audit fact. The scoped definer and caller
roles are NOLOGIN; the migration creates no login memberships. Definer membership, general
trigger disabling, owner/PII/binding changes and exception flags are excluded.

The internal ledger contains only `id`, `operation_ref`, `channel`, `record_id`, `actor_role` and
`occurred_at`. It is append-only during normal operation and stores the authenticated session
role, not PII, digests or keys. Failed audit insertion rolls back the update; unchanged digests
produce no event. Nonempty audit tables prevent destructive migration rollback until the separate
retention procedure is resolved. Production role provisioning and secret changes remain outside
this local implementation authorization. The updated operational runbook describes the dedicated
command and restricted connection requirements.

## Context

Email and telephone records store two forms of the same identifier:

- an encrypted readable value, such as `address` or `number`;
- a searchable HMAC digest, such as `address_digest` or `number_digest`.

The digest exists because encrypted attributes should not be queried directly. Exact-match lookup
and uniqueness are enforced through the digest columns.

The repository intentionally uses HMAC-SHA256 for identifier digests. The digest must be
deterministic to support exact-match search. Password-hash style random salts are not suitable for
this use case because the application must be able to derive the same lookup value from the user's
submitted identifier.

Rails Active Record Encryption key rotation covers the encrypted identifier values. It does not
rotate the HMAC keys used for the digest columns.

## Decision

If an identifier HMAC key is exposed or suspected to be exposed, rotation is handled as an emergency
outage procedure.

The application will stop writes to the affected realm/channel identifier records, replace the exposed HMAC
key, and overwrite the existing digest columns in place from the encrypted source values.

The current design does not add `address_digest_v2`, `number_digest_v2`, or equivalent parallel
columns for emergency rotation.

The explicitly selectable model set is:

- `ClientEmail`, `OperatorEmail`, `VisitorEmail`
- `ClientTelephone`, `OperatorTelephone`, `VisitorTelephone`

The affected columns are:

- `address_digest`
- `number_digest`

## Rationale

The single-column overwrite procedure preserves the current schema and keeps search code simple.

Adding versioned digest columns would allow a more gradual transition, but it increases schema and
query complexity for a rare emergency path. The chosen approach accepts a maintenance window instead
of carrying permanent rotation columns.

During rotation, old-key and new-key digests for the same identifier are different database values.
With only one digest column, the database unique index cannot enforce logical uniqueness across both
versions while old and new digests coexist. For that reason, online rotation is not accepted for
this design.

## Consequences

- HMAC key exposure requires service interruption for affected identifier write paths.
- The backfill must read encrypted `address` and `number` values through Active Record and overwrite
  `address_digest` / `number_digest` with values derived from the new HMAC key.
- Runtime configuration must not keep the exposed HMAC key after the in-place overwrite is complete.
- Search and uniqueness logic remain based on a single current digest column.
- A future no-downtime requirement must introduce a separate design, likely with parallel digest
  columns or another uniqueness-preserving transition mechanism.

## Related

- `docs/security/identifier-hmac-emergency-rotation.md`
- `docs/reference/active-record-encryption-rotation.md`
