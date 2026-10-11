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
2. Refresh/access token rows belong to a `device_session`.
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
