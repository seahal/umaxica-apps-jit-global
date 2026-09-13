# Log client_external_identities for replica reads

## Context

`GET /identity` on the app surface calls `AppleOnlyCredentialStatus`, which
reads `client_external_identities` through `AuthenticationCredentialInventory`.
`ClientExternalIdentity` inherits `AppPrincipalRecord`, which reads from
`app_zenith_replica`.

## Decision

`ALTER TABLE client_external_identities SET LOGGED`.

The table was created UNLOGGED. PostgreSQL hot standbys reject access to
UNLOGGED relations (`PG::FeatureNotSupported: cannot access temporary or
unlogged relations during recovery`). Identity bindings are durable login
state, not ephemeral event logs, so they belong on WAL and on the replica.

`client_apple_notification_events` stays UNLOGGED. It is not queried on the
identity GET path.

## Rejected alternative

Forcing `connected_to(role: :writing)` on the identity page would hide the
error without making the bindings replica-safe.
