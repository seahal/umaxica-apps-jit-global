# WU-A4 XDB-04 TOTP rename audit shape review

## Contract gap

`IdentityTotpNameCommitter` consumes target-bound OP Step-Up and then saves the title in App Zenith,
but it writes no authoritative audit in that Zenith transaction. `two.md` §6.1 XDB-04 requires the
TOTP title mutation and its audit to commit together. The existing Contact outbox is limited to
Email/Telephone events; the Passkey outbox is limited to Passkey lifecycle facts. Using either for a
TOTP rename would misstate the event.

## Proposed shape, pending owner approval

Add an App Zenith `client_totp_audit_outboxes` table and `ClientTotpAuditOutbox` model. Store only:

- unique `event_uuid`;
- constrained `event_type = totp.renamed`;
- nonblank opaque `owner_ref`, `credential_ref`, and UUID `operation_ref`;
- required Zenith `occurred_at`;
- NOT NULL `delivery_status_id` referencing immutable local `pending` / `delivered` rows.

The event contains no TOTP secret, title, or other credential payload. The rename writer creates the
event after the OP transaction commits and the title changes, inside the existing App Zenith
transaction. A failed event insert rolls back the title while the independently committed Step-Up
remains spent. A no-op rename emits no event and consumes no Step-Up.

Add a bounded App TOTP audit delivery job. It writes a Chronicle event with `event_uuid` as the
idempotency key, `totp.renamed` as the action, the operation reference as `request_id`, and only the
opaque references as metadata. On retry it verifies the prior Chronicle event's complete identity
before marking the source row `delivered`. A poison event does not prevent later rows from being
attempted; the job preserves the existing bounded-page/high-water delivery contract.

## Local impact and recovery

The proposed outbox and status tables are new and require no data backfill. Production and Neon are
excluded. If approved, apply the additive migrations only to local App Development and Test Zenith
databases, regenerate only the App Zenith schema dump, and verify the targeted test selection. The
migration rollback must refuse to drop source rows once any TOTP audit event has been recorded;
after that point, repair is forward-only. Before any event is written, rollback may drop the empty
new tables.

## Pending decision

Owner approval is required for the persisted shape and local migration execution. Until then, do not
add the tables, model, writer call, delivery job, or migration. Existing XDB-04 transaction-order,
target-binding, device, HTTP dependency-failure, and final Zenith-commit evidence remains useful but
does not close the missing audit contract.
