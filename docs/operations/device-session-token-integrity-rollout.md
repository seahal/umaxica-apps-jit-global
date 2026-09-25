# Device Session and Token Reference Rollout

This plan covers only the `client`, `visitor`, and `operator` token/session pairs in
`app_ticket`, `com_ticket`, and `org_ticket`. The migrations are local and have been
applied to isolated task-owned databases only. Shared databases remain unchanged. A
checked-in structure snapshot does not establish the state of any connected database.

## Preconditions

For **each** physical target database, confirm the connection name, database name,
schema, PostgreSQL server version (15 or newer), current migration state, and the
definitions and validity of the affected indexes and foreign keys. Do this with a
read-only transaction and finite timeouts. Confirm an isolated disposable database
before applying migrations or creating synthetic records. Do not run the migrations
against a shared database as part of this task.

Count existing violations without recording row values:

```sql
-- Substitute the matching prefix (client/visitor/operator) and actor column.
SELECT count(*)
FROM client_tokens AS token
LEFT JOIN client_device_sessions AS session ON session.id = token.device_session_id
WHERE token.device_session_id IS NOT NULL AND session.id IS NULL;

SELECT count(*)
FROM client_device_sessions AS session
LEFT JOIN client_tokens AS token
  ON token.id = session.current_refresh_token_id
 AND token.device_session_id = session.id
WHERE session.current_refresh_token_id IS NOT NULL AND token.id IS NULL;

SELECT count(*)
FROM client_tokens AS token
JOIN client_device_sessions AS session ON session.id = token.device_session_id
WHERE token.user_id <> session.user_id;
```

Any nonzero count stops validation. Preserve the rows while their ownership and
retention contracts are investigated; do not synthesize a replacement session or
token. Check token/session actor correspondence separately before the actor
foreign key is validated. The first foreign key proves session existence; the
second proves that the current token belongs to that session. The final
composite foreign key proves token/session actor equality.

## Application and migration order

Deploy the application deletion behavior that removes tokens before sessions and
rejects direct session deletion while token history remains. Then, in each ticket
database, run the matching migrations in timestamp order:

1. `20260924150000`: create a unique `(device_session_id, id)` index concurrently,
   confirm it is valid and ready, then remove the old single-column index. An
   interrupted matching invalid index is replaced on retry; a conflicting index
   definition stops the migration.
2. `20260924151000`: add the token-to-session `RESTRICT` foreign key and the
   deferred same-session current-token foreign key as `NOT VALID`. These constrain
   new writes immediately; they are not a compatibility window for old writers.
3. `20260924152000`: validate the token-to-session foreign key.
4. `20260924153000`: validate the current-token ownership foreign key. This is a
   separate transaction so the first validation does not hold its table lock
   through the second validation.
5. `20260924154000`: concurrently create the unique `(actor_id, id)` session
   index required by the actor foreign key. Retain the existing single-column
   actor index pending workload measurements; its role may differ.
6. `20260924155000`: add the token `(actor_id, device_session_id)` to session
   `(actor_id, id)` foreign key as `NOT VALID` with `ON DELETE RESTRICT`.
7. `20260924156000`: validate that actor foreign key in its own transaction.

The concurrent index step uses session-level `lock_timeout = 5s` and
`statement_timeout = 30min` and restores their previous settings. The foreign-key
steps use transaction-local timeouts with the same values. A timeout or violation
stops that database's sequence. Inspect migration state and constraint/index
validity before retrying; do not force a success marker. A long validation must
remain bounded by the statement timeout. Do not kill a shared blocker or remove
unrelated objects.

## Recovery and verification

If validation fails, the `NOT VALID` foreign key remains enforced for new writes.
Resolve historical violations under an explicitly approved data treatment and
rerun only the pending validation migration. Rolling the application back to code
that nullifies token references during session deletion is incompatible with the
new `RESTRICT` foreign key. A database rollback must first establish an approved
replacement lifecycle and retention outcome; dropping validated constraints is
not a routine inverse of validation.

In an isolated disposable database, verify both an upgrade from the immediate
prechange schema with synthetic records and a fresh load from regenerated
structure dumps. Compare column types, nullability, defaults, indexes, foreign
keys, validation status, and representative create/rotate/revoke/delete behavior.
Only generate structure dumps from that isolated database. The three task-owned
database targets passed migration and fresh structure-load checks; independent-
connection race cases and an actual deployment remain unverified.
