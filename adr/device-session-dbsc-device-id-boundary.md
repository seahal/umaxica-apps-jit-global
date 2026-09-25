# Device Session, DBSC, And Device ID Boundary

## Status

Accepted (2026-05-20)

> **Partial supersession (2026-06-02):** Session and refresh-token authority ownership in this ADR
> is superseded by `adr/acme-session-and-token-authority.md`. The stable device-session, DBSC, and
> device-id vocabulary remains useful, but `acme/www` owns user sessions, refresh token families,
> device/session listing, compromise state, and step-up freshness. `sign/id` must not issue,
> refresh, rotate, revoke, list, or display user sessions.

## Context

Auth session state previously treated the surface token row (`ClientToken` / `OperatorToken` /
`VisitorToken`) as the effective session record. That worked while a token row was both the login
session and the refresh-token carrier, but it makes the following concepts drift together:

- `sid` in access-token / OIDC payloads;
- refresh-token rotation rows;
- browser `device_id` compatibility identity;
- DBSC device-bound proof state;
- DPoP / JKT possession binding;
- current-session logout vs all-session revocation.

This is especially fragile because refresh-token rotation creates a new token row. A stable login
session cannot be modeled cleanly if every refresh also creates a new "session" identity.

At the same time, `device_id` is not a cryptographic proof. It is an application-issued cookie value
used for compatibility, display, and device distinction. It can be copied. DBSC is a separate
browser/OS-backed proof based on non-exportable key material and is not the same concept as
`device_id`.

## Decision

Introduce `device_sessions` as the durable session container for authentication sessions.

`device_session` is **not** the `device_id`. It is the record that owns the stable login/device
session identity and the binding attributes attached to that session.

The intended ownership model is:

```text
device_sessions.public_id
  -> access token sid

device_sessions
  -> device_id_digest
  -> dbsc_session_id_digest / dbsc_public_key_thumbprint / dbsc_bound_at
  -> dpop_jkt
  -> refresh_token_family_id
  -> current_refresh_token_id

ClientToken / OperatorToken / VisitorToken
  -> device_session_id
```

Rules:

1. `sid` represents `device_sessions.public_id`, not token row `public_id`.
2. Refresh/access token rows issued by flows that use a `device_session` carry its ID. The database
   column remains nullable for token records whose established contract has no device session;
   nullability does not authorize a flow that uses a session to fall back to another authentication
   path.
3. Normal logout revokes the current `device_session` and token rows linked to it.
4. Normal logout must not revoke every token for the actor.
5. All-session clear remains an explicit configuration/session-management action.
6. `device_id` is a fallback/display/compatibility identifier only.
7. Browser refresh must not trust header `device_id` when the cookie is absent.
8. API usage of header `device_id` requires a proof layer such as DPoP/JKT.
9. Once a `device_session` becomes DBSC-bound, refresh requires DBSC proof.
10. DBSC and `device_id` are distinct attributes attached to the same `device_session`.

Surface databases remain separate. The model layer therefore uses surface-specific models
(`ClientDeviceSession`, `OperatorDeviceSession`, `VisitorDeviceSession`) over per-surface
`device_sessions` tables rather than one cross-surface model.

## PostgreSQL reference enforcement (2026-09-24)

The `app_ticket`, `com_ticket`, and `org_ticket` databases each own their token and device-session
tables. Their references are local to each physical database; no cross-database foreign key is
created.

For session-aware token rows, nullable `tokens.device_session_id` references the matching
`device_sessions.id` with `ON DELETE RESTRICT`. The existing token history remains many-to-one with
the session. The unique index on `(device_session_id, id)` supports the composite reference below
and replaces the former non-unique index on `device_session_id`; it does not make the session ID
unique by itself.

The nullable `device_sessions.current_refresh_token_id` remains optional. A deferred composite
foreign key from `(device_sessions.id, device_sessions.current_refresh_token_id)` to
`(tokens.device_session_id, tokens.id)` ensures a non-null pointer identifies a token in that same
session at transaction commit. PostgreSQL's default `MATCH SIMPLE` permits a null current-token
pointer. Deleting the pointed token sets only `current_refresh_token_id` to null, preserving the
session row. Deleting a session while any token still references it is restricted. The Rails
association uses `dependent: :restrict_with_exception` to preserve the same rule for model deletes;
actor deletion continues to remove tokens before device sessions.

Migration rollout has three stages in each ticket database:

1. Build the composite unique index concurrently, then remove the replaced one-column token index.
2. Add both foreign keys as `NOT VALID`. They enforce new writes while existing rows remain unchecked.
3. Validate the token-to-session foreign key in its own migration.
4. Validate the current-token ownership foreign key in another migration. Each validation stops if
   existing rows violate its reference contract; neither migration rewrites or guesses at ownership.

At the request boundary, an access token whose token row names a missing or inactive device session
is rejected. The token actor and, when present, session actor must match the access-token subject.
Sessionless token kinds remain valid under their existing contract. A further composite foreign key
from `(tokens.actor_id, tokens.device_session_id)` to `(device_sessions.actor_id,
device_sessions.id)` enforces token/session actor equality in each ticket database. The actor column
is `user_id`, `visitor_id`, or `staff_id` on its respective surface. A unique index on the matching
session `(actor_id, id)` pair supports this foreign key; nullable `device_session_id` retains the
established sessionless-token shape.

The index migration uses a five-second lock timeout and a thirty-minute statement timeout. It
compares a same-named index's key definitions (including order, collation, and operator class),
access method, uniqueness/null semantics, included-column and predicate/expression state, and
valid/ready state before resuming or replacing an interrupted index build. An unexpected definition
stops the migration for inspection. Constraint addition and validation use the same finite lock and
statement timeouts inside their migration transactions. Validation is monotonic in PostgreSQL; its
down migration is a no-op, and rolling back the preceding migration removes the constraints.

This migration requires PostgreSQL 15 or newer because it uses a column list with
`ON DELETE SET NULL`. PostgreSQL 15 documents that syntax in its
[CREATE TABLE reference](https://www.postgresql.org/docs/15/sql-createtable.html). PostgreSQL 17
documents the `NOT VALID` then `VALIDATE CONSTRAINT` rollout in its
[ALTER TABLE reference](https://www.postgresql.org/docs/17/sql-altertable.html). Rails documents
the single-column foreign-key migration interface and deferrable options in its
[Active Record Migrations guide](https://guides.rubyonrails.org/active_record_migrations.html); the
same-session ownership rule therefore uses explicit SQL for its composite foreign key.

## Consequences

Future removal of `device_id` is localized. The `device_session` record remains as the login session
container, while `device_id` cookie issuance, `device_id_digest`, fallback policy, and UI display
can be removed without changing the core `sid`, refresh family, DBSC, or logout-current model.

DBSC can mature independently. When browser support is ready, DBSC proof material can become the
primary binding on `device_session` while non-DBSC sessions remain explicit fallback sessions.

Token rows become refresh/access issuance records, not the canonical session identity. This reduces
confusion around rotation and keeps current-session logout aligned with the stable session record.

Existing token rows require compatibility and backfill during rollout. Until that is complete,
lookup code may need to accept legacy token public identifiers as a fallback.

## Related

- `adr/logout-primitive-and-composition.md`
- `adr/session-reset-on-privilege-transition.md`
- GH issue #610
- `docs/architecture/dbsc.md`
- `docs/architecture/dpop.md`
