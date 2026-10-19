# Passkey Ten-Credential Limit Is Not Enforced by the Database

Recorded 2026-10-19. Status: accepted gap, revisit before relying on the limit as a security
boundary.

## Decision that created the gap

On 2026-10-19 the user chose a count check under the owner lock over the finite-slot design that
two.md REQ-P02 had specified (`registration_slot SMALLINT NOT NULL`, CHECK 1..10, unique
owner/slot). Reason: numbering every existing Passkey row needs a data backfill migration and
slot-assignment code, which the user judged too large for the benefit. The decision is recorded in
`adr/passkey-current-state-limit-and-chronicle-outbox.md` and six.md.

Current enforcement:

- `PasskeyRegistrationOperation` locks the owning identity (Client, Visitor or Operator) and saves
  the Passkey in the same principal transaction, so the model count validation runs serialized for
  that owner.
- `ClientPasskey`, `VisitorPasskey` and `OperatorPasskey` validate on create that the owner has
  fewer than ten rows.
- `test/security/invariants/passkey_registration_writer_invariant_test.rb` rejects direct
  `create`/`insert`/`upsert` calls on Passkey models or associations in `app/` and `lib/`.

## What is not covered

The limit holds only for writes through `PasskeyRegistrationOperation`. These can exceed ten
Passkeys for one owner:

- Active Record writes that skip the operation, such as `save` on a hand-built record outside the
  operation, `insert_all`/`upsert_all`, Rails console sessions, seeds and fixtures. Plain `save`
  still runs the count validation, but without the owner lock, so two concurrent saves can both
  pass.
- Any non-Active Record write: raw SQL, `psql`, other services or database tools.

The invariant guard is a text check. It does not detect a write that builds a record with `new` and
calls `save` outside the operation.

## Revisit when

- another service, job or tool writes Passkey tables directly;
- the limit becomes a security or abuse boundary rather than a product limit;
- the limit changes (the constants are `MAX_PASSKEYS_PER_USER`, `MAX_PASSKEYS_PER_VISITOR` and
  `MAX_PASSKEYS_PER_STAFF`).

Options at that point: a BEFORE INSERT trigger that locks the owner and counts (needs an explicit
exception to REQ-P04's "no count trigger" rule), or the finite-slot design with a backfill
migration.
