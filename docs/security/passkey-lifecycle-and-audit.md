# Passkey Lifecycle and Audit Contract

Passkeys are current-state credentials. APP, COM, and ORG each allow ten retained Passkeys per
owner. Registration goes through `PasskeyRegistrationOperation`, which locks the owner so the
model's count validation runs serialized; the database does not enforce the limit, and a write
outside the operation can exceed it (`plans/backlog/2026-10-19-passkey-limit-enforcement-gap.md`).

Settings removal and definitive sign-up cancellation delete the credential row. Withdrawal first
stops authentication and may revoke credentials during the recoverable period; retention purge
performs the later physical deletion after holds, dependencies, and FK ordering are checked. A
deleted credential can be registered again only after a new verified WebAuthn ceremony.

Each lifecycle fact is inserted into the surface principal database's Passkey audit outbox in the
same transaction as the credential mutation. `PasskeyAuditDeliveryJob` delivers the outbox to the
common Chronicle using an immutable `event_uuid`, checks the event identity, and acknowledges only
after the Chronicle row is present. Chronicle outages leave the source fact retryable; duplicate
delivery is idempotent. The delivery job's runtime and backlog still require operational evidence.

The outbox owns the `surface`, `external_id`, and `actor_ref` references. Additional metadata must
not contain any of those keys; the writer raises and rolls back the principal transaction when a
caller attempts to replace them. System events may omit the actor reference. Delivery preserves the
original occurrence time and target reference even after physical credential deletion.

New Passkey lifecycle events are not written to the legacy ClientChronicle or OperatorChronicle. The
APP Activity Log reads its legacy history and eligible common APP Passkey facts, filters both by the
current Client, and merges them at presentation time. Raw credential IDs, public keys, challenges,
tokens, OTPs, cookies, and unnecessary PII are never audit payloads. Passkey Chronicle retention
remains TBC.

See [the lifecycle ADR](../../adr/passkey-current-state-limit-and-chronicle-outbox.md) and the
[APP Activity Log implementation](../../app/presenters/base/identity/activity_log_presenter.rb).
