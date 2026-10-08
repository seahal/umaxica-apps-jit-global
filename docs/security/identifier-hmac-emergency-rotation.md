# Identifier HMAC Emergency Rotation

## Purpose

Email and telephone identifiers are stored as encrypted values plus searchable HMAC digest columns.

This document defines the emergency response when an identifier HMAC key is suspected or confirmed
to be exposed.

Covered identifier models:

- `ClientEmail`, `OperatorEmail`, `VisitorEmail`
- `ClientTelephone`, `OperatorTelephone`, `VisitorTelephone`

Covered digest columns:

- `address_digest`
- `number_digest`

## Current Contract

The encrypted identifier columns are the readable source of truth:

- `address`
- `number`

The digest columns are search and uniqueness indexes only. Application search must use the digest
columns, not indexes on encrypted `address` or `number` values.

Email digest input must be normalized to lowercase before HMAC generation. Telephone digest input
must be normalized to E.164 before HMAC generation.

## Emergency Trigger

Start this procedure when any of the following is true:

- A selected `{APP,COM,ORG}_EMAIL_ADDRESS_HMAC_KEY` is exposed or suspected to be exposed.
- A selected `{APP,COM,ORG}_TELEPHONE_NUMBER_HMAC_KEY` is exposed or suspected to be exposed.
- Credentials, environment variables, logs, backups, or operator access paths may have leaked an
  identifier HMAC key.

Treat telephone HMAC exposure as especially sensitive because telephone numbers have a smaller
candidate space than email addresses.

## Response Policy

Identifier HMAC rotation is an outage operation.

Do not attempt a no-downtime HMAC key rotation with the current single digest column design. During
rotation, old-key and new-key digests for the same identifier are different values, so the database
unique index cannot enforce logical uniqueness across both versions.

The approved emergency response is:

1. Select exactly one realm and channel; stop all writes to that identifier model.
2. Put affected sign-in, sign-up, configuration, and staff-management paths into maintenance mode or
   stop the service.
3. Replace the exposed HMAC key with a new secret.
4. Recompute and overwrite the existing digest columns from the encrypted identifier values.
5. Verify that all target rows have current digests.
6. Restart the service with only the new HMAC key active.

## Rotation Steps

### 1. Freeze Identifier Writes

Block all code paths that can create or update the selected realm/channel model, including background
jobs and administrative writes. Do not stop unrelated realm/channel identifier flows merely because
their model schema looks similar. Maintenance admission must be enforced operationally before
running the recalculation; the recalculation does not itself freeze traffic.

At minimum, freeze:

- email sign-up and sign-in flows
- telephone sign-up and sign-in flows
- email and telephone configuration screens
- staff/operator email and telephone management
- visitor email and telephone registration flows

### 2. Replace Secrets

Rotate the affected secret values in the runtime secret store:

- `{APP,COM,ORG}_EMAIL_ADDRESS_HMAC_KEY`
- `{APP,COM,ORG}_TELEPHONE_NUMBER_HMAC_KEY`

Replace only the selected key. Old global SALT values are not read as a fallback.

Use a high-entropy random value. Do not reuse previous values.

### 3. Backfill In Place

Recompute the digest columns from decrypted model attributes.

After the selected write paths are frozen and the new key is configured, use the explicit server-side
operation. This example selects COM Telephone only; it is not a command executed in this change:

```bash
bin/rails 'identifier_hmac:rotate[com,telephone]'
```

The backfill must:

- read `address` / `number` through Active Record so Rails encryption decrypts the value;
- normalize through `IdentifierBlindIndex`;
- overwrite the same `address_digest` / `number_digest` column;
- avoid logging raw identifiers, HMAC keys, or full record attributes;
- process only the one selected realm/channel model; all five other result counts remain zero.

The command requires `IDENTIFIER_HMAC_MAINTENANCE_DATABASE_URL`, supplied securely by the
operator, for a separate authenticated maintenance connection to the same database, host and port
as the selected Source connection. It has no default or application-connection fallback. Normal
Rails tests and application startup do not require this variable. Do not put a connection URL in
command arguments or evidence records.

Each database has separate NOLOGIN caller and definer roles for each channel. Role names end in
the first twelve hexadecimal characters of SHA-256 of the database name at migration execution.
Database templates preserve the installed function owner and ACLs. The command reads that actual
owner from the PostgreSQL catalog, validates its selected realm/channel prefix and exact suffix
format, then selects only the matching caller role; it does not guess new privileges from a clone
name. An authorized operator
login needs SET membership in only the selected caller role; it must not inherit definer authority.
The migration grants no login memberships. Production membership changes are a separate
operational authorization, not part of this implementation.

The caller can execute only its channel's rotation function. The SECURITY DEFINER function has a
restricted search path and grants its owner only digest-column mutation and audit insertion. It
locks the Source row and compares the supplied previous digest before updating only its digest.
Owner, encrypted PII, binding state and timestamps remain immutable. Existing APP/COM binding
triggers recognize only the exact channel-specific definer and reject every other changed column.
There is no trigger-disable switch or exception flag.

The function also rejects an unexpected executing owner before any Source access. Rails structure
dumps omit PostgreSQL role ownership and ACLs, so a bare schema load does not restore maintenance
authority. Rebuild this privilege boundary from migrations under the explicitly authorized DDL
role, and verify actual ownership/grants before admitting maintenance. Do not treat a schema dump
as a security-role backup or grant a generic owner to make the command work. A misowned restored
function fails closed even when schema loading gives it PostgreSQL's default PUBLIC execution.

Every changed row inserts an atomic audit fact in the realm's identifier rotation audit table:
`id`, `operation_ref`, `channel`, `record_id`, `actor_role`, `occurred_at`. The actor is the actual
authenticated database session user, not the temporary SET ROLE. No identifier, digest, key or
connection secret is stored there. Unchanged digests create no audit event. Audit insertion failure
rolls back the digest update. Compare-and-swap conflicts stop the operation rather than overwriting
concurrent changes. A partial batch can be retried after investigation while admission stays closed;
already-current rows are no-ops. The audit is not user-facing account activity.

Migration rollback refuses a nonempty audit table instead of deleting authoritative evidence.
It does not restore old digest values or an exposed key. Audit erasure requires the applicable
separate legal/retention procedure; no permanent-retention assumption is introduced.

The function privilege model follows PostgreSQL's
[SECURITY DEFINER guidance](https://www.postgresql.org/docs/17/sql-createfunction.html) and
[role membership semantics](https://www.postgresql.org/docs/17/role-membership.html).

### 4. Verify Completeness

Before reopening traffic, verify:

- every nonblank `address` row has a nonblank `address_digest`;
- every nonblank `number` row has a nonblank `number_digest`;
- duplicate digest conflicts are resolved before the service starts;
- representative exact-match searches work for the selected realm/channel without changing other realms;
- targeted model tests for email and telephone identifiers pass.

### 5. Reopen Service

Restart application processes with only the new HMAC key configured.

Do not keep the exposed HMAC key in runtime configuration after the overwrite is complete.

## Non-Goals

This emergency procedure does not rotate Rails Active Record Encryption keys. Encryption key
rotation uses the Rails encryption key provider and previous-key support.

This procedure does not add parallel digest columns. The accepted emergency design overwrites the
current digest columns after writes are stopped.

## Operational Notes

If a future requirement needs no-downtime HMAC key rotation, introduce a separate design with either
parallel digest columns or an equivalent uniqueness-preserving transition mechanism. Do not retrofit
online rotation onto the single-column emergency procedure.

Related decision record:

- `adr/identifier-hmac-emergency-rotation.md`
