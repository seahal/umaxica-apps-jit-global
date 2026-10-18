# Remembered Account Projection and Store Boundary

## Status

Proposed; deferred (2026-10-07). This records a design direction for future work. Nothing in it is
implemented, scheduled, or committed, and no migration, schema, route, cookie, or authentication
flow changes with it.

The feature is a wanted improvement that ranks below IdP core authentication, authorization, and
RBAC work. Implementation tasks and open questions are tracked in
`plans/backlog/remembered-account-chooser.md`.

Applies `adr/preference-scope-and-browser-persistent-state-separation.md`, which already names
"accounts previously used in this browser" as state that needs its own cookie and server-side
storage. It leaves `adr/logout-primitive-and-composition.md` and `adr/logout-ceremony-boundary.md`
unchanged.

Each statement below is labeled as one of:

- **Direction** — the current intent, to be honored unless a later ADR revises it.
- **Candidate** — a plausible option that is not decided.
- **Open** — undecided; listed in the backlog plan.

## Context

- We want the sign-in screen to be able to list accounts that were previously used in the same
  browser, including after sign-out, as consumer identity providers commonly do.
- Storing user information itself in cookies or other client-side storage is undesirable.
- The identity source of truth (the `*_zenith` databases) should not become part of the normal
  access path of an unauthenticated account chooser.
- Adding new database infrastructure for this feature alone is disproportionate today.

## Proposed Direction

### 1. Remembered accounts are not sessions

**Direction.** The authentication session and the memory of previously used accounts are separate
concepts with separate lifecycles.

- Sign-out revokes sessions and tokens. It may leave remembered-account data in place.
- Removing a remembered account and signing out are distinct operations. Neither implies the other.
- Remembered-account data carries no authentication authority. Selecting a remembered account only
  preselects who is about to authenticate; the full sign-in ceremony still runs.

### 2. The browser holds only an opaque identifier

**Direction.** The browser keeps a long-lived cookie holding one short, opaque, random identifier
with sufficient entropy. The cookie contains no user information and no credential. The data it
refers to lives in server-side storage.

**Candidate.** `Secure`, `HttpOnly`, an appropriate `SameSite` value, and the `__Host-` prefix, in
line with `adr/cookie-domain-scope-by-surface.md`.

**Open.** The cookie name, lifetime, identifier format, and whether this identifier is the reserved
`continuity` cookie or a separate dedicated cookie.

### 3. The stored data is a projection created at sign-in

**Direction.** When a sign-in completes successfully, the minimum information the account chooser
needs is copied from the identity source of truth into a remembered-account snapshot.

- The snapshot is an independent projection generated at sign-in time. It is not a cache of the
  identity source of truth.
- Rendering the account chooser does not assume a read of the identity source of truth to refresh or
  complete the snapshot.
- Copied attributes are selected by allow-list. An attribute that is not on the list is not copied.

**Candidate** allow-list (the schema is open):

- remembered browser identifier
- an opaque subject reference dedicated to this purpose
- display name
- masked login identifier
- avatar reference
- snapshot or version metadata
- creation, last-use, and expiry timestamps

**Direction.** The following are never copied: password hashes, WebAuthn credential secrets, TOTP
secrets, recovery codes, access tokens, refresh tokens, authorization codes, password-reset state,
and any other value that can authenticate a person.

### 4. The logical boundary is independent from the start

**Direction.** Remembered-account storage is its own logical boundary regardless of where it
physically lives.

- No join with token or session tables is assumed.
- No foreign key to refresh-token or access-token rows.
- No foreign key to identity or user rows, as a default. `adr/cross-db-reference-policy.md` already
  forbids native foreign keys across database boundaries; this direction extends the same
  independence to tables that happen to share a database.
- Remembered-account lifetime is not shared with token lifetime. Retention and expiry are defined
  separately.
- The database access role can be separated later.
- Callers reach the data through a storage abstraction that hides its physical placement.

**Candidate** shape of that abstraction, here called `RememberedIdentityStore`. The name, methods,
and interface are illustrative only:

- put or upsert a snapshot
- list or get by remembered browser identifier
- remove one remembered account
- forget the browser (remove all)
- expire old snapshots

### 5. Physical placement is provisional

**Direction.** For now, the remembered-account tables would be co-located in the existing token
database rather than in a new physical database. In this repository's current naming that is the
`*_ticket` role (`docs/architecture/database-boundaries.md`).

This is a temporary physical placement chosen to avoid new database infrastructure. It is not a
permanent architecture decision, and remembered-account data does not become part of the token
subsystem's data model.

```text
Now (provisional)                     Later (target)

Identity DB                           Identity DB
Token DB                              Token DB
  - token / session data              Remembered Identity DB
  - remembered identity data
```

The goal is to make that physical separation possible with minimal impact on application code.

**Open.** The criteria that trigger the physical separation, and how the provisional tables are
isolated inside the token database (separate schema, separate role, or naming only).

## Security Properties

These are the properties the eventual design must hold. They are requirements on future work, not
claims about current behavior.

- Disclosure of remembered-account data alone does not allow authentication.
- Tampering with the browser cookie alone does not authenticate as any user.
- Lateral access from the account chooser to identity, credential, and token data is minimized.
- Copied attributes are allow-listed.
- Removing a remembered account and signing out can be performed independently.
- Remembered-account state stays inside the surface that created it, consistent with the `app`,
  `org`, and `com` trust boundaries.

## Consequences

- Display information can temporarily differ from the identity source of truth, for example after a
  display-name or avatar change.
- Profile display data is duplicated.
- Cleanup and expiry handling are required.
- While the data is co-located with the token database, the blast radius is not fully separated.
- The account chooser gains a boundary that does not read the identity source of truth directly.
- The later move to a dedicated physical database costs less.
- The data is personal data held for an unauthenticated screen, so privacy, account-enumeration, and
  tracking risks must be assessed before implementation. That assessment is open.

## Related

- `plans/backlog/remembered-account-chooser.md`
- `adr/preference-scope-and-browser-persistent-state-separation.md`
- `adr/cookie-domain-scope-by-surface.md`
- `adr/cross-db-reference-policy.md`
- `adr/logout-primitive-and-composition.md`
- `adr/logout-ceremony-boundary.md`
- `adr/base-auth-ceremony-and-seven-rp-boundary.md`
- `adr/retainable-concern-and-retention-purge.md`
- `adr/retention-lifecycle-column-boundary.md`
- `docs/architecture/database-boundaries.md`
- `docs/architecture/model-database-inventory.md`
